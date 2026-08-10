# DevOps Automation Stack

A production-inspired containerized backend project built with Docker Compose, Flask, PostgreSQL, Redis, and Nginx.

This project was built as a practical DevOps learning project to understand how multiple services can work together in a containerized environment.

The project currently demonstrates:

- Docker containerization
- Docker Compose orchestration
- Flask backend development
- PostgreSQL database integration
- Redis caching
- Nginx reverse proxy
- Docker networking
- Persistent Docker volumes
- Environment variable management
- Container health checks
- Service dependencies
- Database initialization
- Basic operational automation
- Git and GitHub workflow

---

## 📌 Project Overview

The application is a simple task management backend.

The Flask application provides API endpoints for retrieving and creating tasks.

PostgreSQL is used as the primary database, while Redis is used as a temporary cache layer.

Nginx acts as a reverse proxy and provides the public entry point to the application.

All services are managed using Docker Compose.

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
All services communicate through a dedicated Docker bridge network:
backend

Docker's internal DNS allows services to communicate using their service names.
For example:
app → db:5432
app → redis:6379
nginx → app:5000

No hard-coded container IP addresses are required.

❤️ Health Checks
The project uses Docker health checks for the core services.
PostgreSQL
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]

Redis
healthcheck:
  test: ["CMD", "redis-cli", "ping"]

Flask Application
The Flask application exposes:
GET /health

which returns:
{
  "status": "ok"
}

Docker checks the endpoint using Python:
http://localhost:5000/health

The application therefore becomes:
Up (healthy)

when the health check succeeds.

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
DB_PASS=your_password

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
DB_PASS=your_password

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
tasks_db       Up (healthy)
tasks_redis    Up (healthy)
tasks_app      Up (healthy)
tasks_nginx    Up


🌐 Access the Application
The application is accessible through Nginx:
http://localhost:8080


❤️ Test the Health Endpoint
Run:
curl http://localhost:8080/health

Expected response:
{
  "status": "ok"
}


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

The Redis task cache is cleared after creating a new task so that subsequent requests retrieve fresh data.

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

The script creates a compressed PostgreSQL backup.
Example:
backup_2026-08-10_01-30-00.sql.gz

The .gz extension indicates gzip compression.

♻️ Database Restore
The project also contains:
scripts/restore.sh

Usage:
./scripts/restore.sh <backup-file.sql.gz>

Example:
./scripts/restore.sh backup_2026-08-10_01-30-00.sql.gz

The restore workflow validates the backup and restores the SQL dump into PostgreSQL.

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
Depending on the commands implemented in the current Makefile, common operations can include:
make up
make down
make build
make logs
make health
make backup

Check the available commands with:
cat Makefile


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
docker network inspect devops-automation-stack_backend

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
Internal services communicate through the dedicated:
backend

network.

🧪 Validation Performed
The current project has been tested with the following workflow:
docker compose config

to validate the Compose configuration.
The complete stack was then built and started using:
docker compose up -d --build

Container health was verified using:
docker compose ps

The application successfully reached:
Up (healthy)

for the Flask container.
The API was tested through Nginx:
curl http://localhost:8080/tasks

The first request successfully retrieved data from PostgreSQL:
source: db

A subsequent request successfully retrieved the cached data from Redis:
source: cache

This confirmed communication between the four services.

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
Automated testing
HTTPS
Docker Secrets
Non-root containers
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