import json
import unittest
from unittest.mock import MagicMock, patch

import psycopg2
import redis

import app as app_module


class TaskApiTests(unittest.TestCase):
    def setUp(self):
        app_module.app.config.update(TESTING=True)
        self.client = app_module.app.test_client()

    @staticmethod
    def database_connection(rows=None):
        connection = MagicMock()
        connection.__enter__.return_value = connection
        cursor = connection.cursor.return_value.__enter__.return_value
        cursor.fetchall.return_value = rows or []
        return connection, cursor

    def test_liveness_does_not_require_dependencies(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"status": "ok"})

    def test_readiness_checks_database_and_redis(self):
        connection, cursor = self.database_connection()
        with patch.object(app_module, "get_db_connection", return_value=connection), patch.object(
            app_module.r, "ping", return_value=True
        ):
            response = self.client.get("/ready")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"status": "ready", "checks": {"database": "ok", "redis": "ok"}})
        cursor.execute.assert_called_once_with("SELECT 1;")
        connection.close.assert_called_once()

    def test_readiness_returns_503_when_dependency_is_unavailable(self):
        with patch.object(
            app_module, "get_db_connection", side_effect=psycopg2.OperationalError("unavailable")
        ), patch.object(app_module.r, "ping", side_effect=redis.ConnectionError()):
            response = self.client.get("/ready")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json["status"], "not_ready")
        self.assertEqual(response.json["checks"]["database"], "unavailable")
        self.assertEqual(response.json["checks"]["redis"], "unavailable")

    def test_cached_tasks_do_not_query_database(self):
        tasks = [{"id": 1, "title": "Compose", "done": False}]
        with patch.object(app_module.r, "get", return_value=json.dumps(tasks)), patch.object(
            app_module, "get_db_connection"
        ) as get_db_connection:
            response = self.client.get("/tasks")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"source": "cache", "tasks": tasks})
        get_db_connection.assert_not_called()

    def test_database_results_are_served_when_redis_is_unavailable(self):
        connection, cursor = self.database_connection([(1, "Compose", False)])
        with patch.object(app_module.r, "get", side_effect=redis.ConnectionError()), patch.object(
            app_module.r, "setex", side_effect=redis.ConnectionError()
        ), patch.object(app_module, "get_db_connection", return_value=connection):
            response = self.client.get("/tasks")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"source": "db", "tasks": [{"id": 1, "title": "Compose", "done": False}]})
        cursor.execute.assert_called_once_with("SELECT id, title, done FROM tasks;")
        connection.close.assert_called_once()

    def test_post_rejects_invalid_titles(self):
        cases = [("not-json", "application/json"), ({}, None), ({"title": "  "}, None), ({"title": "x" * 256}, None), ({"title": 42}, None)]
        for payload, content_type in cases:
            with self.subTest(payload=str(payload)[:30]):
                response = self.client.post("/tasks", data=payload, content_type=content_type)
                self.assertEqual(response.status_code, 400)

    def test_post_saves_trimmed_title_even_if_cache_invalidation_fails(self):
        connection, _ = self.database_connection()
        transaction = connection.__enter__.return_value
        cursor = transaction.cursor.return_value.__enter__.return_value
        with patch.object(app_module, "get_db_connection", return_value=connection), patch.object(
            app_module.r, "delete", side_effect=redis.ConnectionError()
        ):
            response = self.client.post("/tasks", json={"title": "  Learn Docker  "})
        self.assertEqual(response.status_code, 201)
        cursor.execute.assert_called_once_with("INSERT INTO tasks (title, done) VALUES (%s, %s);", ("Learn Docker", False))
        connection.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
