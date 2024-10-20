# Бэкап, в каких случаях использовать.

Репликация в ClickHouse и других базах данных используется для повышения отказоустойчивости и доступности данных. Однако репликация не защищает от всех видов проблем, и резервное копирование (бэкап) всё равно необходимо. Давайте рассмотрим, от каких ошибок защищает репликация и почему важно делать резервные копии.
От чего защищает репликация:

    Отказ одного или нескольких узлов:
        При падении одного или нескольких узлов с репликами (например, из-за аппаратного сбоя) другие узлы с репликами смогут продолжать обслуживать запросы. Это обеспечивает высокую доступность (High Availability, HA) системы.

    Отказ дисков и повреждение оборудования:
        Если данные на диске повреждаются или диск выходит из строя, другая реплика может продолжать функционировать и принимать запросы на чтение/запись, сохраняя консистентность данных.

    Обновления и обслуживание:
        Репликация позволяет проводить обновления и обслуживание узлов по очереди, не приводя к недоступности системы в целом.

    Балансировка нагрузки:
        Репликация помогает распределять нагрузку на чтение, так как запросы могут выполняться на разных репликах, что снижает нагрузку на каждый отдельный узел.

    Failover (переключение на другую реплику):
        В случае проблем с основным узлом, система может автоматически переключиться на реплику, минимизируя простои и обеспечивая бесперебойную работу.

От чего репликация не защищает:

    Ошибки пользователя или приложения:
        Если пользователь или приложение случайно удалит данные или таблицу, эта операция будет автоматически синхронизирована со всеми репликами. Таким образом, репликация не защитит от таких ошибок, и данные будут потеряны на всех репликах.

    Коррупция данных на уровне базы:
        Если данные повреждаются на уровне логики работы базы данных (например, из-за багов в ClickHouse или некорректных операций), эта ошибка также распространяется на все реплики.

    Неправильные запросы или массовое обновление данных:
        Если вы случайно выполните запрос, который обновит или удалит множество строк, эта операция также отразится на всех репликах.

    Вредоносные действия:
        Если злоумышленник или недобросовестный пользователь имеет доступ к базе данных и выполнит деструктивные операции, репликация не поможет — изменения синхронизируются между всеми репликами.

    Долговременное хранение и архивация:
        Репликация не предназначена для долговременного хранения и архивации старых данных. Она не защищает от сценариев, когда нужно восстановить состояние базы на определённый момент времени (например, на прошлую неделю).

Почему нужно делать резервное копирование:

    Восстановление после ошибок пользователя:
        Резервные копии позволяют восстановить данные на момент до выполнения некорректной операции, даже если эта ошибка уже синхронизировалась на все реплики.

    Защита от логической и физической коррупции:
        В случае логической или физической порчи данных (например, некорректные обновления, проблемы с файловой системой) бэкапы позволяют восстановить данные из копий, созданных до возникновения проблемы.

    Защита от вредоносных действий:
        Если кто-то умышленно или случайно повредит данные, наличие бэкапов позволяет откатить базу данных к предыдущему состоянию.

    Долговременное хранение и соответствие требованиям:
        Для соответствия политике безопасности и юридическим требованиям компании часто необходимо хранить данные в течение определённого времени. Бэкапы обеспечивают возможность хранения данных на длительный срок и их восстановление.

    Восстановление в случае катастрофы (Disaster Recovery):
        Если все реплики будут потеряны из-за катастрофического сбоя (например, пожар или потеря центра обработки данных), резервные копии помогут восстановить базу данных в другом месте.

Итог:

Репликация и резервное копирование решают разные задачи. Репликация обеспечивает отказоустойчивость и высокую доступность, но не защищает от логических ошибок и повреждения данных. Резервные копии, в свою очередь, позволяют восстановить данные после катастрофических событий или ошибок пользователя.

Поэтому важно использовать оба механизма: репликацию — для обеспечения доступности и распределения нагрузки, а бэкапы — для восстановления данных в случае логических ошибок, катастроф и долговременного хранения.

