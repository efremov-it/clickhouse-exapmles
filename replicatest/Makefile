.DEFAULT_GOAL:=up
.PHONY: config

CH_F := docker-compose-ch.yml
K_F := docker-compose-keeper.yml

SQL_SETUP=commands/setup.sql
SQL_INSERT=commands/insert.sql

PWD := $(shell pwd)
VM := ${PWD}/volumes

test:
	echo ${VM}

up: up-k up-ch

.PHONY: up-k
up-k:
	docker compose -f ${K_F} up -d

.PHONY: up-ch
up-ch:
	docker compose -f ${CH_F} up -d

down: down-ch down-k

.PHONY: down-k
down-k:
	docker compose -f ${K_F} down

.PHONY: down-ch
down-ch:
	docker compose -f ${CH_F} down

re-k:
	docker compose -f ${K_F} restart

re-ch:
	docker compose -f ${CH_F} restart

in:
	docker compose -f ${CH_F} exec clickhouse01 bash

cli:
	docker compose -f ${CH_F} exec clickhouse01 clickhouse-client

keeper:
	docker compose -f ${K_F} exec keeper1 clickhouse-keeper-client

all: config up-k up-ch

setup:
	@echo "Running SQL file: $(SQL_SETUP)..."
	@cat $(SQL_SETUP) | docker compose -f ${CH_F} exec -T clickhouse01 clickhouse-client --multiquery

setup-test:
	@echo "Running SQL file: $(SQL_SETUP)..."
	@cat $(SQL_SETUP) | docker compose -f ${CH_F} exec -T clickhouse-01-01 clickhouse-client --multiquery


insert:
	@echo "Running SQL file: $(SQL_INSERT)..."
	@cat $(SQL_INSERT) | docker compose -f ${CH_F} exec -T clickhouse01 clickhouse-client --multiquery

insert-test:
	@echo "Running SQL file: $(SQL_INSERT)..."
	@cat $(SQL_INSERT) | docker compose -f ${CH_F} exec -T clickhouse-01-01 clickhouse-client --multiquery


read:
	docker compose -f ${CH_F} exec -T clickhouse01 clickhouse-client -q "SELECT count(*) FROM company_db.events_distr;"

trun:
	docker compose -f ${CH_F} exec -T clickhouse01 clickhouse-client -q "TRUNCATE TABLE company_db.events ON CLUSTER '{cluster}';"

