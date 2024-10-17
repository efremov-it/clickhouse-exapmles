.DEFAULT_GOAL:=up
.PHONY: config

config:
	@for i in $$(seq 1 3);do \
		rm -rf keeper$$i; \
		mkdir -p keeper$$i; \
		REPLICA=$$i envsubst < configs/keeper.xml > keeper$$i/keeper.xml; \
		cp configs/users.xml keeper$$i/users.xml; \
		echo configs for keeper$$i is ready; \
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
	docker compose exec keeper1 bash

cli:
	docker compose exec keeper1 clickhouse-keeper-client

all: config up setup
	@echo Now you have clickhouse cluster with 4 nodes!
