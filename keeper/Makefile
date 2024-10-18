.DEFAULT_GOAL:=up

.PHONY: up
up:
	docker compose up -d

.PHONY: start
start:
	docker compose start

.PHONY: stop
stop:
	docker compose stop

.PHONY: down
down:
	docker compose down

in:
	docker compose exec keeper1 bash

cli:
	docker compose exec keeper1 clickhouse-keeper-client
