# Combined Helm Upgrade Guide: v8.6.0 → v9.2.0

For anyone jumping **directly** from `v8.6.0` (or an earlier `v8.x`) to
`v9.2.0`, skipping `v9.0.0`/`v9.1.0`. Full per-version detail lives in
[UPGRADE-9.0.md](./UPGRADE-9.0.md), [UPGRADE-9.1.md](./UPGRADE-9.1.md), and
[UPGRADE-9.2.md](./UPGRADE-9.2.md) — this page is the condensed, single-pass
version, weighted toward **adopting caradhras**, which is the change that
actually needs your attention on this jump.

# Topics

- **[Breaking Changes (v9.0.0)](#breaking-changes-v900)**
- **[Adopting Caradhras (v9.2.0)](#adopting-caradhras-v920)**
- **[Other Additive Features (v9.0.0 + v9.1.0)](#other-additive-features-v900--v910)**
- **[Migration Checklist](#migration-checklist)**
- **[Backward Compatibility Aliases](#backward-compatibility-aliases)**
- **[Known Gotchas](#known-gotchas)**
- **[Preview & upgrade commands](#preview--upgrade-commands)**

# Breaking Changes (v9.0.0)

| # | What changed | Action required |
|---|---|---|
| 1 | Component names now derive from the **release name**, not hardcoded `plugin-access-manager-*` | If your release is named anything other than `plugin-access-manager`, pin `identity.name`/`auth.name`/`auth.backend.name` to the old values, or accept new resources + clean up the old ones |
| 2 | `auth.initUser.adminPassword` has no default and is **required** when `initUser.enabled: true` | On upgrades: set `auth.initUser.enabled: false` (admin already exists, job is first-install-only). On fresh installs: set `adminPassword` or `useExistingSecret` |
| 3 | Cross-component DNS defaults (`AUTH_ADDRESS`, `DB_HOST`, `REDIS_HOST`, ...) are now computed from the release name instead of hardcoded | No action if unset. If you explicitly override these for external services, keep the overrides |

> `initUser` lives directly under `auth:`, never under `auth.backend:` — a value placed there is silently ignored.

# Adopting Caradhras (v9.2.0)

The auth backend (`auth.backend`, running Casdoor) is promoted to a
top-level component, `caradhras`, reflecting the product move from Casdoor
to Lerian's Caradhras. This is a **minor** release — it ships with a
backward-compatibility layer — but four things need a deliberate look.

### 1. The rename itself

| | v8.6.0/Casdoor | v9.2.0/Caradhras |
|---|---|---|
| Config path | `auth.backend.*` | `caradhras.*` |
| Resource/Service name | `<release>-auth-backend` | `<release>-caradhras` |
| Image | `ghcr.io/lerianstudio/casdoor:3.1.0` | `ghcr.io/lerianstudio/caradhras:1.2.0` |
| Migrations image | `ghcr.io/lerianstudio/casdoor-migrations:3.1.0` | `ghcr.io/lerianstudio/caradhras-migrations:1.2.0` |

`auth.backend.*` overrides keep working as a fallback for most fields — **except the image**. See below.

### 2. The one compat exception: the image does not fall back

`caradhras.image.repository`/`.tag`/`.pullPolicy` ship an explicit, non-empty
chart default (`ghcr.io/lerianstudio/caradhras:1.2.0`). The fallback to
`auth.backend.image.*` only triggers when the new key is *empty* — since it
never is here, a legacy `auth.backend.image.tag` override (e.g. to pin
Casdoor `3.1.0`) is **silently ignored**. Every other field (`name`,
`replicaCount`, `service.port`, probe timeouts, and the *migrations* image)
still falls back normally — see the [aliases table](#backward-compatibility-aliases).

**If you need to stay on Casdoor for now:**

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/casdoor
    tag: "3.1.0"
```

**Otherwise, no action** — you get Caradhras `1.2.0` automatically.

### 3. `createDatabase` now defaults to `false`

Most production DB users have no `CREATEDB` privilege; the old default
(`true`) caused permission-denied boot failures wherever the database is
pre-provisioned. If your user *does* have `CREATEDB` and relies on
auto-creation, set `caradhras.createDatabase: true` explicitly. Otherwise,
no action.

### 4. `initUser` now defaults to `false` (on top of Breaking Change #2)

`v9.0.0` already made a password required when enabled; `v9.2.0` flips the
enabled default too. If you already set `auth.initUser.enabled: false` per
the breaking-change table above, this is a no-op. If you never touched the
field, it's now off by default — set `enabled: true` + a password explicitly
if you actually need the job to run.

### New, opt-in: UI and ingress

- `caradhras.ui.enabled: true` — new SPA admin console (nginx), disabled by default.
- `caradhras.ingress.*` — the backend API can now declare its own ingress natively (previously required a hand-written raw Ingress outside the chart).
- `caradhras.pdb.*` — independent from `auth.pdb`; if you'd disabled `auth.pdb.enabled` expecting it to cover the backend too, set `caradhras.pdb.enabled: false` as well.

# Other Additive Features (v9.0.0 + v9.1.0)

None of these require action — they're optional capabilities available
once you're on `v9.2.0`. Full detail in [UPGRADE-9.0.md](./UPGRADE-9.0.md)/[UPGRADE-9.1.md](./UPGRADE-9.1.md).

- **Centralized authorizer client ID** — `common.authorizer.clientId`, shared by `auth`/`identity` instead of duplicated.
- **`global.*` configuration masks** — set `env`, `multiTenant`, `observability`, `datastores` (Postgres/Redis), and `serviceDiscovery` (Consul) once instead of duplicating across `auth`/`identity`. Native component keys (`auth.configmap.*`) always take precedence over the mask if both are set.
- **`lerian-common-helm` library adoption** — shared HPA/PDB/Service templates; rendered manifests are functionally identical.
- **`auth.backend.service` block** — the backend's Service type/port moved out of `auth.service` into its own block (superseded by `caradhras.service` in v9.2.0).

# Migration Checklist

1. `helm list -n plugin-access-manager` — confirm your release name.
2. **Not** `plugin-access-manager`? Pin `identity.name`/`auth.name`/`auth.backend.name` (or `caradhras.name`) to the old values.
3. Set `auth.initUser.enabled: false` (existing release) or provide `adminPassword`/`useExistingSecret` (fresh install).
4. Review any explicit `AUTH_ADDRESS`/`DB_HOST`/`REDIS_HOST`/`AUTHORIZER_ADDRESS` overrides — keep only the ones pointing at genuinely external services.
5. Decide on the Caradhras image: do nothing (adopt `1.2.0`), or pin `caradhras.image.*` to stay on Casdoor.
6. Check your DB user's `CREATEDB` privilege; set `caradhras.createDatabase: true` only if you rely on auto-creation.
7. *(Optional)* Migrate `auth.backend.*` overrides to `caradhras.*`, and/or adopt the `global.*` masks.

# Backward Compatibility Aliases

| `caradhras.*` | Falls back to `auth.backend.*`? | Default |
|---|---|---|
| `name` | ✅ | `<release>-caradhras` |
| `replicaCount` | ✅ | `1` |
| `service.port` | ✅ | `8000` |
| `readinessProbe.timeoutSeconds` / `livenessProbe.timeoutSeconds` | ✅ | `1` |
| `migrations.image.*` | ✅ | `ghcr.io/lerianstudio/caradhras-migrations:1.2.0` |
| **`image.repository` / `.tag` / `.pullPolicy`** | ❌ **explicit default always wins** | `ghcr.io/lerianstudio/caradhras:1.2.0` |

Use **either** `caradhras.*` **or** `auth.backend.*` consistently — mixing them works (new key wins per-field) but is easy to misread later.

# Known Gotchas

- **Redis `caCert` must be Amazon Root CA1, not the RDS truststore bundle.** ElastiCache/Valkey TLS chains to the general Amazon root, not the RDS-specific one — using the RDS bundle fails with `x509: certificate signed by unknown authority`. Fetch it with:
  ```bash
  curl -s https://www.amazontrust.com/repository/AmazonRootCA1.pem | base64 -w0
  ```
- **Dedicated (non-`CREATEDB`) Postgres role**: pre-create the database/role yourself and set `caradhras.createDatabase: false` (the v9.2.0 default already does this) rather than granting `CREATEDB` to a least-privilege role just to satisfy the old default.

# Preview & upgrade commands

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
```

> `helm diff` requires the [helm-diff plugin](https://github.com/databus23/helm-diff).
