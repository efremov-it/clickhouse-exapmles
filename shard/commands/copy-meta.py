from clickhouse_driver import Client

existing_shard_host = '172.23.32.110'
new_shard_host = '172.23.32.170'
db_name = 'company_db'

# Подключение к существующему шару для получения списка таблиц
client = Client(host=existing_shard_host, user='default', password='')
client.execute(f"USE {db_name}")
tables = client.execute("SHOW TABLES")

print(tables)

# Подключение к новому шару
new_shard_client = Client(host=new_shard_host, user='default', password='')

# Проверка существования базы данных на новом шарде, создание если не существует
db_exists = new_shard_client.execute(f"EXISTS DATABASE {db_name}")
if not db_exists[0][0]:
    new_shard_client.execute(f"CREATE DATABASE {db_name}")

# Переключение на новую базу на новом шарде
new_shard_client.execute(f"USE {db_name}")

# Создание таблиц на новом шарде
for table in tables:
    create_query = client.execute(f"SHOW CREATE TABLE {db_name}.{table[0]}")[0][0]
    new_shard_client.execute(create_query)

print("Таблицы успешно скопированы на новый шард.")
