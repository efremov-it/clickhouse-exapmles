Давай разберём каждый вопрос по репликации в ClickHouse с шардированием:

### 1. **Нагрузка на файловую систему при репликации и без**
- **Без репликации**: Каждый узел (шард) хранит свои собственные данные. Нагрузка на файловую систему ограничивается локальными операциями записи и чтения.
- **С репликацией**: Каждая реплика хранит копию данных своего шарда, что увеличивает нагрузку на файловую систему, так как каждая реплика должна хранить полный набор данных шарда. Например, если один шард имеет размер 100GB, и есть 2 реплики, то для каждой реплики потребуется дополнительное место на диске (еще 100GB на каждую).

### 2. **Нагрузка на файловую систему, когда рядом с шардом есть реплика**
- **Когда есть реплика**: Файловая система каждого узла, где размещена реплика, будет использовать больше дискового пространства. Нагрузка на дисковое хранилище при записи данных на шард возрастает, так как данные одновременно отправляются на реплику (обычно через механизм данных "MergeTree"), что увеличивает число операций ввода-вывода.
- **Балансирование нагрузки**: Обычно ClickHouse управляет репликацией асинхронно, то есть реплика догоняет основной шард, что может создавать временные всплески нагрузки на диск.

### 3. **Нагрузка на сеть при одной и нескольких репликах (2-4 реплики)**
- **Одна реплика**: При каждой записи данных, шард отправляет изменения на одну реплику. Это создает сетевой трафик, зависящий от объема данных и скорости репликации.
- **2-4 реплики**: С увеличением числа реплик увеличивается нагрузка на сеть, так как каждая реплика должна получать свои данные. Однако передача данных может быть параллельной (если сеть поддерживает высокую пропускную способность), что помогает уменьшить задержки.

  Чаще всего ограничивающим фактором становится сетевой канал, когда в кластер добавляются несколько реплик, особенно если они находятся на удалённых физических серверах. Чем больше реплик — тем выше сетевой трафик при синхронизации данных.

### 4. **Потеря реплик (поочереди, пока не останется только одна)**
- **Сценарий потери реплик**: При потере одной реплики остальные продолжают работать, потому что данные хранятся на других репликах шарда. ClickHouse автоматически восстанавливает баланс и выполняет репликацию на оставшиеся узлы.
- **Последствия потери всех, кроме одной реплики**: Если потеряна последняя реплика, система всё ещё может продолжать работу, но репликационные механизмы больше не смогут поддерживать целостность данных. Придется восстанавливать потерянные узлы вручную, либо из резервных копий, если они есть.

### 5. **Восстановление реплики**
- **Автоматическое восстановление**: Когда реплика восстанавливается (например, узел возвращается онлайн), ClickHouse автоматически начинает процесс восстановления данных, копируя недостающие или изменённые данные с основной реплики или с другого узла.
- **Механизмы восстановления**:
  - *Занимает время*: Восстановление реплики может занять время, в зависимости от объёма данных, которые нужно скопировать, и от сетевой пропускной способности.
  - *Файловая система*: При восстановлении возможна дополнительная нагрузка на дисковую систему, так как восстановление данных с других реплик будет производить множество операций ввода-вывода.

### Оптимизация репликации:
- Для снижения нагрузки на сеть и дисковую систему можно настроить задержку между репликациями или использовать компрессию данных.
- Инфраструктура с низкими задержками и высокой пропускной способностью помогает уменьшить негативные эффекты от репликации.

https://clickhouse.com/docs/en/operations/settings/settings#insert_quorum

## Документация: Настройка отказоустойчивости ClickHouse с репликацией и шардированием

### Введение

В этом документе описаны стратегии для обеспечения бесперебойной работы кластера ClickHouse с шардированием и репликацией в условиях, когда возможны сбои и падения реплик. Основной задачей является настройка кластера таким образом, чтобы при отказе двух реплик система продолжала принимать запросы, а при отказе последней реплики одного из шардов данные кэшировались до восстановления узлов.

