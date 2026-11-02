.PHONY: up down restart logs backup restore health build clean

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

logs:
	docker compose logs -f

backup:
	./scripts/backup.sh

restore:
	@test -n "$(FILE)" || (echo 'Usage: make restore FILE=backups/backup.dump' >&2; exit 2)
	./scripts/restore.sh --replace "$(FILE)"

health:
	./scripts/healthcheck.sh

build:
	docker compose build --no-cache

clean:
	@read -r -p 'This permanently deletes the PostgreSQL volume. Type DELETE to continue: ' answer; \
	  test "$$answer" = DELETE || { echo 'Cancelled.'; exit 1; }
	docker compose down --volumes
