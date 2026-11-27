# matcher — Installation Runbook

> How to install, validate and troubleshoot Matcher from this chart. For operators,
> BYOC clients included. Português: [00-getting-start.md](00-getting-start.md).

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `matcher-helm` **4.0.0** / app **6.1.0** |
| Chart registry | `oci://ghcr.io/lerianstudio/matcher-helm` (public, no login) |
| Components | `matcher` Deployment (API on port `8080`, health on `8099`, export and cleanup workers in the same process), `matcher-migrations` PreSync Job (opt-in) |
| Images | `lerianstudio/matcher:6.1.0` (Docker Hub, public), `ghcr.io/lerianstudio/matcher-migrations:6.1.0` (GHCR, see section 4 "Migration image") |
| Kubernetes | 1.27 or later (`kubeVersion` in `Chart.yaml`) |
| Last review of this runbook | 2026-11-27, against chart 4.0.0 / app 6.1.0 |
| Escalation contact | `@LerianStudio/G_Github_Devops` |

---

## 1. Installation profiles

> **Bundled infrastructure is for development and quickstart only.** Production installs use external, managed PostgreSQL, Redis/Valkey and RabbitMQ.

| Profile | What runs | Use case |
|---|---|---|
| **Quickstart** | matcher, migration Job, bundled PostgreSQL (primary + replica), Valkey and RabbitMQ | Evaluation, POC |
| **Production / external infra** | matcher, migration Job; PostgreSQL, Redis/Valkey, RabbitMQ and object storage external | Real tiers |

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| Lerian license | Always | `matcher.secrets.LICENSE_KEY`, or `matcher.licenseFile.existingSecret` (key `license.lic`), or `LICENSE_KEY` in the Secret named by `matcher.existingSecretName` |
| PostgreSQL (primary and replica) | Always. Matcher refuses to boot on an unmigrated schema | Bundled (`postgresql.enabled: true`, the default) or external (`postgresql.enabled: false` + `matcher.configmap.POSTGRES_*` and `POSTGRES_REPLICA_*` + the passwords in the Secret) |
| Schema migrations | Always, on install and on every upgrade | `migrations.enabled: true`. Off by default |
| Redis / Valkey | Always | Bundled (`valkey.enabled: true`) or external (`matcher.configmap.REDIS_HOST` as `host:port`, `REDIS_TLS` + `REDIS_PASSWORD` in the Secret) |
| RabbitMQ | Always | Bundled (`rabbitmq.enabled: true`) or external (`matcher.configmap.RABBITMQ_URI`, `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_VHOST`, `RABBITMQ_HEALTH_URL` + `RABBITMQ_PASSWORD` in the Secret). `RABBITMQ_PASSWORD` is required in both cases |
| S3-compatible object storage | For exports (the export worker is on by default). The app boots without a reachable endpoint, but exports fail at use time | `matcher.configmap.OBJECT_STORAGE_ENDPOINT`, `OBJECT_STORAGE_REGION`, `OBJECT_STORAGE_BUCKET` + `OBJECT_STORAGE_ACCESS_KEY_ID` / `OBJECT_STORAGE_SECRET_ACCESS_KEY` in the Secret |
| Encryption keys | `APP_ENC_KEY` is required in production. `IDEMPOTENCY_HMAC_SECRET` for `DEPLOYMENT_MODE` `byoc` and `saas` | Secret keys `APP_ENC_KEY` (base64, 32 bytes) and `IDEMPOTENCY_HMAC_SECRET` |
| plugin-access-manager | When authentication is on (`PLUGIN_AUTH_ENABLED: "true"`) | `matcher.configmap.PLUGIN_AUTH_ENABLED` + `PLUGIN_AUTH_ADDRESS` |

---

## 3. Installation order

### 3.1 Namespace