Документация охватывает:
1. Настройку кворума для обработки вставок даже при потере реплик.
2. Использование буферного движка для временного кэширования данных.
3. Распределение запросов между репликами для обеспечения отказоустойчивости.
4. Восстановление реплик и управление их состоянием.
5. Преимущества и недостатки разных подходов.

---

### 1. Настройка кворума для отказоустойчивых вставок

#### Параметр `insert_quorum`
**Описание**: Параметр `insert_quorum` контролирует минимальное количество реплик, которые должны подтвердить вставку данных перед завершением операции.

**Пример настройки**:
```sql
SET insert_quorum = 1;
```

**Как это работает**:
- По умолчанию, для завершения вставки необходимо, чтобы данные были записаны на все реплики. Это создает зависимость от всех реплик и может привести к блокировке вставок при недоступности одной или нескольких реплик.
- Установка параметра `insert_quorum` в значение 1 позволяет продолжить вставки данных даже при недоступных репликах, завершив операцию после успешного подтверждения вставки хотя бы на одной реплике.

**Преимущества**:
- Кластер продолжает принимать вставки данных даже при сбое нескольких реплик.
- Обеспечивается гибкость и устойчивость в условиях недоступности реплик.

**Недостатки**:
- При восстановлении реплик возможна дополнительная нагрузка на сеть, так как недостающие данные будут синхронизированы с оставшимися репликами.
- Нет полной уверенности в целостности данных до завершения синхронизации.

---

### 2. Буферизация данных с помощью `Buffer` Engine

**Описание**: Движок `Buffer` позволяет временно хранить данные в оперативной памяти до их записи в целевую таблицу. Это полезно в случаях, когда одна из реплик недоступна, и данные могут быть записаны позже.

**Пример создания буферной таблицы**:
```sql
CREATE TABLE buffer_table AS replica_table ENGINE = Buffer(default, replica_table, 16, 10, 1000, 10000, 1000000, 10000000);
```

**Как это работает**:
- Таблица с движком `Buffer` временно хранит данные в памяти. Как только недоступная реплика восстановится, данные из буфера будут автоматически записаны в основную таблицу.
- Параметры буфера можно настроить таким образом, чтобы данные сохранялись в течение определённого времени или до достижения определённого объёма.

**Преимущества**:
- Буферизация данных позволяет избежать потери информации в случаях, когда реплика временно недоступна.
- Повышение скорости вставок, так как данные не сразу записываются на диск.

**Недостатки**:
- Потенциальная потеря данных, если сервер с буфером аварийно завершит работу до того, как данные будут записаны в основную таблицу.
- Требуется дополнительная память для хранения данных в буфере.

---

### 3. Настройка отказоустойчивости для чтения и записи

**Описание**: Чтобы кластер оставался доступным для чтения и записи, необходимо грамотно распределить нагрузку между активными репликами.

**Пример настройки**:
```xml
<remote_servers>
    <company_cluster>
        <shard>
            <internal_replication>true</internal_replication>
            <replica>
                <host>clickhouse01</host>
                <port>9000</port>
            </replica>
            <replica>
                <host>clickhouse02</host>
                <port>9000</port>
            </replica>
        </shard>
        <shard>
            <internal_replication>true</internal_replication>
            <replica>
                <host>clickhouse03</host>
                <port>9000</port>
            </replica>
            <replica>
                <host>clickhouse04</host>
                <port>9000</port>
            </replica>
        </shard>
    </company_cluster>
</remote_servers>
```

**Параметры отказоустойчивости**:
- **`load_balancing=random`**: Запросы будут случайным образом направляться на доступные реплики, что позволяет равномерно распределять нагрузку.
- **`prefer_local_replica=true`**: Сначала запросы будут направляться на локальную реплику, что уменьшает задержки и снижает сетевую нагрузку.

