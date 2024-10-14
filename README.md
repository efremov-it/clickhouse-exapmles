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
SET allow_unrestricted_reads_from_keeper = 1;

- проверка участников zookeeper

SELECT * FROM system.zookeeper;

- детально
SET asterisk_include_materialized_columns=1;
