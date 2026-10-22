# DevOps Automation Stack

A learning project for operating a small Flask API with Docker Compose, PostgreSQL, Redis, and Nginx. It is not a production deployment template.

## Quick start

Requirements: Docker Engine with the Compose plugin and Git Bash, WSL, or another Bash shell for the helper scripts.

```bash
git clone https://github.com/mhmdhmdbdh2050/devops-automation-stack.git
cd devops-automation-stack
cp .env.example .env
```

Set a unique local `DB_PASS` in `.env`, then start the stack:

```bash
docker compose up -d --build
docker compose ps
curl -i http://localhost:8080/ready
```

The API is available through Nginx at `http://localhost:8080`. `/health` is a liveness endpoint; `/ready` checks PostgreSQL and Redis. Set `APP_PORT` in `.env` if host port 8080 is already occupied. See the sections below for API examples, backup and restore, troubleshooting, and cleanup.

To run the API unit tests and configuration checks:

```bash
docker build --target test -t devops-automation-stack-app-test ./app
docker run --rm devops-automation-stack-app-test
docker compose --env-file .env.example config --quiet
bash -n scripts/backup.sh scripts/restore.sh scripts/healthcheck.sh
```

`docker compose down` removes this project's containers and networks while preserving the PostgreSQL volume. Use the documented explicit reset command only when you intend to delete the project's data.

---

## 📌 Project Overview

The Flask API lists and creates tasks. PostgreSQL stores the tasks, Redis caches list responses, and Nginx is the only service exposed to the host. Nginx and Flask share a frontend network; Flask, PostgreSQL, and Redis share a backend network.

---

## 🏗️ Architecture

