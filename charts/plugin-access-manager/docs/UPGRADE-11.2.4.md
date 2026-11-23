<!-- {% raw %} -->
# Helm Upgrade from v11.2.3 to v11.2.4

## Overview

This patch keeps application version `3.19.0` and the default container images unchanged. It updates the locked `lerian-common-helm` dependency from `2.6.0` to `2.7.0` and wires modeled `ALLOW_INSECURE_OTEL` settings for auth, identity and Caradhras.

Working deployments need no values-schema migration, but auth, identity and Caradhras roll even when the node-local collector is disabled and images remain pinned. Changed ConfigMap/Secret checksums alter their pod templates. Replacement Caradhras pods run their existing migration init container again. With identical values, bundled PostgreSQL/Valkey and optional Caradhras UI pod templates are unchanged.

Plan for authentication availability. Before rollout, take private configuration/manifest/Secret backups and a consistent database backup, and verify the recovery procedure. Preserve image pins, credentials and existing license keys: default auth/identity retain key-based licensing and Caradhras 2.1.0 requires a nonempty `LICENSE_KEY`; a license-file mount is not a substitute with these images.

## OpenTelemetry configuration

The published chart contains its locked library; do not install or upgrade the library separately. The collector is not a dependency installed by this chart. Independently deploy and verify a reachable collector before enabling node-local routing.

When `otel-collector-lerian.enabled: true`, the Deployment uses `status.hostIP` to construct `$(HOST_IP):4317`. The chart resolves the plaintext permission in this order:

1. `<component>.configmap.ALLOW_INSECURE_OTEL` for `auth`, `identity` or `caradhras`.
2. `global.observability.allowInsecureOtel`.
3. The node-local default reason, `node-local collector on the pod's own node`.

A null value is unset and falls back through this hierarchy. Blank, `false`, `0`, `no` and `off` refuse permission at runtime (case-insensitive and whitespace-trimmed); other strings permit and should record actual risk acceptance. Preserve an intentional refusal rather than replacing it with a reason merely to obtain readiness.

Existing `<component>.extraEnvVars` overrides remain supported: when that list already supplies `ALLOW_INSECURE_OTEL`, the chart does not inject another entry. Explicit container env overrides the same key imported from an external Secret. With node-local injection enabled, use the modeled component setting to preserve refusal rather than relying on an external Secret value being effective.

These are fragments to merge into your complete intended configuration, not standalone production values files. For an independently managed plaintext collector with node-local routing disabled:

```yaml
otel-collector-lerian:
  enabled: false
global:
  observability:
    enabled: true
    allowInsecureOtel: "internal collector on approved network"
identity:
  configmap:
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector.monitoring:4317"
```

Configure the appropriate endpoint for every enabled component that needs it. A component-specific reason takes precedence over the global value:

```yaml
auth:
  configmap:
    ALLOW_INSECURE_OTEL: "internal collector on approved network"
```

An explicit refusal is also supported:

```yaml
caradhras:
  configmap:
    ALLOW_INSECURE_OTEL: "false"
```

With telemetry enabled, shipped `lib-observability` v4.9.0 rejects an insecure exporter when its telemetry deployment environment is `production` or `prod`, unless `ALLOW_INSECURE_OTEL` permits it. This runtime policy predates this chart patch. Auth and identity propagate telemetry initialization errors; Caradhras 2.1.0 instead logs an error and retries with telemetry disabled. Verify actual telemetry delivery, not just pod readiness. A permission reason does not repair license, database, migration or other startup errors.

A node-address endpoint is not proof of loopback isolation, authenticated collector ownership or network trust. Evaluate collector placement, node/network controls and plaintext risk acceptance; retain TLS where required. Automatic environment injection proves neither secure transport nor successful delivery. With node-local routing disabled and a TLS exporter endpoint, no plaintext permission is needed, but the backend rollout still needs verification.

## Prepare and preview

Prepare private `values-11.2.4.yaml` as the **complete intended user configuration**, not only the OTEL fragment. Preserve all unrelated overrides: datastore endpoints/current credentials or Secret references, license keys/references, component image pins and pull Secrets, client/identity-provider settings, ingress/TLS, replicas, resources and scheduling. Reconcile target defaults.

Both commands below reset stored values and apply this same file: omitted overrides return to target defaults. Keep values, previews and backups out of Git, logs and tickets. Create fresh artifacts with owner-only permissions and retain or remove them according to your private recovery process.

Bundled PostgreSQL upgrade rendering can require its current password through `auth-database.auth.password` in the private values file. Client rendering cannot establish existing Secret state. Where existing-object `lookup` is required, use a supported lookup-aware server-side preview with authorized cluster access. Client-generated passwords/checksum changes are not a credential rotation plan. Never decode credentials into terminal output or pass them through CLI `--set`.

Confirm the release and namespace match your installation. The preview requires the [helm-diff plugin](https://github.com/databus23/helm-diff). `--suppress-secrets` reduces output but does not make other resources or diagnostics nonsensitive; inspect previews privately.

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.4 --reset-values -f values-11.2.4.yaml --suppress-secrets
```

Do not continue until the preview matches the intended configuration, including all three backend rollouts and retained image/credential references.

## Upgrade and verify

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.4 --reset-values -f values-11.2.4.yaml --wait
```

Verify auth, identity and Caradhras rollout/readiness, successful completion of both Caradhras init containers, representative login/token flows and actual telemetry delivery. Use rendered workload names when name overrides are configured. `--wait` and readiness do not prove these application-level checks.

For recovery, select the recorded known-good revision from release history and follow the tested recovery procedure. Helm rollback changes Kubernetes resources but does not restore database contents or external credentials. No cluster install/upgrade, server-side preview, helm-diff execution, application boot, database integration or backup/restore was exercised in the offline validation of this guide.
<!-- {% endraw %} -->
