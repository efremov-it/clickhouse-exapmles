.DEFAULT_GOAL:=up
.PHONY: config

SQL_SETUP=commands/setup.sql
SQL_INSERT=commands/insert.sql

PWD := $(shell pwd)

.PHONY: up
up: config
	docker compose  up -d

down:
	docker compose  down

.PHONY: down

restart:
	docker compose  restart

in:
	docker compose exec clickhouse01 bash

cli:
	docker compose exec clickhouse01 clickhouse-client

all: config up-k up-ch

setup:
	@echo "Running SQL file: $(SQL_SETUP)..."
	@cat $(SQL_SETUP) | docker compose exec -T clickhouse01 clickhouse-client --multiquery

insert:
	@echo "Running SQL file: $(SQL_INSERT)..."
	@cat $(SQL_INSERT) | docker compose exec -T clickhouse01 clickhouse-client --multiquery

read:
	docker compose exec -T clickhouse01 clickhouse-client -q "SELECT count(*) FROM company_db.events_distr;"

trun:
	docker compose exec -T clickhouse01 clickhouse-client -q "TRUNCATE TABLE company_db.events ON CLUSTER '{cluster}';"

