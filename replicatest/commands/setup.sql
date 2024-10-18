CREATE DATABASE IF NOT EXISTS company_db ON CLUSTER '{cluster}';

CREATE TABLE IF NOT EXISTS company_db.events ON CLUSTER '{cluster}' (
    time DateTime,
    uid  Int64,
    type LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{cluster}/{shard}/events', '{replica}')
PARTITION BY toDate(time)
ORDER BY (uid);

CREATE TABLE IF NOT EXISTS company_db.events_distr ON CLUSTER '{cluster}' AS company_db.events
ENGINE = Distributed('{cluster}', company_db, events, uid);


CREATE TABLE company_db.table1 ON CLUSTER '{cluster}'
(
    `id` UInt64,
    `column1` String
)
ENGINE = ReplicatedMergeTree
ORDER BY id;

CREATE TABLE IF NOT EXISTS company_db.table1_distr ON CLUSTER '{cluster}' AS company_db.table1
ENGINE = Distributed('{cluster}', company_db, table1, id);
