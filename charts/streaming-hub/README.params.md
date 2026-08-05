# Parameters

## Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `nameOverride` | string | `""` | Override the chart name component of resource names. |
| `fullnameOverride` | string | `""` | Override the fully-qualified release name (wins verbatim). |
| `namespaceOverride` | string | `""` | Override the namespace (defaults to .Release.Namespace). |
| `global.externalPostgresDefinitions` | string | `{}` | Bootstrap Job for an external/shared PostgreSQL: creates the hub's ONE database + role and grants privileges. The hub owns a SINGLE database with a tenant_id column (NOT per-tenant DB). Default OFF — dev-st may instead point STREAMING_HUB_POSTGRES_DSN at a pre-provisioned managed host. |
| `global.externalPostgresDefinitions.enabled` | bool | `false` | Enable or disable the PostgreSQL bootstrap Job. |
| `global.externalPostgresDefinitions.database` | string | `"streaming-hub"` | Name of the database the Job creates (must match the DSN dbname). |
| `global.externalPostgresDefinitions.role` | string | `"streaming-hub"` | Name of the login role the Job creates (must match the DSN user). |
| `global.externalPostgresDefinitions.connection` | string | `{}` | PostgreSQL connection settings for the bootstrap Job. |
| `global.externalPostgresDefinitions.connection.host` | string | `"streaming-hub-postgresql"` | PostgreSQL host. |
| `global.externalPostgresDefinitions.connection.port` | string | `"5432"` | PostgreSQL port. |
| `global.externalPostgresDefinitions.postgresAdminLogin` | string | `{}` | Admin credentials used by the Job to create the DB/role. |
| `global.externalPostgresDefinitions.postgresAdminLogin.useExistingSecret.name` | string | `""` | Existing secret with DB_USER_ADMIN and DB_ADMIN_PASSWORD keys. |
| `global.externalPostgresDefinitions.postgresAdminLogin.username` | string | `"postgres"` | Admin username (ignored if useExistingSecret.name is set). |
| `global.externalPostgresDefinitions.postgresAdminLogin.password` | string | `""` | Admin password (ignored if useExistingSecret.name is set). |
| `global.externalPostgresDefinitions.hubCredentials` | string | `{}` | Credentials for the hub role created by the Job. |
| `global.externalPostgresDefinitions.hubCredentials.useExistingSecret.name` | string | `""` | Existing secret with DB_PASSWORD_HUB key. |
| `global.externalPostgresDefinitions.hubCredentials.password` | string | `""` | Password for the hub role (ignored if useExistingSecret.name is set). |
| `global.auth` | object | `{}` | Env-wide inbound auth (lib-auth / plugin-auth), consumed by lerian-common.globalValue. Declare once at the umbrella level; a component streamingHub.common.configmap.PLUGIN_AUTH_* still overrides per-service. Precedence: common.configmap.<KEY> > global.auth.<field> > chart default. Leave empty ({}) to keep the chart defaults. |
| `streamingHub.mode` | enum: all|split | `all` | Deployment topology switch. One of: all | split. all   (default) -> ONE Deployment with STREAMING_HUB_ROLE=all (ingest + delivery co-resident; the dev-st target). Byte-equivalent to the historical single binary. split           -> TWO Deployments: ingest (role=ingest) and delivery (role=delivery), each scaled independently.  !!! NEVER run both an `all` Deployment AND ingest/delivery against the same Kafka cluster: they join ONE consumer group and DOUBLE-CONSUME every event. The mode switch enforces either/or — do not work around it. !!! The values.schema.json constrains this to the enum ["all","split"]. |
| `streamingHub.image.repository` | string | `ghcr.io/lerianstudio/streaming-hub` | Container image repository. |
| `streamingHub.image.pullPolicy` | string | `IfNotPresent` | Image pull policy. |
| `streamingHub.image.tag` | string | `""` | Image tag. Empty falls back to Chart.appVersion via the defaultTag helper. |
| `streamingHub.imagePullSecrets` | list | `[{name: ghcr-credential}]` | Secrets for pulling the image from a private registry. |
| `streamingHub.revisionHistoryLimit` | int | `10` | Number of old ReplicaSets to retain for rollback. |
| `streamingHub.annotations` | object | `{}` | Annotations applied to every Deployment resource. |
| `streamingHub.podAnnotations` | object | `{}` | Annotations applied to every pod. |
| `streamingHub.deploymentStrategy` | object | `{}` | Deployment update strategy (shared by all roles). |
| `streamingHub.podSecurityContext` | object | `{}` | Pod-level security context. Empty by default (the hub needs no fsGroup). |
| `streamingHub.securityContext` | object | `{}` | Container-level security context (distroless:nonroot, uid/gid 65532). |
| `streamingHub.securityContext.runAsGroup` | int | `65532` | Group ID for the process inside the container. |
| `streamingHub.securityContext.runAsUser` | int | `65532` | User ID for the process inside the container. |
| `streamingHub.securityContext.runAsNonRoot` | bool | `true` | Never run as root. |
| `streamingHub.securityContext.readOnlyRootFilesystem` | bool | `true` | Read-only root filesystem (the image carries no writable state). |
| `streamingHub.service.type` | string | `ClusterIP` | Service type. MUST be ClusterIP (Lerian convention; Ingress fronts external). |
| `streamingHub.service.port` | int | `8080` | Control-plane HTTP port (the hub listens on :8080; see Dockerfile EXPOSE). |
| `streamingHub.service.annotations` | object | `{}` | Annotations for every Service. |
| `streamingHub.ingress.enabled` | bool | `false` | Enable or disable the control-plane Ingress (opt-in per env in gitops). |
| `streamingHub.ingress.className` | string | `"nginx"` | Ingress class name. |
| `streamingHub.ingress.annotations` | object | `{}` | Additional ingress annotations. |
| `streamingHub.ingress.hosts` | list | `[]` | Hosts (default empty; the control API is served on every role). |
| `streamingHub.ingress.tls` | list | `[]` | TLS configuration. |
| `streamingHub.serviceAccount.create` | bool | `true` | Whether a ServiceAccount is created. |
| `streamingHub.serviceAccount.annotations` | object | `{}` | Annotations for the ServiceAccount (e.g. AWS IRSA role-arn). |
| `streamingHub.serviceAccount.name` | string | `""` | ServiceAccount name. Empty defaults to the chart fullname. |
| `streamingHub.serviceAccount.automountServiceAccountToken` | bool | `false` | Mount the SA API token into pods. Default false — the hub makes no in-cluster Kubernetes API calls. (IRSA's projected token is injected by the EKS webhook independently of this, so it stays functional.) |
| `streamingHub.terminationGracePeriodSeconds` | int | `80` | Graceful-shutdown window. Defaults to the hub's derived SIGTERM drain ceiling (80s) at STREAMING_HUB_SHUTDOWN_TIMEOUT=30s + STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT=5s: 30s HTTP + 5s consumer-commit + 30s dispatcher + 10s slack = 75s, + 5s pre-stop = 80s (see .env.reference). If you tune those knobs up, recompute and keep this AT OR ABOVE the new ceiling so the orchestrator never SIGKILLs a still-draining replica. NO preStop hook is used — the hub self-drains on SIGTERM (PID 1 receives it directly; exec-form ENTRYPOINT). |
| `streamingHub.livenessProbe` | object | `{}` | Liveness probe tuning (GET /healthz on the http port; stays 200 during drain). |
| `streamingHub.readinessProbe` | object | `{}` | Readiness probe tuning (GET /readyz; flips NotReady first on SIGTERM). |
| `streamingHub.nodeSelector` | object | `{}` | Shared default scheduling (per-role blocks may override). |
| `streamingHub.telemetry.enabled` | bool | `false` | Inject the per-pod OTLP endpoint override (HOST_IP downward API). |
| `streamingHub.common` | object | `{}` | Native per-key escape hatch (highest precedence). Any UPPER_SNAKE app env var can be pinned here verbatim, overriding the grouped field + default. |
| `streamingHub.extraEnvVars` | object | `{}` | Unmodeled extra env vars appended verbatim to the ConfigMap. |
| `streamingHub.app` | object | `{}` | Application / lifecycle (STREAMING_HUB_ENV|LOG_LEVEL|HEALTH_WINDOW| SWAGGER_ENABLED|SHUTDOWN_TIMEOUT|PRE_STOP_DRAIN_TIMEOUT). |
| `streamingHub.server` | object | `{}` | HTTP server / metrics (STREAMING_HUB_HTTP_LISTEN_ADDR|METRICS_ENABLED). |
| `streamingHub.kafka` | object | `{}` | Kafka / Redpanda (brokers|scramMechanism|scramUsername|tlsEnabled|caCert). The SCRAM password is a Secret (see secrets below). |
| `streamingHub.kek` | object | `{}` | Crypto / KEK config (source|ref). The KEK material itself is a Secret. |
| `streamingHub.dispatch` | object | `{}` | Dispatch / poison worker pool (workers|claimBatch|idleIntervalMs|poisonThreshold). |
| `streamingHub.pull` | object | `{}` | Pull rate limit (rate|burst). |
| `streamingHub.dlq` | object | `{}` | DLQ visibility (group|retention|pruneInterval). |
| `streamingHub.manifest` | object | `{}` | Event manifest sources (sources|refreshInterval). |
| `streamingHub.reconciler` | object | `{}` | Reconciler / topic-drift (enabled|interval). |
| `streamingHub.partition` | object | `{}` | Partition lifecycle cron (cronInterval|futureBufferWeeks|retentionEnabled|retentionHorizon). |
| `streamingHub.idempotency` | object | `{}` | Idempotency (ttl|reapInterval). |
| `streamingHub.autodisable` | object | `{}` | Auto-disable subscriber circuit (enabled|failureWindow|failureSpread). |
| `streamingHub.multiTenant` | object | `{}` | Tenancy (F4). libEnabled=MULTI_TENANT_ENABLED (lib-commons request tenancy); the rest is the hub SaaS tenant-manager roster (STREAMING_HUB_MULTI_TENANT_*/ TENANT_MANAGER_*/TENANT_ID/ENVIRONMENT_NAME). Default = BYOC single-tenant. |
| `streamingHub.security` | object | `{}` | Security posture (allowInsecureKafka|allowInsecureDbTls|allowPrivateSinks). All fail-closed; MUST stay false in staging/production. |
| `streamingHub.aws` | object | `{}` | AWS SaaS setup metadata (hubPrincipalArn|setupTemplateUrl). |
| `streamingHub.observability` | object | `{}` | Observability (OTEL_*: libraryName|serviceName|deploymentEnvironment| exporterOtlpEndpoint|insecureExporter). OTEL_EXPORTER_OTLP_ENDPOINT is overridden per-pod when telemetry.enabled=true (downward API). |
| `streamingHub.migrations.enabled` | bool | `false` | Enable or disable the migrations Job. Default false — opt-in per env (consistent with the chart's other optional features). |
| `streamingHub.migrations.useExistingSecret` | bool | `false` | Optional. When true, the Job reads STREAMING_HUB_POSTGRES_DSN from a pre-existing Secret (existingSecretName) instead of the chart-managed migration-secret hook. Independent of streamingHub.useExistingSecret; set this to point migrations at the app's existing (e.g. Vault) Secret. |
| `streamingHub.migrations.existingSecretName` | string | `""` | Name of the pre-existing Secret holding STREAMING_HUB_POSTGRES_DSN (only used when migrations.useExistingSecret=true). |
| `streamingHub.migrations.image.repository` | string | `ghcr.io/lerianstudio/streaming-hub-migrations` | Migrations image (FROM migrate/migrate + COPY migrations/ /migrations/). |
| `streamingHub.migrations.image.tag` | string | `""` | Tag for the migrations image. Empty falls back to the app image tag (streamingHub.image.tag, or the chart appVersion). An explicit tag or digest overrides this. |
| `streamingHub.migrations.image.digest` | string | `""` | Pin by digest (sha256:...) instead of tag. Wins over tag when set. |
| `streamingHub.migrations.image.pullPolicy` | string | `IfNotPresent` | Image pull policy. |
| `streamingHub.migrations.backoffLimit` | int | `3` | Maximum retries before the Job is considered failed. |
| `streamingHub.migrations.activeDeadlineSeconds` | int | `600` | Hard wall-clock cap on the Job (seconds). |
| `streamingHub.migrations.ttlSecondsAfterFinished` | int | `600` | TTL after which a finished Job is garbage-collected (seconds). |
| `streamingHub.migrations.annotations` | object | `{}` | Extra annotations on the Job (merged after the hook annotations). |
| `streamingHub.migrations.podAnnotations` | object | `{}` | Extra annotations on the migration pod. |
| `streamingHub.migrations.resources` | object | `{}` | Resource requests/limits for the migration container. |
| `streamingHub.all.autoscaling.enabled` | bool | `false` | HPA off by default; replicaCount governs. maxReplicas × poolMaxOpenConns must respect the connection-budget invariant above. |
| `streamingHub.ingest.autoscaling.maxReplicas` | int | `4` | maxReplicas × 8 (poolMaxOpenConns) must fit the connection budget. |
| `streamingHub.delivery.autoscaling.maxReplicas` | int | `4` | maxReplicas × 16 (poolMaxOpenConns) must fit the connection budget. |

