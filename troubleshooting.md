cd keeper && make all

SELECT * FROM system.clusters WHERE cluster = 'company_cluster';

SELECT * FROM system.dns_cache;

# Ошибки при вставке/выборке данных

В текущей версии CH `harbor.rvision.pro/sec/clickhouse:23.2.6.34-init-20240529` **НЕВОЗМОЖНО** настроить продолжение работы кластера при потере одного из шардов.
Необходимо использовать образ на `24.7.4.51-distroless-20240529`

## 1. Основные шаги проверки кластера (шардирование и шардирование + репликация)

### 1.1 **Проверка конфигурации кластера**

Прежде чем начинать проверку, убедитесь, что конфигурация кластера настроена корректно:
- Проверьте конфигурационный файл ClickHouse (`<remote_servers>` в `config.xml`) на наличие правильной структуры для шардирования и репликации.
- Убедитесь, что параметр `<internal_replication>` установлен в `true`, если используется репликация.
- Для каждой реплики укажите правильные адреса хостов и порты.

### 1.3 **Проверка работы Keeper**

 > Если реплики работают в режиме `readOnly`, это может указывать на проблемы с Keeper или синхронизацией.

- Проверьте состояние ClickHouse Keeper (или ZooKeeper) через команду `system.zookeeper`:
  ```sql
  SELECT * FROM system.zookeeper WHERE path = '/clickhouse/tables/cluster_2S_2R';
  ```

```sh
┌─name──────────┬─value─┬─path────────────────┐
│ cluster_2S_2R │       │ /clickhouse/tables/ │
└───────────────┴───────┴─────────────────────┘
```
Дальше, в зависимости от имени кластера, шарда и таблиц которые нас интересуют, указываем их в запросах

```sql
SELECT * FROM system.zookeeper WHERE path = '/clickhouse/tables/cluster_2S_2R';
```

```sh
┌─name────┬─value─┬─path─────────────────────────────┐
│ shard01 │       │ /clickhouse/tables/cluster_2S_2R │
│ shard02 │       │ /clickhouse/tables/cluster_2S_2R │
└─────────┴───────┴──────────────────────────────────┘
```

Это поможет убедиться, что шарды и реплики правильно зарегистрированы в Keeper, и что его состояние актуально.

### 1.4 **Вставка данных с проверкой шардирования и репликации**

- Выполните вставку данных в таблицу и проверьте, на каком шарде они размещаются:
  ```sql
  INSERT INTO my_table (col1, col2) VALUES (1, 'test');
  ```

- Для проверки вставки данных на репликах используйте:
  ```sql
  SELECT * FROM my_table WHERE _shard_num = 1;
  ```

## 2. Основные ошибки при работе с шардированием и репликацией

### 2.1 **Ошибки репликации**
Если одна из реплик перестала реплицироваться корректно, возможно, возникли ошибки в очереди репликации.

- Проверьте таблицу очереди репликации:
  ```sql
  SELECT * FROM system.replication_queue WHERE last_exception != '';
  ```

Ошибки могут указывать на проблемы с сетью, нарушениями данных или временными недоступностями реплик.

### 2.3 **Ошибка вставки с кворумом**
Ошибка вставки с кворумом может произойти, если недостаточно реплик для выполнения кворумной вставки.

- Проверьте, что все реплики доступны:
  ```sql
  SELECT * FROM system.replicas WHERE is_readonly = 1;
  ```

Если репликация работает корректно, данные должны быть видны на всех репликах, которые относятся к одному шардированному сегменту.

## Проверка 

Проверка репликай

### Хранения данных, когда шард недоступен
Когда один из шардов упал, и проходит вставка данных, они будут храниться в локальной директории той тачки на которой был выполнен запрос вставки.

**Пример: Недоступно 3 шарда**
```sh
I have no name!@clickhouse04:/var/lib/clickhouse/store/047/04780175-b88c-4756-82f4-b487c0165469$ du -sh ./* --summarize
12K	./shard1_replica1
28K	./shard2_replica1
12K	./shard3_replica1
```


# **Поведение при нехватке места на одном из шардов**
Если на одном из шардов заканчивается место, ClickHouse будет продолжать записывать данные на другие доступные шарды. Однако на шарде, на котором нет свободного места, любые операции записи будут завершаться ошибками. Поведение системы зависит от стратегии шардирования:

- **Если используется взвешенное шардирование (`weight`):** Данные будут записываться на те шарды, у которых еще есть место. Задача распределения данных между шардовыми узлами будет выполнять балансировку, исходя из веса.
- **Если нет взвешивания:** Запись на полностью заполненный шард будет завершаться ошибкой, но система продолжит функционировать на других шардах.

