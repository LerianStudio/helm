<!-- {% raw %} -->
# Helm Upgrade from v10.3.2 to v10.3.3

## Topics

- **[Changes](#changes)**
  - [1. Default image is the stable 4.4.0](#1-default-image-is-the-stable-440)
  - [2. Tags below 4.5.0-beta.94 render the 4.4 layout](#2-tags-below-450-beta94-render-the-44-layout)
- **[Action required](#action-required)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Changes

### 1. Default image is the stable 4.4.0

The default `ledger.image.tag` and `tracer.image.tag` change from `4.5.0-beta.94` to `4.4.0`, and the chart `appVersion` changes to `4.4.0`. The ledger and tracer migrations Jobs use the `4.4.0` migration images by default.

The ledger partition runner starts at ledger `4.5.0-beta.1`. With the `4.4.0` default, the chart renders no `midaz-ledger-partition` CronJob and no partition reconcile Job.

### 2. Tags below 4.5.0-beta.94 render the 4.4 layout

In v10.3.2, a ledger or tracer `image.tag` below `4.5.0-beta.94` failed the render. In v10.3.3, such a tag renders the 4.4 layout. A tag of `4.5.0-beta.94` or later keeps the health preset, with the same output as v10.3.2.

| Item | Health preset (`4.5.0-beta.94` and later) | 4.4 layout (below `4.5.0-beta.94`) |
|---|---|---|
| Probes | `/health` and `/readyz` on the health port `8099`, plus a startup probe | `/health` and `/readyz` on the main port (ledger `3002`, tracer `4020`), no startup probe |
| Health port | `8099` on the container and the Service, `HEALTH_PORT` set | Not rendered |
| `SHUTDOWN_TIMEOUT` | `30s` | Not set |
| Rollout | `maxSurge: 25%`, `maxUnavailable: 0` | Ledger `maxSurge: 100%`, tracer `maxSurge: 1`, `maxUnavailable: 0` |
| Termination grace | `55` seconds | Ledger `72` seconds, tracer `55` seconds |
| PodDisruptionBudget | `maxUnavailable: 1`, `unhealthyPodEvictionPolicy: AlwaysAllow` | `maxUnavailable: 1` |

With the 4.4 layout, the chart reads the `livenessProbe`, `readinessProbe`, `terminationGracePeriodSeconds`, `deploymentUpdate` and `pdb.minAvailable` or `pdb.maxUnavailable` values of the ledger and the tracer, and ignores their `health` block.

The 4.4 layout also adds these ConfigMap keys:

- Ledger: `RABBITMQ_PROTOCOL` (default `http`), `RABBITMQ_PORT_AMQP` (default `15672`) and `RABBITMQ_HEALTH_CHECK_URL`. Images below the preset call the broker management API for the RabbitMQ check of `/readyz`. The chart builds the URL from the broker host, the protocol and the port (`http://midaz-rabbitmq:15672` with the bundled RabbitMQ; with `https`, from the host only). Set `ledger.configmap.RABBITMQ_HEALTH_CHECK_URL` to replace it.
- Tracer: `READYZ_DRAIN_GRACE_SECONDS` (default `12`). Set `tracer.configmap.READYZ_DRAIN_GRACE_SECONDS` to change it.

## Action required

> **Warning:** A release that runs the v10.3.2 default image must pin its tag before the upgrade. Without the pin, the default `4.4.0` migrations Job finds a schema newer than its migrations and fails (its log shows `no migration found for version N`), and `helm upgrade` stops at the pre-upgrade hook before any pod changes. If that already happened, add the pin and run the upgrade again. A move from a `4.5.0` pre-release back to `4.4.0` is not supported.

1. Save the values of the release:

   ```bash
   helm get values midaz -n midaz -o yaml > midaz-values.yaml
   ```

2. Find `ledger.image.tag` in `midaz-values.yaml`. If the file sets it, the release already runs `4.5.0-beta.94` or later, because v10.3.2 refused a lower tag. Do the same check for `tracer.image.tag` when the tracer is enabled.

3. For each tag the file does not set, add `tag: "4.5.0-beta.94"` under `image` inside the `ledger:` or `tracer:` block of the file. Add the block when the file has none. Do not add a second `ledger:` or `tracer:` key: Helm keeps only the last one and drops the rest of that block, for example `tracer.enabled`.

   ```yaml
   ledger:
     # other ledger values stay here
     image:
       tag: "4.5.0-beta.94"
   tracer:
     # other tracer values stay here
     image:
       tag: "4.5.0-beta.94"
   ```

With the pin, the rendered manifests are the same as v10.3.2 except for the `helm.sh/chart` label and what follows from it: the config checksums of the CRM and the tracer, and the name suffix of the tracer migrations Job. The pods restart once, with the usual rolling update.

Setting `ledger.migrations.enabled: false` or `tracer.migrations.enabled: false` removes only the migrations Job of that component. With Argo CD, an empty `deploymentSyncWave` puts the Deployment in the same wave as its migrations Job, so the Deployment applies even when the Job fails and the sync reports the failure. In these installs a Deployment can move to `4.4.0` on a schema that `4.4.0` does not support. Pin every enabled component in those installs too. With Argo CD, add the pin to the values of the Application.

A release that sets every tag it runs needs no change before the upgrade.

## Preview changes before upgrading

The commands below are examples. Replace `midaz` (release name) and `-n midaz` (namespace) with the values used at install time.

A release that needs no pin keeps its stored values, so the commands pass no `-f` or `--set`:

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.3 -n midaz
```

A release that added the pin passes the full values file from step 1. A `-f` file replaces the stored values, so the file must hold all of them:

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.3 -n midaz -f midaz-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

A release that needs no pin:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.3 -n midaz
```

A release that added the pin:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.3 -n midaz -f midaz-values.yaml
```

## Verify

```bash
kubectl get pods -n midaz -l app.kubernetes.io/instance=midaz
kubectl rollout status deployment/midaz-ledger -n midaz
kubectl get deployment midaz-ledger -n midaz -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
helm status midaz -n midaz
```

With the default `nameOverride` and `fullnameOverride` values, the ledger and tracer Deployments are named `midaz-ledger` and `midaz-tracer` whatever the release is called.

All pods reach `Running` and `Ready`, and `helm status` shows `deployed`. The ledger image keeps the tag it ran before the upgrade. When the tracer is enabled, run the same `rollout status` and image checks for `deployment/midaz-tracer`. A migrations Job is deleted when it succeeds. Only a failed one stays, and a failed one also makes `helm upgrade` fail.
<!-- {% endraw %} -->
