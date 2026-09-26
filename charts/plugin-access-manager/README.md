# Plugin Access Manager Helm Chart

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `identity.secrets.AUTHORIZER_CLIENT_SECRET`, `auth.secrets.AUTHORIZER_CLIENT_SECRET`, and `auth.initUser.adminPassword` while `auth.initUser.enabled` is true (or `auth.initUser.useExistingSecret=true` with `auth.initUser.adminPasswordSecretName` pointing at an existing Secret). `auth.secrets.DB_PASSWORD` is single-sourced from the `<release>-auth-database` Secret this chart keeps for the bundled database (read via `secretKeyRef`) and is only required when the database is **external** (`auth-database.external=true`/disabled) without an `auth-database.auth.existingSecret` override — in that case install fails loud if it is unset.
- Dependency notes: Uses local PostgreSQL/Valkey dependencies for auth services unless external services are configured.
- Production overrides: Provide authorizer and database credentials through chart secrets or existing Secrets where supported; override identity/auth/caradhras image tags, ingress, resources, and persistence.
- Initial admin: the bootstrap admin (`admin@midaz.tech`) is first seeded from `init_data.json` baked into the `ghcr.io/lerianstudio/caradhras` image at first boot, with a placeholder password. While `auth.initUser.enabled` is true, a `post-install` hook Job then sets that account's password to the operator-supplied credential: `auth.initUser.adminPassword` when `auth.initUser.useExistingSecret=false`, otherwise the `adminPasswordSecretKey` value from the Secret named by `auth.initUser.adminPasswordSecretName`. The hook runs on `helm install` only, never on upgrades, so upgrades and later value changes neither reset the password nor recreate a deleted admin account, and passwords rotated inside Caradhras are preserved. If `auth.initUser.enabled=false`, the chart never touches the account and the image placeholder stays live; rotate it immediately after the first login.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

> **Uninstall keeps the identity data.** `helm uninstall` leaves the bundled database volume (`data-<release>-auth-database-0`) and its password Secret (`<release>-auth-database`), so a reinstall under the same release name opens the same users, organizations and applications with the same password. This chart, not the Bitnami subchart, owns that Secret: it takes `auth-database.auth.password` when set, else the Secret already in the namespace, else a new random password. Deleting the data is a separate, manual step: delete that PVC and that Secret together (the Valkey volume `valkey-data-<release>-valkey-primary-0`, sessions and cached tokens only, is left too). Deleting only the Secret resets nothing: a reinstall generates a new password that the kept data never learned.

