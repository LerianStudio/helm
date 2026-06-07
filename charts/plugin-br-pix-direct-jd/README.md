# Plugin BR Instant Payment Helm Chart

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `pix.secrets.MIDAZ_CLIENT_SECRET`, `pix.secrets.JD_SECRET`, `pix.secrets.JD_PIX_CLIENT_SECRET`, and `pix.secrets.SECRET_KEY_BASE` (external-boundary credentials). The PostgreSQL password (`DATABASE_PASSWORD`/`POSTGRES_PASSWORD`) is **not** required: it is single-sourced from the bundled `postgresql` subchart Secret and read via `secretKeyRef` (see "Single-source PostgreSQL secret" below).
- Dependency notes: Uses the bundled Bitnami PostgreSQL dependency chart unless an external PostgreSQL is configured.
- Production overrides: Provide production JD credentials, certificates, encryption keys, and messaging credentials through chart secrets or existing Secrets where supported; override image tags, ingress, resources, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

### Single-source PostgreSQL secret

The PostgreSQL password lives in exactly one place per deployment mode:

- **Bundled subchart (default, `postgresql.enabled=true`):** the Bitnami `postgresql` subchart generates the Secret `<release>-postgresql` (key `password`). The `pix` Deployment wires both `DATABASE_PASSWORD` and `POSTGRES_PASSWORD`, and the job CronJob wires `DATABASE_PASSWORD`, to that key via `secretKeyRef`. The app Secret carries no DB password keys, and `pix.secrets.DATABASE_PASSWORD`/`POSTGRES_PASSWORD` should be left empty.
- **External Postgres with `postgresql.auth.existingSecret`:** the refs point at that existing Secret's `password` key. The app Secret carries no DB password keys.
- **External Postgres inline (`postgresql.enabled=false`, `postgresql.external=true`, no `existingSecret`):** set `pix.secrets.DATABASE_PASSWORD`/`POSTGRES_PASSWORD`; these are stored in the app Secret and the refs point there.

### Release name

The bundled-subchart paths assume the release is installed as **`plugin-br-pix-direct-jd`**:

- `DATABASE_HOST` is hardcoded to `plugin-br-pix-direct-jd-postgresql.midaz-plugins.svc.cluster.local` in the pix and job ConfigMaps.
- The single-source `secretKeyRef` resolves the subchart Secret as `<release>-postgresql`, which only equals `plugin-br-pix-direct-jd-postgresql` when the release name is `plugin-br-pix-direct-jd`.

Installing under any other release name breaks both the DB host resolution and the secret reference. This is a pre-existing constraint of the hardcoded host; install this chart as `plugin-br-pix-direct-jd` or switch to an external Postgres.

This Helm chart installs **Plugin BR Instant Payment** for Midaz, a high-performance and open-source ledger.

---

## Install Plugin BR Instant Payment Helm Chart

To install Plugin BR Instant Payment using Helm, run the following command:

```console

$ helm install plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd --version <> -n midaz-plugins --create-namespace

This will create a new namespace called `midaz-plugins` if it doesn't already exist and deploy the Plugin BR Instant Payment Helm chart.

After installation, you can verify that the release was successful by listing the Helm releases in the `midaz-plugins` namespace:

```console
$ helm list -n midaz-plugins
```

---

## Upgrading

To upgrade the chart to a new version:

```console
$ helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd --version <new-version> -n midaz-plugins
```

---

## Uninstalling

To uninstall the chart:

```console
$ helm uninstall plugin-br-pix-direct-jd -n midaz-plugins
```

---

## Configuring Ingress for Different Controllers

The Plugin pix Helm Chart optionally supports different Ingress Controllers for exposing services when necessary. Below are the configurations for commonly used controllers.

- **Note:** Before configuring Ingress, ensure that you have an Ingress Controller installed in your cluster. Examples include NGINX, AWS ALB, and Traefik.

### NGINX Ingress Controller
To use the **NGINX Ingress Controller**, configure the `values.yaml` as follows:

```yaml
pix:
  ingress:
    enabled: true
    className: "nginx"
    annotations: {}
    hosts:
      - host: midaz.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: midaz-tls
        hosts:
          - midaz.example.com
