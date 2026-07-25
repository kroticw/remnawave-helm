# remnawave-helm

[🇬🇧 English version](./README.md)

Helm-чарты для развёртывания компонентов VPN-панели [Remnawave](https://github.com/remnawave/backend) в Kubernetes.

## Чарты

| Чарт                                                                  | Описание                           | Образ по умолчанию                   |
|-----------------------------------------------------------------------|------------------------------------|--------------------------------------|
| [`remnawave-panel`](./charts/remnawave-panel)                         | Бэкенд + фронтенд панели Remnawave | `remnawave/backend:2`                |
| [`remnawave-subscription-page`](./charts/remnawave-subscription-page) | Лёгкий портал подписок             | `remnawave/subscription-page:latest` |

Чарты независимы и могут быть развёрнуты в любой комбинации: оба в одном неймспейсе, в разных неймспейсах одного кластера или в полностью отдельных кластерах. Страница подписок обращается к панели по HTTPS с использованием API-токена.

## Требования

- Kubernetes 1.25+
- Helm 3.10+
- Для `ingress`: Ingress-контроллер (например ingress-nginx) и cert-manager
- Для `httproute`: установленные [Gateway API CRD](https://gateway-api.sigs.k8s.io/) и Gateway-контроллер (например Envoy Gateway)
- Для `serviceMonitor`: prometheus-operator или victoria-metrics-operator

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
  --from-literal=REDIS_DB='0' \
  --from-literal=JWT_AUTH_SECRET="$(openssl rand -hex 64)" \
  --from-literal=JWT_API_TOKENS_SECRET="$(openssl rand -hex 64)" \
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
| `image.tag`               | Тег образа                                                 | `2`                 |
| `image.pullPolicy`        | Политика загрузки образа                                   | `Always`            |
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
| `image.tag`             | Тег образа                                                 | `latest`                      |
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
| `resources`             | Запросы и лимиты CPU/памяти                                | см. values.yaml               |
| `nodeSelector`          | Node selector                                              | `{}`                          |
| `tolerations`           | Toleration'ы                                               | `[]`                          |
| `affinity`              | Правила affinity                                           | `{}`                          |

## Справочник по ключам секрета

### Ключи секрета remnawave-panel

| Ключ                                | Обязателен | Описание                                                             |
|-------------------------------------|------------|----------------------------------------------------------------------|
| `DATABASE_URL`                      | Да         | Строка подключения PostgreSQL: `postgresql://user:pass@host:5432/db` |
| `REDIS_HOST`                        | Да         | Хост Redis/KeyDB                                                     |
| `REDIS_PORT`                        | Да         | Порт Redis/KeyDB (по умолчанию: `6379`)                              |
| `REDIS_DB`                          | Да         | Номер базы данных Redis (по умолчанию: `0`)                          |
| `JWT_AUTH_SECRET`                   | Да         | Секрет для Auth JWT, минимум 64 символа (`openssl rand -hex 64`)     |
| `JWT_API_TOKENS_SECRET`             | Да         | Секрет для API-токенов JWT, минимум 64 символа                       |
| `FRONT_END_DOMAIN`                  | Да         | Публичный URL панели для CORS (например `https://panel.example.com`) |
| `SUB_PUBLIC_DOMAIN`                 | Да         | Публичный URL подписок (например `https://sub.example.com/api/sub`)  |
| `APP_PORT`                          | Нет        | Порт панели (по умолчанию: `3000`)                                   |
| `METRICS_PORT`                      | Нет        | Порт метрик (по умолчанию: `3001`)                                   |
| `API_INSTANCES`                     | Нет        | Количество API-воркеров (по умолчанию: `1`)                          |
| `REDIS_PASSWORD`                    | Нет        | Пароль Redis                                                         |
| `REDIS_SOCKET`                      | Нет        | Unix-сокет Redis (альтернатива host/port)                            |
| `JWT_AUTH_LIFETIME`                 | Нет        | Время жизни auth-токена в часах (по умолчанию: `12`)                 |
| `PANEL_DOMAIN`                      | Нет        | Домен панели для генерации ссылок                                    |
| `METRICS_USER`                      | Да         | Логин для basic auth на эндпоинте метрик                             |
| `METRICS_PASS`                      | Да         | Пароль для basic auth на эндпоинте метрик                            |
| `IS_TELEGRAM_NOTIFICATIONS_ENABLED` | Нет        | Включить Telegram-уведомления (по умолчанию: `false`)                |
| `TELEGRAM_BOT_TOKEN`                | Нет        | Токен Telegram-бота                                                  |
| `WEBHOOK_ENABLED`                   | Нет        | Включить webhook-уведомления (по умолчанию: `false`)                 |
| `WEBHOOK_URL`                       | Нет        | URL webhook-эндпоинта                                                |
| `WEBHOOK_SECRET_HEADER`             | Нет        | Ключ подписи webhook, минимум 32 символа                             |
| `IS_DOCS_ENABLED`                   | Нет        | Включить Swagger/Scalar UI (по умолчанию: `false`)                   |
| `IS_HTTP_LOGGING_ENABLED`           | Нет        | Включить логирование HTTP-запросов (по умолчанию: `false`)           |
| `ENABLE_DEBUG_LOGS`                 | Нет        | Включить debug-логирование (по умолчанию: `false`)                   |

Полный список переменных — в [документации Remnawave](https://docs.rw/docs/install/environment-variables).

### Ключи секрета remnawave-subscription-page

| Ключ                               | Обязателен | Описание                                                           |
|------------------------------------|------------|--------------------------------------------------------------------|
| `REMNAWAVE_PANEL_URL`              | Да         | Полный URL панели Remnawave (например `https://panel.example.com`) |
| `REMNAWAVE_API_TOKEN`              | Да         | API-токен из панели: Settings → API Tokens                         |
| `APP_PORT`                         | Нет        | Порт сервиса (по умолчанию: `3010`)                                |
| `CUSTOM_SUB_PREFIX`                | Нет        | Кастомный корневой путь, без ведущего и завершающего слеша         |
| `MARZBAN_LEGACY_LINK_ENABLED`      | Нет        | Поддержка Marzban legacy-ссылок (по умолчанию: `false`)            |
| `MARZBAN_LEGACY_SECRET_KEY`        | Нет        | Секрет для Marzban legacy-ссылок                                   |
| `SUBSCRIPTION_UI_DISPLAY_RAW_KEYS` | Нет        | Показывать сырые `vless://`-ссылки (по умолчанию: `false`)         |

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
      version: "0.1.0"
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
      version: "0.1.0"
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
