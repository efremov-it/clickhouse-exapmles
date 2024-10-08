Основная задача. Обеспечить быстрый и отказоустойчивый clickhouse cluster при минимальном кол-ве нод.
Логи такая
1. Всего 2 ноды в кластере
2. На каждой ноде, находится по 2 шарда.
    * в данном случае предполагается следующее:
    - Если одна из нод упадет, в этом случае, вся информация будет доступна с другой ноды
    - В случае если обе ноды работают в штатном режиме, чтение будут идти с обеих нод. (Таким образом обеспечивается отказоустойчивость)
3. Репликации. Нужно ли учитывая 2-й пункт реплицировать данные с одной ноды на вторую?
4. Использовать встроенный keeper
5. Опиши мне лучшую архитектуру, учитывая все вышееречисленные требования

CREATE DATABASE cluster_db ON CLUSTER '{cluster}';


CREATE TABLE IF NOT EXISTS cluster_db.scan_logs ON CLUSTER '{cluster}' (
        task_id UUID,
        scan_id UUID,
        host_id UUID,
        level UInt8,
        process_type String,
        msg String,
        payload String,
        timestamp DateTime64,
        created_at DateTime DEFAULT now()
    ) ENGINE = MergeTree
    ORDER BY (timestamp)
    TTL created_at + INTERVAL 1 MONTH;

CREATE TABLE cluster_db.scan_logs_distr ON CLUSTER '{cluster}' AS cluster_db.scan_logs
ENGINE = Distributed('{cluster}', cluster_db, scan_logs, rand());


SELECT hostname(),database, name FROM clusterAllReplicas('{cluster}', system.tables) WHERE database='cluster_db'
                order by database,name;



CREATE TABLE my_table_distributed AS my_table
ENGINE = Distributed(cluster_name, database_name, my_table, rand());

<distributed_replica>
    <prefer_localhost_replica>true</prefer_localhost_replica>
    <use_least_replicated_shard>false</use_least_replicated_shard>
</distributed_replica>

