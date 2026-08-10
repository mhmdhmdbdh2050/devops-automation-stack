from flask import Flask, jsonify, request
import psycopg2
import redis
import os
import json

app = Flask(__name__)

# read the data from environment variables
DB_HOST = os.environ.get("DB_HOST", "db")
DB_NAME = os.environ.get("DB_NAME", "tasksdb")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASS = os.environ.get("DB_PASS", "postgres")

REDIS_HOST = os.environ.get("REDIS_HOST", "redis")

r = redis.Redis(host=REDIS_HOST, port=6379, decode_responses=True)

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASS
    )

@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200

@app.route("/tasks", methods=["GET"])
def get_tasks():
    cached = r.get("tasks")
    if cached:
        return jsonify({"source": "cache", "tasks": json.loads(cached)})

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, title, done FROM tasks;")
    rows = cur.fetchall()
    cur.close()
    conn.close()

    tasks = [{"id": row[0], "title": row[1], "done": row[2]} for row in rows]
    r.setex("tasks", 30, json.dumps(tasks))  # كاش لمدة 30 ثانية
    return jsonify({"source": "db", "tasks": tasks})

@app.route("/tasks", methods=["POST"])
def add_task():
    data = request.get_json()
    title = data.get("title")

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO tasks (title, done) VALUES (%s, %s);", (title, False))
    conn.commit()
    cur.close()
    conn.close()

    r.delete("tasks")
    return jsonify({"message": "Task added"}), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
