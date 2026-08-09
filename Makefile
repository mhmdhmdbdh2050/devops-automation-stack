.PHONY: up down restart logs backup restore health build clean

up:
	docker-compose up -d

down:
	docker-compose down

restart:
	docker-compose down
	docker-compose up -d

logs:
	docker-compose logs -f

backup:
	./scripts/backup.sh

restore:
	./scripts/restore.sh $(FILE)

health:
	./scripts/healthcheck.sh

build:
	docker-compose build --no-cache

clean:
	docker-compose down -v
