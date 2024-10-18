.DEFAULT_GOAL:=up
.PHONY: config

REPLECA := replica/docker-compose.yml
KEEPER := keeper/docker-compose.yml
GRAFANA := grafana/docker-compose.yml

SQL_SETUP=commands/setup.sql
SQL_INSERT=commands/insert.sql

PWD := $(shell pwd)
VM := ${PWD}/volumes

test:
	echo ${VM}

up: up-k up-ch grafana

.PHONY: up-k
up-k:
	docker compose -f ${KEEPER} up -d

.PHONY: up-ch
up-ch:
	docker compose -f ${REPLECA} up -d

.PHONY: grafana
grafana:
	@mkdir --mode 777 -p grafana/data
	@docker compose -f ${GRAFANA} up -d
	@echo "----------------------------------------"
	@echo "Grafana is running on http://localhost:3000"
	@echo "Username: admin Password: admin"
	@echo "Add Clickhouse datasource with Server Address: clickhouse01:9000"
	@echo "Username: 'default' with no password"
	@echo "----------------------------------------"

down: down-ch down-k down-g

.PHONY: down-k
down-k:
	docker compose -f ${KEEPER} down

.PHONY: down-ch
down-ch:
	docker compose -f ${REPLECA} down

.PHONY: down-g
down-g:
	docker compose -f ${GRAFANA} down

re-k:
	docker compose -f ${KEEPER} restart

re-ch:
	docker compose -f ${REPLECA} restart

in:
	docker compose -f ${REPLECA} exec clickhouse01 bash

cli:
	docker compose -f ${REPLECA} exec clickhouse01 clickhouse-client

keeper:
	docker compose -f ${KEEPER} exec keeper1 clickhouse-keeper-client

all: config up-k up-ch

setup:
	@echo "Running SQL file: $(SQL_SETUP)..."
	@cat $(SQL_SETUP) | docker compose -f ${REPLECA} exec -T clickhouse01 clickhouse-client --multiquery

insert:
	@echo "Running SQL file: $(SQL_INSERT)..."
	@cat $(SQL_INSERT) | docker compose -f ${REPLECA} exec -T clickhouse01 clickhouse-client --multiquery

read:
	docker compose -f ${REPLECA} exec -T clickhouse01 clickhouse-client -q "SELECT count(*) FROM company_db.events_distr;"

trun:
	docker compose -f ${REPLECA} exec -T clickhouse01 clickhouse-client -q "TRUNCATE TABLE company_db.events ON CLUSTER '{cluster}';"

