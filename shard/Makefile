.DEFAULT_GOAL:=up
.PHONY: config

SQL_SETUP=commands/setup.sql
SQL_INSERT=commands/insert.sql

config:
	@for i in $$(seq 1 8);do \
		rm -rf clickhouse0$$i; \
		mkdir -p clickhouse0$$i; \
		REPLICA=0$$i SHARD=0$$i CLICKHOUSE_SERVER_ID=$$i envsubst < configs/config.xml > clickhouse0$$i/config.xml; \
		cp configs/users.xml clickhouse0$$i/users.xml; \
		echo configs for clickhouse0$$i is ready; \
	done

.PHONY: up
up: config
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

restart:
	docker compose restart

in:
	docker compose exec clickhouse01 bash

cli:
	docker compose exec clickhouse01 clickhouse-client

copy:
	python3 commands/copy-meta.py

setup:
	@echo "Running SQL file: $(SQL_SETUP)..."
	@cat $(SQL_SETUP) | docker compose exec -T clickhouse01 clickhouse-client --multiquery

insert:
	@echo "Running SQL file: $(SQL_INSERT)..."
	@cat $(SQL_INSERT) | docker compose exec -T clickhouse01 clickhouse-client --multiquery

read:
	docker compose exec -T clickhouse01 clickhouse-client -q "SELECT * FROM company_db.events_distr"

all: down up
