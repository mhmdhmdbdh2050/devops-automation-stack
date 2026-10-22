.PHONY: up down restart logs backup restore health build clean reset-data

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

backup:
	./scripts/backup.sh

restore:
	@test -n "$(FILE)" || (echo "Usage: make restore FILE=backups/backup.sql.gz"; exit 2)
	./scripts/restore.sh "$(FILE)"

health:
	./scripts/healthcheck.sh

build:
	docker compose build --no-cache

clean:
	docker compose down

reset-data:
	@test "$(CONFIRM)" = "yes" || (echo "This deletes the PostgreSQL volume. Run: make reset-data CONFIRM=yes"; exit 2)
	docker compose down -v
