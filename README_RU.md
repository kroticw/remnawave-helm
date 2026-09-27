# remnawave-helm

[🇬🇧 English version](./README.md)

Helm-чарты для развёртывания компонентов VPN-панели [Remnawave](https://github.com/remnawave/backend) в Kubernetes.

## Чарты

| Чарт                                                                  | Описание                           | Образ по умолчанию                   |
|-----------------------------------------------------------------------|------------------------------------|--------------------------------------|
| [`remnawave-panel`](./charts/remnawave-panel)                         | Бэкенд + фронтенд панели Remnawave | `remnawave/backend:3.4.4`            |
| [`remnawave-subscription-page`](./charts/remnawave-subscription-page) | Лёгкий портал подписок             | `remnawave/subscription-page:8.0.0`  |

Чарты независимы и могут быть развёрнуты в любой комбинации: оба в одном неймспейсе, в разных неймспейсах одного кластера или в полностью отдельных кластерах. Страница подписок обращается к панели по HTTPS с использованием API-токена.

## Требования

- Kubernetes 1.25+
- Helm 3.10+
- Для `ingress`: Ingress-контроллер (например ingress-nginx) и cert-manager
- Для `httproute`: установленные [Gateway API CRD](https://gateway-api.sigs.k8s.io/) и Gateway-контроллер (например Envoy Gateway)
- Для `serviceMonitor`: prometheus-operator или victoria-metrics-operator

## Обновление

Обновление установки, которая уже обслуживает пользователей, описано в [docs/UPGRADING_RU.md](./docs/UPGRADING_RU.md): что каждая версия требует от Secret, как идут миграции базы, в каком порядке обновлять и как откатываться.

Чарт `0.5.0` добавляет `pathFilter` у `remnawave-subscription-page`, по умолчанию выключенный. Образы не меняются: панель `3.4.4`, страница подписок `8.0.0`.

## Установка

Оба чарта требуют `existingSecret` — Kubernetes Secret, который вы создаёте заранее и который содержит все переменные окружения приложения. Чарты секретами не управляют.

### remnawave-panel

**1. Создайте секрет**

```bash
kubectl create secret generic panel-secret \
  --namespace remnawave \
  --from-literal=DATABASE_URL='postgresql://remnawave:password@postgres:5432/remnawave' \
  --from-literal=REDIS_HOST='redis' \
  --from-literal=REDIS_PORT='6379' \
  --from-literal=APP_SECRET="$(openssl rand -hex 64)" \
  --from-literal=FRONT_END_DOMAIN='https://panel.example.com' \
  --from-literal=SUB_PUBLIC_DOMAIN='https://sub.example.com/api/sub' \
  --from-literal=METRICS_USER='metrics' \
  --from-literal=METRICS_PASS="$(openssl rand -hex 16)"
```

Полный список поддерживаемых переменных — в разделе [Ключи секрета](#ключи-секрета-remnawave-panel) ниже.

**2. Установка с Ingress**

```bash
helm install remnawave-panel oci://ghcr.io/kroticw/remnawave-helm/remnawave-panel \
  --namespace remnawave \
  --create-namespace \
  --set existingSecret=panel-secret \
  --set ingress.enabled=true \
  --set ingress.host=panel.example.com \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod
```

**Или с Gateway API HTTPRoute**

```bash
helm install remnawave-panel oci://ghcr.io/kroticw/remnawave-helm/remnawave-panel \
  --namespace remnawave \
  --create-namespace \
  --set existingSecret=panel-secret \
  --set httproute.enabled=true \
  --set httproute.hostname=panel.example.com \
  --set "httproute.parentRefs[0].name=services" \
  --set "httproute.parentRefs[0].namespace=envoy-gateway-system"
```

### remnawave-subscription-page

**1. Сгенерируйте API-токен** в UI панели: Settings → API Tokens → Create.

**2. Создайте секрет**

```bash
kubectl create secret generic sub-page-secret \
  --namespace remnawave \
  --from-literal=REMNAWAVE_PANEL_URL='https://panel.example.com' \
  --from-literal=REMNAWAVE_API_TOKEN='ваш-api-токен-из-панели'
```

Полный список поддерживаемых переменных — в разделе [Ключи секрета](#ключи-секрета-remnawave-subscription-page) ниже.

**3. Установка**

```bash
helm install remnawave-subscription-page oci://ghcr.io/kroticw/remnawave-helm/remnawave-subscription-page \
  --namespace remnawave \
  --create-namespace \
  --set existingSecret=sub-page-secret \
  --set ingress.enabled=true \
  --set ingress.host=sub.example.com \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod
```

## Установка из исходников

```bash
git clone https://github.com/kroticw/remnawave-helm.git
cd remnawave-helm

helm install remnawave-panel charts/remnawave-panel \
  --namespace remnawave \
  --set existingSecret=panel-secret \
  --set ingress.enabled=true \
  --set ingress.host=panel.example.com
```

## Конфигурация

### remnawave-panel

| Параметр                  | Описание                                                   | По умолчанию        |
|---------------------------|------------------------------------------------------------|---------------------|
| `replicaCount`            | Количество реплик                                          | `1`                 |
| `image.repository`        | Репозиторий образа                                         | `remnawave/backend` |
| `image.tag`               | Тег образа                                                 | `3.4.4`             |
| `image.pullPolicy`        | Политика загрузки образа                                   | `IfNotPresent`      |
| `strategy`                | Стратегия деплоймента; `Recreate`, потому что энтрипойнт мигрирует базу | `{type: Recreate}` |
| `existingSecret`          | **Обязателен.** Имя существующего Secret с env-переменными | `""`                |
| `service.port`            | HTTP-порт панели                                           | `3000`              |
| `service.metricsPort`     | Порт метрик Prometheus                                     | `3001`              |
| `ingress.enabled`         | Включить Ingress                                           | `false`             |
| `ingress.className`       | Ingress class                                              | `nginx`             |
| `ingress.annotations`     | Аннотации Ingress                                          | `{}`                |
| `ingress.host`            | Имя хоста                                                  | `""`                |
| `ingress.tls`             | Включить TLS                                               | `true`              |
| `ingress.tlsSecretName`   | Имя TLS-секрета (генерируется из host, если не задано)     | `""`                |
| `httproute.enabled`       | Включить Gateway API HTTPRoute                             | `false`             |
| `httproute.parentRefs`    | Gateway parentRefs                                         | см. values.yaml     |
| `httproute.hostname`      | Имя хоста для HTTPRoute                                    | `""`                |
| `startupProbe`            | Startup-проба; закладывает 5 минут на миграции             | см. values.yaml     |
| `livenessProbe`           | Liveness-проба (`tcpSocket`)                               | см. values.yaml     |
| `readinessProbe`          | Readiness-проба (`httpGet /api/health`)                    | см. values.yaml     |
| `serviceMonitor.enabled`  | Включить ServiceMonitor для сбора метрик                   | `false`             |
| `serviceMonitor.interval` | Интервал сбора метрик                                      | `30s`               |
| `serviceMonitor.labels`   | Дополнительные метки ServiceMonitor                        | `{}`                |
| `resources`               | Запросы и лимиты CPU/памяти                                | см. values.yaml     |
| `nodeSelector`            | Node selector                                              | `{}`                |
| `tolerations`             | Toleration'ы                                               | `[]`                |
| `affinity`                | Правила affinity                                           | `{}`                |
| `volumes`                 | Дополнительные volume пода (например секреты/configmaps с TLS-сертификатами Xray) | `[]` |
| `volumeMounts`            | Дополнительные монтируемые в контейнер тома                | `[]`                |

> `ingress.enabled` и `httproute.enabled` взаимоисключающие. Одновременное включение обоих приведёт к ошибке рендеринга.

### Монтирование пользовательских volume (например TLS-сертификатов Xray)

Панель позволяет подключать произвольные volume и монтировать их в контейнер. Это полезно, чтобы передать Xray TLS-сертификаты, которыми чарт не управляет (например, сертификаты, выпущенные сторонним средством и сохранённые в Kubernetes Secret).

```yaml
volumes:
  - name: certificates-node01
    secret:
      secretName: node01.example.com-tls
      items:
        - key: tls.crt
          path: fullchain.pem
        - key: tls.key
          path: privkey.key

volumeMounts:
  - name: certificates-node01
    mountPath: /var/lib/remnawave/configs/xray/ssl/node01/privkey.key
    subPath: privkey.key
    readOnly: true
  - name: certificates-node01
    mountPath: /var/lib/remnawave/configs/xray/ssl/node01/fullchain.pem
    subPath: fullchain.pem
    readOnly: true
```

### remnawave-subscription-page

| Параметр                | Описание                                                   | По умолчанию                  |
|-------------------------|------------------------------------------------------------|-------------------------------|
| `replicaCount`          | Количество реплик                                          | `1`                           |
| `image.repository`      | Репозиторий образа                                         | `remnawave/subscription-page` |
| `image.tag`             | Тег образа                                                 | `8.0.0`                       |
| `image.pullPolicy`      | Политика загрузки образа                                   | `IfNotPresent`                |
| `existingSecret`        | **Обязателен.** Имя существующего Secret с env-переменными | `""`                          |
| `service.port`          | HTTP-порт                                                  | `3010`                        |
| `ingress.enabled`       | Включить Ingress                                           | `false`                       |
| `ingress.className`     | Ingress class                                              | `nginx`                       |
| `ingress.annotations`   | Аннотации Ingress                                          | `{}`                          |
| `ingress.host`          | Имя хоста                                                  | `""`                          |
| `ingress.tls`           | Включить TLS                                               | `true`                        |
| `ingress.tlsSecretName` | Имя TLS-секрета (генерируется из host, если не задано)     | `""`                          |
| `httproute.enabled`     | Включить Gateway API HTTPRoute                             | `false`                       |
| `httproute.parentRefs`  | Gateway parentRefs                                         | см. values.yaml               |
| `httproute.hostname`    | Имя хоста для HTTPRoute                                    | `""`                          |
| `pathFilter.enabled`    | Пускать только пути приложения, остальному 404             | `false`                       |
| `pathFilter.shortUuidPattern` | Regex одного идентификатора подписки                 | `[0-9A-Za-z_-]{16,64}`        |
| `pathFilter.clientTypes` | Типы клиента во втором сегменте пути                      | см. values.yaml               |
| `resources`             | Запросы и лимиты CPU/памяти                                | см. values.yaml               |
| `nodeSelector`          | Node selector                                              | `{}`                          |
| `tolerations`           | Toleration'ы                                               | `[]`                          |
| `affinity`              | Правила affinity                                           | `{}`                          |

### Как не пускать сканеры на страницу подписки

Страница подписки никогда не отвечает 404. На любой запрос, который не ведёт к существующей подписке, она обрывает TCP-соединение, и прокси перед ней отдаёт клиенту 502. Поэтому фоновое сканирование интернета по `/.env`, `/.git/config` и `/docs/phpinfo.php` превращается во всплеск серверных ошибок вашего собственного ingress — и этого хватает, чтобы сработал обычный алёрт «слишком много пятисотых».

`pathFilter` пускает дальше только те пути, которые приложение действительно обслуживает, а на остальные прокси отвечает 404:

```yaml
pathFilter:
  enabled: true
```

Работает для обеих веток маршрутизации: Ingress переходит на regex-пути с `nginx.ingress.kubernetes.io/use-regex`, HTTPRoute — на совпадения типа `RegularExpression`. По умолчанию выключен, потому что включение меняет то, какие запросы доезжают до приложения.

Шаблон по умолчанию рассчитан на обычные ссылки подписки. Если в панели задан `CUSTOM_SUB_PREFIX`, нестандартный `SHORT_UUID_METHOD` или `SHORT_UUID_CUSTOM_PATTERN`, либо используются legacy-ссылки Marzban, правьте `pathFilter.shortUuidPattern` и `pathFilter.clientTypes` под свою форму — иначе 404 получат живые пользователи.

Это сужает проблему, но не закрывает её: правильный по форме, но несуществующий идентификатор подписки по-прежнему доезжает до приложения и заканчивается 502. Подробности — в [docs/UPGRADING_RU.md](./docs/UPGRADING_RU.md).

## Справочник по ключам секрета

### Ключи секрета remnawave-panel

| Ключ                                            | Обязателен | Описание                                                               |
|-------------------------------------------------|------------|-------------------------------------------------------------------------|
| `DATABASE_URL`                                  | Да         | Строка подключения PostgreSQL: `postgresql://user:pass@host:5432/db`   |
| `APP_SECRET`                                    | Да         | Секрет приложения (`openssl rand -hex 64`); `change_me` не принимается |
| `FRONT_END_DOMAIN`                              | Да         | Публичный URL панели для CORS (например `https://panel.example.com`)   |
| `SUB_PUBLIC_DOMAIN`                             | Да         | Публичный URL подписок (например `https://sub.example.com/api/sub`)    |
| `METRICS_USER`                                  | Да         | Логин для basic auth на эндпоинте метрик                               |
| `METRICS_PASS`                                  | Да         | Пароль для basic auth на эндпоинте метрик                              |
| `REDIS_SOCKET`                                  | Условно    | Unix-сокет Redis/Valkey. Либо он, либо пара host и port                |
| `REDIS_HOST`                                    | Условно    | Хост Redis/Valkey, вместе с `REDIS_PORT`                               |
| `REDIS_PORT`                                    | Условно    | Порт Redis/Valkey, вместе с `REDIS_HOST`                               |
| `APP_PORT`                                      | Нет        | Порт панели (по умолчанию: `3000`)                                     |
| `METRICS_PORT`                                  | Нет        | Порт метрик (по умолчанию: `3001`)                                     |
| `API_INSTANCES`                                 | Нет        | Количество API-воркеров (по умолчанию: `1`)                            |
| `REDIS_USERNAME`                                | Нет        | Имя пользователя Redis ACL                                             |
| `REDIS_PASSWORD`                                | Нет        | Пароль Redis                                                           |
| `REDIS_DB`                                      | Нет        | Номер базы Redis, 0-15 (по умолчанию: `1`)                             |
| `JWT_AUTH_LIFETIME`                             | Нет        | Время жизни auth-токена в часах, 12-168 (по умолчанию: `12`)           |
| `PANEL_DOMAIN`                                  | Нет        | Домен панели для генерации ссылок                                      |
| `SHORT_UUID_METHOD`                             | Нет        | Генератор идентификаторов подписки: `nanoid`, `uuid`, `custom` (с 3.4.0) |
| `SHORT_UUID_LENGTH`                             | Нет        | Длина для метода `nanoid`, 16-64 (по умолчанию: `16`)                  |
| `SHORT_UUID_CUSTOM_PATTERN`                     | Нет        | Шаблон для `SHORT_UUID_METHOD=custom`, например `{hex:16}-{digits:10}` |
| `IS_TELEGRAM_NOTIFICATIONS_ENABLED`             | Нет        | Включить Telegram-уведомления (по умолчанию: `false`)                  |
| `TELEGRAM_BOT_TOKEN`                            | Нет        | Токен Telegram-бота; обязателен при включённых уведомлениях            |
| `TELEGRAM_BOT_API_ROOT`                         | Нет        | Базовый URL Telegram Bot API (по умолчанию: `https://api.telegram.org`) |
| `TELEGRAM_BOT_PROXY`                            | Нет        | URL прокси для Telegram-бота                                           |
| `TELEGRAM_NOTIFY_USERS`                         | Нет        | Chat id для событий по пользователям                                   |
| `TELEGRAM_NOTIFY_NODES`                         | Нет        | Chat id для событий по нодам                                           |
| `TELEGRAM_NOTIFY_CRM`                           | Нет        | Chat id для событий CRM                                                |
| `TELEGRAM_NOTIFY_SERVICE`                       | Нет        | Chat id для служебных событий                                          |
| `TELEGRAM_NOTIFY_TBLOCKER`                      | Нет        | Chat id для событий torrent-blocker                                    |
| `WEBHOOK_ENABLED`                               | Нет        | Включить webhook-уведомления (по умолчанию: `false`)                   |
| `WEBHOOK_URL`                                   | Нет        | URL webhook-эндпоинта; обязателен при включённых вебхуках              |
| `WEBHOOK_SECRET_HEADER`                         | Нет        | Ключ подписи webhook: минимум 32 символа, только буквы и цифры         |
| `EXPIRATION_NOTIFICATIONS_ENABLED`              | Нет        | Уведомления об истечении подписки (по умолчанию: `false`)              |
| `EXPIRATION_NOTIFICATIONS`                      | Нет        | Часы относительно истечения, по возрастанию (`[-72, -48, -24, 24]`)    |
| `BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED`         | Нет        | Уведомления о расходе трафика (по умолчанию: `false`)                  |
| `BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD`       | Нет        | JSON-массив процентов, например `[60, 80]`                             |
| `NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED`     | Нет        | Уведомления о неподключавшихся пользователях (по умолчанию: `false`)   |
| `NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS` | Нет        | JSON-массив часов, например `[24, 72]`                                 |
| `USER_USAGE_IGNORE_BELOW_BYTES`                 | Нет        | Не записывать расход меньше этого размера (по умолчанию: `0`)          |
| `SERVICE_CLEAN_USAGE_HISTORY`                   | Нет        | Чистить историю расхода (по умолчанию: `false`)                        |
| `SERVICE_DISABLE_USER_USAGE_RECORDS`            | Нет        | Не писать записи о расходе пользователей (по умолчанию: `false`)       |
| `SERVICE_DISABLE_SRH_RECORDS`                   | Нет        | Не писать историю запросов подписки (по умолчанию: `false`)            |
| `EXPORT_TO_STREAM_ENABLED`                      | Нет        | Экспорт событий панели в Redis Streams (по умолчанию: `false`)         |
| `EXPORT_TO_STREAM_MAXLEN`                       | Нет        | Примерный лимит сообщений в стриме (по умолчанию: `3000`)              |
| `IS_HTTP_LOGGING_ENABLED`                       | Нет        | Включить логирование HTTP-запросов (по умолчанию: `false`)             |
| `ENABLE_DEBUG_LOGS`                             | Нет        | Включить debug-логирование (по умолчанию: `false`)                     |

Подключение к Redis задаётся ровно одной из двух форм: либо `REDIS_SOCKET`, либо `REDIS_HOST` вместе с `REDIS_PORT`. Если задать все три, панель не стартует.

Полный список переменных — в [документации Remnawave](https://docs.rw/docs/install/environment-variables).

### Ключи секрета remnawave-subscription-page

| Ключ                                        | Обязателен | Описание                                                           |
|---------------------------------------------|------------|--------------------------------------------------------------------|
| `REMNAWAVE_PANEL_URL`                       | Да         | Полный URL панели; должен начинаться с `http://` или `https://`    |
| `REMNAWAVE_API_TOKEN`                       | Да         | API-токен из панели: Settings → API Tokens                         |
| `APP_PORT`                                  | Нет        | Порт сервиса (по умолчанию: `3010`)                                |
| `CUSTOM_SUB_PREFIX`                         | Нет        | Кастомный корневой путь, без ведущего и завершающего слеша         |
| `SUBPAGE_CONFIG_UUID`                       | Нет        | Конфигурация страницы подписки из панели (по умолчанию: нулевой UUID) |
| `TRUST_PROXY`                               | Нет        | Настройка Express `trust proxy` для определения реального IP клиента (по умолчанию: `1`) |
| `CADDY_AUTH_API_TOKEN`                      | Нет        | `X-Api-Key` для запросов к панели за Caddy security / Tiny Auth    |
| `CLOUDFLARE_ZERO_TRUST_CLIENT_ID`           | Нет        | Client ID для Cloudflare Zero Trust                                |
| `CLOUDFLARE_ZERO_TRUST_CLIENT_SECRET`       | Нет        | Client Secret для Cloudflare Zero Trust                            |
| `MARZBAN_LEGACY_LINK_ENABLED`               | Нет        | Поддержка Marzban legacy-ссылок (по умолчанию: `false`)            |
| `MARZBAN_LEGACY_SECRET_KEY`                 | Нет        | Секрет для Marzban legacy-ссылок; обязателен при включённых legacy-ссылках |
| `MARZBAN_LEGACY_SUBSCRIPTION_VALID_FROM`    | Нет        | Отсечка по времени, например `2025-01-17T15:38:45.065Z`            |
| `MARZBAN_LEGACY_DROP_REVOKED_SUBSCRIPTIONS` | Нет        | Отклонять отозванные legacy-ссылки (по умолчанию: `false`)         |
| `EGAMES_COOKIE`                             | Нет        | Значение cookie для интеграции eGames                              |

Не кладите в этот Secret `INTERNAL_JWT_SECRET`: энтрипойнт образа генерирует его при каждом старте — поэтому же чарт никогда не переопределяет команду контейнера.

## Использование с FluxCD и SOPS

Сначала добавьте `HelmRepository`, указывающий на OCI-реестр. Это делается один раз на кластер:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: remnawave-helm
  namespace: flux-system
spec:
  interval: 1h
  type: oci
  url: oci://ghcr.io/kroticw/remnawave-helm
```

Затем создайте `HelmRelease` для каждого компонента. Секреты управляются внешне через SOPS — чарт ссылается на них только по имени.

**remnawave-panel** (пример для staging с Gateway API):

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: remnawave-panel
  namespace: remnawave
spec:
  interval: 1h
  chart:
    spec:
      chart: remnawave-panel
      version: "0.4.0"
      sourceRef:
        kind: HelmRepository
        name: remnawave-helm
        namespace: flux-system
  values:
    existingSecret: panel-secret
    httproute:
      enabled: true
      hostname: panel.example.com
    nodeSelector:
      kubernetes.io/os: linux
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 1000m
        memory: 512Mi
```

**remnawave-subscription-page** (пример для production с Ingress):

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: remnawave-subscription-page
  namespace: remnawave
spec:
  interval: 1h
  chart:
    spec:
      chart: remnawave-subscription-page
      version: "0.4.0"
      sourceRef:
        kind: HelmRepository
        name: remnawave-helm
        namespace: flux-system
  values:
    existingSecret: sub-page-secret
    ingress:
      enabled: true
      host: sub.example.com
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
    nodeSelector:
      kubernetes.io/os: linux
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
```

## Лицензия

[Apache 2.0](./LICENSE)