**Преимущества**:
- Запросы на чтение и запись могут обрабатываться даже при недоступности нескольких реплик.
- Повышение отказоустойчивости и равномерное распределение нагрузки.

**Недостатки**:
- Возможны задержки в доставке данных, если реплики временно недоступны.

---

### 4. Восстановление реплик

**Описание**: Когда реплика снова становится доступной после сбоя, данные, которые были записаны в другие реплики во время её недоступности, должны быть синхронизированы.

**Пример команды восстановления реплики**:
```sql
SYSTEM RESTART REPLICA replica_table;
```

**Как это работает**:
- После выполнения команды восстановления, реплика начинает синхронизацию с другими репликами и получает недостающие данные из журнала транзакций.
- Восстановление реплики может занимать некоторое время в зависимости от объёма данных, которые нужно синхронизировать.

**Преимущества**:
- Полная синхронизация данных между репликами после восстановления.
- Реплики автоматически восстанавливают целостность после восстановления узлов.

**Недостатки**:
- Синхронизация может занять много времени при большом объёме данных, что может снизить производительность.

---

### 5. Пример аварийного режима работы

В случае, если остаётся только одна реплика на один из шардов, кластер может перейти в аварийный режим с кэшированием данных недоступных реплик.

- Оставшаяся реплика продолжит принимать данные, а недостающие реплики синхронизируют свои данные после восстановления.
- Использование буферной таблицы позволяет временно сохранять данные, пока все реплики не восстановятся.

---

### Преимущества и недостатки предложенных решений

| Решение                      | Преимущества                                                                 | Недостатки                                                                     |
|------------------------------|------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `insert_quorum`               | Позволяет вставлять данные при потере реплик                                  | Возможна несогласованность данных до завершения синхронизации                  |
| `Buffer` Engine               | Временное хранение данных до восстановления реплик                           | Потеря данных в случае падения сервера с буфером                               |
| Распределение запросов        | Отказоустойчивость и балансировка нагрузки между активными репликами         | Возможны задержки при восстановлении реплик                                    |
| Восстановление реплик         | Полная синхронизация данных после восстановления узлов                       | Высокая нагрузка на сеть и диски при большом объёме данных                     |

---

### Заключение

Используя эти стратегии, можно повысить отказоустойчивость кластера ClickHouse и минимизировать потери данных в случае отказов реплик. Комбинация параметров `insert_quorum`, буферных таблиц и распределения запросов позволяет кластерам ClickHouse продолжать работу в аварийных ситуациях.



 При отключении одного шарда из 4-х, все работает стабильно, все данные сохраняются. 3 шарда работают стабильно, данные записывают без проблем.
 Как только дропается еще один шард. Остается 1 реплика на каждый ширд, появляется проблема. 
 Вероятней всего, связана с утерей кворума нод в кипере. т.к. всего 4 ноды в кластере, для работы требуется как минимум 3.
 В следствии чего, реплики уходят в read_only режим
 Code: 242. DB::Exception: Received from localhost:9000. DB::Exception: Table is in readonly mode: replica_path=/clickhouse/tables/company_cluster/01/events/replicas/clickhouse01. (TABLE_IS_READ_ONLY)
Странная особенность, теряется часть данных. Хотя судя по настройке 2 реплики доступны и они долждны иметь одинаковые данные.
Даже при запуске clickhouse02 (clickhouse03 остановлен) кворум не восстанавливается.
Только когда я запусти clickhouse03 кворум восстановился и все данные появились снова.
Кластер вышел из состояния read only.

Разница в поведении системы, когда используется конфигурация только с шардами (без репликации) и когда есть репликация, объясняется особенностями работы ClickHouse с репликами и механизмом кворума.

