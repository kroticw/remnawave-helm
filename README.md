# remnawave-helm

[🇷🇺 Русская версия](./README_RU.md)

Helm charts for deploying [Remnawave](https://github.com/remnawave/backend) VPN panel components in Kubernetes.

## Charts

| Chart                                                                 | Description                        | Default Image                        |
|-----------------------------------------------------------------------|------------------------------------|--------------------------------------|
| [`remnawave-panel`](./charts/remnawave-panel)                         | Remnawave backend + frontend panel | `remnawave/backend:2`                |
| [`remnawave-subscription-page`](./charts/remnawave-subscription-page) | Lightweight subscription portal    | `remnawave/subscription-page:latest` |

The charts are independent and can be deployed in any combination: both in the same namespace, in different namespaces within one cluster, or in entirely separate clusters. The subscription page communicates with the panel over HTTPS using a configured API token.

## Requirements

- Kubernetes 1.25+
- Helm 3.10+
- For `ingress`: an Ingress controller (e.g. ingress-nginx) and cert-manager
- For `httproute`: [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) installed and a Gateway controller (e.g. Envoy Gateway)
- For `serviceMonitor`: prometheus-operator or victoria-metrics-operator

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
  --from-literal=REDIS_DB='0' \
  --from-literal=JWT_AUTH_SECRET="$(openssl rand -hex 64)" \
  --from-literal=JWT_API_TOKENS_SECRET="$(openssl rand -hex 64)" \
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
| `image.tag`               | Image tag                                           | `2`                 |
| `image.pullPolicy`        | Image pull policy                                   | `Always`            |
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
| `serviceMonitor.enabled`  | Enable ServiceMonitor for metrics scraping          | `false`             |
| `serviceMonitor.interval` | Scrape interval                                     | `30s`               |
| `serviceMonitor.labels`   | Additional labels on ServiceMonitor                 | `{}`                |
| `resources`               | CPU/memory requests and limits                      | see values.yaml     |
| `nodeSelector`            | Node selector                                       | `{}`                |
| `tolerations`             | Tolerations                                         | `[]`                |
| `affinity`                | Affinity rules                                      | `{}`                |

> `ingress.enabled` and `httproute.enabled` are mutually exclusive. Setting both to `true` will cause a render error.

### remnawave-subscription-page

| Parameter               | Description                                         | Default                       |
|-------------------------|-----------------------------------------------------|-------------------------------|
| `replicaCount`          | Number of replicas                                  | `1`                           |
| `image.repository`      | Image repository                                    | `remnawave/subscription-page` |
| `image.tag`             | Image tag                                           | `latest`                      |
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

| Key                                 | Required | Description                                                         |
|-------------------------------------|----------|---------------------------------------------------------------------|
| `DATABASE_URL`                      | Yes      | PostgreSQL connection string: `postgresql://user:pass@host:5432/db` |
| `REDIS_HOST`                        | Yes      | Redis/KeyDB hostname                                                |
| `REDIS_PORT`                        | Yes      | Redis/KeyDB port (default: `6379`)                                  |
| `REDIS_DB`                          | Yes      | Redis database number (default: `0`)                                |
| `JWT_AUTH_SECRET`                   | Yes      | Auth JWT secret, min 64 chars (`openssl rand -hex 64`)              |
| `JWT_API_TOKENS_SECRET`             | Yes      | API tokens JWT secret, min 64 chars                                 |
| `FRONT_END_DOMAIN`                  | Yes      | Panel public URL, used for CORS (e.g. `https://panel.example.com`)  |
| `SUB_PUBLIC_DOMAIN`                 | Yes      | Subscription public URL (e.g. `https://sub.example.com/api/sub`)    |
| `APP_PORT`                          | No       | Panel port (default: `3000`)                                        |
| `METRICS_PORT`                      | No       | Metrics port (default: `3001`)                                      |
| `API_INSTANCES`                     | No       | Number of API workers (default: `1`)                                |
| `REDIS_PASSWORD`                    | No       | Redis password                                                      |
| `REDIS_SOCKET`                      | No       | Redis Unix socket path (alternative to host/port)                   |
| `JWT_AUTH_LIFETIME`                 | No       | Auth token lifetime in hours (default: `12`)                        |
| `PANEL_DOMAIN`                      | No       | Panel domain for link generation                                    |
| `METRICS_USER`                      | Yes      | Prometheus metrics basic auth username                              |
| `METRICS_PASS`                      | Yes      | Prometheus metrics basic auth password                              |
| `IS_TELEGRAM_NOTIFICATIONS_ENABLED` | No       | Enable Telegram notifications (default: `false`)                    |
| `TELEGRAM_BOT_TOKEN`                | No       | Telegram bot token                                                  |
| `WEBHOOK_ENABLED`                   | No       | Enable webhook notifications (default: `false`)                     |
| `WEBHOOK_URL`                       | No       | Webhook endpoint URL                                                |
| `WEBHOOK_SECRET_HEADER`             | No       | Webhook signature key, min 32 chars                                 |
| `IS_DOCS_ENABLED`                   | No       | Enable Swagger/Scalar UI (default: `false`)                         |
| `IS_HTTP_LOGGING_ENABLED`           | No       | Enable HTTP request logging (default: `false`)                      |
| `ENABLE_DEBUG_LOGS`                 | No       | Enable debug logging (default: `false`)                             |

For the full list see [Remnawave environment variables docs](https://docs.rw/docs/install/environment-variables).

### remnawave-subscription-page secret keys

| Key                                | Required | Description                                                        |
|------------------------------------|----------|--------------------------------------------------------------------|
| `REMNAWAVE_PANEL_URL`              | Yes      | Full URL of the Remnawave panel (e.g. `https://panel.example.com`) |
| `REMNAWAVE_API_TOKEN`              | Yes      | API token from panel: Settings → API Tokens                        |
| `APP_PORT`                         | No       | Service port (default: `3010`)                                     |
| `CUSTOM_SUB_PREFIX`                | No       | Custom root path, no leading/trailing slashes                      |
| `MARZBAN_LEGACY_LINK_ENABLED`      | No       | Enable Marzban legacy link support (default: `false`)              |
| `MARZBAN_LEGACY_SECRET_KEY`        | No       | Secret for Marzban legacy links                                    |
| `SUBSCRIPTION_UI_DISPLAY_RAW_KEYS` | No       | Show raw `vless://` links (default: `false`)                       |

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

## License

[Apache 2.0](./LICENSE)
