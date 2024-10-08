.DEFAULT_GOAL:=up
.PHONY: config

SQL_FILE=commands/setup.sql

config:
	@for i in $$(seq 1 4);do \
		rm -rf clickhouse0$$i; \
		mkdir -p clickhouse0$$i; \
		REPLICA=0$i SHARD=0$$i CLICKHOUSE_SERVER_ID=$$i envsubst < configs/config.xml > clickhouse0$$i/config.xml; \
		cp configs/users.xml clickhouse0$$i/users.xml; \
		echo configs for clickhouse0$$i is ready; \
	done

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
	docker compose exec clickhouse01 bash

cli:
	docker compose exec clickhouse01 clickhouse-client

all: config up setup
	@echo Now you have clickhouse cluster with 4 nodes!

setup:
	@echo "Running SQL file: $(SQL_FILE)..."
	@cat $(SQL_FILE) | docker compose exec -T clickhouse01 clickhouse-client --multiquery

