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
| Coming from another chart | [`UPGRADE-4.0.md`](UPGRADE-4.0.md) |
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
| Redis / Valkey | Always, while the scheduler is on (`SCHEDULER_ENABLED: "true"`, the default) | Bundled (`valkey.enabled: true`) or external (`flowker.configmap.REDIS_HOST`, `REDIS_PORT`, `REDIS_TLS`, `flowker.secrets.REDIS_PASSWORD`) |
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
    ALLOW_INSECURE_TLS: "false"          # only with TLS-enabled MongoDB and Redis
    PLUGIN_AUTH_ENABLED: "true"          # required in production: the app refuses "false"
    PLUGIN_AUTH_ADDRESS: "https://plugin-access-manager-auth.example.internal"
    MONGO_HOST: "mongo.example.internal" # host checked by the wait-for-mongodb init container
    REDIS_HOST: "redis.example.internal"
    REDIS_PORT: "6379"
    REDIS_TLS: "true"
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
- **Redis.** With the defaults (`SCHEDULER_ENABLED: "true"`, `valkey.enabled: false`, `REDIS_HOST` empty) the worker has no queue and does not boot. Enable Valkey or set `REDIS_HOST`. If you don't use `schedule` triggers, you can run without Redis: set both `SCHEDULER_ENABLED: "false"` and `worker.enabled: false`. The `/worker` binary refuses to start with the scheduler off, so turning off only the scheduler trades one crash loop for another.
- **Access Manager over `http://`.** The XSD sidecar inherits `PLUGIN_AUTH_*` and exits on a cleartext address. The chart refuses to render until you set `flowker.xsdValidator.pluginAuth.allowInsecureHttp: "true"` or use `https://`. Disabling the sidecar also clears the error, but read the next item first.
- **XSD sidecar.** On by default. It validates XML webhooks and XSD uploads. With `flowker.xsdValidator.enabled: false`, validation is not wired: webhooks bound to an XSD **accept well-formed but schema-invalid XML and run their workflows**, and XSD uploads are not checked. Disable it only on installs with no schema-bound XML workflows.
- **Health and rollout.** Probes, PDB and rollout come from the `lerian-common` health preset and are not values. The chart refuses an image tag below `1.7.0-beta.50`. See the chart [README](../README.md#health-drain-and-rollout).
- **Image pull secrets.** The images are public. `flowker.imagePullSecrets` can stay `[]`.

---

## 5. How to validate a successful install

```bash
kubectl -n flowker get pods
# expected: flowker-* (2/2: api + sidecar), flowker-worker-* (2/2), and the bundled
# flowker-mongodb / flowker-valkey when they are enabled
kubectl -n flowker rollout status deploy/flowker --timeout=300s
# skip the next line when worker.enabled is false
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
| Worker exits: `worker binary requires SCHEDULER_ENABLED=true` | Scheduler off with the worker on | Set `worker.enabled: false` too, or turn the scheduler back on with a Redis |
| Render fails: `lerian-common: MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true` | Multi-tenancy on with the URL only under `global.multiTenant` | Set `flowker.configmap.MULTI_TENANT_URL` (and `MULTI_TENANT_REDIS_HOST`) |
| Pods stuck in `Init`, `wait-for-mongodb` loops on `<host>:27017` | MongoDB unreachable, on another port, or in another namespace | Check `MONGO_HOST`, the port, and the namespace rule (section 3.1) |
| Pods in `CreateContainerConfigError` | Secret or key missing in the pod namespace | Check `existingSecretName`, its keys, and the namespace rule |
| api log: MongoDB URI empty or missing, with `useExistingSecret: true` | The existing Secret has no `MONGO_URI` key | Add `MONGO_URI` to the Secret (section 3.2) |
| Worker `CrashLoopBackOff` right after install | No queue Redis while the scheduler is on | See "Redis" in section 4 |
| api `CrashLoopBackOff`, log "TLS required" (Mongo) | `ALLOW_INSECURE_TLS: "false"` against a non-TLS MongoDB | Keep `"true"` for bundled infra; `"false"` only with real TLS |
| Render fails: `... is below 1.7.0-beta.50` | `flowker.image.tag` older than the chart supports | Use the chart's default tag, or a tag at or above `1.7.0-beta.50` |