This helm chart installs [Plugin Acess Manager](https://docs.lerian.studio/docs/auth-identity) for Midaz, a high-performance and open-source ledger.

---

## Install Plugin Access Manager Helm Chart:

To install Plugin Access Manager using Helm, run the following command:

```console
$ helm install plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version <> -n midaz-plugins --create-namespace
```

This will create a new namespace called midaz-plugins if it doesn't already exist and deploy the Plugin Access Manager Helm chart.

After installation, you can verify that the release was successful by listing the Helm releases in the midaz-plugins namespaces:

```console
$ helm list -n midaz-plugins
```

---
## Managed Cloud (`global.cloud`)

Point this chart at a managed-cloud environment (AWS/GCP/Azure) instead of the
bundled in-cluster Caradhras/Postgres/Redis with one knob:

```yaml
global:
  cloud: "aws"   # aws | gcp | azure — leave unset for the bundled dev topology
  datastores:
    postgres: { host: "my-rds.example.com", user: "access_manager" }
    redis: { host: "my-elasticache.example.com", port: "6379" }
  env:
    name: "production"
  multiTenant:
    enabled: false
  observability:
    enabled: true

# Disable the bundled in-cluster datastores — otherwise they still deploy
# alongside the managed ones above (wasted resources, confusing topology).
auth-database:
  enabled: false
valkey:
  enabled: false

# auth.secrets.DB_PASSWORD/REDIS_PASSWORD are normally single-sourced from the
# bundled datastores' Secrets. With both disabled above, supply the managed
# instances' credentials explicitly (or point auth.existingSecretName at a
# pre-created Secret with the same keys instead of inlining them here):
auth:
  secrets:
    DB_PASSWORD: "CHANGE_ME"
    REDIS_PASSWORD: "CHANGE_ME"
```

`global.cloud` sets the connection TOPOLOGY (TLS, SSL mode) for every mask
below; only the ENDPOINTS (host/port/user) still come from `global.datastores`
— a cloud preset can't know your RDS host. A native
`{auth,identity}.configmap.<KEY>` always overrides any mask.

Copy `values-template.yaml` as your starting point — it documents every
`global.*` mask with a working example. `values.yaml` is the full
power-user reference; `values.schema.json` validates it.

---
## Configuring Ingress for Different Controllers

The Midaz Helm Chart optionally supports different Ingress Controllers for exposing services when necessary. It is possible to enable Ingress for the following services: Transaction, Onboarding and Console. Below are the configurations for commonly used controllers.

- **Note:** Before configuring Ingress, ensure that you have an Ingress Controller installed in your cluster. The Ingress Controller is responsible for managing external access to the services. Examples of popular Ingress Controllers include NGINX, AWS ALB, and Traefik.

### NGINX Ingress Controller
To use the **NGINX Ingress Controller**, configure the `values.yaml` as follows:

```yaml
ingress:
  enabled: true
  className: "nginx"
  // The `annotations` field is used to add custom metadata to the Nginx resource.
  // Annotations are key-value pairs that can be used to attach arbitrary non-identifying metadata to objects.
  // These annotations can be used by various tools and libraries to augment the behavior of the Nginx resource.
  // See more https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md
  annotations: {} 
  hosts:
    - host: midaz.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: midaz-tls  # Ensure this secret exists or is managed by cert-manager
      hosts:
        - midaz.example.com
```

---

### AWS ALB (Application Load Balancer)
For **AWS ALB Ingress Controller**, use the following configuration:

```yaml
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internal  # Use "internet-facing" for public ALB
    alb.ingress.kubernetes.io/target-type: ip   # Use "instance" if targeting EC2 instances
    alb.ingress.kubernetes.io/group.name: "midaz"  # Group ALB resources under this name
    alb.ingress.kubernetes.io/healthcheck-path: "/healthz"  # Health check path
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'  # Listen on HTTP and HTTPS
  hosts:
    - host: midaz.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []  # TLS is managed by the ALB using ACM certificates
```

---

### Traefik Ingress Controller
For **Traefik**, configure the `values.yaml` as follows:

```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "web, websecure"  # Entrypoints defined in Traefik
    traefik.ingress.kubernetes.io/router.tls: "true"  # Enable TLS for this route
  hosts:
    - host: midaz.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: midaz-tls  # Ensure this secret exists and contains the TLS certificate
      hosts:
        - midaz.example.com
```

## Plugin Access Manager Components:

### Identity Service

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Number of replicas for the deployment | `1` |
| `image.repository` | Repository for the container image | `ghcr.io/lerianstudio/plugin-identity` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `image.tag` | Image tag used for deployment | `2.4.5` |
| `imagePullSecrets` | Secrets for pulling images from a private registry | `[{"name": "regcred"}]` |
| `nameOverride` | Overrides the default generated name by Helm | `""` |
| `fullnameOverride` | Overrides the full name generated by Helm | `""` |
| `ingress.enabled` | Enable or disable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Additional ingress annotations | `{}` |
| `ingress.hosts` | Ingress host configuration | `[{"host": "", "paths": [{"path": "/", "pathType": "Prefix"}]}]` |
| `ingress.tls` | TLS configuration for ingress | `[]` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `4001` |
| `deploymentStrategy` | Deployment strategy | `{"type": "RollingUpdate", "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 1}}` |
| `podSecurityContext` | Pod security context | `{}` |
| `securityContext` | Security context for the container | See `values.yaml` |
| `pdb.enabled` | Enable or disable PodDisruptionBudget | `true` |
| `pdb.maxUnavailable` | Maximum number of unavailable pods | `1` |
| `pdb.minAvailable` | Minimum number of available pods | `0` |
| `pdb.annotations` | Annotations for PodDisruptionBudget | `{}` |
| `resources` | CPU and memory limits for pods | See `values.yaml` |
| `autoscaling.enabled` | Enable or disable horizontal pod autoscaling | `true` |
| `autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `autoscaling.maxReplicas` | Maximum number of replicas | `3` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | `80` |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | `80` |
| `nodeSelector` | Node selector for scheduling pods | `{}` |
| `tolerations` | Tolerations for scheduling on tainted nodes | `{}` |
| `affinity` | Affinity rules for pod scheduling | `{}` |
| `extraEnvVars` | Extra environment variables to be added to the deployment | `{}` |
| `configmap.PLUGIN_AUTH_SSO_CALLBACK_URL` | Literal callback URL for this component, overriding `common.sso.*`. Must match the auth component — see [Single sign-on](#single-sign-on-commonssobaseurl) | unset |
| `useExistingSecret` | Use an existing secret instead of creating a new one | `false` |
| `existingSecretName` | The name of the existing secret to use | `""` |

### Auth Service

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Number of replicas for the deployment | `3` |
| `image.repository` | Repository for the console service container image | `ghcr.io/lerianstudio/plugin-auth` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `image.tag` | Image tag used for deployment | `2.6.7` |
| `imagePullSecrets` | Secrets for pulling images from a private registry | `[{"name": "regcred"}]` |
| `nameOverride` | Overrides the default generated name by Helm | `""` |
| `fullnameOverride` | Overrides the full name generated by Helm | `""` |
| `namespaceOverride` | Overrides the namespace for the service | `""` |
| `ingress.enabled` | Enable or disable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Additional ingress annotations | `{}` |
| `ingress.hosts` | Ingress host configuration | `[{"host": "", "paths": [{"path": "/", "pathType": "Prefix"}]}]` |
| `ingress.tls` | TLS configuration for ingress | `[]` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `4000` |
| `deploymentStrategy` | Deployment strategy | `{"type": "RollingUpdate", "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 1}}` |
| `podSecurityContext` | Pod security context | `{}` |
| `securityContext` | Security context for every auth-side container: auth, caradhras (including its migrate init container) and its UI, the init-user Job, and their init containers | See `values.yaml` |
| `pdb.enabled` | Enable or disable PodDisruptionBudget | `true` |
| `pdb.maxUnavailable` | Maximum number of unavailable pods | `1` |
| `pdb.minAvailable` | Minimum number of available pods | `0` |
| `pdb.annotations` | Annotations for PodDisruptionBudget | `{}` |
| `resources` | CPU and memory limits for pods | See `values.yaml` |
| `autoscaling.enabled` | Enable or disable horizontal pod autoscaling | `true` |
| `autoscaling.minReplicas` | Minimum number of replicas | `3` |
| `autoscaling.maxReplicas` | Maximum number of replicas | `9` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | `80` |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | `80` |
| `nodeSelector` | Node selector for scheduling pods | `{}` |
| `tolerations` | Tolerations for scheduling on tainted nodes | `{}` |
| `affinity` | Affinity rules for pod scheduling | `{}` |
| `extraEnvVars` | Extra environment variables to be added to the deployment | `{}` |
| `configmap.MFA_ENABLED` | Multi-factor authentication gate. Unset omits the key and leaves the application default in force | unset |
| `configmap.PLUGIN_AUTH_SSO_CALLBACK_URL` | Literal callback URL for this component, overriding `common.sso.*`. Must match the identity component — see [Single sign-on](#single-sign-on-commonssobaseurl) | unset |
| `useExistingSecret` | Use an existing secret instead of creating a new one | `false` |
| `existingSecretName` | The name of the existing secret to use | `""` |

#### Single sign-on (`common.sso.baseUrl`)

An SSO login leaves the platform for the identity provider and has to come back.
The address it comes back to has two halves, and they belong to different people:

| half | example | whose |
| --- | --- | --- |
| scheme + host (+ path prefix) | `https://console.example.com` | **yours** — you map the console on your own domain; the chart cannot know or derive it |
| callback path | `/signin/sso/callback` | **ours** — the console route the browser lands on; do not change it |

So you give the chart the first half and it composes the second:

```yaml
common:
  sso:
    baseUrl: "https://console.example.com"
    # -> https://console.example.com/signin/sso/callback
```

Serving the console under a path prefix works the same way —
`baseUrl: "https://apps.example.com/console"` yields
`https://apps.example.com/console/signin/sso/callback`.

**Why the chart composes it instead of taking the whole URL.** A mistyped path is
the most likely mistake here and by far the hardest to diagnose: Caradhras rejects
a `redirect_uri` that is not on its allow-list without saying which part was wrong,
so `/signin/sso/calback` produces a login that fails with an error naming nothing.
Composing takes that mistake off the table.

Setting this is **required to configure an SSO provider at all**. Without it,
identity refuses to save the provider and answers the request with an error; the
provider would otherwise look saved while no login through it could ever complete.

**Passing the whole URL literally.** `common.sso.callbackUrl` takes the finished
URL instead of composing one — but the host is the only part it may change: the
chart refuses a value whose path is not `/signin/sso/callback`, naming the
expected path and the one received. A near-miss (`/sso/callback`,
`/signin/callback`, `/signin/sso/calback`) otherwise renders clean and surfaces
only at the first login.

```yaml
common:
  sso:
    callbackUrl: "https://console.example.com/signin/sso/callback"
```

**The escape hatch, and it says so.** A deployment that genuinely answers SSO on
another path — a console mounted on a custom route, or a proxy that rewrites it —
lifts that check explicitly:

```yaml
common:
  sso:
    callbackUrl: "https://console.example.com/custom/sso/return"
    allowCustomCallbackPath: true   # leaving the supported path, on purpose
```

Off this path the chart can no longer tell you whether the URL is right; it must
match whatever actually serves the console callback, and a mismatch shows up only
as a failed login. The absolute-`http(s)`-with-a-path requirement still applies —
that one is the binary's, not the chart's.

`baseUrl` and `callbackUrl` are alternatives, not layers — one asks the chart to
append the route, the other supplies the finished URL — and the chart refuses to
render when both are set. It also refuses a `baseUrl` that already ends in
`/signin/sso/callback`, which is what a full URL pasted into the wrong field looks
like and would otherwise double the path.

**What the chart validates before you deploy.** The resolved URL must be an
absolute `http(s)` URL carrying a concrete path — the same rule the binary applies
(`isAbsoluteCallbackURL`). A host with no path is refused on purpose: Casdoor
treats an allow-list entry without a path as a wildcard over every path on that
host *and its subdomains*, so a half-formed value would widen the allow-list
instead of authorising one endpoint. On top of that the chart checks the path is
the console route, unless `allowCustomCallbackPath` says otherwise. Failing at
`helm template` names the values field; failing at runtime is a provider that
saves and never completes a login.

**One value, both components, and the chart enforces it.** identity writes the URL
into the Caradhras provider's redirect allow-list; auth then sends the same URL as
the `redirect_uri` of the code relay, and Caradhras rejects any `redirect_uri` the
allow-list does not carry. Two different values therefore deploy cleanly and break
at the first login, with an error that names neither component. The shared
`common.sso.*` fields give that for free; the per-component
`{identity,auth}.configmap.PLUGIN_AUTH_SSO_CALLBACK_URL` overrides exist for
migration, and the chart **refuses to render** whenever the two resolve differently.

The value is never derived from `PLUGIN_AUTH_ADDRESS`. That address is how the
components reach each other inside the cluster; this one has to be reachable by
the end user's browser, and they are not the same host.

#### Multi-factor authentication (`auth.configmap.MFA_ENABLED`)

`MFA_ENABLED` gates multi-factor authentication on the auth component. It is unset
by default: the key is then absent from the ConfigMap and the application's own
default stays in force. Set `auth.configmap.MFA_ENABLED: "true"` to turn it on.
The `MFA_SESSION_TTL_SEC` / `MFA_REMEMBER_TTL_SEC` / `MFA_MAX_ATTEMPTS` /
`MFA_MAX_RESEND_ATTEMPTS` keys tune it and already have chart defaults.

#### Moving these keys off `extraEnvVars`

Both keys were previously deliverable only through `extraEnvVars`. That still
works and nothing breaks on upgrade. But setting a key through **both** channels
is refused: the named key and `extraEnvVars` render into the same ConfigMap `data`
map, so the key would be emitted twice and the surviving value is whatever the
YAML parser keeps — the chart refuses rather than shipping an install whose
effective configuration nobody can read off the values file. When migrating,
delete the `extraEnvVars` entry in the same change that adds the named key.

```yaml
# before
auth:
  extraEnvVars:
    PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"
    MFA_ENABLED: "true"
identity:
  extraEnvVars:
    PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"

# after
common:
  sso:
    baseUrl: "https://console.example.com"
auth:
  configmap:
    MFA_ENABLED: "true"
```

### Caradhras Service (auth backend)

Caradhras is a top-level component, sibling to `identity`/`auth` (formerly the
nested `auth.backend`, which ran the legacy Casdoor image). A legacy
`auth.backend.*` override in your OWN values file is still honored as a
fallback for `image.repository`/`image.tag`/`image.pullPolicy`/`service.port`/
`replicaCount` — see `docs/UPGRADE-10.0.md`.

| Parameter | Description | Default |
| --- | --- | --- |
| `caradhras.replicaCount` | Number of replicas | `1` |
| `caradhras.name` | Name of the caradhras component | `<release>-caradhras` |
| `caradhras.image.repository` | Repository for the caradhras container image | `ghcr.io/lerianstudio/caradhras` |
| `caradhras.image.tag` | Image tag used for deployment | `1.2.0-beta.59` |
| `caradhras.service.port` | Service port | `8000` |
| `caradhras.autoscaling` | Autoscaling configuration | See `values.yaml` |
| `caradhras.migrations.image.repository` | Repository for the caradhras-migrations container image | `ghcr.io/lerianstudio/caradhras-migrations` |
| `caradhras.migrations.image.tag` | Image tag — MUST stay on the `1.2.0-beta.x` train, not the unrelated `3.2.0-beta.x` train also present in this GHCR repo | `1.2.0-beta.59` |
| `caradhras.ui.enabled` | Enable the Caradhras UI (SPA console) sub-resource | `false` |
| `caradhras.ui.image.repository` | Repository for the caradhras-ui container image | `ghcr.io/lerianstudio/caradhras-ui` |
| `caradhras.ui.image.tag` | Image tag used for deployment | `1.2.0-beta.59` |
| `caradhras.ui.service.port` | Service port | `80` |
| `caradhras.ui.ingress.enabled` | Enable ingress for the UI | `false` |
| `caradhras.configmap.redisEndpoint` | Shared session store for a Redis **without AUTH**, `host:port` with no space. Empty keeps sessions in a file on each pod's own filesystem. **Required above one replica** — see below. Refused when it carries a password | `""` |
| `caradhras.secrets.redisEndpoint` | Shared session store for a Redis **with AUTH**: the full beego connection string `host:port,poolsize,password[,dbnum]`. Delivered by Secret, never by ConfigMap | `""` |
| `caradhras.useExistingSecret` | Manage the caradhras Secret yourself; the chart creates none | `false` |
| `caradhras.existingSecretName` | Name of that Secret. Must carry the key `redisEndpoint` | `""` |
| `caradhras.redisPassword.enabled` | Inject the Redis AUTH password as the `redisPassword` config key, by `secretKeyRef`. Lets the endpoint stay a bare `host:port` | `false` |
| `caradhras.redisPassword.secretName` | Secret holding that password. Empty uses the auth Secret | `""` |
| `caradhras.redisPassword.secretKey` | Key inside that Secret | `REDIS_PASSWORD` |
| `caradhras.configmap.redisTls` | Reach the session store over TLS (`"true"`/`"false"`). Only emitted when an endpoint is configured; also settable once for every component via `global.datastores.redis.tls` | `""` (resolves to `false`) |

#### Session store (required above one replica)

Caradhras is beego, and beego writes a login session to a file under the pod's
own working directory unless `redisEndpoint` names a Redis. With one pod that
works. With two, a login that starts on one pod and finishes on another does not
find its session and fails with `unknown authentication type`. The failure is
intermittent by nature: it depends on which pod the load balancer picks.

A session store is therefore mandatory whenever caradhras is pinned above one
replica (`replicaCount > 1` with autoscaling off, or `autoscaling.minReplicas >
1`). The chart **refuses to render** in that state rather than deploying a login
that fails intermittently. When autoscaling can merely reach more than one pod
(`autoscaling.maxReplicas > 1`, the chart default), the install notes carry a
warning instead — failing there would break every default install.

**Two channels, and they are mutually exclusive.** Beego's endpoint is
positional — `host:port,poolsize,password,dbnum` — so the password, when there
is one, is part of the same string the chart has to deliver:

| The Redis | Set | Delivered as |
|---|---|---|
| needs no AUTH | `caradhras.configmap.redisEndpoint: "valkey:6379"` | ConfigMap key, via `envFrom` |
| requires AUTH | `caradhras.secrets.redisEndpoint: "valkey:6379,100,<password>"` | Secret key, via `secretKeyRef` |
| requires AUTH, password already in a Secret | `caradhras.configmap.redisEndpoint: "valkey:6379"` plus `caradhras.redisPassword.enabled: true` | endpoint in the ConfigMap, password as env `redisPassword`, via `secretKeyRef` |

The ConfigMap channel **refuses a value with a third field**: a ConfigMap gives
no Secret-equivalent protection, so any principal that can read it would recover
the Redis password. Setting both channels is also refused — caradhras reads a
single env named `redisEndpoint`, and defining it twice is undefined behavior.

**The third row is the one to prefer when the password already lives in a
Secret.** Caradhras reads `redisPassword` as its own config key and resolves the
session store and the rate limiter from that one reading, so the credential never
has to be spliced into a connection string — and the endpoint, carrying no
password, can ride the ConfigMap. The password defaults to the auth Secret's
`REDIS_PASSWORD` key, which is where the caradhras `DB_PASSWORD` already reads
from; point `caradhras.redisPassword.secretName`/`.secretKey` elsewhere for a
different topology.

That channel requires the endpoint to be a **bare `host:port`**, and the chart
refuses to render otherwise. Caradhras compares the endpoint's own password field
with `redisPassword` and refuses to boot when they differ — and an endpoint that
carries fields with an *empty* password field differs from any password, so
`valkey:6379,100` plus `redisPassword` crashloops even though neither value looks
wrong on its own. Set one or the other, never a mix.

To keep the password out of your values file entirely, set
`caradhras.useExistingSecret=true` and point `caradhras.existingSecretName` at a
Secret you manage (external-secrets, sealed-secrets, or `kubectl create secret`)
carrying the key `redisEndpoint`. The chart then creates no Secret of its own.

The config keys are the beego literals in camelCase on purpose: caradhras
resolves them with `conf.GetConfigString`, which looks the exact key up in the
environment. `REDIS_HOST` / `REDIS_TLS` are the `auth`/`identity` names, read by
lib-commons, and are silently ignored by caradhras.

The endpoint is never derived from `global.datastores.redis.*`: the mask knows
only host and port, so a derived value would be silently unauthenticated against
any Redis that requires AUTH. Set it explicitly. `redisTls` does come from the
mask, so a managed-cloud profile that sets `redis.tls` once covers auth and
caradhras both.

### Auth Database (PostgreSQL)

| Parameter | Description | Default |
| --- | --- | --- |
| `auth-database.enabled` | Enable the database dependency | `true` |
| `auth-database.auth.enabled` | Enable authentication for the database | `true` |
| `auth-database.auth.enablePostgresUser` | Enable the default postgres user | `false` |
| `auth-database.auth.username` | Username for the database | `auth` |
| `auth-database.auth.password` | Password for the database (generated by this chart when left empty, and kept across uninstall) | `""` |
| `auth-database.auth.existingSecret` | Your own Secret with the database password (key `password`), replacing the one this chart keeps. LDAP and custom `secretKeys` need it | the chart's `<release>-auth-database` |
| `auth-database.auth.database` | Name of the database | `casdoor` |
| `auth-database.primary.persistence.size` | Persistence size for the primary node | `8Gi` |
| `auth-database.primary.resourcesPreset` | Resource preset for the primary node | `large` |
| `auth-database.primary.extendedConfiguration` | Extended PostgreSQL configuration | See `values.yaml` |
| `auth-database.primary.extraEnvVars` | Extra environment variables for the database | See `values.yaml` |

### Valkey (Redis)

| Parameter | Description | Default |
| --- | --- | --- |
| `valkey.enabled` | Enable the Valkey (Redis) dependency | `true` |
| `valkey.architecture` | Architecture for Valkey deployment | `standalone` |
| `valkey.auth.enabled` | Enable authentication for Valkey | `false` |

### OTEL Collector

| Parameter | Description | Default |
| --- | --- | --- |
| `otel-collector-lerian.enabled` | Enable the OpenTelemetry collector | `false` |

| `auth.deploymentStrategy.rollingUpdate.maxSurge` | Maximum number of pods that can be created over the desired number of pods.              | `1`                                            |
| `auth.deploymentStrategy.rollingUpdate.maxUnavailable` | Maximum number of pods that can be unavailable during the update.                        | `1`                                            |
| `auth.pdb.enabled`                            | Specifies whether PodDisruptionBudget is enabled.                                         | `true`                                         |
| `auth.pdb.minAvailable`                       | Minimum number of available pods.                                                        | `0`                                            |
| `auth.pdb.maxUnavailable`                     | Maximum number of unavailable pods.                                                      | `1`                                            |
| `auth.pdb.annotations`                        | Annotations for the PodDisruptionBudget.                                                 | `{}`                                           |
| `auth.resources.limits.cpu`                   | CPU limit allocated for the pods.                                                        | `1`                                            |
| `auth.resources.limits.memory`                | Memory limit allocated for the pods.                                                     | `"756Mi"`                                      |
| `auth.resources.requests.cpu`                 | Minimum CPU request for the pods.                                                        | `"500m"`                                       |
| `auth.resources.requests.memory`              | Minimum memory request for the pods.                                                     | `"256Mi"`                                      |
| `auth.autoscaling.enabled`                    | Specifies whether autoscaling is enabled.                                                | `true`                                         |
| `auth.autoscaling.minReplicas`                | Minimum number of replicas for autoscaling.                                              | `1`                                            |
| `auth.autoscaling.maxReplicas`                | Maximum number of replicas for autoscaling.                                              | `3`                                            |
| `auth.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                       | `80`                                           |
| `auth.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling.                                    | `80`                                           |
| `auth.nodeSelector`                           | Node selectors for pod scheduling.                                                       | `{}`                                           |
| `auth.tolerations`                            | Tolerations for pod scheduling.                                                          | `{}`                                           |
| `auth.affinity`                               | Affinity rules for pod scheduling.                                                       | `{}`                                           |
| `auth.configmap`                              | Additional configurations in ConfigMap.                                                  | See default values in the configuration.       |
| `auth.secrets`                                | Additional secrets for the service.                                                      | See default values in the configuration.       |

## Dependencies: 

### PostgreSQL

- **Version:** 16.3.5
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `auth-database.enabled` to `false` in the values file.
- **Note:** If you have an existing PostgreSQL instance, you can disable this dependency and configure Midaz Components to use your external PostgreSQL, like this:
- **Important:** When using an external Postgres instance, make sure to load the init SQL file [`00_init.sql`](https://github.com/LerianStudio/midaz-helm/blob/main/charts/plugin-access-manager/files/00_init.sql) into your database.

  ```yaml
  auth:
    configmap:
      DB_HOST: { your-host }
      DB_USER: { your-host-user }
      DB_PORT: { your-host-port }
    
    secrets:
      DB_PASSWORD: { your-host-pass }

  ```

### Valkey

- **Version:** 2.4.6
- **Repository:** oci://registry-1.docker.io/bitnamicharts
- **How to disable:** Set `valkey.enabled` to `false` in the values file.
- **Note:** If you have an existing Valkey or Redis instance, you can disable this dependency and configure Midaz Components to use your external instance, like this:

  ```yaml
  auth:
    configmap:
      REDIS_HOST: { your-host }
      REDIS_PORT: { your-host-port }
      REDIS_USER: { your-host-user }

    secrets:
      REDIS_PASSWORD: { your-host-pass }
  ```
