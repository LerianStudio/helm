# Helm Upgrade from v10.0.2 to v10.0.3

## Topics

- **[Fixes](#fixes)**
  - [1. The bundled Valkey keeps its data and refuses writes when full](#1-the-bundled-valkey-keeps-its-data-and-refuses-writes-when-full)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. The bundled Valkey keeps its data and refuses writes when full

**Who is affected:** every release that runs the bundled Valkey (`valkey.enabled: true`, the default). A release on an external Valkey or Redis is unaffected, but should check that instance against [Why it matters](#why-it-matters).

#### What changed

| Setting | v10.0.2 | v10.0.3 |
|---------|---------|---------|
| `valkey.primary.persistence.enabled` | `false` (memory only, `emptyDir`) | `true`: claim `valkey-data-midaz-valkey-primary`, 8Gi, ReadWriteOnce, kept on `helm uninstall` |
| `valkey.primary.updateStrategy.type` | `RollingUpdate` | `Recreate` |
| `--maxmemory-policy` | `allkeys-lru` | `noeviction` |
| `--appendonly` / `--appendfsync` | AOF on the `emptyDir` | `yes` / `everysec`, on the volume |
| `valkey.image.digest` | none (`latest` floats) | Valkey 9.1.2, pinned |
| `--maxmemory` | `640mb` | `640mb` |

#### Why it matters

The Ledger keeps state in Valkey that no other store holds: balances not yet synced to PostgreSQL, idempotency keys, engine receipts and the open fee debts of `deferrable` fees. In the Lua engine (the default) each approval holds about 14 KB for its 300-second retention, so 640mb fills at about 150 approvals per second. Under `allkeys-lru` a full Valkey then evicted that state in silence: an evicted idempotency key lets a retried request post twice, an evicted fee debt is a receivable lost, and an evicted unsynced balance is gone. Any Valkey restart wiped all of it.

From v10.0.3 a full Valkey refuses the write and the Ledger answers that request with an error. A restart reloads the append-only file from the volume; a crash loses at most about one second of writes.

#### What happens at the upgrade

- **One Valkey restart.** The `Recreate` strategy stops the old pod before the new one starts, so the Ledger answers errors until the new pod is ready. Upgrade in a maintenance window.
- **What the old pod held is lost.** The new pod starts on an empty volume. Everything the old pod held only in memory, including open fee debts on the bundled Valkey, is lost at that restart exactly as at any Valkey restart before this version.
- **A StorageClass is needed.** The claim uses the cluster's default StorageClass, as the PostgreSQL and MongoDB volumes already do. Without one, set `valkey.primary.persistence.storageClass`; otherwise the claim stays `Pending` and Valkey does not start.
- **Server-side apply needs one patch first.** A release installed with Helm 4 (`helm install` applies server-side by default and `helm upgrade` keeps the method) or synced by Argo CD with `ServerSideApply=true` cannot switch the strategy by itself: the API server keeps the `rollingUpdate` block it defaulted, and the upgrade fails with `spec.strategy.rollingUpdate: Forbidden: may not be specified when strategy type is 'Recreate'`. Run this once before upgrading. It changes no pod and is harmless under any apply method:

  ```bash
  kubectl -n midaz patch deployment midaz-valkey-primary --type strategic \
    -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
  ```

#### Sizing

640mb sustains about 150 approvals per second in the Lua engine. For more, raise `--maxmemory` with the Valkey sizing rule in the Midaz engine guide (`docs/architecture/engine.md` in the Midaz repository), and raise the pod memory with it (`valkey.primary.resourcesPreset` or `valkey.primary.resources`). See the chart README, section Valkey.

#### Keeping `allkeys-lru`

Not recommended: it brings back the silent eviction described above. An operator who insists overrides `extraFlags`. It is a list, so restate every flag:

```yaml
valkey:
  primary:
    extraFlags:
      - "--maxmemory 640mb"
      - "--maxmemory-policy allkeys-lru"
      - "--appendonly yes"
      - "--appendfsync everysec"
      - "--hz 100"
      - "--maxclients 10000"
```

The volume stays on with this override; only the eviction policy goes back.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.3 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.3 -n midaz
```
