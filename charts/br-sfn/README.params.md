# Parameters

## Global (shared across all components)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `global.imageRegistry` | string | `""` | Container image registry prefix shared by every component (umbrella-wide). |
| `global.imagePullSecrets` | list | `[]` | Image pull secrets shared by every component and migration Job (umbrella-wide). |
| `global.datastores` | object | `{}` | Shared datastore masks. Keys per type: postgres / redis / broker (RabbitMQ). Each accepts host / port / user / name / ssl / replicaHost (spi uses postgres + redis; spb adds broker). |
| `global.observability` | object | `{}` | Env-wide observability (OTel collector): enabled / otlpEndpoint / deploymentEnvironment. |
| `global.auth` | object | `{}` | Env-wide auth (plugin-access-manager): enabled / host. Per-component override via `<component>.configmap.AUTH_ENABLED` / `PLUGIN_AUTH_ADDRESS`. |
| `global.multiTenant` | object | `{}` | Env-wide multi-tenant (tenant-manager). Read by scr (MULTI_TENANT_URL) via lerian-common.multiTenant.env; keys: url (+ redisHost/redisPort/redisTls for rails that emit the redis group). Per-component gate via configmap.MULTI_TENANT_ENABLED. |
| `global.serviceDiscovery` | object | `{}` | Env-wide service discovery (Consul). Reserved; no br-sfn component wires it yet. |
| `global.streaming` | object | `{}` | Env-wide streaming (lib-streaming / RedPanda). Reserved as a GAP: spi's settlement topics and scr's SCR_STREAMING_* are app-prefixed and do NOT match lib-streaming's canonical STREAMING_* env contract, so no component wires streaming.env yet. |
| `global.objectStorage` | object | `{}` | Env-wide object storage (S3 / SeaweedFS), keyed by backend name. Read by correios (backend `default`) via lerian-common.objectStorage.value; fields: <name>.{endpoint,region,bucket,disableSSL,usePathStyle}. Credentials -> secrets. |
| `global.kms` | object | `{}` | Env-wide KMS / Vault (envelope encryption). Reserved; spi custody is BACEN signer-kind, not this. |
| `imagePullSecrets` | object | `{}` | Default pull secret for every component and migration Job (single GHCR credential). Override per component via <component>.imagePullSecrets. |
| `podSecurityContext` | object | `{}` | Pod-level security context (all components) |
| `securityContext` | object | `{}` | Container security context (alpine/debian nonroot images — UID/GID 65532; the cockpit overrides runAsUser/runAsGroup via cockpit.securityContext because nginx-unprivileged runs as uid 101). |
| `waitImage` | string | `busybox:1.36` | Image used by wait-for-dependency initContainers. |
| `migrateImage` | string | `migrate/migrate:v4.18.1` | golang-migrate image for components whose migrations run from their baked /migrations tree (spb, scr, desk). spi and siloc ship dedicated migrator images instead (see their migrations blocks). |
| `spb.datastores` | object | `{}` | Dedicated datastore masks for SPB (Postgres + Redis + RabbitMQ). Overrides global.datastores; each configmap.<KEY> still wins. postgres: host/port/user/name/ ssl/replicaHost; redis: host/port; broker (RabbitMQ): host/port/user. |
| `spb.configmap` | object | `{}` | SPB ConfigMap escape hatch: set/override ANY native env KEY here (wins over the template default). Credentials NEVER go here — use secrets. |
| `spb.secrets` | object | `{}` | SPB Secret map (emit-when-set). Holds POSTGRES/REDIS/RABBITMQ/STR_MQ passwords, WEBHOOK_SECRET_KEY, STR_PAYLOAD_ENCRYPTION_KEY, SPB_KMIP_CRYPTO_USER_TOKEN, DEV_DEBUG_TOKEN. Use useExistingSecret/existingSecretName to bring your own. |

