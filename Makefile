.PHONY: up down restart logs build consul-upload-local backend-run migrate-up migrate-down flutter-run test tidy

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

consul-upload-local:
	curl -sf -X PUT --data-binary @backend/config.local.json http://localhost:8500/v1/kv/songothon-local && echo 'local config uploaded to consul key songothon-local'

backend-run:
	cd backend && CONSUL_URL=http://localhost:8500 CONSUL_PATH=songothon-local go run . serve

migrate-up:
	cd backend && CONSUL_URL=http://localhost:8500 CONSUL_PATH=songothon-local go run . migrate up

migrate-down:
	cd backend && CONSUL_URL=http://localhost:8500 CONSUL_PATH=songothon-local go run . migrate down

flutter-run:
	cd mobile && flutter run

test:
	cd backend && go test ./...
	cd mobile && flutter test

tidy:
	cd backend && go mod tidy
