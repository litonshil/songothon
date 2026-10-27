.PHONY: up down restart logs build backend-run migrate-up migrate-down flutter-run test tidy

up:
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose down && docker compose up -d --build

logs:
	docker compose logs -f

build:
	docker compose build

backend-run:
	cd backend && CONFIG_FILE_PATH=config.local.json go run . serve

migrate-up:
	cd backend && CONFIG_FILE_PATH=config.local.json go run . migrate up

migrate-down:
	cd backend && CONFIG_FILE_PATH=config.local.json go run . migrate down

flutter-run:
	cd mobile && flutter run

test:
	cd backend && go test ./...
	cd mobile && flutter test

tidy:
	cd backend && go mod tidy
