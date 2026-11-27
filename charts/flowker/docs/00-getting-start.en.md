# flowker — Installation Runbook

> How to install, validate and troubleshoot Flowker from this chart. For operators,
> BYOC clients included. Português: [00-getting-start.md](00-getting-start.md).

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `flowker-helm` **4.0.0** / app **1.7.0** |
| Chart registry | `oci://ghcr.io/lerianstudio/flowker-helm` (public, no login) |
| Components | `api` Deployment (port `4021`), `worker` Deployment (port `4022`, `/worker` binary), `xsd-validator` sidecar in both pods (port `8081`, loopback only) |
| Images | `ghcr.io/lerianstudio/flowker:1.7.0`, `ghcr.io/lerianstudio/flowker-xsd-validator:1.7.0` (both public on GHCR) |
| Kubernetes | 1.27 or later (`kubeVersion` in `Chart.yaml`) |
| Last review of this runbook | 2026-11-26, against chart 4.0.0 / app 1.7.0 |
| Escalation contact | `@LerianStudio/G_Github_Devops` |

---

## 1. Installation profiles

> **Bundled infrastructure is for development and quickstart only.** Production installs use external, managed MongoDB and Redis.

| Profile | What runs | Use case |
|---|---|---|
| **Quickstart** | api, worker, sidecar, bundled MongoDB (Bitnami) and bundled Valkey | Evaluation, POC |
| **Production / external infra** | api, worker, sidecar; MongoDB and Redis external | Real tiers |

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| Lerian license | Always. Flowker 1.6 or later does not boot without it | `flowker.secrets.LICENSE_KEY`, or `flowker.licenseFile.existingSecret` (key `license.lic`), or `LICENSE_KEY` in the Secret named by `flowker.existingSecretName` |
| MongoDB | Always | Bundled (`mongodb.enabled: true`, the default) or external (`mongodb.enabled: false` + `flowker.secrets.MONGO_URI` + `flowker.configmap.MONGO_HOST`) |
| Redis / Valkey | Always: the worker needs a queue Redis, and every install needs the worker | Bundled (`valkey.enabled: true`) or external (`flowker.configmap.REDIS_HOST`, `REDIS_PORT`, `REDIS_TLS`, `flowker.secrets.REDIS_PASSWORD`) |
| S3 bucket (Schema Registry) | For native providers (Midaz ledger, Tracer, CRM and others), XSD uploads and OpenAPI schema routes. The app boots without it, but those features fail at use time | `flowker.configmap.SCHEMA_REGISTRY_S3_BUCKET` + `SCHEMA_REGISTRY_S3_REGION`. AWS credentials come from the SDK chain: IRSA (`flowker.serviceAccount.annotations` and `worker.serviceAccount.annotations`) or Roles Anywhere (`aws.rolesAnywhere`) |
| KMS key (credential sealing) | Required to save any provider with a secret (`key`, `token`, `password`, `secret`, `client_secret`), so in practice for almost every authenticated provider. The app boots without it | Non-secret settings (`KMS_VENDOR`, and for AWS KMS `KMS_AWS_KEY_ID`; `AWS_REGION` only with Roles Anywhere) through `flowker.extraEnvVars`. On EKS with IRSA the key must be in the cluster region. Secret settings only in the existing Secret. Grant the key to the api and worker service accounts |
| plugin-access-manager | Required with `ENV_NAME: "production"`: Flowker 1.7.0 refuses `PLUGIN_AUTH_ENABLED: "false"` there. Optional in other environments | `flowker.configmap.PLUGIN_AUTH_ENABLED: "true"` + `flowker.configmap.PLUGIN_AUTH_ADDRESS` (use `https://`) |
| Tenant manager | Only with multi-tenancy | `flowker.multiTenant.enabled` + `flowker.configmap.MULTI_TENANT_URL` and `MULTI_TENANT_REDIS_*` + `flowker.secrets.MULTI_TENANT_SERVICE_API_KEY`. Set the URL and Redis keys under `flowker.configmap`: values under `global.multiTenant` alone do not reach the app in chart 4.0.0 |

---

## 3. Installation order

### 3.1 Namespace

The chart pins its workloads to `namespaceOverride`, which defaults to `flowker`. The bundled
MongoDB and Valkey follow the Helm release namespace. **Install in the same namespace you set in
`namespaceOverride`.** Either use the default namespace `flowker`, or set both to the same value:

```bash
helm install flowker oci://ghcr.io/lerianstudio/flowker-helm --version 4.0.0 \
  -n <ns> --create-namespace --set namespaceOverride=<ns> -f <your-values>.yaml
```

If they differ, the api and worker land in `flowker` while MongoDB lands in `<ns>`, and no pod starts.

### 3.2 License

Keep the license out of values files in git. Two ways, one per profile:

- **Quickstart:** pass the key from a file with `--set-file flowker.secrets.LICENSE_KEY=./flowker.license`. The chart writes it to its own Secret and assembles `MONGO_URI` for the bundled MongoDB.
- **Production:** create your own Secret and set `flowker.useExistingSecret: true`. That Secret replaces the chart Secret, so it must hold every secret key the pods read: `LICENSE_KEY`, `MONGO_URI` (the chart does not assemble it in this mode), and `REDIS_PASSWORD` or others when they apply.

```bash
kubectl create namespace flowker
# the values stay in files: they never land in shell history
kubectl create secret generic flowker-secrets -n flowker \
  --from-file=LICENSE_KEY=./flowker.license \
  --from-file=MONGO_URI=./mongo-uri.txt
```

### 3.3 Quickstart

```yaml
# quickstart-values.yaml
valkey:
  enabled: true   # the worker needs a queue Redis while the scheduler is on
```

```bash
helm install flowker oci://ghcr.io/lerianstudio/flowker-helm --version 4.0.0 \
  -n flowker --create-namespace -f quickstart-values.yaml \
  --set-file flowker.secrets.LICENSE_KEY=./flowker.license
```

### 3.4 Production / external infra

```yaml
# production-values.yaml
flowker:
  useExistingSecret: true
  existingSecretName: flowker-secrets    # LICENSE_KEY, MONGO_URI, REDIS_PASSWORD (section 3.2)
  configmap:
    ENV_NAME: "production"
    DEPLOYMENT_MODE: "byoc"              # the chart default "local" is for development only
    ALLOW_INSECURE_TLS: "false"          # only with TLS-enabled MongoDB and Redis
    PLUGIN_AUTH_ENABLED: "true"          # required in production: the app refuses "false"
    PLUGIN_AUTH_ADDRESS: "https://auth.example.com"   # public HTTPS host (see "Outbound URLs" in section 4)
    MONGO_HOST: "mongo.example.internal" # host checked by the wait-for-mongodb init container
    REDIS_HOST: "redis.example.internal"
    REDIS_PORT: "6379"
    REDIS_TLS: "true"
    SCHEMA_REGISTRY_S3_BUCKET: "flowker-schema-registry"
    SCHEMA_REGISTRY_S3_REGION: "sa-east-1"
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "<role with access to the bucket and the KMS key>"   # IRSA on EKS
  extraEnvVars:                          # non-secret values only: this renders into the ConfigMap
    KMS_VENDOR: "aws-kms"                # 1.7.0 accepts only "aws-kms" or "hashicorp-vault"
    KMS_AWS_KEY_ID: "<kms-key-id-or-arn>"   # key in the EKS cluster region (see "Workflow credentials")
    CRM_BASE_URL: "https://crm.example.com"   # public HTTPS host; no dedicated chart value in 4.0.0
  ingress:
    enabled: true
    className: "<your-ingress-class>"
    hosts:
      - host: flowker.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: flowker-tls
        hosts: [flowker.example.com]
worker:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "<role with access to the bucket and the KMS key>"
mongodb:
  enabled: false
```

```bash
helm install flowker oci://ghcr.io/lerianstudio/flowker-helm --version 4.0.0 \
  -n flowker -f production-values.yaml
```

Start from [`values-template.yaml`](../values-template.yaml) for the full set of keys.

---

## 4. Operational notes