The chart pins the matcher workloads to `namespaceOverride`, which defaults to `matcher`. The bundled
PostgreSQL, Valkey and RabbitMQ, and the hosts the chart derives for them, follow the Helm release
namespace. **Install in the same namespace you set in `namespaceOverride`.** Either use the default
namespace `matcher`, or set both to the same value:

```bash
helm install matcher oci://ghcr.io/lerianstudio/matcher-helm --version 4.0.0 \
  -n <ns> --create-namespace --set namespaceOverride=<ns> -f <your-values>.yaml
```

If they differ, matcher lands in `matcher` while its dependencies land in `<ns>`, and the pods stay in `Init`.

### 3.2 Secrets

Keep the license and the passwords out of values files in git. Two ways, one per profile:

- **Quickstart:** pass the values from files with `--set-file`. The chart writes them to its own Secret. The bundled PostgreSQL and Valkey generate their passwords, and matcher and the migration Job read them from the subchart Secrets.
- **Production:** create your own Secret and set `matcher.useExistingSecret: true`. That Secret replaces the chart Secret, so it must hold every secret key the pods read: `LICENSE_KEY`, `POSTGRES_PASSWORD`, `POSTGRES_REPLICA_PASSWORD`, `REDIS_PASSWORD`, `RABBITMQ_PASSWORD`, `APP_ENC_KEY`, `IDEMPOTENCY_HMAC_SECRET`, and `OBJECT_STORAGE_ACCESS_KEY_ID` / `OBJECT_STORAGE_SECRET_ACCESS_KEY` when exports use static keys. The migration Job reads `POSTGRES_PASSWORD` and `LICENSE_KEY` from the same Secret, so create it before the install.

```bash
kubectl create namespace matcher
openssl rand -base64 32 | tr -d '\n' > app-enc-key.txt
openssl rand -base64 32 | tr -d '\n' > idempotency-hmac.txt
# the values stay in files: they never land in shell history
kubectl create secret generic matcher-secrets -n matcher \
  --from-file=LICENSE_KEY=./matcher.license \
  --from-file=POSTGRES_PASSWORD=./pg-password.txt \
  --from-file=POSTGRES_REPLICA_PASSWORD=./pg-password.txt \
  --from-file=REDIS_PASSWORD=./redis-password.txt \
  --from-file=RABBITMQ_PASSWORD=./rabbitmq-password.txt \
  --from-file=APP_ENC_KEY=./app-enc-key.txt \
  --from-file=IDEMPOTENCY_HMAC_SECRET=./idempotency-hmac.txt \
  --from-file=OBJECT_STORAGE_ACCESS_KEY_ID=./s3-access-key-id.txt \
  --from-file=OBJECT_STORAGE_SECRET_ACCESS_KEY=./s3-secret-access-key.txt
```

Keep a copy of `APP_ENC_KEY` in your secret store. The engine credentials Matcher stores are encrypted with it.

### 3.3 Quickstart

```yaml
# quickstart-values.yaml
matcher:
  configmap:
    DEPLOYMENT_MODE: "local"      # development posture; client installs use "byoc"
    ENV_NAME: "development"
migrations:
  enabled: true                   # matcher refuses to boot on an unmigrated schema
```

```bash
openssl rand -hex 16 > rabbitmq-password.txt
helm install matcher oci://ghcr.io/lerianstudio/matcher-helm --version 4.0.0 \
  -n matcher --create-namespace -f quickstart-values.yaml \
  --set-file matcher.secrets.LICENSE_KEY=./matcher.license \
  --set-file matcher.secrets.RABBITMQ_PASSWORD=./rabbitmq-password.txt
```

The export worker has no object storage in this profile. Exports fail until you set `OBJECT_STORAGE_*`.

### 3.4 Production / external infra

