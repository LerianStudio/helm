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

> ⚠️ **The migrations image falling back "normally" is a trap on this jump — read this before you skip it.**
> Unlike the main image, the migrations image repository *does* inherit from
> the legacy path (`auth.backend.migrations.image.repository`) — and that is
> exactly the problem. If a prior version of your values pinned
> `casdoor-migrations` there, that override **silently wins** over the correct
> `caradhras-migrations` default. Whether you set the new key
> (`caradhras.migrations.image.repository`) or the legacy alias, any non-empty
> migration-repo override beats the chart default. **Operators who pinned
> `casdoor-migrations` in a prior version MUST change it to
> `caradhras-migrations`** (see the [Migration Checklist](#migration-checklist)
> and [Known Gotchas](#known-gotchas)).
>
> This chart now **guards against the specific `casdoor-migrations` case**: if
> the resolved migration repository contains `casdoor-migrations`, Helm
> **rendering fails** (`helm template`/`upgrade`) with an error pointing here, so
> you cannot deploy it by accident. The guard only denylists that one legacy
> name — so understand why it exists, because any *other* wrong migration repo
> still fails silently:
>
> - **The wrong repo has a coincidental `1.2.0` tag that pulls cleanly.**
>   `casdoor-migrations` happens to carry a `1.2.0` tag (June 2025, from the
>   previous product line). Absent the guard above (or for any other mis-pinned
>   repo the guard does not catch), the image pulls without error and only fails
>   *at runtime*. A wrong tag that exists is more confusing than one that
>   doesn't: there is no `ImagePullBackOff` to tip you off, just a failed
>   migration Job (see [Known Gotchas](#known-gotchas) for the exact signature).
> - **caradhras `1.2.0` is a different product line, not an older casdoor.**
>   caradhras-migrations `1.2.x` is **not** a downgrade or an earlier version of
>   casdoor `3.1.0`; the two version numbers belong to unrelated release trains.
>   Do not "stay on the higher number" (`casdoor-migrations:3.1.0`) thinking it
>   is newer — on `v9.x` the correct migration image is `caradhras-migrations`
>   on its own `1.2.x` train, because only it reads the `POSTGRES_*` env vars
>   the `v9.x` migration Job injects.

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

### 5. Preparing your values.yaml

Take this as your worked example — a typical `v8.6.0` `auth.backend` block:

```yaml
auth:
  backend:
    name: ""
    replicaCount: 2
    createDatabase: true
    service:
      port: 8000
    image:
      repository: ghcr.io/lerianstudio/casdoor
      pullPolicy: Always
      tag: "3.1.0"
    migrations:
      image:
        repository: ghcr.io/lerianstudio/casdoor-migrations
        pullPolicy: Always
        tag: "3.1.0"
    readinessProbe:
      timeoutSeconds: 10
    livenessProbe:
      timeoutSeconds: 10
  initUser:
    enabled: true
    adminPassword: "Lerian@123"
```

**Step by step, translate it into `caradhras.*`:**

1. **Rename the block**, drop everything you're not intentionally overriding — the chart has sane defaults for the rest:

   ```yaml
   caradhras:
     replicaCount: 2
   ```

2. **Decide the image explicitly** — this is the one field that does NOT inherit from `auth.backend`, so silence here means "adopt Caradhras `1.2.0`":

   ```yaml
   caradhras:
     replicaCount: 2
     image:
       repository: ghcr.io/lerianstudio/caradhras   # omit entirely to accept the chart default
       tag: "1.2.0"
     migrations:
       image:
         repository: ghcr.io/lerianstudio/caradhras-migrations
         tag: "1.2.0"
   ```

   > If you deliberately want to stay on Casdoor a bit longer, put the *old* image values here instead (`ghcr.io/lerianstudio/casdoor:3.1.0`) — see [item 2](#2-the-one-compat-exception-the-image-does-not-fall-back).

3. **Carry over anything you tuned on purpose** (probe timeouts, service port, `createDatabase`) — these DO still fall back from `auth.backend.*` on their own, but move them anyway if you're doing the full migration:

   ```yaml
   caradhras:
     replicaCount: 2
     image:
       tag: "1.2.0"
     migrations:
       image:
         tag: "1.2.0"
     service:
       port: 8000
     readinessProbe:
       timeoutSeconds: 10
     livenessProbe:
       timeoutSeconds: 10
     # createDatabase: true   # only if your DB user actually has CREATEDB; chart default is now false
   ```

4. **Handle `initUser` separately** — it stays under `auth:`, not `caradhras:`, and its default flipped to `false`. On an existing release, just disable it:

   ```yaml
   auth:
     initUser:
       enabled: false
   ```

5. **Delete the old `auth.backend` block entirely** once you've moved what you need — a leftover `auth.backend.image.tag` sitting next to an explicit `caradhras.image.tag` does nothing (it's dead config, not a conflict), but it's confusing for the next person reading the file.

**End state:**

```yaml
auth:
  initUser:
    enabled: false

caradhras:
  replicaCount: 2
  image:
    tag: "1.2.0"
  migrations:
    image:
      tag: "1.2.0"
  service:
    port: 8000
  readinessProbe:
    timeoutSeconds: 10
  livenessProbe:
    timeoutSeconds: 10
```

> **Don't want to migrate the structure right now?** You don't have to — `auth.backend.*` keeps working for everything except the image (step 2 above still applies: decide the image explicitly, one way or the other). The full migration in steps 1-5 is about clarity, not a requirement.

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
6. **If you pinned the migration repo, change it to `caradhras-migrations` (the `1.2.x` train).** Grep your values for `casdoor-migrations` under **either** `caradhras.migrations.image.repository` **or** the legacy `auth.backend.migrations.image.repository`. A leftover `casdoor-migrations` pin is now caught at **Helm render time** (the chart fails `helm template`/`upgrade` with a guard error) so you cannot deploy it; any *other* wrong repo instead silently overrides the correct default, pulls cleanly (wrong tag exists), then fails at runtime. Leave it empty to accept the chart default. Note: `caradhras-migrations:1.2.x` is a *different product line*, not a downgrade of `casdoor-migrations:3.1.0`.
7. Check your DB user's `CREATEDB` privilege; set `caradhras.createDatabase: true` only if you rely on auto-creation.
8. *(Optional)* Migrate `auth.backend.*` overrides to `caradhras.*`, and/or adopt the `global.*` masks.

# Backward Compatibility Aliases

| `caradhras.*` | Falls back to `auth.backend.*`? | Default |
|---|---|---|
| `name` | ✅ | `<release>-caradhras` |
| `replicaCount` | ✅ | `1` |
| `service.port` | ✅ | `8000` |
| `readinessProbe.timeoutSeconds` / `livenessProbe.timeoutSeconds` | ✅ | `1` |
| `migrations.image.*` | ✅ **but see warning** | `ghcr.io/lerianstudio/caradhras-migrations:1.2.0` |
| **`image.repository` / `.tag` / `.pullPolicy`** | ❌ **explicit default always wins** | `ghcr.io/lerianstudio/caradhras:1.2.0` |

Use **either** `caradhras.*` **or** `auth.backend.*` consistently — mixing them works (new key wins per-field) but is easy to misread later.

> ⚠️ **`migrations.image.*` falls back, and that is the trap.** A migration-repo
> override on *either* path (`caradhras.migrations.image.repository` or the
> legacy `auth.backend.migrations.image.repository`) silently wins over the
> `caradhras-migrations` default. If you carried a `casdoor-migrations` pin
> over from a prior version, it will keep applying the wrong image — with no
> render- or pull-time error. See the [warning in item 2](#2-the-one-compat-exception-the-image-does-not-fall-back)
> and [Known Gotchas](#known-gotchas).

# Known Gotchas

- **Redis `caCert` must be Amazon Root CA1, not the RDS truststore bundle.** ElastiCache/Valkey TLS chains to the general Amazon root, not the RDS-specific one — using the RDS bundle fails with `x509: certificate signed by unknown authority`. Fetch it with:
  ```bash
  curl -s https://www.amazontrust.com/repository/AmazonRootCA1.pem | base64 -w0
  ```
- **Dedicated (non-`CREATEDB`) Postgres role**: pre-create the database/role yourself and set `caradhras.createDatabase: false` (the v9.2.0 default already does this) rather than granting `CREATEDB` to a least-privilege role just to satisfy the old default.
- **Migration Job fails with `Missing required environment variables: DB_USER, DB_PASS, DB_HOST, DB_NAME`** → your migration image is still the **old `casdoor-migrations`**, not `caradhras-migrations`. (On this chart version a `casdoor-migrations` pin is normally caught earlier, at Helm render — see the warning above; you'll only reach this *runtime* signature on a pre-guard chart, or with a mis-pinned repo whose name doesn't contain `casdoor-migrations`.) Root cause: the old image reads `DB_*` env vars, while the `v9.x` migration Job injects `POSTGRES_*` (the standard lib-commons names that `caradhras-migrations` reads) — so the old image sees none of the DB vars it expects and aborts. The image usually **pulls cleanly** first, because `casdoor-migrations` carries a coincidental `1.2.0` tag (June 2025, previous product line) that exists but is wrong — *a wrong tag that exists is more confusing than one that doesn't*, since there is no `ImagePullBackOff` to point at it. **Fix:** find the stale pin (`grep -rn casdoor-migrations` your values) under either `caradhras.migrations.image.repository` or the legacy `auth.backend.migrations.image.repository`, and either remove it (accept the `caradhras-migrations` default) or set it explicitly to `ghcr.io/lerianstudio/caradhras-migrations` on the `1.2.x` train. Reminder: `caradhras-migrations:1.2.x` is a *different product line*, **not** an older version of `casdoor-migrations:3.1.0` — do not "upgrade" to the higher number.

# Preview & upgrade commands

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
```

> `helm diff` requires the [helm-diff plugin](https://github.com/databus23/helm-diff).
