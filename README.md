# remnawave-helm

[🇷🇺 Русская версия](./README_RU.md)

Helm charts for deploying [Remnawave](https://github.com/remnawave/backend) VPN panel components in Kubernetes.

## Charts

| Chart                                                                 | Description                        | Default Image                        |
|-----------------------------------------------------------------------|------------------------------------|--------------------------------------|
| [`remnawave-panel`](./charts/remnawave-panel)                         | Remnawave backend + frontend panel | `remnawave/backend:3.4.4`            |
| [`remnawave-subscription-page`](./charts/remnawave-subscription-page) | Lightweight subscription portal    | `remnawave/subscription-page:8.0.0`  |

The charts are independent and can be deployed in any combination: both in the same namespace, in different namespaces within one cluster, or in entirely separate clusters. The subscription page communicates with the panel over HTTPS using a configured API token.

## Requirements

- Kubernetes 1.25+
- Helm 3.10+
- For `ingress`: an Ingress controller (e.g. ingress-nginx) and cert-manager
- For `httproute`: [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) installed and a Gateway controller (e.g. Envoy Gateway)
- For `serviceMonitor`: prometheus-operator or victoria-metrics-operator

## Upgrading

Upgrading an installation that already serves users is described in [docs/UPGRADING.md](./docs/UPGRADING.md): what each version needs from the Secret, how database migrations run, the order of operations and how to roll back.

Chart `0.4.0` moves the panel from `3.2.1` to `3.4.4`. The subscription page stays on `8.0.0`.

## Installing the charts

Both charts require an `existingSecret` — a Kubernetes Secret you create beforehand containing all environment variables for the application. The charts do not manage secrets themselves.

### remnawave-panel

**1. Create the secret**

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

See [full list of supported variables](#remnawave-panel-secret-keys) below.

**2. Install with Ingress**

```bash
helm install remnawave-panel oci://ghcr.io/kroticw/remnawave-helm/remnawave-panel \
  --namespace remnawave \
  --create-namespace \
  --set existingSecret=panel-secret \
  --set ingress.enabled=true \
  --set ingress.host=panel.example.com \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod
```

**Or with Gateway API HTTPRoute**

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

**1. Generate an API token** in the panel UI: Settings → API Tokens → Create.

**2. Create the secret**

```bash
kubectl create secret generic sub-page-secret \
  --namespace remnawave \
  --from-literal=REMNAWAVE_PANEL_URL='https://panel.example.com' \
  --from-literal=REMNAWAVE_API_TOKEN='your-api-token-from-panel'
```

See [full list of supported variables](#remnawave-subscription-page-secret-keys) below.

**3. Install**

```bash
helm install remnawave-subscription-page oci://ghcr.io/kroticw/remnawave-helm/remnawave-subscription-page \
  --namespace remnawave \
  --create-namespace \
  --set existingSecret=sub-page-secret \
  --set ingress.enabled=true \
  --set ingress.host=sub.example.com \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod
```

## Installing from source

```bash
git clone https://github.com/kroticw/remnawave-helm.git
cd remnawave-helm

helm install remnawave-panel charts/remnawave-panel \
  --namespace remnawave \
  --set existingSecret=panel-secret \
  --set ingress.enabled=true \
  --set ingress.host=panel.example.com
```

## Configuration

### remnawave-panel

| Parameter                 | Description                                         | Default             |
|---------------------------|-----------------------------------------------------|---------------------|
| `replicaCount`            | Number of replicas                                  | `1`                 |
| `image.repository`        | Image repository                                    | `remnawave/backend` |
| `image.tag`               | Image tag                                           | `3.4.4`             |
| `image.pullPolicy`        | Image pull policy                                   | `IfNotPresent`      |
| `strategy`                | Deployment strategy; `Recreate` because the entrypoint migrates the database | `{type: Recreate}` |
| `existingSecret`          | **Required.** Name of existing Secret with env vars | `""`                |
| `service.port`            | Panel HTTP port                                     | `3000`              |
| `service.metricsPort`     | Prometheus metrics port                             | `3001`              |
| `ingress.enabled`         | Enable Ingress                                      | `false`             |
| `ingress.className`       | Ingress class name                                  | `nginx`             |
| `ingress.annotations`     | Ingress annotations                                 | `{}`                |
| `ingress.host`            | Hostname                                            | `""`                |
| `ingress.tls`             | Enable TLS                                          | `true`              |
| `ingress.tlsSecretName`   | TLS secret name (auto-generated from host if empty) | `""`                |
| `httproute.enabled`       | Enable Gateway API HTTPRoute                        | `false`             |
| `httproute.parentRefs`    | Gateway parentRefs                                  | see values.yaml     |
| `httproute.hostname`      | Hostname for HTTPRoute                              | `""`                |
| `startupProbe`            | Startup probe; budgets 5 minutes for migrations     | see values.yaml     |
| `livenessProbe`           | Liveness probe (`tcpSocket`)                        | see values.yaml     |
| `readinessProbe`          | Readiness probe (`httpGet /api/health`)             | see values.yaml     |
| `serviceMonitor.enabled`  | Enable ServiceMonitor for metrics scraping          | `false`             |
| `serviceMonitor.interval` | Scrape interval                                     | `30s`               |
| `serviceMonitor.labels`   | Additional labels on ServiceMonitor                 | `{}`                |
| `resources`               | CPU/memory requests and limits                      | see values.yaml     |
| `nodeSelector`            | Node selector                                       | `{}`                |
| `tolerations`             | Tolerations                                         | `[]`                |
| `affinity`                | Affinity rules                                      | `{}`                |
| `volumes`                 | Extra pod volumes (e.g. secrets/configmaps for Xray TLS certs) | `[]`      |
| `volumeMounts`            | Extra container volume mounts                       | `[]`                |

> `ingress.enabled` and `httproute.enabled` are mutually exclusive. Setting both to `true` will cause a render error.

### Mounting custom volumes (e.g. Xray TLS certificates)

The panel lets you attach arbitrary volumes and mount them into the container. This is useful for providing Xray with TLS certificates that are not managed by the chart (for example, certificates issued out-of-band and stored in a Kubernetes Secret).

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

| Parameter               | Description                                         | Default                       |
|-------------------------|-----------------------------------------------------|-------------------------------|
| `replicaCount`          | Number of replicas                                  | `1`                           |
| `image.repository`      | Image repository                                    | `remnawave/subscription-page` |
| `image.tag`             | Image tag                                           | `8.0.0`                       |
| `image.pullPolicy`      | Image pull policy                                   | `IfNotPresent`                |
| `existingSecret`        | **Required.** Name of existing Secret with env vars | `""`                          |
| `service.port`          | HTTP port                                           | `3010`                        |
| `ingress.enabled`       | Enable Ingress                                      | `false`                       |
| `ingress.className`     | Ingress class name                                  | `nginx`                       |
| `ingress.annotations`   | Ingress annotations                                 | `{}`                          |
| `ingress.host`          | Hostname                                            | `""`                          |
| `ingress.tls`           | Enable TLS                                          | `true`                        |
| `ingress.tlsSecretName` | TLS secret name (auto-generated from host if empty) | `""`                          |
| `httproute.enabled`     | Enable Gateway API HTTPRoute                        | `false`                       |
| `httproute.parentRefs`  | Gateway parentRefs                                  | see values.yaml               |
| `httproute.hostname`    | Hostname for HTTPRoute                              | `""`                          |
| `resources`             | CPU/memory requests and limits                      | see values.yaml               |
| `nodeSelector`          | Node selector                                       | `{}`                          |
| `tolerations`           | Tolerations                                         | `[]`                          |
| `affinity`              | Affinity rules                                      | `{}`                          |

## Secret keys reference

### remnawave-panel secret keys

| Key                                             | Required    | Description                                                             |
|-------------------------------------------------|-------------|-------------------------------------------------------------------------|
| `DATABASE_URL`                                  | Yes         | PostgreSQL connection string: `postgresql://user:pass@host:5432/db`     |
| `APP_SECRET`                                    | Yes         | Application secret (`openssl rand -hex 64`); `change_me` is rejected    |
| `FRONT_END_DOMAIN`                              | Yes         | Panel public URL, used for CORS (e.g. `https://panel.example.com`)      |
| `SUB_PUBLIC_DOMAIN`                             | Yes         | Subscription public URL (e.g. `https://sub.example.com/api/sub`)        |
| `METRICS_USER`                                  | Yes         | Prometheus metrics basic auth username                                  |
| `METRICS_PASS`                                  | Yes         | Prometheus metrics basic auth password                                  |
| `REDIS_SOCKET`                                  | Conditional | Redis/Valkey Unix socket path. Provide this **or** host plus port       |
| `REDIS_HOST`                                    | Conditional | Redis/Valkey hostname, together with `REDIS_PORT`                       |
| `REDIS_PORT`                                    | Conditional | Redis/Valkey port, together with `REDIS_HOST`                           |
| `APP_PORT`                                      | No          | Panel port (default: `3000`)                                            |
| `METRICS_PORT`                                  | No          | Metrics port (default: `3001`)                                          |
| `API_INSTANCES`                                 | No          | Number of API workers (default: `1`)                                    |
| `REDIS_USERNAME`                                | No          | Redis ACL username                                                      |
| `REDIS_PASSWORD`                                | No          | Redis password                                                          |
| `REDIS_DB`                                      | No          | Redis database index, 0-15 (default: `1`)                               |
| `JWT_AUTH_LIFETIME`                             | No          | Auth token lifetime in hours, 12-168 (default: `12`)                    |
| `PANEL_DOMAIN`                                  | No          | Panel domain for link generation                                        |
| `SHORT_UUID_METHOD`                             | No          | Subscription link id generator: `nanoid`, `uuid`, `custom` (3.4.0+)     |
| `SHORT_UUID_LENGTH`                             | No          | Length for the `nanoid` method, 16-64 (default: `16`)                   |
| `SHORT_UUID_CUSTOM_PATTERN`                     | No          | Pattern for `SHORT_UUID_METHOD=custom`, e.g. `{hex:16}-{digits:10}`     |
| `IS_TELEGRAM_NOTIFICATIONS_ENABLED`             | No          | Enable Telegram notifications (default: `false`)                        |
| `TELEGRAM_BOT_TOKEN`                            | No          | Telegram bot token; required when notifications are enabled             |
| `TELEGRAM_BOT_API_ROOT`                         | No          | Telegram Bot API base URL (default: `https://api.telegram.org`)         |
| `TELEGRAM_BOT_PROXY`                            | No          | Proxy URL for the Telegram bot                                          |
| `TELEGRAM_NOTIFY_USERS`                         | No          | Chat id for user events                                                 |
| `TELEGRAM_NOTIFY_NODES`                         | No          | Chat id for node events                                                 |
| `TELEGRAM_NOTIFY_CRM`                           | No          | Chat id for CRM events                                                  |
| `TELEGRAM_NOTIFY_SERVICE`                       | No          | Chat id for service events                                              |
| `TELEGRAM_NOTIFY_TBLOCKER`                      | No          | Chat id for torrent-blocker events                                      |
| `WEBHOOK_ENABLED`                               | No          | Enable webhook notifications (default: `false`)                         |
| `WEBHOOK_URL`                                   | No          | Webhook endpoint URL; required when webhooks are enabled                |
| `WEBHOOK_SECRET_HEADER`                         | No          | Webhook signature key: min 32 chars, letters and digits only            |
| `EXPIRATION_NOTIFICATIONS_ENABLED`              | No          | Enable expiration notifications (default: `false`)                      |
| `EXPIRATION_NOTIFICATIONS`                      | No          | Hours relative to expiration, ASC (e.g. `[-72, -48, -24, 24]`)          |
| `BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED`         | No          | Notify on traffic usage thresholds (default: `false`)                   |
| `BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD`       | No          | JSON array of percentages, e.g. `[60, 80]`                              |
| `NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED`     | No          | Notify about idle users (default: `false`)                              |
| `NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS` | No          | JSON array of hours, e.g. `[24, 72]`                                    |
| `USER_USAGE_IGNORE_BELOW_BYTES`                 | No          | Drop usage records below this size (default: `0`)                       |
| `SERVICE_CLEAN_USAGE_HISTORY`                   | No          | Prune usage history (default: `false`)                                  |
| `SERVICE_DISABLE_USER_USAGE_RECORDS`            | No          | Stop writing user usage records (default: `false`)                      |
| `SERVICE_DISABLE_SRH_RECORDS`                   | No          | Stop writing subscription request history (default: `false`)            |
| `EXPORT_TO_STREAM_ENABLED`                      | No          | Export panel events to Redis Streams (default: `false`)                 |
| `EXPORT_TO_STREAM_MAXLEN`                       | No          | Approximate max messages kept per stream (default: `3000`)              |
| `IS_HTTP_LOGGING_ENABLED`                       | No          | Enable HTTP request logging (default: `false`)                          |
| `ENABLE_DEBUG_LOGS`                             | No          | Enable debug logging (default: `false`)                                 |

The Redis connection takes exactly one of the two forms: `REDIS_SOCKET`, or `REDIS_HOST` together with `REDIS_PORT`. Providing all three aborts startup.

For the full list see [Remnawave environment variables docs](https://docs.rw/docs/install/environment-variables).

### remnawave-subscription-page secret keys

| Key                                         | Required | Description                                                            |
|---------------------------------------------|----------|------------------------------------------------------------------------|
| `REMNAWAVE_PANEL_URL`                       | Yes      | Full URL of the panel; must start with `http://` or `https://`         |
| `REMNAWAVE_API_TOKEN`                       | Yes      | API token from panel: Settings → API Tokens                            |
| `APP_PORT`                                  | No       | Service port (default: `3010`)                                         |
| `CUSTOM_SUB_PREFIX`                         | No       | Custom root path, no leading/trailing slashes                          |
| `SUBPAGE_CONFIG_UUID`                       | No       | Subscription page config served by the panel (default: all-zero UUID)  |
| `TRUST_PROXY`                               | No       | Express `trust proxy` setting used to resolve the real client IP (default: `1`) |
| `CADDY_AUTH_API_TOKEN`                      | No       | `X-Api-Key` sent to the panel behind Caddy security / Tiny Auth        |
| `CLOUDFLARE_ZERO_TRUST_CLIENT_ID`           | No       | Cloudflare Zero Trust client ID                                        |
| `CLOUDFLARE_ZERO_TRUST_CLIENT_SECRET`       | No       | Cloudflare Zero Trust client secret                                    |
| `MARZBAN_LEGACY_LINK_ENABLED`               | No       | Enable Marzban legacy link support (default: `false`)                  |
| `MARZBAN_LEGACY_SECRET_KEY`                 | No       | Secret for Marzban legacy links; required when legacy links are on     |
| `MARZBAN_LEGACY_SUBSCRIPTION_VALID_FROM`    | No       | Cut-off timestamp, e.g. `2025-01-17T15:38:45.065Z`                     |
| `MARZBAN_LEGACY_DROP_REVOKED_SUBSCRIPTIONS` | No       | Reject revoked legacy links (default: `false`)                         |
| `EGAMES_COOKIE`                             | No       | Cookie value for the eGames integration                                |

Do not add `INTERNAL_JWT_SECRET` to this Secret. The image entrypoint generates it on every start, which is also why the chart never overrides the container command.

## Using with FluxCD and SOPS

First, add a `HelmRepository` pointing to the OCI registry. This is a one-time setup per cluster:

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

Then create a `HelmRelease` for each component. Secrets are managed externally via SOPS — the chart only references them by name.

**remnawave-panel** (staging cluster example with Gateway API):

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

**remnawave-subscription-page** (production cluster example with Ingress):

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

## License

[Apache 2.0](./LICENSE)
