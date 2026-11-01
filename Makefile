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

# Firebase service-account key (never commit it). Override with FCM_KEY=/path/to/key.json
FCM_KEY ?= backend/service-account.json

consul-upload-local:
	@if [ -f "$(FCM_KEY)" ]; then \
		jq --slurpfile sa "$(FCM_KEY)" '.fcm.fcm = $$sa[0]' backend/config.local.json \
			| curl -sf -X PUT --data-binary @- http://localhost:8500/v1/kv/songothon-local \
			&& echo "local config (with FCM key from $(FCM_KEY)) uploaded to consul key songothon-local"; \
	else \
		curl -sf -X PUT --data-binary @backend/config.local.json http://localhost:8500/v1/kv/songothon-local \
			&& echo "local config uploaded to consul key songothon-local (no FCM key found at $(FCM_KEY); push runs in simulator mode)"; \
	fi

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
