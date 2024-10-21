# Базовые положения основных сущностей
### Шард
Подмножество данных, в котором шардированные данные разбиваются на непересекающиеся наборы. Допустим, у нас есть таблица с большим количеством логов, которая физически не помещается на одном сервере. Мы можем разбить таблицу на 4 части и разместить на 4 разных серверах. Это позволяет не только уменьшить объём данных на одном инстансе, но и увеличить пропускную способность системы и количество операций ввода/вывода за счёт того, что операции выполняются на всех хостах.

ClickHouse всегда имеет хотя бы один шард для ваших данных. Поэтому, если вы не распределяете данные по нескольким серверам, ваши данные будут храниться в одном шарде. Целевой сервер определяется ключом партицирования и определяется при создании распределенной таблицы.

Каждый шард по умолчанию состоит минимум из 1 реплики.

### Реплика
Это простая копия данных. ClickHouse всегда имеет хотя бы одну копию ваших данных, поэтому минимальное количество реплик — одна. Это важная деталь: оригинал данных не считается репликой, однако в коде и документации ClickHouse используется система, при которой все инстансы — это реплики. 

### Метаданные
Информация, которая описывает другие данные и представляет собой структурированные справочники, что помогают сортировать и идентифицировать атрибуты описываемой ими информации.