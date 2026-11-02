import json
import os
from pathlib import Path

os.environ.setdefault("DB_HOST", "127.0.0.1")
os.environ.setdefault("DB_NAME", "tasksdb")
os.environ.setdefault("DB_USER", "postgres")
os.environ.setdefault("DB_PASS", "ci-only-password")
os.environ.setdefault("REDIS_HOST", "127.0.0.1")

import pytest

from app.app import app, get_db_connection, r


@pytest.fixture(scope="session", autouse=True)
def initialize_database():
    schema = (Path(__file__).parents[1] / "init.sql").read_text(encoding="utf-8")
    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(schema)


@pytest.fixture(autouse=True)
def clean_state():
    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("TRUNCATE tasks RESTART IDENTITY")
    r.delete("tasks")


@pytest.fixture
def client():
    app.config.update(TESTING=True)
    return app.test_client()


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_tasks_cache_and_invalidation(client):
    first = client.get("/tasks")
    assert first.get_json() == {"source": "db", "tasks": []}

    cached = client.get("/tasks")
    assert cached.get_json() == {"source": "cache", "tasks": []}

    created = client.post("/tasks", json={"title": "  Review CI  "})
    assert created.status_code == 201
    assert created.get_json() == {"message": "Task added"}
    assert r.get("tasks") is None

    refreshed = client.get("/tasks")
    assert refreshed.get_json() == {
        "source": "db",
        "tasks": [{"id": 1, "title": "Review CI", "done": False}],
    }


@pytest.mark.parametrize("payload", [{}, {"title": "  "}, {"title": 7}, None])
def test_invalid_task_title_returns_400(client, payload):
    response = client.post("/tasks", data=json.dumps(payload), content_type="application/json")
    assert response.status_code == 400
    assert response.get_json() == {"error": "A non-empty title is required"}
