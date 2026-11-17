# Helm Upgrade from v2.3.0 to v2.3.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Removal of TLS configuration from main HTTP server](#1-removal-of-tls-configuration-from-main-http-server)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.3.0` to `2.3.1`. Both releases ship application image `1.2.0`. This patch removes TLS options from the chart-managed ConfigMap; it does not remove TLS capability from the unchanged binary. The chart-managed path expects upstream TLS termination and an HTTP backend.

Existing deployments that set `SERVER_TLS_CERT_FILE` or `SERVER_TLS_KEY_FILE` in their values overlay must remove these keys before upgrading. The chart will fail fast at upgrade time if these keys are still present.

## Fixes

### 1. Removal of TLS configuration from main HTTP server

The chart no longer supports TLS termination at the application layer. Three environment variables have been removed from the ConfigMap template:

- `TLS_TERMINATED_UPSTREAM`
- `SERVER_TLS_CERT_FILE`
- `SERVER_TLS_KEY_FILE`

Application `1.2.0` still reads all three variables. Its main listener uses TLS only when upstream termination is false and both certificate/key paths are supplied; otherwise it uses plain HTTP. In chart `2.3.0`, upstream termination defaulted to true, so certificate paths alone did not mean the application previously served HTTPS.

**Before (v2.3.0):**

```yaml
data:
  TLS_TERMINATED_UPSTREAM: "true"
  SERVER_TLS_CERT_FILE: "/path/to/cert.pem"
  SERVER_TLS_KEY_FILE: "/path/to/key.pem"
```

**After (v2.3.1):**

These keys are no longer rendered in the ConfigMap. The chart will reject any values overlay that includes `SERVER_TLS_CERT_FILE` or `SERVER_TLS_KEY_FILE` with an explicit error message:

```
ERROR: app.configmap.SERVER_TLS_CERT_FILE is no longer read by plugin-br-payments (the main port serves plain HTTP; terminate TLS at the Ingress or mesh).
   Remove it from your values overlay.
```

```
ERROR: app.configmap.SERVER_TLS_KEY_FILE is no longer read by plugin-br-payments (the main port serves plain HTTP; terminate TLS at the Ingress or mesh).
   Remove it from your values overlay.
```

**Operational impact:**

Audit the effective environment, existing Secrets loaded through `envFrom`, `app.extraEnvVars` and any custom pod configuration before changing backend protocol. Those paths can supply settings independently of the removed ConfigMap entries. Do not bypass the chart guards to retain retired `app.configmap` fields. The validation errors quoted above describe the chart contract, not the unchanged binary's implementation.

If you rely on end-to-end encryption between the Ingress and the application pod, you must reconfigure your architecture to terminate TLS at the Ingress or enable mTLS via a service mesh (e.g., Istio, Linkerd).

> **Warning:** If the effective backend currently serves TLS, coordinate its cutover to HTTP with the Ingress/mesh configuration. Verify the actual pre-upgrade transport first; do not change backend protocol solely because a certificate path appeared in the old values file.

> **Important:** The chart no longer renders `TLS_TERMINATED_UPSTREAM`; only the two certificate/key fields are rejected under `app.configmap`. The binary still reads the flag. Confirm no alternative environment injection retains main-listener TLS settings when adopting the chart-managed HTTP path.

## Configuration Changes

| Setting | v2.3.0 | v2.3.1 |
|---------|--------|--------|
| `app.configmap.TLS_TERMINATED_UPSTREAM` | `"true"` (default) | removed |
| `app.configmap.SERVER_TLS_CERT_FILE` | optional | removed (rejected by chart) |
| `app.configmap.SERVER_TLS_KEY_FILE` | optional | removed (rejected by chart) |

No new configuration values were added. The chart now enforces that `SERVER_TLS_CERT_FILE` and `SERVER_TLS_KEY_FILE` must not be present in `app.configmap`.

## Migration Steps

Before editing the maintained values file or changing the backend protocol, record the current release revision and chart version and make private backups:

```bash
umask 077
backup_dir=$(mktemp -d "./payments-upgrade-backup.XXXXXX")
helm history my-payments --namespace midaz-plugins -o yaml > "$backup_dir/history.yaml"
helm get values my-payments --namespace midaz-plugins -o yaml > "$backup_dir/values.yaml"
helm get manifest my-payments --namespace midaz-plugins > "$backup_dir/manifest.yaml"
cp values.yaml "$backup_dir/maintained-values.yaml"
```

