<!-- {% raw %} -->
# Helm Upgrade from v2.4.0 to v2.5.0

## Topics

- [Release changes](#release-changes)
- [Trusted proxies](#trusted-proxies)
- [HTTP listener bounds](#http-listener-bounds)
- [Sandbox simulation](#sandbox-simulation)
- [Prepare configuration and recovery](#prepare-configuration-and-recovery)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)
- [Verify and recover](#verify-and-recover)

## Release changes

This guide covers chart `plugin-br-payments` 2.4.0 → 2.5.0. Both chart versions ship application 1.3.0. This chart release restores `TRUSTED_PROXIES` configuration, aligns the configured body limit with the existing application ceiling, and exposes receive/idle timeout and sandbox simulation settings. It does not introduce a new application binary or a higher request-body allowance.

| Chart configuration | 2.4.0 | 2.5.0 |
|---|---|---|
| `TRUSTED_PROXIES` | Rejected by retirement guard | Rendered when configured |
| Default `HTTP_BODY_LIMIT_BYTES` | `104857600` (100 MiB) | `4194304` (4 MiB) |
| `HTTP_RECEIVE_TIMEOUT_SEC` / `HTTP_IDLE_TIMEOUT_SEC` | Not exposed by this ConfigMap path | Rendered when configured |
| `SANDBOX_SIMULATION_ENABLED` / `SANDBOX_FAKEBTG_ADMIN_URL` | Not exposed by this ConfigMap path | Rendered when configured |
| Application version | `1.3.0` | `1.3.0` |

## Trusted proxies

Chart 2.4.0 rejected `app.configmap.TRUSTED_PROXIES` through its retirement guard. Chart 2.5.0 removes that check and renders the key when supplied. Operators who removed valid proxy configuration because of that guard can restore it in their intended values.

Supply comma-separated CIDRs of the actual trusted proxies, not bare IP addresses. Use `/32` for one IPv4 host or `/128` for one IPv6 host. Application 1.3.0 drops bare addresses, invalid entries, IPv4 ranges broader than `/8`, and IPv6 ranges broader than `/48`. IPv4-mapped IPv6 prefixes are normalized and evaluated as IPv4 ranges; use ordinary IPv4 notation to avoid ambiguity. Dropped entries produce error logs; startup continues with accepted entries. Do not use trust-all ranges such as `0.0.0.0/0`, which are dropped.

Partial example only — replace these documentation ranges with verified, narrow proxy CIDRs:

```yaml
app:
  configmap:
    TRUSTED_PROXIES: "192.0.2.10/32,2001:db8::10/128"
```

Behind an ingress or load balancer, an empty accepted proxy list can make callers share one rate-limit bucket. Validate actual client-IP attribution and trusted-hop behavior; do not trust arbitrary forwarded headers.

## HTTP listener bounds

Both chart versions ship application 1.3.0, whose main HTTP listener already caps `HTTP_BODY_LIMIT_BYTES` at `4194304` (4 MiB). Larger configured values are clamped and produce a warning. The 2.5.0 chart default aligns with this existing ceiling; rendering a larger ConfigMap value is not evidence that the application accepts it. Individual Huma endpoints impose their own, potentially lower, body limits.

Do not prescribe 10 MiB or 100 MiB overrides to cure HTTP 413 responses. Diagnose the specific endpoint contract, listener limit and upstream proxy limit; split requests only according to supported API contracts. Preserve intentional lower application limits.

Partial configuration fragment selecting the listener ceiling and optional timeouts:

```yaml
app:
  configmap:
    HTTP_BODY_LIMIT_BYTES: "4194304"
    HTTP_RECEIVE_TIMEOUT_SEC: "60"
    HTTP_IDLE_TIMEOUT_SEC: "120"
```

When unset or non-positive, application 1.3.0 resolves the receive timeout to 30 seconds and idle timeout to 120 seconds. Configure bounds for supported request sizes and network conditions. Longer timeouts do not lift body limits. `HTTP_READ_BUFFER_SIZE` was already exposed in chart 2.4.0 and is not a new field in this release. These listener settings do not govern the separate health listener.

## Sandbox simulation

The new chart settings expose the existing application's sandbox controls. The simulator is a separate running component; enabling the flag does not deploy it. Never enable simulation in production or point simulator traffic at a real provider.

This is a partial fragment, not an independently bootable or complete values file:

```yaml
app:
  configmap:
    ENV_NAME: "development"
    SANDBOX_SIMULATION_ENABLED: "true"
    SANDBOX_FAKEBTG_ADMIN_URL: "http://simulator.example.test:8080"
```

Before enabling it, configure all actual simulator endpoint paths and remaining application prerequisites in your complete intended configuration:

- The chart defaults `ENV_NAME` to `production`. Select a genuinely isolated non-production environment; application 1.3.0 refuses simulation in production.
- `SANDBOX_FAKEBTG_ADMIN_URL` must be an absolute HTTP(S) URL naming the running simulator.
- Required `BTG_API_BASE_URL` and `BTG_AUTH_URL` must share its scheme, host and effective port. Preserve the correct API/auth paths; paths need not be identical.
- If set, `BTG_COMMON_BASE_URL` must share that origin too. Origin mismatches refuse startup. The canonical API key is `BTG_API_BASE_URL`, not `BTG_API_URL`.
- Preserve required credentials and other service settings securely. The fragment alone does not configure provider endpoints, connectivity, storage or authentication.

Existing production installations should leave simulation disabled. Validate the effective environment and all provider URLs privately before starting any simulator-enabled deployment.

## Prepare configuration and recovery

1. Confirm the release name and namespace. Commands below use release `my-payments` in `midaz-plugins`; adapt them consistently.
2. Save current Helm values, manifests, history, chart version and effective image privately. These may contain credentials: use owner-only files and your approved secure backup process; never commit live credentials or license material.
3. Take consistent backups of the actual persistent datastores and retain the previous revision, images and complete configuration. Use an established, tested restore procedure. Both exact chart tags ship application 1.3.0 and unchanged migration templates; this does not prove a live upgrade or recovery is safe in your environment.
4. Prepare `payments-values.yaml` as the **complete intended configuration**. Merge only needed fragments, preserving unrelated settings, image pins, storage and existing Secret references. Check accepted proxy CIDRs, endpoint limits, timeouts, and the environment/provider prerequisites above.
5. The preview and upgrade both use `--reset-values -f`: omitted settings fall back to chart defaults rather than retaining stored overrides. Review the effective diff privately before applying. Do not use an isolated fragment or an empty values file as the complete configuration.
6. Plan a maintenance window and an operator-approved recovery path. Helm rollback alone does not restore datastore contents. Test recovery before production; the source and render checks behind this guide are not an exercised upgrade, backup or restore.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.0 --reset-values -f payments-values.yaml
```

Requires the public [helm-diff plugin](https://github.com/databus23/helm-diff). Use your approved plugin installation procedure. Confirm the effective image, ConfigMap, Secret references and persistent resource identities in the diff before proceeding.

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.0 --reset-values -f payments-values.yaml
```

## Verify and recover

Use both chart name and release instance labels to avoid inspecting another installation:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments
kubectl get deployments -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments -o name
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments --tail=100
```

Run `kubectl rollout status` for each Deployment returned, in that namespace. Check readiness, intended image/configuration, authenticated payment behavior and client-IP attribution. Inspect logs for dropped proxy entries, body-limit clamps, HTTP 413, timeouts and sandbox validation errors. Do not increase the listener setting beyond its hard ceiling as a remediation.

If recovery is necessary, stop affected writers and follow the tested recovery procedure for the previous application/configuration and any required datastore restoration. Do not assume a successful Helm rollback restored data. Validate recovery in isolation, then application behavior before resuming traffic. Remove temporary sensitive configuration exports when no longer needed, retaining protected backups according to policy.
<!-- {% endraw %} -->
