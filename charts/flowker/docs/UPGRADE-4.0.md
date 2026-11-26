# Helm Upgrade to v4.0.0

## Topics

- **[Versions](#versions)**
- **[Where the chart lives](#where-the-chart-lives)**
- **[Coming from helm-internal 1.5.x](#coming-from-helm-internal-15x)**
- **[Coming from the public chart 3.1.x](#coming-from-the-public-chart-31x)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Versions

| Setting | helm-internal | v4.0.0 |
|---------|---------------|--------|
| Chart version | `1.5.0` | `4.0.0` |
| App version | `1.7.0-beta.50` | `1.7.0` |
| Registry | `oci://ghcr.io/lerianstudio/helm-internal/flowker-helm` | `oci://ghcr.io/lerianstudio/flowker-helm` |

For a new install, follow the [installation runbook](00-getting-start.en.md) instead.

## Where the chart lives

The chart moved back from `LerianStudio/helm-internal` to the public `LerianStudio/helm` repo.
The chart and both images (`flowker`, `flowker-xsd-validator`) pull without a GHCR login.
The chart version jumps to `4.0.0` so it never collides with the `3.x` line published here before.
Remove any registry credential you kept only to pull the chart or the images.

## Coming from helm-internal 1.5.x

The templates are the same as helm-internal `1.5.0`, with these changes:

1. **App `1.7.0`.** `appVersion` and the default `flowker.image.tag` move from `1.7.0-beta.50` to the `1.7.0` stable. The sidecar inherits the same tag. If you pin `flowker.image.tag`, update it.
2. **`MONGO_URI` from the Secret.** A supplied `flowker.secrets.MONGO_URI` used to be a literal env value in the PodSpec. It is now stored in the chart Secret and read with `secretKeyRef`. With `flowker.useExistingSecret: true` and `flowker.secrets.MONGO_URI` set, the pods read the `MONGO_URI` key **from your existing Secret**. Add that key to the Secret before you upgrade, or the pods fail with `CreateContainerConfigError`.
3. **Access Manager over `http://`.** With `PLUGIN_AUTH_ENABLED: "true"` and an `http://` `PLUGIN_AUTH_ADDRESS`, the render now fails unless `flowker.xsdValidator.pluginAuth.allowInsecureHttp: "true"` is set. Before, the render passed and the XSD sidecar exited at boot. Set the flag or switch to `https://`. Do not disable the sidecar to clear the error if you have webhooks bound to an XSD: without the sidecar, those webhooks accept schema-invalid XML and run their workflows.
4. **`lerian-common` 2.7.0.** The library is now the published `lerian-common-helm` `2.7.0` instead of the internal `lerian-common` `1.2.0`. No values were renamed or removed, but two helpers render differently:
   - **Multi-tenancy (action required if you use it).** The component keys in `flowker.configmap` now win whenever they are present, even when empty. The chart ships `MULTI_TENANT_URL: ""` and empty `MULTI_TENANT_REDIS_*` keys, so a URL or Redis host set only under `global.multiTenant` no longer reaches the app. With `flowker.multiTenant.enabled: true`, the render fails with `lerian-common: MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true`, and a global Redis host is replaced with an empty one. Before you upgrade, set `flowker.configmap.MULTI_TENANT_URL` and `flowker.configmap.MULTI_TENANT_REDIS_HOST` (plus `MULTI_TENANT_REDIS_PORT` and `MULTI_TENANT_REDIS_TLS` if they differ from the defaults).
   - **OpenTelemetry.** With `flowker.otel.enabled: true`, the api and worker containers now also get `ALLOW_INSECURE_OTEL` in their env.

## Coming from the public chart 3.1.x

The `3.1.x` line (app `1.2.0-beta.x`) predates the license gate, the internal health port and the
health preset. This guide does not cover that jump step by step. Treat it as a new install: read the
[installation runbook](00-getting-start.en.md), build your values from
[`values-template.yaml`](../values-template.yaml), and run the preview below before you upgrade.
The main blockers are a license (`LICENSE_KEY` or `flowker.licenseFile`), Kubernetes 1.27 or later,
and the retired probe, PDB and rollout values that the chart now refuses.

## Preview changes before upgrading

```bash
helm diff upgrade flowker oci://ghcr.io/lerianstudio/flowker-helm \
  --version 4.0.0 -n <namespace> -f <your-values>.yaml
```

## Command to upgrade

```bash
helm upgrade flowker oci://ghcr.io/lerianstudio/flowker-helm \
  --version 4.0.0 -n <namespace> -f <your-values>.yaml
```