```

---

## Parameters

### pix Service

| Parameter | Description | Default |
| --- | --- | --- |
| `pix.replicaCount` | Number of replicas for the deployment | `1` |
| `pix.image.repository` | Repository for the container image | `ghcr.io/lerianstudio/plugin-br-pix-direct-jd` |
| `pix.image.pullPolicy` | Image pull policy | `Always` |
| `pix.image.tag` | Image tag used for deployment | `""` (defaults to Chart.AppVersion) |
| `pix.imagePullSecrets` | Secrets for pulling images from a private registry | `{}` |
| `pix.revisionHistoryLimit` | Old ReplicaSets to retain | `10` |
| `pix.nameOverride` | Overrides the default generated name by Helm | `""` |
| `pix.fullnameOverride` | Overrides the full name generated by Helm | `""` |
| `pix.ingress.enabled` | Enable or disable ingress | `false` |
| `pix.ingress.className` | Ingress class name | `""` |
| `pix.ingress.annotations` | Additional ingress annotations | `{}` |
| `pix.ingress.hosts` | Ingress host configuration | `[{"host": "", "paths": [{"path": "/", "pathType": "Prefix"}]}]` |
| `pix.ingress.tls` | TLS configuration for ingress | `[]` |
| `pix.service.type` | Kubernetes service type | `ClusterIP` |
| `pix.service.port` | Service port | `4011` |
| `pix.deploymentStrategy` | Deployment strategy | See `values.yaml` |
| `pix.podSecurityContext` | Pod security context | `{}` |
| `pix.securityContext` | Security context for the container | See `values.yaml` |
| `pix.pdb.enabled` | Enable or disable PodDisruptionBudget | `true` |
| `pix.pdb.maxUnavailable` | Maximum number of unavailable pods | `1` |
| `pix.pdb.minAvailable` | Minimum number of available pods | `0` |
| `pix.resources` | CPU and memory limits for pods | See `values.yaml` |
| `pix.autoscaling.enabled` | Enable or disable horizontal pod autoscaling | `true` |
| `pix.autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `pix.autoscaling.maxReplicas` | Maximum number of replicas | `3` |
| `pix.nodeSelector` | Node selector for scheduling pods | `{}` |
| `pix.tolerations` | Tolerations for scheduling on tainted nodes | `{}` |
| `pix.affinity` | Affinity rules for pod scheduling | `{}` |
| `pix.extraEnvVars` | Extra environment variables to be added to the deployment | `{}` |
| `pix.useExistingSecrets` | Use an existing secret instead of creating a new one | `false` |
| `pix.existingSecretName` | The name of the existing secret to use | `""` |

### QR Code Service

| Parameter | Description | Default |
| --- | --- | --- |
| `qrcode.replicaCount` | Number of replicas for the deployment | `1` |
| `qrcode.image.repository` | Repository for the container image | `lerianstudio/cert-provider` |
| `qrcode.image.pullPolicy` | Image pull policy | `Always` |
| `qrcode.image.tag` | Image tag used for deployment | `""` |
| `qrcode.imagePullSecrets` | Secrets for pulling images from a private registry | `{}` |
| `qrcode.ingress.enabled` | Enable or disable ingress | `false` |
| `qrcode.ingress.className` | Ingress class name | `""` |
| `qrcode.ingress.annotations` | Additional ingress annotations | `{}` |
| `qrcode.ingress.hosts` | Ingress host configuration | `[{"host": "", "paths": [{"path": "/", "pathType": "Prefix"}]}]` |
| `qrcode.ingress.tls` | TLS configuration for ingress | `[]` |
| `qrcode.service.type` | Kubernetes service type | `ClusterIP` |
| `qrcode.service.port` | Service port | `4009` |
| `qrcode.podSecurityContext` | Pod security context | `{}` |
| `qrcode.resources` | CPU and memory limits for pods | See `values.yaml` |
| `qrcode.autoscaling.enabled` | Enable or disable horizontal pod autoscaling | `true` |
| `qrcode.autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `qrcode.autoscaling.maxReplicas` | Maximum number of replicas | `9` |
| `qrcode.useExistingSecret` | Use an existing secret instead of creating a new one | `false` |
| `qrcode.existingSecretName` | The name of the existing secret to use | `""` |

### Job (CronJob)

| Parameter | Description | Default |
| --- | --- | --- |
| `job.name` | Resource base name | `"plugin-br-pix-direct-jd-job"` |
| `job.image.repository` | Repository for the container image | `ghcr.io/lerianstudio/plugin-br-pix-direct-jd-job` |
| `job.image.pullPolicy` | Image pull policy | `Always` |
| `job.image.tag` | Image tag used for deployment | `""` (defaults to Chart.AppVersion) |
| `job.imagePullSecrets` | Secrets for pulling images from a private registry | `{}` |
| `job.podSecurityContext` | Pod security context | `{}` |
| `job.service.type` | Kubernetes service type | `ClusterIP` |
| `job.service.port` | Service port | `4012` |
| `job.resources` | CPU and memory limits for pods | See `values.yaml` |
| `job.configmap.JOBS_CRON` | Cron schedule for background processing | `"*/1 * * * *"` |
| `job.extraEnvVars` | Extra environment variables | `{}` |
| `job.useExistingSecret` | Use an existing secret instead of creating a new one | `false` |
| `job.existingSecretName` | The name of the existing secret to use | `"cert-provider"` |

### PostgreSQL Dependency

| Parameter | Description | Default |
| --- | --- | --- |
| `postgresql.enabled` | Enable the PostgreSQL dependency | `true` |
| `postgresql.external` | Use an external PostgreSQL instance | `false` |
| `postgresql.image.repository` | PostgreSQL image repository | `bitnamisecure/postgresql` |
| `postgresql.image.tag` | PostgreSQL image tag | `latest` |
| `postgresql.auth.enabled` | Enable authentication | `true` |
| `postgresql.auth.enablePostgresUser` | Create default postgres user | `false` |
| `postgresql.auth.username` | Application DB user | `pix` |
| `postgresql.auth.password` | Application DB password | `lerian` |
| `postgresql.auth.database` | Application DB name | `pix` |

> IMPORTANT: The bundled PostgreSQL is not intended for production. For production, use an external/managed PostgreSQL and set `postgresql.enabled=false`.


## Support

For more information, see the [Lerian Studio Documentation](https://docs.lerian.studio/) or contact the maintainers.