- **External MongoDB.** `MONGO_URI` is read from the Secret (`secretKeyRef`), never written into the PodSpec. The `wait-for-mongodb` init container checks `MONGO_HOST` on port `27017`, so a MongoDB on another port keeps the pods in `Init`. Use a password without `:`, `/`, `@` or `%`, or percent-encode it in the URI.
- **Redis.** With the defaults (`SCHEDULER_ENABLED: "true"`, `valkey.enabled: false`, `REDIS_HOST` empty) the worker has no queue and does not boot. Enable Valkey or set `REDIS_HOST`. Keep the worker on even if you don't use `schedule` triggers: in Flowker 1.7.0 only the worker starts `durable_external` runs, wakes `wait` nodes and fails runs whose lease expired, so `worker.enabled: false` leaves those executions pending or waiting for good. The `/worker` binary refuses to start with `SCHEDULER_ENABLED: "false"`, so every install needs a queue Redis.
- **Access Manager over `http://`.** The XSD sidecar inherits `PLUGIN_AUTH_*` and exits on a cleartext address. The chart refuses to render until you set `flowker.xsdValidator.pluginAuth.allowInsecureHttp: "true"` or use `https://`. Disabling the sidecar also clears the error, but read the next item first.
- **XSD sidecar.** On by default. It validates XML webhooks and XSD uploads. With `flowker.xsdValidator.enabled: false`, validation is not wired: webhooks bound to an XSD **accept well-formed but schema-invalid XML and run their workflows**, and XSD uploads are not checked. Disable it only on installs with no schema-bound XML workflows.
- **Health and rollout.** Probes, PDB and rollout come from the `lerian-common` health preset and are not values. The chart refuses an image tag below `1.7.0-beta.50`. See the chart [README](../README.md#health-drain-and-rollout).
- **Schema Registry (S3).** Health checks pass without `SCHEMA_REGISTRY_S3_BUCKET`, so a green rollout does not prove native providers work. Set the bucket in every profile that runs native-provider workflows or XSD-bound webhooks, and grant the api and worker access to it. **Open point:** the native provider specs must also be in the bucket, or every native provider fails at use time. The Lerian publish pipeline only writes to Lerian-owned buckets, and there is no documented procedure yet for a client-owned bucket. Agree on it with the Flowker team (object keys, versions and who uploads them) before the client runs native-provider workflows.
- **Deployment mode.** The chart defaults `DEPLOYMENT_MODE` to `local`. With `ENV_NAME: "production"` the app logs a warning at boot, and `local` also allows Vault token auth for the KMS. Set `DEPLOYMENT_MODE: "byoc"` on client installs.
- **CRM provider.** The app reads `CRM_BASE_URL`, but chart 4.0.0 only has `MIDAZ_BASE_URL` and `TRACER_BASE_URL` values. Set `CRM_BASE_URL` through `flowker.extraEnvVars`, with a public HTTPS host (see the next item).
- **Outbound URLs (SSRF guard).** Flowker checks every outbound call against an SSRF guard. It blocks `.internal`, `.local` and `.cluster.local` hostnames before DNS, and with `SSRF_ALLOW_PRIVATE: "false"` (the chart default, and the only safe value in production) it also blocks names that resolve to private IPs. This applies to `PLUGIN_AUTH_ADDRESS` (the workflow M2M token URL is built from it), `CRM_BASE_URL`, `MIDAZ_BASE_URL`, `TRACER_BASE_URL` and provider base URLs. Use public HTTPS hosts for them. An in-cluster Service name fails every step that calls it, while health and rollout checks still pass. `MONGO_HOST` and `REDIS_HOST` are not affected.
- **Image pull secrets.** The images are public. `flowker.imagePullSecrets` can stay `[]`.
- **Workflow credentials.** Flowker 1.7.0 stores provider-config and node-auth credentials KMS-sealed in MongoDB and needs a key-encryption key (`KMS_VENDOR` and its grants). Chart 4.0.0 has no dedicated `KMS_*` values. Put secret KMS settings (for example a Vault AppRole secret ID) only in the existing Secret (`flowker.useExistingSecret: true`). Never in `flowker.extraEnvVars`: it renders into the ConfigMap. `extraEnvVars` is fine for non-secret settings such as `KMS_VENDOR`. `FLOWKER_SECRETS_BACKEND` has no effect on app 1.7.0. Without `KMS_VENDOR`, the install is healthy but refuses to store any provider secret (409 `FLK-0966`). The KMS client takes its region from the AWS SDK chain, not from `SCHEMA_REGISTRY_S3_REGION`. On EKS with IRSA, the pod identity webhook injects `AWS_REGION` with the cluster region as explicit container env, which wins over anything in `flowker.extraEnvVars` (that goes through the ConfigMap, via `envFrom`). Chart 4.0.0 has no explicit-env value for the api, so you cannot override it: the KMS key must be in the cluster region. With Roles Anywhere (non-EKS) nothing injects a region: set `AWS_REGION` to the key's region in `flowker.extraEnvVars`. A wrong region gives a healthy install where every provider save fails with 503 `FLK-0969`.

---

## 5. How to validate a successful install

```bash
kubectl -n flowker get pods
# expected: flowker-* (2/2: api + sidecar), flowker-worker-* (2/2), and the bundled
# flowker-mongodb / flowker-valkey when they are enabled
kubectl -n flowker rollout status deploy/flowker --timeout=300s
kubectl -n flowker rollout status deploy/flowker-worker --timeout=300s
```

Then check the API from inside the cluster, through the Service on port `4021`:

```bash
kubectl -n flowker run flowker-check --rm -i --restart=Never --image=busybox:1.37 -- \
  wget -qO- http://flowker:4021/health
```

Readiness (`/readyz`) and `/metrics` are served on the internal health port `8099` of each pod.

---

## 6. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| Render fails: `flowker.secrets.LICENSE_KEY ... is required` | No license configured | Set the license (section 3.2) |
| Log: `license: validation failed; flowker drains and exits` | License key missing or not accepted at boot | Check `LICENSE_KEY` in the Secret the pods load, and egress to the license gateway |
| Render fails: `flowker.configmap.MONGO_HOST is required when mongodb is external` | `mongodb.enabled: false` without `MONGO_HOST` | Set `MONGO_HOST` to the MongoDB host |
| Render fails: `flowker.xsdValidator: PLUGIN_AUTH_ADDRESS ... is cleartext http://` | Auth on with an `http://` Access Manager | Set `allowInsecureHttp: "true"` or use `https://` (see "XSD sidecar" in section 4 before disabling it) |
| api and worker exit at boot: `PLUGIN_AUTH_ENABLED=false is not permitted in production` | `ENV_NAME: "production"` with auth off | Set `PLUGIN_AUTH_ENABLED: "true"` and `PLUGIN_AUTH_ADDRESS` (section 3.4) |
| Worker exits: `worker binary requires SCHEDULER_ENABLED=true` | Scheduler turned off | Keep `SCHEDULER_ENABLED: "true"` and give the worker a Redis (see "Redis" in section 4). Do not turn the worker off |
| Render fails: `lerian-common: MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true` | Multi-tenancy on with the URL only under `global.multiTenant` | Set `flowker.configmap.MULTI_TENANT_URL` (and `MULTI_TENANT_REDIS_HOST`) |
| Pods stuck in `Init`, `wait-for-mongodb` loops on `<host>:27017` | MongoDB unreachable, on another port, or in another namespace | Check `MONGO_HOST`, the port, and the namespace rule (section 3.1) |
| Pods in `CreateContainerConfigError` | Secret or key missing in the pod namespace | Check `existingSecretName`, its keys, and the namespace rule |
| api log: MongoDB URI empty or missing, with `useExistingSecret: true` | The existing Secret has no `MONGO_URI` key | Add `MONGO_URI` to the Secret (section 3.2) |
| Worker `CrashLoopBackOff` right after install | No queue Redis while the scheduler is on | See "Redis" in section 4 |
| api `CrashLoopBackOff`, log "TLS required" (Mongo) | `ALLOW_INSECURE_TLS: "false"` against a non-TLS MongoDB | Keep `"true"` for bundled infra; `"false"` only with real TLS |
| Workflow step fails with `URL rejected by SSRF policy` or `token endpoint rejected by SSRF policy` | An outbound URL uses an internal hostname or a private IP | Use a public HTTPS host ("Outbound URLs" in section 4) |
| api and worker exit at boot: `unknown KMS_VENDOR` | `KMS_VENDOR` is not `aws-kms` or `hashicorp-vault` | Fix the value |
| Saving a provider returns 409 `FLK-0966` | No KMS configured (`KMS_VENDOR` empty) | Configure the KMS key (section 2) |
| Saving a provider returns 503 `FLK-0969` | KMS key denied or unreachable, or wrong region | Check the key region (cluster region on IRSA, `AWS_REGION` on Roles Anywhere), the key grant for the api and worker service accounts, and network access to the KMS |
| Workflow step fails with `ErrCredentialSealerNotConfigured` or `has no stored credential` | No KMS key configured, or credentials not re-supplied after moving to app 1.7.0 | See "Workflow credentials" in section 4 |
| Native provider step fails on save or run, XSD upload fails with `ErrBlobStorageNotConfigured`, or OpenAPI schema routes return 503 `FLK-0804` | `SCHEMA_REGISTRY_S3_BUCKET` empty, or no access to the bucket | Set the bucket and region, and the IRSA or Roles Anywhere grant (section 2) |
| Render fails: `... is below 1.7.0-beta.50` | `flowker.image.tag` older than the chart supports | Use the chart's default tag, or a tag at or above `1.7.0-beta.50` |
