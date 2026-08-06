# Parameters

## Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `nameOverride` | string | `"br-sta"` | Override the chart top-level name |
| `fullnameOverride` | string | `""` | Override the fully generated name |
| `namespaceOverride` | string | `""` | Override the namespace used by templates |
| `global.externalPostgresDefinitions` | string | `{}` | Bootstrap job for external PostgreSQL: creates database and role |
| `global.externalPostgresDefinitions.enabled` | bool | `false` | Enable or disable the PostgreSQL bootstrap job |
| `global.externalPostgresDefinitions.connection` | string | `{}` | PostgreSQL connection settings (used by the bootstrap job only) |
| `global.externalPostgresDefinitions.connection.host` | string | `"br-sta-postgresql-primary"` | PostgreSQL host |
| `global.externalPostgresDefinitions.connection.port` | string | `"5432"` | PostgreSQL port |
| `global.externalPostgresDefinitions.postgresAdminLogin` | string | `{}` | Admin (superuser) credentials used to create the application DB and role |
| `global.externalPostgresDefinitions.postgresAdminLogin.useExistingSecret.name` | string | `""` | Name of existing secret containing DB_USER_ADMIN and DB_ADMIN_PASSWORD keys |
| `global.externalPostgresDefinitions.postgresAdminLogin.username` | string | `"postgres"` | Admin username (ignored if useExistingSecret.name is set) |
| `global.externalPostgresDefinitions.postgresAdminLogin.password` | string | `""` | Admin password (ignored if useExistingSecret.name is set) |
| `global.externalPostgresDefinitions.appCredentials` | string | `{}` | Credentials for the br_sta role created by the job |
| `global.externalPostgresDefinitions.appCredentials.useExistingSecret.name` | string | `""` | Name of existing secret containing DB_PASSWORD_BR_STA key |
| `global.externalPostgresDefinitions.appCredentials.password` | string | `""` | Password for br_sta role (ignored if useExistingSecret.name is set) |
| `global.observability` | string | `{}` | Env-wide observability, consumed by lerian-common.otel.env. Declare once at the umbrella level; a component configmap.<KEY> still overrides per-service. Precedence: brSta.configmap.<KEY> > global.observability.<field> > chart default. |
| `global.observability.enabled` | bool | `false` | Enable telemetry export (ENABLE_TELEMETRY). Unset → chart default "false". |
| `global.observability.otlpEndpoint` | string | `""` | OTLP collector endpoint (OTEL_EXPORTER_OTLP_ENDPOINT). Unset → chart default "". |
| `global.observability.deploymentEnvironment` | string | `"production"` | Deployment environment tag (OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT). Unset → "production". |
| `global.multiTenant` | object | `{}` | Env-wide multi-tenant infra (tenant-manager URL + its Redis), consumed by lerian-common.multiTenant.env. Only used when MT is enabled (see brSta.multiTenant.enabled). A component configmap.<KEY> still overrides. |
| `global.datastores` | object | `{}` | Env-wide datastore mask, consumed by lerian-common.datastore.value. Declare a SHARED instance once here; a DEDICATED per-service instance goes under brSta.datastores; a component configmap.<KEY> still overrides everything. Precedence: brSta.configmap.<KEY> > brSta.datastores.<type>.<field> > global.datastores.<type>.<field> > chart default. |
| `global.serviceDiscovery` | object | `{}` | Env-wide service discovery (Consul), consumed by lerian-common.serviceDiscovery.env. Only used when SD is enabled (brSta.serviceDiscovery.enabled). Leave {} for defaults. |
| `global.streaming` | object | `{}` | Env-wide streaming (lib-streaming → Kafka), consumed by lerian-common.streaming.env. Only used when streaming is enabled (brSta.streaming.enabled). Leave {} for defaults. |
| `global.auth` | object | `{}` | Env-wide inbound auth (access-manager), consumed by lerian-common.globalValue for PLUGIN_AUTH_ENABLED / PLUGIN_AUTH_HOST. A component configmap.<KEY> still overrides. Precedence: brSta.configmap.PLUGIN_AUTH_* > global.auth.<field> > chart default. |
| `brSta.multiTenant` | string | `{}` | Multi-tenancy toggle (grouped API for MULTI_TENANT_ENABLED). Tenant-manager URL + Redis infra come from global.multiTenant (or configmap.MULTI_TENANT_*). Precedence: configmap.MULTI_TENANT_ENABLED > brSta.multiTenant.enabled > "false". |
| `brSta.multiTenant.enabled` | bool | `false` | Enable multi-tenancy (MULTI_TENANT_ENABLED) |
| `brSta.datastores` | object | `{}` | Dedicated datastore mask for THIS service (see global.datastores for the shared form + precedence). Same fields as global.datastores; wins over global, loses to configmap.<KEY>. Leave empty ({}) to keep the bundled-subchart / native defaults. |
| `brSta.name` | string | `"br-sta"` | Service name |
| `brSta.replicaCount` | int | `2` | Number of replicas |
| `brSta.revisionHistoryLimit` | int | `10` | Number of old ReplicaSets to retain for rollback |
| `brSta.annotations` | object | `{}` | Annotations applied to the Deployment resource |
| `brSta.podAnnotations` | object | `{}` | Annotations applied to the pods |
| `brSta.image.repository` | string | `ghcr.io/lerianstudio/br-sta` | Repository for the br-sta image |
| `brSta.image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `brSta.image.tag` | string | `""` | Image tag (defaults to Chart.appVersion if empty) |
| `brSta.imagePullSecrets` | list | `[]` | Image pull secrets for private registries |
| `brSta.migrations` | string | `{}` | Database migrations Job (init/postgres-migrations runner image). Applies the SQL migrations once as an Argo hook — PreSync for external Postgres (schema-first, before the app rolls out) or PostSync for the bundled subchart (after the DB is provisioned) — so schema changes are applied by a dedicated process rather than at application runtime. Disabled by default; enable per-environment (e.g. the dev-st gitops values). |
| `brSta.migrations.enabled` | bool | `false` | Enable or disable the migrations Job. |
| `brSta.migrations.useExistingSecret` | bool | `false` | When true, read POSTGRES_PASSWORD from a pre-existing Secret (existingSecretName) instead of the chart-managed app Secret. |
| `brSta.migrations.existingSecretName` | string | `""` | Name of the pre-existing Secret containing POSTGRES_PASSWORD (only used when useExistingSecret=true). |
| `brSta.migrations.image.repository` | string | `ghcr.io/lerianstudio/br-sta-migrations` | Repository for the migrations runner image. |
| `brSta.migrations.image.tag` | string | `""` | Tag for the migrations image. Defaults to the app image tag (brSta.image.tag, or the chart appVersion) when left empty. |
| `brSta.migrations.image.digest` | string | `""` | Optional image digest (overrides tag when set). |
| `brSta.migrations.image.pullPolicy` | string | `IfNotPresent` | Image pull policy. |
| `brSta.migrations.path` | string | `"/migrations"` | Path inside the image where the SQL migrations live. |
| `brSta.migrations.allowInsecureTLS` | string | `""` | Bypass the lib-commons migrator TLS guard for a non-TLS Postgres (POSTGRES_SSLMODE=disable is rejected without it). When empty, inherits ALLOW_INSECURE_TLS from brSta.extraEnvVars, then brSta.configmap. Leave empty for a TLS-enabled Postgres. |
| `brSta.migrations.backoffLimit` | int | `3` | Maximum retries before the Job is considered failed. |
| `brSta.migrations.activeDeadlineSeconds` | int | `600` | Hard wall-clock cap for the Job (seconds). |
| `brSta.migrations.ttlSecondsAfterFinished` | int | `600` | Seconds to retain the finished Job before garbage collection. |
| `brSta.migrations.timeoutSeconds` | string | `""` | Optional MIGRATIONS_TIMEOUT_SEC passed to the runner (per-run deadline). |
| `brSta.migrations.resources` | string | `{}` | Resource requests/limits for the migrations container. |
| `brSta.migrations.annotations` | object | `{}` | Extra annotations on the Job resource. |
| `brSta.migrations.podAnnotations` | object | `{}` | Extra annotations on the migration pod. |
| `brSta.nameOverride` | string | `""` | Override of the resource name |
| `brSta.fullnameOverride` | string | `""` | Override of the fully qualified resource name |
| `brSta.terminationGracePeriodSeconds` | int | `60` | Termination grace period. |
| `brSta.podSecurityContext` | object | `{}` | Pod security context |
| `brSta.securityContext` | string | `{}` | Container security context (Distroless nonroot UID/GID is 65532) |
| `brSta.pdb` | string | `{}` | PodDisruptionBudget configuration |
| `brSta.deploymentStrategy` | string | `{}` | Deployment strategy |
| `brSta.service` | string | `{}` | Service configuration |
| `brSta.ingress` | string | `{}` | Ingress configuration |
| `brSta.resources` | string | `{}` | Resource requests and limits |
| `brSta.autoscaling` | string | `{}` | HorizontalPodAutoscaler configuration |
| `brSta.readinessProbe` | string | `{}` | Readiness probe configuration |
| `brSta.livenessProbe` | string | `{}` | Liveness probe configuration |
| `brSta.nodeSelector` | object | `{}` | Node selector for scheduling pods on specific nodes |
| `brSta.tolerations` | list | `[]` | Tolerations for scheduling on tainted nodes |
| `brSta.affinity` | object | `{}` | Affinity rules for pod scheduling |
| `brSta.hostAliases` | list | `[]` | Host aliases for custom DNS resolution inside the pod |
| `brSta.configmap` | object | `templates/configmap.yaml` | Primary override surface: raw ConfigMap env-var passthrough. Every non-dependency app key defaults in templates/configmap.yaml; set brSta.configmap.<NATIVE_KEY> here to override a default or pass an opt-in key (e.g. AUDIT_PUBLISHER_INTERVAL_SEC). Dependency connections are the ONLY typed knobs — Postgres/Redis/RabbitMQ HOST/PORT/ USER/SSL via the datastores mask; MULTI_TENANT/OTEL/streaming/SD via the global.* blocks; PLUGIN_AUTH via global.auth. Precedence: configmap.<KEY> > mask/global > default. |
| `brSta.serviceDiscovery` | string | `{}` | Service discovery toggle (grouped API for SD_ENABLED). SD_TOKEN (ACL) is a Secret. |
| `brSta.streaming` | string | `{}` | Streaming toggle (grouped API for STREAMING_ENABLED). SASL password is a Secret. |
| `brSta.secrets` | string | `templates/secrets.yaml` | Secrets (sensitive environment variables) |
| `brSta.useExistingSecret` | bool | `false` | Use an externally managed Secret instead of generating one |
| `brSta.existingSecretName` | string | `""` | Name of the externally managed Secret |
| `brSta.extraEnvVars` | object | `{}` | Extra environment variables (map of key:value pairs) |
| `brSta.serviceAccount` | string | `{}` | ServiceAccount configuration |
| `worker.enabled` | bool | `false` | Enable the worker Deployment. REQUIRES worker.image to point at a dedicated worker image (built from cmd/worker) — keep this false until that image is confirmed available, then enable per-deployment. |
| `worker.replicaCount` | int | `1` | Replicas. The background jobs are leader-gated but the worker does NOT run its own leader election yet — keep this at 1 (and do not add an HPA) to avoid duplicate processing. |
| `worker.revisionHistoryLimit` | int | `10` | Number of old ReplicaSets to retain for rollback |
| `worker.annotations` | object | `{}` | Annotations applied to the Deployment resource |
| `worker.podAnnotations` | object | `{}` | Annotations applied to the pods |
| `worker.image` | string | `{}` | Worker image. REQUIRED: point at the dedicated worker image (built from cmd/worker). Empty repository/tag fall back to the manager image, which does NOT run the worker's logic — only set for local testing. |
| `worker.imagePullSecrets` | list | `[]` | Image pull secrets (empty inherits the manager's) |
| `worker.command` | string | `{}` | Container command. The worker image's own ENTRYPOINT already runs the correct binary (/service, built from cmd/worker) — this override matches that ENTRYPOINT rather than replacing it with a different binary name. |
| `worker.terminationGracePeriodSeconds` | int | `60` | Termination grace period |
| `worker.podSecurityContext` | object | `{}` | Pod security context |
| `worker.securityContext` | object | `{}` | Container security context (empty inherits the manager's) |
| `worker.serviceAccount` | string | `{}` | ServiceAccount configuration |
| `worker.service` | string | `{}` | Probe server port. WorkerMode binds SERVER_ADDRESS here; no Service or Ingress is created for the worker. |
| `worker.resources` | string | `{}` | Resource requests and limits |
| `worker.deploymentStrategy` | string | `{}` | Deployment strategy. Recreate by default: the worker is leader-gated but runs no leader election, so a RollingUpdate surge would briefly run two worker pods and duplicate background processing (audit drain, scheduler). |
| `worker.readinessProbe` | string | `{}` | Readiness probe configuration |
| `worker.livenessProbe` | string | `{}` | Liveness probe configuration |
| `worker.nodeSelector` | object | `{}` | Node selector for scheduling pods on specific nodes |
| `worker.tolerations` | list | `[]` | Tolerations for scheduling on tainted nodes |
| `worker.affinity` | object | `{}` | Affinity rules for pod scheduling |
| `worker.hostAliases` | list | `[]` | Host aliases for custom DNS resolution inside the pod |
| `worker.configmap` | string | `templates/worker/configmap.yaml` | Worker-only environment (layered on top of the manager ConfigMap/Secret). SetConfigFromEnvVars ignores envDefault, so every knob a background job needs must be set explicitly. SERVER_ADDRESS is derived from service.port. |
| `worker.extraEnvVars` | object | `{}` | Extra environment variables (map of key:value pairs) rendered as inline container env (wins over both ConfigMaps). |

