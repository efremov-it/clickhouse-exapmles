.DEFAULT_GOAL:=up
.PHONY: config

SQL_SETUP=commands/setup.sql
SQL_INSERT=commands/insert.sql
VERSION=0
COUNT=4

config:
	rm -rf clickhouse0*
	@for i in $$(seq 1 "${COUNT}");do \
		mkdir -p clickhouse0$$i; \
		SHARDS=""; \
		RAFT_CONFIG=""; \
		ZOOKEEPER_NODES=""; \
		for shard in $$(seq 1 "${COUNT}"); do \
			SHARDS="$$SHARDS<shard><replica><host>clickhouse$$(printf %02d $$shard)</host><port>9000</port></replica></shard>\n\t\t\t"; \
			RAFT_CONFIG="$$RAFT_CONFIG<server><id>${VERSION}$$shard</id><hostname>clickhouse$$(printf %02d $$shard)</hostname><port>9234</port></server>\n\t\t\t"; \
			ZOOKEEPER_NODES="$$ZOOKEEPER_NODES<node><host>clickhouse$$(printf %02d $$shard)</host><port>9181</port></node>\n\t\t"; \
		done; \
		VERSION=${VERSION} REPLICA=${VERSION}$$i SHARDS="$$(echo "$$SHARDS")" RAFT_CONFIG="$$(echo "$$RAFT_CONFIG")" ZOOKEEPER_NODES="$$(echo "$$ZOOKEEPER_NODES")" CLICKHOUSE_SERVER_ID=$$i envsubst < configs/config.xml > clickhouse0$$i/config.xml; \
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

setup:
	@echo "Running SQL file: $(SQL_SETUP)..."
	@cat $(SQL_SETUP) | docker compose exec -T clickhouse01 clickhouse-client --multiquery

insert:
	@echo "Running SQL file: $(SQL_INSERT)..."
	@cat $(SQL_INSERT) | docker compose exec -T clickhouse01 clickhouse-client --multiquery

read:
	docker compose exec -T clickhouse01 clickhouse-client -q "SELECT * FROM company_db.events_distr"

all: down up
