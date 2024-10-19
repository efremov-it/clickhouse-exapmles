cd keeper && make all

SELECT * FROM system.clusters WHERE cluster = 'company_cluster';

SELECT * FROM system.dns_cache;

### Хранения данных, когда шард недоступен
Когда один из шардов упал, и проходит вставка данных, они будут храниться в локальной директории той тачки на которой был выполнен запрос вставки.

**Пример: Недоступно 3 шарда**
```sh
I have no name!@clickhouse04:/var/lib/clickhouse/store/047/04780175-b88c-4756-82f4-b487c0165469$ du -sh ./* --summarize
12K	./shard1_replica1
28K	./shard2_replica1
12K	./shard3_replica1
```
### Тестовые команды

- Генерация данных

```sql
INSERT INTO company_db.events_distr SELECT
    now(),
    rand(1),
    if((rand() % 2) = 0, 'view', 'contact')
FROM numbers(1250000000)
```
- Проверка размера
```sql
SELECT
    sum(bytes) AS total_size_bytes,
    formatReadableSize(sum(bytes)) AS total_size_human
FROM system.parts
WHERE (`table` = 'events') AND (database = 'company_db')
```

```sql
SELECT count(*) FROM company_db.events;
```
**debug**

SYSTEM SYNC REPLICA company_db.events;

SET allow_unrestricted_reads_from_keeper = 1;

- проверка участников zookeeper

SELECT * FROM system.zookeeper;

- детально
SET asterisk_include_materialized_columns=1;

<distributed_replica>
    <prefer_localhost_replica>true</prefer_localhost_replica>
    <use_least_replicated_shard>false</use_least_replicated_shard>
</distributed_replica>


troubleshooting

- проверка статуса раплик

```sql
SELECT * FROM system.replication_queue WHERE table = 'events';
```

3. Использование другой команды для удаления данных

Вместо TRUNCATE TABLE ты можешь попробовать использовать команду DROP PARTITION для удаления всех данных в таблице:

sql

ALTER TABLE company_db.events ON CLUSTER '{cluster}' DROP PARTITION ID 'partition_id';

Эта команда удалит все данные в указанной партиции. Чтобы узнать список партиций, используй:

SELECT partition FROM system.parts WHERE table = 'events';


во время падения, одна реплика остается в рабочем состоянии, но запись всеравно будет идти поочередно (асинхронно). При этом, данные которые будут направляться на недоступные шарды, будут сохраняться в локальной директории

В данном примере в рабочем состоянии находится только 3-я нода (2 шард первая реплика)

```sh
I have no name!@clickhouse03:/var/lib/clickhouse/store/bee/bee285f0-59a4-420d-a213-0f7ed022a7a5$ du -sh ./*
20K     ./shard1_replica1
8.0K    ./shard1_replica2
16K     ./shard2_replica2
```

Состояние реплики

```sql
SELECT *
FROM system.replicas
WHERE table = 'events'
FORMAT Vertical
```