```yaml
# production-values.yaml
matcher:
  useExistingSecret: true
  existingSecretName: matcher-secrets      # every secret key (section 3.2)
  configmap:
    ENV_NAME: "production"
    DEPLOYMENT_MODE: "byoc"
    ALLOW_INSECURE_TLS: "false"            # the chart default "true" is for development only
    CORS_ALLOWED_ORIGINS: "https://console.example.com"   # the chart default "*" is refused in production
    PUBLIC_BASE_HOST: "matcher.example.com"   # host of the webhook and callback URLs Matcher hands out
    TRUSTED_PROXIES: "10.0.0.0/16"         # CIDR of your load balancer or ingress
    POSTGRES_HOST: "postgres.example.com"
    POSTGRES_SSLMODE: "require"
    POSTGRES_REPLICA_HOST: "postgres-ro.example.com"   # same host as POSTGRES_HOST if you have no replica
    POSTGRES_REPLICA_SSLMODE: "require"
    REDIS_HOST: "redis.example.com:6379"
    REDIS_TLS: "true"
    RABBITMQ_URI: "amqps"
    RABBITMQ_HOST: "rabbitmq.example.com"
    RABBITMQ_PORT: "5671"
    RABBITMQ_VHOST: "matcher"
    RABBITMQ_HEALTH_URL: "https://rabbitmq.example.com:443"
    OBJECT_STORAGE_ENDPOINT: "https://s3.sa-east-1.amazonaws.com"   # HTTPS: production refuses http
    OBJECT_STORAGE_REGION: "sa-east-1"
    OBJECT_STORAGE_BUCKET: "matcher-exports"
    OBJECT_STORAGE_USE_PATH_STYLE: "false"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "https://auth.example.com"
  ingress:
    enabled: true
    className: "<your-ingress-class>"
    hosts:
      - host: matcher.example.com
        paths:
          - path: /v1
            pathType: Prefix
          - path: /system
            pathType: Prefix
          - path: /health
            pathType: Exact
          - path: /version
            pathType: Exact
    tls:
      - secretName: matcher-tls
        hosts: [matcher.example.com]
migrations:
  enabled: true                            # reads POSTGRES_PASSWORD and LICENSE_KEY from matcher-secrets
postgresql:
  enabled: false
valkey:
  enabled: false
rabbitmq:
  enabled: false
```

```bash
helm install matcher oci://ghcr.io/lerianstudio/matcher-helm --version 4.0.0 \
  -n matcher -f production-values.yaml
```

Start from [`values.yaml`](../values.yaml) for the full set of keys.

---

## 4. Operational notes

- **Migration image.** `ghcr.io/lerianstudio/matcher-migrations` must be pullable from the cluster. If your cluster gets `401`/`ImagePullBackOff` on it, contact Lerian. Do not turn migrations off to get around it: Matcher refuses to boot on an unmigrated schema.
- **Migrations outside ArgoCD.** The migration Job and its Secret carry ArgoCD `PreSync` hook annotations. ArgoCD runs them before the Deployment. Plain `helm install` and `helm upgrade` ignore those annotations and create the Job together with the Deployment, so matcher pods may restart until the Job finishes. That is expected. If a pod stays in `CrashLoopBackOff` after the Job is `Complete`, read the pod log (section 6). With ArgoCD, the Job runs before every sync.
- **Multi-tenant.** Do not enable `migrations.enabled` with `MULTI_TENANT_ENABLED: "true"`: the runner refuses it, and the Tenant Manager owns tenant schema migrations.
- **Production fences.** With `ENV_NAME: "production"` the app refuses the chart defaults that are only safe in development: `CORS_ALLOWED_ORIGINS: "*"`, an `http://` object storage endpoint, and `SWAGGER_ENABLED: "true"`. Set the values in section 3.4. A plaintext OpenTelemetry exporter also needs `ALLOW_INSECURE_OTEL` (a reason string) through `matcher.extraEnvVars`.
- **Background workers.** The app turns on its workers by default. Confirm with the Matcher team which workers a BYOC install keeps on (for example billing or provisioning workers that only make sense in Lerian Cloud), and turn the others off with `<NAME>_WORKER_ENABLED: "false"` under `matcher.configmap`.
- **RabbitMQ user.** With the bundled broker, the chart provisions the `matcher` user with `RABBITMQ_PASSWORD`. With an external broker, create the user and vhost yourself, or enable `global.externalRabbitmqDefinitions` (HTTPS management API only).
- **External PostgreSQL bootstrap.** The chart can create the `matcher` role and database on an external server with `global.externalPostgresDefinitions` (admin credentials from an existing Secret). Otherwise create them before the install.
- **Health and rollout.** Probes, PDB and rollout come from the `lerian-common` health preset and are not values. The chart refuses an image tag below `6.1.0-beta.1`.
- **Image pull secrets.** `lerianstudio/matcher` is public on Docker Hub. `matcher.imagePullSecrets` can stay `[]`. Use `migrations.imagePullSecrets` only if Lerian gives you a credential for the migration image.
- **Object storage endpoint.** The default endpoint points at `matcher-seaweedfs` in the release namespace. The chart does not install SeaweedFS. Set `OBJECT_STORAGE_ENDPOINT` in every profile that uses exports.