Для мониторинга свободного места на шардах можно использовать такие SQL-запросы:

```sql
SELECT
    shard,
    free_space,
    total_space,
    free_space / total_space * 100 AS free_space_percent
FROM system.disks
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

- проверка статуса реплик

```sql
SELECT * FROM system.replication_queue WHERE table = 'events';
```

3. Использование другой команды для удаления данных

Вместо TRUNCATE TABLE ты можешь попробовать использовать команду DROP PARTITION для удаления всех данных в таблице:

sql

ALTER TABLE company_db.events ON CLUSTER '{cluster}' DROP PARTITION ID 'partition_id';

Эта команда удалит все данные в указанной партиции. Чтобы узнать список партиций, используй:

SELECT partition FROM system.parts WHERE table = 'events';


### Проблемы Репликации
1. При удалении контейнера, данные автоматически не реплицируются (имею ввиду что не создается база данных и таблицы)

Данные автоматически реплицируются если разница между данными не велика

Когда реплика была полностью потеряна (в данном примере это clickhouse01). Или данные с неё были полностью удалены, *нужно создать базу и таблицы руками*.
После создания базы, воссоздание потерянных таблиц может быть проблематично, это связанно с ошибкой
`Code: 253. DB::Exception: Replica /clickhouse/tables/company_cluster/01/events/replicas/clickhouse01 already exists `
в которой говорится что (потерянная)реплика уже существует, хотя по факту её нет, так происходит из-за того, что на второй реплике (рабочей), сохранилось упоминание о ней.
Для устранения этой ошибки, нужно зайти на (рабочую) реплику и выполнить:
1. Проверить точно ли текущая реплика является клоном потерянной
`SELECT * FROM system.replicas WHERE table = 'events' FORMAT Vertical;`

* Премерный вывод

    ```sh
    database:                    company_db
    table:                       events
    engine:                      ReplicatedMergeTree
    is_leader:                   1
    can_become_leader:           1
    is_readonly:                 0
    is_session_expired:          0
    future_parts:                0
    parts_to_check:              0
    zookeeper_path:              /clickhouse/tables/company_cluster/01/events
    replica_name:                clickhouse01
    replica_path:                /clickhouse/tables/company_cluster/01/events/replicas/clickhouse01
    columns_version:             -1
    queue_size:                  0
    inserts_in_queue:            0
    merges_in_queue:             0
    part_mutations_in_queue:     0
    queue_oldest_time:           1970-01-01 03:00:00
    inserts_oldest_time:         1970-01-01 03:00:00
    merges_oldest_time:          1970-01-01 03:00:00
    part_mutations_oldest_time:  1970-01-01 03:00:00
    oldest_part_to_get:          
    oldest_part_to_merge_to:     
    oldest_part_to_mutate_to:    
    log_max_index:               1
    log_pointer:                 2
    last_queue_update:           1970-01-01 03:00:00
    absolute_delay:              0
    total_replicas:              2
    active_replicas:             2
    last_queue_update_exception: 
    zookeeper_exception:         
    replica_is_active:           {'clickhouse01':1,'clickhouse02':1}
    ```

2. Удаление метаданных реплики
`SYSTEM DROP REPLICA 'clickhouse01';`

После выполнения этой команды, снова проверяем состояние реплики пердыдущей командой
```sh
zookeeper_exception:
replica_is_active:           {'clickhouse02':1}
```
3. Создать утерянную таблицу, аналогичным образом как была создана таблица на реплике.
Если нет рядом информации как была создана таблица, можем посмотреть на реплике, используя команду
`SHOW CREATE TABLE events;`

На основе полученного результата, создаем таблицу.
Проводим эту операцию с каждой таблицей.

*После пересоздания таблицы, данные автоматически реплицируются в неё*

4. Провести данную операцию для каждой таблицы.

во время падения, одна реплика остается в рабочем состоянии, но запись все равно будет идти поочередно (асинхронно). При этом, данные которые будут направляться на недоступные шарды, будут сохраняться в локальной директории

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

Конфигурация таблиц в Keeper

Таблицы, использующие механизм внутренней репликации, должны быть зарегистрированы в Keeper под соответствующими путями. Пример правильной структуры каталогов в Keeper:

/ :) ls "/clickhouse/tables/cluster_2S_2R"
/shard01
/shard02

/ :) ls "/clickhouse/tables/cluster_2S_2R/shard02/"
/events

Каждая таблица должна быть зарегистрирована для каждого шарда (например, shard01, shard02) в кластере.
Внутри каждого шарда должно быть указано имя таблицы, которое будет синхронизироваться между репликами.