```text
                         Client
                           │
                           │ HTTP :8080
                           ▼
                  ┌─────────────────┐
                  │      Nginx      │
                  │ Reverse Proxy   │
                  │      :80        │
                  └────────┬────────┘
                           │
                           │ HTTP :5000
                           ▼
                  ┌─────────────────┐
                  │   Flask App     │
                  │      :5000      │
                  └───────┬─────────┘
                          │
                 ┌────────┴────────┐
                 │                 │
                 ▼                 ▼
        ┌─────────────────┐ ┌─────────────────┐
        │   PostgreSQL    │ │      Redis      │
        │      :5432      │ │      :6379      │
        └────────┬────────┘ └─────────────────┘
                 │
                 ▼
          Docker Volume
             db_data

Request Flow
Client
   │
   ▼
localhost:8080
   │
   ▼
Nginx
   │
   ▼
Flask Application
   │
   ├──────────────► PostgreSQL
   │
   └──────────────► Redis


🧰 Technologies
Technology
Purpose
Docker
Containerization
Docker Compose
Multi-container orchestration
Python
Application runtime
Flask
Backend web framework
PostgreSQL 16
Relational database
Redis 7
In-memory cache
Nginx
Reverse proxy
Bash
Automation scripts
Git
Version control
GitHub
Source code hosting

📁 Project Structure
devops-automation-stack/
│
├── app/
│   ├── app.py
│   ├── tests/
│   │   └── test_app.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── nginx/
│   └── nginx.conf
│
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── healthcheck.sh
│
├── .env.example
├── .gitignore
├── docker-compose.yml
├── init.sql
├── Makefile
└── README.md


🐳 Docker Compose Services
The project consists of four main services.
1. PostgreSQL
PostgreSQL is used as the primary relational database.
image: postgres:16

The database uses a persistent Docker volume:
db_data

The database data is stored inside the container at:
/var/lib/postgresql/data

PostgreSQL also has a Docker health check using:
pg_isready


2. Redis
Redis provides an in-memory caching layer.
image: redis:7-alpine

Redis has its own health check:
redis-cli ping

Expected response:
PONG


3. Flask Application
The backend application is built from:
./app

The Flask application listens internally on:
5000

The application is not directly exposed to the host.
Instead, requests are routed through Nginx.
The application connects to PostgreSQL using the Docker service name:
db

and Redis using:
redis


4. Nginx
Nginx acts as the reverse proxy.
The host exposes:
8080

which is mapped to Nginx:
80

Therefore:
localhost:8080
        ↓
Nginx :80
        ↓
Flask :5000

The Nginx configuration is mounted as read-only:
./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro


🌐 Docker Networking
The stack uses separate frontend and backend bridge networks. Nginx and Flask share the frontend network; Flask, PostgreSQL, and Redis share the backend network. Nginx cannot connect directly to the database or cache. Docker DNS lets services use their Compose names, such as `app → db:5432` and `app → redis:6379`.

❤️ Health Checks
PostgreSQL checks that its configured database accepts connections, and Redis uses `redis-cli ping`. Flask separates `GET /health` (process liveness) from `GET /ready` (PostgreSQL and Redis readiness). Compose uses `/ready` before reporting the app healthy and starting Nginx.

🔄 Service Dependencies
The application waits for PostgreSQL and Redis to become healthy.
depends_on:
  db:
    condition: service_healthy
  redis:
    condition: service_healthy

Nginx also waits for the Flask application to become healthy:
depends_on:
  app:
    condition: service_healthy

The startup flow is therefore:
PostgreSQL
     │
     ▼
  Healthy
     │
     ▼
   Redis
     │
     ▼
  Healthy
     │
     ▼
 Flask App
     │
     ▼
  Healthy
     │
     ▼
   Nginx

This helps reduce startup race conditions between services.

🔐 Environment Variables
Database configuration is provided through environment variables.
Example:
DB_NAME=tasksdb
DB_USER=postgres
DB_PASS=replace_with_a_random_local_password

The actual .env file is intended for local use only.
The repository contains:
.env.example

instead of real credentials.
The real:
.env

should not be committed to GitHub.

🚀 Getting Started
Prerequisites
Make sure the following are installed:
Docker
Docker Compose
Git
Docker Compose is included with modern Docker installations as:
docker compose


1. Clone the Repository
git clone https://github.com/mhmdhmdbdh2050/devops-automation-stack.git

Enter the project directory:
cd devops-automation-stack


2. Configure Environment Variables
Create a local .env file:
cp .env.example .env

Edit the file and configure the database credentials:
DB_NAME=tasksdb
DB_USER=postgres
DB_PASS=replace_with_a_random_local_password

Do not commit the real .env file.

3. Build and Start the Stack
Run:
docker compose up -d --build

Docker Compose will:
Create the network.
Create the PostgreSQL container.
Create the Redis container.
Build the Flask application image.
Start the Flask application.
Start Nginx.
Create the persistent PostgreSQL volume.

🔍 Check Container Status
Run:
docker compose ps

Expected result:
db       Up (healthy)
redis    Up (healthy)
app      Up (healthy)
nginx    Up


🌐 Access the Application
The application is accessible through Nginx:
http://localhost:8080

Set `APP_PORT` in `.env` to choose a different host port if 8080 is already in use.


❤️ Test the Health Endpoint
Run:
curl http://localhost:8080/health

Expected response:
{
  "status": "ok"
}

`/health` checks process liveness only. Use `/ready` to confirm PostgreSQL and Redis readiness.


📋 API Endpoints
GET /health
Checks whether the Flask application is responding.
GET /health

Example:
curl http://localhost:8080/health

Response:
{
  "status": "ok"
}

GET /ready
Checks whether PostgreSQL and Redis respond. Returns HTTP 503 when either dependency is unavailable.

Example:
curl -i http://localhost:8080/ready


GET /tasks
Returns the available tasks.
GET /tasks

Example:
curl http://localhost:8080/tasks

The response includes the source of the data:
{
  "source": "db",
  "tasks": [
    {
      "id": 1,
      "title": "Learn Docker Compose",
      "done": false
    }
  ]
}


⚡ Redis Caching
The /tasks endpoint uses Redis as a caching layer.
The first request retrieves the data from PostgreSQL:
{
  "source": "db"
}

The result is then stored in Redis for 30 seconds.
A subsequent request can return:
{
  "source": "cache"
}

This demonstrates a basic cache-aside pattern.
The flow is:
GET /tasks
     │
     ▼
 Check Redis
     │
     ├── Cache HIT
     │      │
     │      ▼
     │    Return cached data
     │
     └── Cache MISS
            │
            ▼
       Query PostgreSQL
            │
            ▼
       Store in Redis
            │
            ▼
       Return data

When a new task is created, the cache is invalidated.

➕ Create a Task
The API supports creating tasks through:
POST /tasks

Example:
curl -X POST http://localhost:8080/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Docker Networking"}'

Expected response:
{
  "message": "Task added"
}

The application attempts to clear the Redis task cache after saving a task. If Redis is unavailable, the task is still saved and the cached response may remain until its 30-second TTL expires.

The request must contain a JSON object with a non-empty `title` of at most 255 characters; invalid input returns HTTP 400.

💾 Database Persistence
PostgreSQL uses a named Docker volume:
db_data

Check volumes:
docker volume ls

Inspect the volume:
docker volume inspect devops-automation-stack_db_data

The volume allows database data to survive container recreation.

🗄️ Database Initialization
The project contains:
init.sql

which is mounted into PostgreSQL:
./init.sql:/docker-entrypoint-initdb.d/init.sql

PostgreSQL executes initialization scripts from this directory when the database is initialized for the first time.

💾 Database Backup
The project contains a backup script:
scripts/backup.sh

Run:
./scripts/backup.sh

The script creates a compressed PostgreSQL backup using Compose, validates a temporary gzip archive before publishing it, and removes archives older than seven days. The dump includes cleanup statements so restoring can replace objects captured in the backup. Set `RETENTION_DAYS` to change retention.

♻️ Database Restore
The project also contains:
scripts/restore.sh

Usage:
make restore FILE=backups/backup_20260810_013000_1234.sql.gz

The script validates the archive, requires interactive confirmation, and imports SQL in one transaction. It replaces objects included in the dump, but does not drop the database itself. Review the configured target before confirming.

🩺 Service Health Check Script
The project contains:
scripts/healthcheck.sh

Run:
./scripts/healthcheck.sh

The script is intended to provide an operational check of the project services.

🛠️ Makefile
The project also includes a:
Makefile

which provides shortcuts for common project operations.
The Makefile provides shortcuts for common operations, including:
make up
make down
make build
make logs
make health
make backup

Check the available commands with:
cat Makefile

`make clean` preserves the database volume. To intentionally delete database data, run `make reset-data CONFIRM=yes`.


📊 Useful Docker Commands
List running containers
docker ps

List all containers
docker ps -a

Check Compose services
docker compose ps

View logs
docker compose logs

Follow logs
docker compose logs -f

View application logs
docker compose logs app

View Nginx logs
docker compose logs nginx

View PostgreSQL logs
docker compose logs db

View Redis logs
docker compose logs redis


🔎 Inspect Docker Network
List networks:
docker network ls

Inspect the project network:
docker network ls --filter "label=com.docker.compose.network=backend"

This can be used to inspect service connectivity and Docker DNS information.

🛑 Stop the Project
To stop the services:
docker compose down

This removes the containers and network while keeping the named PostgreSQL volume.

⚠️ Remove Database Data
To remove containers and the database volume:
docker compose down -v

Warning: This permanently removes the PostgreSQL data stored in the Docker volume.
Use this only when intentionally resetting the project database.

🔐 Security Considerations
The project follows several basic security practices.
Environment Variables
Database credentials are provided through environment variables instead of being hard-coded in the Compose configuration.
.env Protection
The real .env file should remain local and should not be pushed to GitHub.
Only:
.env.example

should be included in the repository.
Internal Services
PostgreSQL and Redis are not directly exposed to the host.
The public entry point is Nginx:
8080 → 80

Read-Only Nginx Configuration
The Nginx configuration is mounted read-only:
./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro

Docker Network
Nginx is not attached to the backend network, so it cannot initiate connections directly to PostgreSQL or Redis.

🧪 Local Validation Procedure
The GitHub Actions workflow validates Compose configuration, shell syntax, API unit tests, and the application image build. Run the checks locally:

```bash
docker compose --env-file .env.example config --quiet
bash -n scripts/backup.sh scripts/restore.sh scripts/healthcheck.sh
docker build --target test -t devops-automation-stack-app-test ./app
docker run --rm devops-automation-stack-app-test
docker compose --env-file .env.example build app
docker compose up -d --build
docker compose ps
curl http://localhost:8080/tasks
```

Expected: PostgreSQL, Redis, and Flask report healthy; Nginx is running. The first `/tasks` response should report `source: db`; a subsequent request within 30 seconds can report `source: cache`.

📚 DevOps Concepts Demonstrated
This project demonstrates practical understanding of:
Docker containers
Docker images
Docker Compose
Multi-container applications
Docker bridge networks
Docker service discovery
Container-to-container communication
Docker named volumes
PostgreSQL
Redis
Redis caching
Flask
Nginx reverse proxy
Environment variables
Docker health checks
Service dependencies
Database initialization
Database backup
Database restore
Bash scripting
Makefile automation
Container troubleshooting
Git
GitHub

🚧 Future Improvements
The project can be extended later as additional DevOps concepts are learned.
Possible future improvements include:
CI/CD with GitHub Actions
HTTPS
Docker Secrets
Container resource limits
Image vulnerability scanning
Prometheus monitoring
Grafana dashboards
Centralized logging
Alerting
Automated backup scheduling
Backup retention policies
Deployment to AWS
Infrastructure as Code with Terraform
Kubernetes deployment
These features are not currently implemented and are listed only as future improvements.

🎯 Learning Objectives
The main objective of this project is to build practical DevOps experience by running a multi-service application in a containerized environment.
The project focuses on understanding the complete lifecycle of a small containerized application:
Build
  ↓
Configure
  ↓
Run
  ↓
Connect Services
  ↓
Health Check
  ↓
Cache
  ↓
Backup
  ↓
Restore
  ↓
Troubleshoot


👨‍💻 Author
Mohamed Ahmed Abdo