### 1. Конфигурация **только с шардами** (без реплик):
```xml
<remote_servers>
    <company_cluster>
        <shard><replica><host>clickhouse01</host><port>9000</port></replica></shard>
        <shard><replica><host>clickhouse02</host><port>9000</port></replica></shard>
        <shard><replica><host>clickhouse03</host><port>9000</port></replica></shard>
    </company_cluster>
</remote_servers>
```
- **Шардирование** — это горизонтальное разделение данных, и каждый шард содержит уникальный набор данных. Когда у каждого шарда по одной реплике, в каждом шард-сегменте данных хранится только одна копия данных, и для каждой ноды нет необходимости проверять наличие кворума реплик для сохранения или чтения данных.
- **Отсутствие внутренней репликации**: так как в каждом шарде только одна реплика, система не ожидает синхронизации данных между репликами и, соответственно, не использует механизм кворума. Это позволяет остановить все ноды, кроме одной, без нарушения работы — данные на оставшихся узлах будут доступны для записи и чтения, потому что не требуется поддерживать синхронизацию с другими узлами.

### 2. Конфигурация с **репликацией**:
```xml
<remote_servers>
    <company_cluster>
        <shard>
            <internal_replication>true</internal_replication>
            <replica>
                <host>clickhouse01</host>
                <port>9000</port>
            </replica>
            <replica>
                <host>clickhouse02</host>
                <port>9000</port>
            </replica>
        </shard>
        <shard>
            <internal_replication>true</internal_replication>
            <replica>
                <host>clickhouse03</host>
                <port>9000</port>
            </replica>
            <replica>
                <host>clickhouse04</host>
                <port>9000</port>
            </replica>
        </shard>
    </company_cluster>
</remote_servers>
```
- **Внутренняя репликация**: При активной репликации ClickHouse ожидает, что данные будут синхронизированы между репликами для каждого шарда. Репликация добавляет надежность, позволяя восстановить данные в случае отказа одной из нод, но это требует кворума для корректного функционирования.
- **Кворум для вставки**: При записи данных с активной репликацией, ClickHouse ожидает, что данные будут реплицированы на большинство узлов для обеспечения согласованности. Если одна из реплик становится недоступной, вставки могут продолжаться, но как только выходит из строя вторая реплика, вставка данных блокируется — так как не может быть достигнут кворум (большинство).
- **Кворум для чтения**: При чтении данных с реплицированной таблицы система также может блокироваться, если потеряно несколько реплик, потому что ClickHouse не может гарантировать, что чтение будет происходить с консистентных данных.

### Почему нет ошибок кворума при отсутствии репликации:
- Когда нет репликации, каждая нода полностью независима, и не требуется синхронизация данных между узлами. Следовательно, отказ других узлов не нарушает работу оставшихся узлов.
- При репликации система требует кворум (согласие большинства) для вставки или чтения данных, чтобы гарантировать консистентность данных на всех узлах. При недостатке реплик система переходит в режим только для чтения, потому что она не может выполнить безопасную синхронизацию.

### Решение проблемы:

Чтобы снизить влияние кворума на работу при репликации, можно рассмотреть несколько подходов:

1. **Использование опции `<insert_quorum>`**:
   - Можно уменьшить кворум на вставки, установив `<insert_quorum>1`, что позволит вставлять данные даже с одной активной репликой. Но это потенциально может привести к несогласованности данных, если несколько реплик не синхронизируются.
   
2. **Увеличение количества узлов**:
   - Добавление большего количества узлов в кластер позволит повысить отказоустойчивость. Например, если у вас 3 или более реплик на каждый шард, система сможет пережить отказ 1 или 2 реплик без перехода в режим только для чтения.

3. **Использование стратегии восстановления**:
   - При восстановлении реплик можно использовать такие параметры, как `<prefer_local_replica>` для ускорения чтения данных с локальной реплики (если она доступна), и настроить агрессивные механизмы восстановления реплик, чтобы минимизировать простои.

Таким образом, основная разница между конфигурациями с шардами и репликами заключается в том, что репликация требует поддержания кворума для согласованности данных, тогда как шардирование без реплик позволяет каждой ноде работать независимо.