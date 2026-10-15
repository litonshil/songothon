.PHONY: up down restart logs build backend-run flutter-run test tidy

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
	cd backend && go run cmd/api/main.go

flutter-run:
	cd mobile && flutter run

test:
	cd backend && go test ./...
	cd mobile && flutter test

tidy:
	cd backend && go mod tidy
