# Helm Upgrade from v10.0.2 to v10.0.3

## Topics

- **[Fixes](#fixes)**
  - [1. The bundled Valkey keeps its data and refuses writes when full](#1-the-bundled-valkey-keeps-its-data-and-refuses-writes-when-full)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. The bundled Valkey keeps its data and refuses writes when full

**Who is affected:** every release that runs the bundled Valkey (`valkey.enabled: true`, the default). Values that set `valkey.primary.extraFlags`, `valkey.primary.persistence` or `valkey.primary.kind` change what the upgrade does: see [Check your Valkey overrides](#check-your-valkey-overrides). A release on an external Valkey or Redis is unaffected, but should check that instance against [Why it matters](#why-it-matters).

#### What changed

| Setting | v10.0.2 | v10.0.3 |
|---------|---------|---------|
| `valkey.primary.persistence.enabled` | `false`: the append-only file lives in an `emptyDir` and dies with the pod | `true`: claim `valkey-data-midaz-valkey-primary`, 8Gi, ReadWriteOnce, kept on `helm uninstall` |
| `valkey.primary.updateStrategy.type` | `RollingUpdate` | `Recreate` |
| `--maxmemory-policy` | `allkeys-lru` | `noeviction` |
| `valkey.image.digest` | none (`latest` floats) | Valkey 9.1.2, pinned |

#### Why it matters

The Ledger keeps state in Valkey that no other store holds: balances not yet synced to PostgreSQL, idempotency keys, engine receipts and the open fee debts of `deferrable` fees. In the Lua engine (the default) each approval holds about 14 KB until `X-TTL` (300 seconds by default) after it completes, so 640mb fills at about 150 approvals per second. Under `allkeys-lru` a full Valkey then evicted that state in silence: an evicted idempotency key lets a retried request post twice, an evicted fee debt is a receivable lost, and an evicted unsynced balance is gone. Any Valkey restart wiped all of it.

From v10.0.3 a full Valkey refuses the write and the Ledger answers that request with an error. A restart reloads the append-only file from the volume; a crash loses at most about one second of writes. Size `--maxmemory` for your traffic with the rule in the chart README, section [Valkey](../README.md#valkey).

#### Check your Valkey overrides

Run `helm get values midaz -n midaz` and look under `valkey.primary`. Helm replaces lists and keeps the values you set, so:

- **`extraFlags`:** yours replace the chart's, eviction policy included. Delete them to take the new defaults, or make sure they carry `--maxmemory-policy noeviction`.
- **`persistence.enabled: false`:** Valkey stays in memory. Delete it.
- **`persistence.enabled: true`** (the old README asked for it before `deferrable` fees): the release keeps its claim, and the new pod reloads its append-only file. Valkey still restarts once, but nothing is lost and the drain below is not needed.
- **`kind: StatefulSet`:** a StatefulSet refuses `Recreate`, so set `valkey.primary.updateStrategy.type: RollingUpdate`. If it ran without persistence, the new volume template is a StatefulSet field Kubernetes does not let an upgrade change. Keep `persistence.enabled: false`, or delete the StatefulSet but not its pod right before upgrading, so the upgrade creates it again with the volume:

  ```bash
  kubectl -n midaz delete statefulset midaz-valkey-primary --cascade=orphan
  ```

#### What happens at the upgrade

- **One Valkey restart.** The `Recreate` strategy stops the old pod before the new one starts, so the Ledger answers errors until the new pod is ready.
- **Drain first if Valkey ran without persistence** (the v10.0.2 default). The new pod starts on an empty volume, which flushes everything the old pod held. Executions the engine applied but did not complete are never completed, a balance not yet synced re-seeds from an older PostgreSQL row and forks from its operations, and an idempotency key lost inside its `X-TTL` lets a retry post twice. Drain, so the restart loses only open fee debts, exactly as any Valkey restart before this version did:
  1. Prepare as [UPGRADE-9.8](UPGRADE-9.8.md#before-you-upgrade-midaz-v42x-to-v43) describes: pause autoscaling and GitOps self-heal, and in multi-tenant raise `MULTI_TENANT_CACHE_TTL_SEC` above the length of the window. Then cut traffic to the ledger outside its pods and keep them running, as in step 1 of its drained cutover. Wait until the write-behind queue shows 0 ready and 0 unacked, the hashes `engine:{transactions}:recover` and `backup_queue:{transactions}` are empty and the sorted sets `schedule:{transactions}:balance-sync-v2` and `schedule:{transactions}:balance-sync` are empty. Multi-tenant: check the `tenant:<tenantId>:` copy of each key.
  2. Wait out the longest `X-TTL` your clients send (300 seconds by default), then upgrade and restore traffic.
- **A StorageClass is needed.** The claim uses the cluster's default StorageClass, as the PostgreSQL and MongoDB volumes already do. Without one, set `valkey.primary.persistence.storageClass`; otherwise the claim stays `Pending` and Valkey does not start.
- **Server-side apply needs one patch first.** A release installed with Helm 4 (`helm install` applies server-side by default and `helm upgrade` keeps the method) or synced by Argo CD with `ServerSideApply=true` cannot switch the strategy by itself: the API server keeps the `rollingUpdate` block it defaulted, and the upgrade fails with `spec.strategy.rollingUpdate: Forbidden: may not be specified when strategy type is 'Recreate'`. Run this once before upgrading. It changes no pod and is harmless under any apply method:

  ```bash
  kubectl -n midaz patch deployment midaz-valkey-primary --type strategic \
    -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
  ```

#### Keeping `allkeys-lru`

Not recommended: it brings back the silent eviction described above. An operator who insists overrides `extraFlags`. It is a list, so restate every flag:

```yaml
valkey:
  primary:
    extraFlags:
      - "--maxmemory 640mb"
      - "--maxmemory-policy allkeys-lru"
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