---

## 5. How to validate a successful install

```bash
kubectl -n matcher get jobs,pods
# expected: matcher-migrations Complete (it is deleted after success under ArgoCD),
# matcher-* Running and Ready, and the bundled matcher-postgresql-*, matcher-valkey-*
# and matcher-rabbitmq-* when they are enabled
kubectl -n matcher rollout status deploy/matcher --timeout=600s
```

Then check the API from inside the cluster, through the Service on port `8080`:

```bash
kubectl -n matcher run matcher-check --rm -i --restart=Never --image=busybox:1.37 -- \
  wget -qO- http://matcher:8080/health
```

Readiness (`/readyz`) is served on the health port `8099` of each pod.

---

## 6. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| Render fails: `missing property 'DEPLOYMENT_MODE'` or `matcher.configmap.DEPLOYMENT_MODE is required` | No deployment mode | Set `DEPLOYMENT_MODE` (`byoc` for client installs) |
| Render fails: `matcher.secrets.RABBITMQ_PASSWORD is required ...` | No RabbitMQ password | Set it (section 3.2) |
| Render fails: `migrations.postgres.password (or matcher.secrets.POSTGRES_PASSWORD) is required ...` | Migrations on, external PostgreSQL, no password and no existing Secret | Use `matcher.useExistingSecret: true` (section 3.2) |
| Render fails: `ui is no longer part of this chart` | A values file still sets `ui` | Remove the `ui` block. The console ships in product-console |
| Render fails: `global.externalRabbitmqDefinitions.connection.protocol must be "https"` | Bootstrap Job over `http://` | Use the HTTPS management API |
| `matcher-migrations` pod in `ImagePullBackOff` | The cluster cannot pull `ghcr.io/lerianstudio/matcher-migrations` | See "Migration image" in section 4 |
| matcher `CrashLoopBackOff`, log about the schema or migrations | Migrations off, or the Job has not finished or failed | Enable `migrations.enabled` and check `kubectl -n matcher logs job/matcher-migrations` |
| Pods stuck in `Init`, `wait-for-dependencies` loops on a host | PostgreSQL or Redis unreachable, or in another namespace | Check the hosts, ports and the namespace rule (section 3.1) |
| Pods in `CreateContainerConfigError` | Secret or key missing in the namespace | Check `existingSecretName` and its keys (section 3.2) |
| matcher exits at boot with a license error | License missing or not accepted | Check `LICENSE_KEY` in the Secret the pods load, and egress to the license gateway |
| matcher exits at boot about CORS, TLS or the object storage endpoint | A development default in production | Set the values in section 3.4 ("Production fences" in section 4) |
| Exports fail | No reachable object storage, or no credentials | Set `OBJECT_STORAGE_*` and the access keys |