## SPI (Pix rail — 4 binaries: spi-api / spi-dict / spi-brcode / spi-core)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `spi.enabled` | bool | `false` | Deploy the SPI/Pix rail (all four sub-deployments). |
| `spi.datastores` | object | `{}` | Dedicated datastore masks for the SPI family (one Postgres + one Redis shared by all four binaries). Overrides global.datastores; each configmap.<KEY> still wins. postgres accepts host/port/user/name/ssl/replicaHost; redis accepts host. |
| `spi.configmap` | object | `{}` | SHARED ConfigMap escape hatch for all four binaries: set/override ANY native env KEY here (wins over the template default). Per-binary override via spi.<api|dict|brcode|core>.configmap.<KEY>. Credentials NEVER go here — use secrets. |
| `spi.secrets` | object | `{}` | SHARED Secret map for all four binaries (emit-when-set; per-binary override via spi.<comp>.secrets). Holds POSTGRES_PASSWORD/REDIS_PASSWORD and the PII/crypto keys. |
| `spi.useExistingSecret` | bool | `false` | Bring your own Secret instead of the chart-managed one (family-wide). |
| `siloc.datastores` | object | `{}` | Dedicated datastore masks for SILOC (Postgres + Redis). Overrides global.datastores; each configmap.<KEY> still wins. postgres: host/port/user/ name/ssl/replicaHost (native DB_*); redis: host (native REDIS_ADDRESS). The SAME postgres mask also feeds the migrator's POSTGRES_* (see migrations below). |
| `siloc.configmap` | object | `{}` | SILOC ConfigMap escape hatch: set/override ANY native env KEY (DB_*, MQ_*, SFN_*, ...); wins over the template default. Credentials NEVER go here — use secrets. |
| `siloc.secrets` | object | `{}` | SILOC Secret map (emit-when-set). Holds DB_PASSWORD, REDIS_PASSWORD. |
| `scr.datastores` | object | `{}` | Dedicated datastore masks for SCR (Postgres + Redis). Overrides global.datastores; each configmap.<KEY> still wins. postgres: host/port/user/ name/ssl (no replica); redis: host/port. The app and the baked migrator both read POSTGRES_*, so one mask feeds both. |
| `scr.configmap` | object | `{}` | SCR ConfigMap escape hatch: set/override ANY native env KEY (POSTGRES_*, SCR_STREAMING_*, SCR_WSSCR2N_*, SECRET_STORE_*, MULTI_TENANT_ENABLED/URL, ...); wins over the template default. Credentials NEVER go here — use secrets. |
| `scr.secrets` | object | `{}` | SCR Secret map (emit-when-set). Holds POSTGRES_PASSWORD, REDIS_PASSWORD, MULTI_TENANT_SERVICE_API_KEY, SCR_WSSCR2N_BASIC_PASSWORD, and the SCR_ATREST_* PII keys. |
| `desk.datastores` | object | `{}` | Dedicated datastore mask for DESK (Postgres only; no Redis/replica). Overrides global.datastores; each configmap.<KEY> still wins. postgres: host/port/user/name/ssl (native DB_*). The app reads DB_*; the baked migrator reads POSTGRES_* — the same mask feeds both (see migrations passwordSecret). |
| `desk.configmap` | object | `{}` | DESK ConfigMap escape hatch: set/override ANY native env KEY (DB_*, DESK_*, PLUGIN_ACCESS_MANAGER_URL/CLIENT_ID, ...); wins over the template default. Credentials NEVER go here — use secrets. |
| `desk.secrets` | object | `{}` | DESK Secret map (emit-when-set). Holds DB_PASSWORD and the outbound M2M PLUGIN_ACCESS_MANAGER_CLIENT_SECRET. |
| `correios.datastores` | object | `{}` | Dedicated datastore masks for CORREIOS. Overrides global.datastores; each configmap.<KEY> still wins. postgres: host/port/user/name/ssl (native db-name is POSTGRES_NAME; app + baked migrator both POSTGRES_*); redis: host (native CACHE_ADDR, host:port). RabbitMQ is NOT masked — correios uses a full RABBITMQ_URL (a Secret). |
| `correios.objectStorage` | object | `{}` | Dedicated object-storage mask for CORREIOS (S3/SeaweedFS attachment store). Overrides global.objectStorage; backend name is `default`. Fields: endpoint/ region/bucket/usePathStyle. Credentials (ACCESS_KEY/SECRET_KEY) -> secrets. |
| `correios.configmap` | object | `{}` | CORREIOS ConfigMap escape hatch: set/override ANY native env KEY (POSTGRES_*, CACHE_*, OBJECT_STORAGE_*, MULTI_TENANT_*, AI_*, BC_CORREIO_*, ...); wins over the template default. Credentials NEVER go here — use secrets. |
| `correios.secrets` | object | `{}` | CORREIOS Secret map (emit-when-set). Holds POSTGRES_PASSWORD, CACHE_PASSWORD, RABBITMQ_URL (embeds creds) + RABBITMQ_PASS, OBJECT_STORAGE_ACCESS_KEY/SECRET_KEY, ENCRYPTION_KEY, LICENSE_KEY, PLUGIN_AUTH_CLIENT_SECRET, MULTI_TENANT_SERVICE_API_KEY, MULTI_TENANT_REDIS_PASSWORD. |
| `slcEdge.configmap` | object | `{}` | SLC-EDGE ConfigMap escape hatch: set/override ANY native env KEY (SLC_UPSTREAM_URL, SLC_*_TIMEOUT, SLC_EDGE_CORS_ALLOWED_ORIGINS, ...). |
| `slcEdge.secrets` | object | `{}` | SLC-EDGE has NO secrets (it forwards the caller's Authorization header verbatim; it holds no credential). Kept for the escape-hatch contract. |
| `cockpit` | object | `{}` | build-arg VITE_*=... (out of chart scope). ============================================================================= |
| `cockpit.configmap` | object | `{}` | BUILD-ARG-ONLY rail: no runtime env. These stay as the OPEN escape-hatch contract (no schema enum) — the SPA reads no runtime env; VITE_* are image build args. Only set configmap here if a future runtime-config image variant introduces runtime keys. |
