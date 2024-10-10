CREATE DATABASE IF NOT EXISTS company_db ON CLUSTER '{cluster}';

CREATE TABLE IF NOT EXISTS company_db.events ON CLUSTER '{cluster}' (
    time DateTime,
    uid  Int64,
    type LowCardinality(String)
)
ENGINE = MergeTree()
PARTITION BY toDate(time)
ORDER BY (uid);

CREATE TABLE IF NOT EXISTS company_db.events_distr ON CLUSTER '{cluster}' AS company_db.events
ENGINE = Distributed('{cluster}', company_db, events, uid);

CREATE TABLE IF NOT EXISTS company_db.events_distr2 ON CLUSTER '{cluster}' AS company_db.events
ENGINE = Distributed('{cluster}', company_db, events, uid)
SETTINGS skip_unavailable_shards = 1;

INSERT INTO company_db.events_distr
SELECT
    now() - INTERVAL rand() % 1000 SECOND, -- Random timestamp within the last 1000 seconds
    rand(1),                               -- Random unique identifier
    if(rand() % 2 = 0, 'view', 'contact')   -- Random event type: either 'view' or 'contact'
FROM numbers(3);                          -- Number of rows to generate (10 in this case)

-- SELECT * FROM company_db.events_distr2 SETTINGS skip_unavailable_shards=1;