These commands assume the complete maintained configuration is `values.yaml`; adapt that path before running them. Release values and manifests can contain credentials and Secret data. Keep this fresh owner-only directory outside version control, restrict access, and remove it after the upgrade and rollback window. Also retain the pre-change Ingress/mesh configuration, effective backend TLS settings and certificate/Secret references through your existing private configuration-backup process. Helm does not back up independently managed routing or Secrets.

Do not change the Ingress backend protocol while old pods still require HTTPS. Plan the application and routing transition together in a maintenance window, including mixed old/new pods during rollout; if the controller cannot safely support that transition, stop traffic for the cutover rather than sending HTTP to a TLS-only listener. Keep the previous configuration and certificate material available for recovery until validation succeeds.

1. Review your values overlay for any references to `SERVER_TLS_CERT_FILE`, `SERVER_TLS_KEY_FILE`, or `TLS_TERMINATED_UPSTREAM` under `app.configmap`. Remove all three keys if present.

2. Verify your Ingress configuration terminates TLS and forwards plain HTTP to the application Service. If you use an Ingress controller with backend protocol annotations (e.g., AWS ALB, NGINX), ensure the backend protocol is set to HTTP, not HTTPS.

   Example for AWS ALB Ingress:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     annotations:
       alb.ingress.kubernetes.io/backend-protocol: HTTP
   ```

   Example for NGINX Ingress:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     annotations:
       nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
   ```

3. Remove only main-listener certificate mounts confirmed unused after the HTTP cutover. Do not remove unrelated outbound/provider TLS or Roles Anywhere certificates. This historical chart does not provide generic `app.volumeMounts`/`app.volumes` wiring; inspect separately managed pod customizations instead of assuming those values are supported.

4. **(Optional)** If you require end-to-end encryption between the Ingress and the application pod, configure a service mesh with mTLS (e.g., Istio, Linkerd) before upgrading.

5. Preserve every other installation-specific override in the same complete maintained file, called `values.yaml` below. Keep it outside version control and restrict its permissions if it contains secrets. Preview and upgrade during a maintenance window. Both commands deliberately use `--reset-values` with that complete file to drop retired stored keys; do not supply an incomplete TLS-only overlay.

6. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl rollout status -n midaz-plugins deployment/plugin-br-payments --timeout=300s
   kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments
   ```

7. Confirm the application is serving HTTP on its main port by checking the Service and pod logs:

   ```bash
   kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments --tail=50
   ```

   Inspect startup configuration and effective backend transport separately; absence of a TLS log line is not proof. These commands assume release `my-payments`, namespace `midaz-plugins` and the default application name. Adapt them consistently if overridden.

8. Test the dedicated internal health listener, not the main-port Ingress. In one terminal:

   ```bash
   kubectl port-forward -n midaz-plugins deployment/plugin-br-payments 18099:8099
   ```

   In another terminal:

   ```bash
   curl --fail http://127.0.0.1:18099/health
   curl --fail http://127.0.0.1:18099/readyz
   ```

   Verify Ingress TLS separately against a known public application route with the required authentication. A successful front-end TLS handshake does not establish backend transport. Do not expose the internal health listener publicly for this test.

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Recovery if validation fails

Stop or drain traffic if requests fail or the backend protocol is inconsistent. Coordinate recovery of routing and the application; do not switch the Ingress back to HTTPS while it still targets HTTP-only pods. Select the actual pre-upgrade revision recorded in the private history backup, not an assumed revision number:

```bash
helm history my-payments --namespace midaz-plugins
read -r -p "Pre-upgrade release revision: " previous_revision
helm rollback my-payments "$previous_revision" --namespace midaz-plugins --wait --timeout 10m
kubectl rollout status -n midaz-plugins deployment/plugin-br-payments --timeout=300s
```

Restore the separately managed Ingress/mesh configuration, TLS environment, certificate mounts and Secret references to the backed-up state in the planned traffic-stopped recovery sequence. Helm rollback restores the selected Helm revision's resources and values; it cannot restore external routing, independently managed Secrets or database contents. Recheck the dedicated health listener, actual backend transport, front-end TLS and an authenticated application route before reopening traffic. Retain backups until the recovery window closes, then remove the private exports under your retention policy. This procedure is guidance, not evidence of an exercised upgrade or rollback.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.3.1 --reset-values -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.3.1 --reset-values -f values.yaml
```
