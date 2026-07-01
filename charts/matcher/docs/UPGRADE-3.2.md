# Helm Upgrade from v3.1.x to v3.2.x

## Overview

`matcher-helm` 3.2.0 promotes the **UI**, **MCP**, and **detached migrations** into
this chart as first-class, optional components, following the Lerian multi-component
house pattern. The chart annotation changes from `single-service` to `multi-component`.

**This is a backward-compatible (additive) release.** The existing `matcher.*` (API)
values block is unchanged, and all new components default to `enabled: false`. A default
render (no new components enabled) matches 3.1.x except for:

- the chart version string (`helm.sh/chart: matcher-helm-3.2.0-beta.1`);
- moved-file provenance: the API templates now live under `templates/matcher/`, which
  changes the `# Source:` comments and the emit order of two `Secret` documents (the
  rendered Kubernetes objects are otherwise unchanged); and
- the deliberate auth changes below — the ConfigMap emits `PLUGIN_AUTH_ENABLED` /
  `PLUGIN_AUTH_ADDRESS` in place of `AUTH_ENABLED` / `AUTH_SERVICE_ADDRESS`, and the
  `AUTH_JWT_SECRET` Secret key is removed. Values and runtime behavior are preserved
  (the app honors both aliases; legacy values still resolve via a fallback).

No action is required for existing API-only consumers.

## What changed

### 1. Template layout (no output change for the API)

The flat `templates/*.yaml` app manifests moved into component subdirectories:

- `templates/matcher/` — API (deployment, service, ingress, hpa, pdb, configmap, secrets, serviceaccount)
- `templates/ui/` — UI (deployment, service, ingress)
- `templates/mcp/` — MCP (deployment, service, ingress)
- `templates/migrations/` — PreSync Secret + Job

`bootstrap-postgres.yaml`, `bootstrap-rabbitmq.yaml`, `rabbitmq_load_definitions.yaml`
and `_helpers.tpl` remain at the `templates/` root.

### 2. New optional components (default off)

See `README.md` for the full parameter tables.

- **`ui.*`** — Vite SPA served by nginx-unprivileged. When `ui.ingress.enabled=true`,
  the ingress implements the **same-origin proxy**: `/v1` and `/system` route to the
  matcher API Service; `/` routes to the UI Service (single ingress, two backends). The
  UI image hardcodes a CSP with `connect-src 'self'`, so the API must be same-origin.
- **`mcp.*`** — Streamable-HTTP MCP relay. Holds no credentials; forwards to the
  in-cluster API. Independent version line from the app tag.
- **`migrations.*`** — ArgoCD PreSync Secret (hook-weight `-2`) + Job (hook-weight `-1`)
  that applies the schema up-only before the app Deployment. **Never** set
  `MULTI_TENANT_ENABLED=true` for the runner. When `matcher.useExistingSecret=true`,
  the Job reads `POSTGRES_PASSWORD` from the existing Secret and no PreSync Secret is minted.

### 3. Secret allowlist

- **Added `APP_ENC_KEY`** (base64 32-byte engine-credential master key). **Required in
  production** per the app. It is now first-class in `matcher.secrets` and is emitted into
  the Secret **only when set** (opt-in), so a default render stays byte-identical. Previously
  operators had to inject it via an external secret.
  Generate: `openssl rand -base64 32 | tr -d '\n'`.
- **Added `ACTOR_PII_ENCRYPTION_KEY`** (optional, base64 32-byte). Emitted only when set.
- **`AUTH_JWT_SECRET` removed** (no-op in app v4 — token validation is delegated to
  plugin-auth). It is no longer emitted into the Secret. If you still set
  `matcher.secrets.AUTH_JWT_SECRET`, the value is simply ignored (harmless). No action needed.
- **`AUTH_ENABLED` / `AUTH_SERVICE_ADDRESS` renamed to `PLUGIN_AUTH_ENABLED` /
  `PLUGIN_AUTH_ADDRESS`** in the ConfigMap (the app's canonical v4 names). The template still
  reads the legacy `matcher.configmap.AUTH_ENABLED` / `AUTH_SERVICE_ADDRESS` as a fallback, so
  existing values keep working without a lockstep change — migrate to the new keys when
  convenient. The rendered ConfigMap now carries the `PLUGIN_AUTH_*` keys instead of `AUTH_*`.
  (Security note: because the legacy values are still honored, an upgrade will NOT silently
  disable auth on environments that set `AUTH_ENABLED: "true"`.)

### 4. App env knob

- **`matcher.configmap.GOMEMLIMIT`** — new opt-in knob for the Go soft memory limit
  (Go 1.26 does not auto-detect cgroup limits). Set to ~85% of the pod memory limit
  (e.g. `"435MiB"`). Emitted only when non-empty; default render unchanged.

## Migration steps

1. **API-only consumers:** none. `helm upgrade` is a no-op change to workloads.
2. **To enable the UI:** set `ui.enabled=true`, `ui.image.tag`, and — for external access —
   `ui.ingress.enabled=true` with `ui.ingress.host` and a cert-manager issuer annotation.
3. **To enable the MCP:** set `mcp.enabled=true` and `mcp.image.tag`.
4. **To enable detached migrations:** set `migrations.enabled=true` and provide the
   Postgres password via `migrations.postgres.password` (or set `matcher.useExistingSecret`).
5. **Production:** set `matcher.secrets.APP_ENC_KEY` (or provide it via your existing secret).

## Preview changes before upgrading

```bash
helm template <release> charts/matcher --set ui.enabled=true --set ui.image.tag=<tag> \
  --set mcp.enabled=true --set mcp.image.tag=<tag> --set migrations.enabled=true
```
