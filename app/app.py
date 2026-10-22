import json
import logging
import os
from contextlib import closing

import psycopg2
import redis
from flask import Flask, jsonify, request

app = Flask(__name__)
app.logger.setLevel(logging.INFO)

DB_HOST = os.environ.get("DB_HOST", "db")
DB_NAME = os.environ.get("DB_NAME", "tasksdb")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASS = os.environ.get("DB_PASS", "")
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")

r = redis.Redis(
    host=REDIS_HOST,
    port=6379,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
)


def get_db_connection():
    if not DB_PASS:
        raise RuntimeError("DB_PASS must be set through the environment.")
    return psycopg2.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        connect_timeout=3,
    )


def read_cache():
    try:
        cached = r.get("tasks")
    except redis.RedisError:
        app.logger.warning("Redis read failed; falling back to PostgreSQL.")
        return None

    if cached is None:
        return None

    try:
        tasks = json.loads(cached)
    except (json.JSONDecodeError, TypeError):
        app.logger.warning("Redis contained invalid task cache; falling back to PostgreSQL.")
        try:
            r.delete("tasks")
        except redis.RedisError:
            app.logger.warning("Could not remove invalid task cache.")
        return None

    return tasks if isinstance(tasks, list) else None


def write_cache(tasks):
    try:
        r.setex("tasks", 30, json.dumps(tasks))
    except redis.RedisError:
        app.logger.warning("Redis write failed; serving tasks from PostgreSQL.")


@app.get("/health")
def health():
    """Liveness check: the Flask process is responding."""
    return jsonify({"status": "ok"}), 200


@app.get("/ready")
def ready():
    """Readiness check: required database and cache dependencies respond."""
    checks = {"database": "ok", "redis": "ok"}
    try:
        with closing(get_db_connection()) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
    except (psycopg2.Error, RuntimeError):
        app.logger.warning("Readiness check failed for PostgreSQL.")
        checks["database"] = "unavailable"

    try:
        r.ping()
    except redis.RedisError:
        app.logger.warning("Readiness check failed for Redis.")
        checks["redis"] = "unavailable"

    status_code = 200 if all(value == "ok" for value in checks.values()) else 503
    status = "ready" if status_code == 200 else "not_ready"
    return jsonify({"status": status, "checks": checks}), status_code


@app.get("/tasks")
def get_tasks():
    cached = read_cache()
    if cached is not None:
        return jsonify({"source": "cache", "tasks": cached}), 200

    try:
        with closing(get_db_connection()) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT id, title, done FROM tasks;")
                rows = cursor.fetchall()
    except (psycopg2.Error, RuntimeError):
        app.logger.exception("Could not read tasks from PostgreSQL.")
        return jsonify({"error": "database_unavailable"}), 503

    tasks = [{"id": row[0], "title": row[1], "done": row[2]} for row in rows]
    write_cache(tasks)
    return jsonify({"source": "db", "tasks": tasks}), 200


@app.post("/tasks")
def add_task():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "json_object_required"}), 400

    title = data.get("title")
    if not isinstance(title, str):
        return jsonify({"error": "title_must_be_a_string"}), 400

    title = title.strip()
    if not title:
        return jsonify({"error": "title_must_not_be_empty"}), 400
    if len(title) > 255:
        return jsonify({"error": "title_must_be_255_characters_or_less"}), 400

    try:
        with closing(get_db_connection()) as connection:
            with connection:
                with connection.cursor() as cursor:
                    cursor.execute(
                        "INSERT INTO tasks (title, done) VALUES (%s, %s);",
                        (title, False),
                    )
    except (psycopg2.Error, RuntimeError):
        app.logger.exception("Could not add task to PostgreSQL.")
        return jsonify({"error": "database_unavailable"}), 503

    try:
        r.delete("tasks")
    except redis.RedisError:
        app.logger.warning("Task was saved, but Redis cache invalidation failed.")

    return jsonify({"message": "Task added"}), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
