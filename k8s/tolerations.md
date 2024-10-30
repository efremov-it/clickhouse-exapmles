Labels:           app.kubernetes.io/component=clickhouse
                  app.kubernetes.io/instance=ch-cluster
                  app.kubernetes.io/managed-by=Helm
                  app.kubernetes.io/name=clickhouse
                  app.kubernetes.io/version=24.9.2
                  apps.kubernetes.io/pod-index=0
                  controller-revision-hash=ch-cluster-clickhouse-shard0-86457f7c8c
                  helm.sh/chart=clickhouse-6.3.0
                  shard=0
                  statefulset.kubernetes.io/pod-name=ch-cluster-clickhouse-shard0-0
Annotations:      checksum/config: 9dbd7a4ddc09a88155bc4b4730ddfa1059a19adab414f14676ea1c70cc931148
                  checksum/config-extra: 01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b
                  checksum/config-users-extra: 01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b

shard=0 (первый шард)
pod.index=0 (перавя реплика)

настроить тениты таким образом, чтобы реплики одного шарда не могли находиться на одной ноде.

допустим 2 ноды

1 == shard0.replica0 shard1.replica.0
2 == shard0.replica1 shard1.replica.1

3 ноды (3 шарда)

1 == shard0.replica0 shard1.replica.0 shard2.replica.0
2 == shard0.replica1 shard1.replica.1 shard2.replica.1
3 == shard0.replica2 shard1.replica.2 shard2.replica.2

k label no evo-nats01.stest.dev.rvision.local node-role.kubernetes.io/clickhouse=true
k label no evo-nats02.stest.dev.rvision.local node-role.kubernetes.io/clickhouse=true
k label no evo-nats03.stest.dev.rvision.local node-role.kubernetes.io/clickhouse=true

## 3 шарда 2 реплики 3 ноды

#### Нода 1:
- `shard0.replica0`
- `shard1.replica1`

#### Нода 2:
- `shard1.replica0`
- `shard2.replica1`

#### Нода 3:
- `shard0.replica1`
- `shard2.replica0`

*На каждой ноде, бедет 2 пода*
интекс дода шарда ==
apps.kubernetes.io/pod-index=0
shard=0

из этого следует, что на ноде не может быть больше одного пода с index 0 и с index 1
нет, на ноде может быть 2 пода к примеру shard1.replica0 shard2.replica0. И тогда, теряется смысл шардирования? ведь CH будет записывать на shard2.replica0 данные и т.к. они на одной ноде находятся, возрастет нагрузка не неё!
Требования:
1. на каждой ноде должна быть 0 реплика одного шарда
2. На одной ноде, не могут быть 2 реплики одного шарда!
но, здесь не учитывается вариант, что может быть поднят на одной ноде поды 0 и 1 одного шарда!

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: "apps.kubernetes.io/pod-index"
              operator: In
              values:
                - "0"
        topologyKey: "kubernetes.io/hostname"
      - labelSelector:
          matchExpressions:
            - key: "apps.kubernetes.io/pod-index"
              operator: In
              values:
                - "1"
        topologyKey: "kubernetes.io/hostname"


первое правило
на каждой ноде только одна реплика 0
всего 6 реплик, нужно как-то их размазать по нодам, кубер не сможет поднять больше 1 r0 на ноде,
Он решит, что лучший вариант закинуть как минимум 1 r0 на каждую ноду.

n1
s0.r0
n2
s1.r0
n3
s2.r0

может попробовать поднять на одной ноде 2 реплики одного шарда к примеру s0.r0 s0.r1, для этого я применяю другое правило, которое гласит что невозможно поднять на одной ноде такие варианты подов у которых

s0.r1
s1.r1
s2.r1

и т.к. у нас на каждой ноде находится r0 каждого шарда, нам запрещено на них запустить еще и r1

Пример
n1
s0.r0
s0.r1 --> запрещено, т.к. уже есть под с меткой s0 на этой ноде.

итого, это приводит к тому, что невозможно запустить поды одного шарда на одной ноде.

Вы абсолютно верно поняли логику, и описанный вами порядок действительно предотвращает запуск двух реплик одного шарда на одной ноде. 

Вот как это работает, учитывая оба правила:

1. **Правило для `replica 0`**: каждую реплику `r0` для каждого шарда можно запустить только на отдельной ноде. Это условие означает, что `shard0.replica0`, `shard1.replica0`, и `shard2.replica0` займут по одной ноде: одну ноду для каждой реплики `r0`.

2. **Правило для `replica 1`**: чтобы избежать конфликта с `r0`-репликами и исключить запуск двух реплик одного шарда на одной ноде, для каждой `r1`-реплики на каждой ноде проверяется, что она **не находится на той же ноде, что и `r0` того же шарда**. Это правило также исключает возможность запуска `r1` на той же ноде, где уже присутствует соответствующий `r0`. 

Таким образом, Kubernetes сможет только так распределить поды, чтобы не нарушить ни одно из правил. Применение этих правил приводит к следующему:

- **Каждая нода имеет ровно одну `replica 0` для каждого шарда**, что исключает любую возможность запуска `r1`-реплик того же шарда на тех же нодах.
  
- В итоге, Kubernetes автоматически ограничен в своих возможностях распределения, и он не сможет разместить две реплики одного шарда на одной ноде, что полностью соответствует вашим требованиям. 

Итог: **распределение подов не позволит присутствовать двум репликам одного шарда на одной ноде**, так как соблюдение обоих правил заставляет Kubernetes "размазать" их по разным нодам.
