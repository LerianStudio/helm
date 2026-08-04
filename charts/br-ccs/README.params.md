# Parameters

## Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `global.externalPostgresDefinitions` | string | `{}` | Bootstrap job for external PostgreSQL: creates databases, roles, and grants privileges |
| `global.externalPostgresDefinitions.enabled` | bool | `false` | Enable or disable the PostgreSQL bootstrap job |
| `global.externalPostgresDefinitions.connection` | string | `{}` | PostgreSQL connection settings |
| `global.externalPostgresDefinitions.connection.host` | string | `"br-ccs-postgresql-primary"` | PostgreSQL host |
| `global.externalPostgresDefinitions.connection.port` | string | `"5432"` | PostgreSQL port |
| `global.externalPostgresDefinitions.postgresAdminLogin` | string | `{}` | Admin credentials for PostgreSQL |
| `global.externalPostgresDefinitions.postgresAdminLogin.useExistingSecret.name` | string | `""` | Name of existing secret containing DB_USER_ADMIN and DB_ADMIN_PASSWORD keys |
| `global.externalPostgresDefinitions.postgresAdminLogin.username` | string | `"postgres"` | Admin username (ignored if useExistingSecret.name is set) |
| `global.externalPostgresDefinitions.postgresAdminLogin.password` | string | `""` | Admin password (ignored if useExistingSecret.name is set) |
| `global.externalPostgresDefinitions.brCcsCredentials` | string | `{}` | Credentials for the br-ccs role created by the job |
| `global.externalPostgresDefinitions.brCcsCredentials.useExistingSecret.name` | string | `""` | Name of existing secret containing DB_PASSWORD_BR_CCS key |
| `global.externalPostgresDefinitions.brCcsCredentials.password` | string | `""` | Password for the br-ccs role (ignored if useExistingSecret.name is set) |
| `global.externalRabbitmqDefinitions` | string | `{}` | Bootstrap job for external RabbitMQ: creates users, vhosts, and permissions |
| `global.externalRabbitmqDefinitions.enabled` | bool | `false` | Enable or disable the RabbitMQ bootstrap job |
| `global.externalRabbitmqDefinitions.connection` | string | `{}` | RabbitMQ connection settings |
| `global.externalRabbitmqDefinitions.connection.protocol` | string | `"http"` | RabbitMQ protocol (http or https) |
| `global.externalRabbitmqDefinitions.connection.host` | string | `"br-ccs-rabbitmq"` | RabbitMQ host (management API endpoint) |
| `global.externalRabbitmqDefinitions.connection.port` | string | `"15672"` | RabbitMQ HTTP management port |
| `global.externalRabbitmqDefinitions.connection.portAmqp` | string | `"5672"` | RabbitMQ AMQP port (for connectivity check) |
| `global.externalRabbitmqDefinitions.connection.skipTlsVerify` | bool | `false` | Skip TLS verification for self-signed certificates (not recommended for production) |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin` | string | `{}` | Admin credentials for RabbitMQ management API |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin.useExistingSecret.name` | string | `""` | Name of existing secret containing RABBITMQ_ADMIN_USER and RABBITMQ_ADMIN_PASS keys |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin.username` | string | `"admin"` | Admin username (ignored if useExistingSecret.name is set) |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin.password` | string | `""` | Admin password (ignored if useExistingSecret.name is set) |
| `global.externalRabbitmqDefinitions.brCcsCredentials` | string | `{}` | Credentials for the br-ccs user created by the job |
| `global.externalRabbitmqDefinitions.brCcsCredentials.useExistingSecret.name` | string | `""` | Name of existing secret containing RABBITMQ_BR_CCS_PASS key |
| `global.externalRabbitmqDefinitions.brCcsCredentials.password` | string | `""` | Password for the br-ccs user (ignored if useExistingSecret.name is set) |
| `global.observability` | string | `{}` | Env-wide observability, consumed by lerian-common.otel.env. Declare once at the umbrella level; a component brCcs.configmap.<KEY> still overrides per-service. Precedence: brCcs.configmap.<KEY> > global.observability.<field> > chart default. |
| `global.observability.enabled` | bool | `false` | Enable telemetry export (ENABLE_TELEMETRY). Unset → chart default "false". |
| `global.observability.otlpEndpoint` | string | `""` | OTLP collector endpoint (OTEL_EXPORTER_OTLP_ENDPOINT). Unset → chart default "". |
| `global.observability.deploymentEnvironment` | string | `"production"` | Deployment environment tag (OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT). Unset → "production". |
| `global.datastores` | object | `{}` | Env-wide datastore mask, consumed by lerian-common.datastore.value. Declare a SHARED instance once here; a DEDICATED per-service instance goes under brCcs.datastores; a component brCcs.configmap.<KEY> still overrides everything. Precedence: brCcs.configmap.<KEY> > brCcs.datastores.<type>.<field> > global.datastores.<type>.<field> > chart default. Leave empty ({}) to keep the bundled-subchart / native-key defaults. |
| `global.multiTenant` | object | `{}` | Env-wide multi-tenant infra (tenant-manager URL + its Redis), consumed by lerian-common.multiTenant.env. Declare once; a component brCcs.configmap.<KEY> still overrides. Only consulted when multi-tenancy is enabled (see brCcs.multiTenant.enabled). Leave empty ({}) for the native-key / chart defaults. |
| `global.serviceDiscovery` | object | `{}` | Env-wide service discovery (Consul), consumed by lerian-common.serviceDiscovery.env. Only used when SD is enabled (brCcs.serviceDiscovery.enabled). A component brCcs.configmap.SD_* still overrides. Leave empty ({}) for the chart defaults. |
| `global.streaming` | object | `{}` | Env-wide streaming (lib-streaming → Kafka), consumed by lerian-common.streaming.env. Only used when streaming is enabled (brCcs.streaming.enabled). SASL/broker contract; STREAMING_SASL_PASSWORD is a secret. Leave empty ({}) for the chart defaults. |
| `brCcs.readinessProbe` | object | `{}` | Readiness probe configuration. All fields override chart defaults. |
| `brCcs.livenessProbe` | object | `{}` | Liveness probe configuration. All fields override chart defaults. |
| `brCcs.multiTenant` | string | `{}` | Multi-tenancy toggle (grouped API for MULTI_TENANT_ENABLED). The tenant-manager URL + Redis infra come from global.multiTenant (or brCcs.configmap.MULTI_TENANT_*). Precedence for the toggle: brCcs.configmap.MULTI_TENANT_ENABLED > brCcs.multiTenant.enabled > "false". |
| `brCcs.multiTenant.enabled` | bool | `false` | Enable multi-tenancy (MULTI_TENANT_ENABLED) |
| `brCcs.datastores` | object | `{}` | Dedicated datastore mask for THIS service (see global.datastores for the shared form + precedence). Same fields as global.datastores; wins over global, loses to brCcs.configmap.<KEY>. Leave empty ({}) to keep the bundled-subchart / native defaults. |
| `brCcs.serviceDiscovery` | string | `{}` | Service discovery toggle (grouped API for SD_ENABLED). Infra comes from global.serviceDiscovery (or brCcs.configmap.SD_*). SD_TOKEN (ACL) is a secret. |
| `brCcs.serviceDiscovery.enabled` | bool | `false` | Enable Consul service discovery (SD_ENABLED) |
| `brCcs.streaming` | string | `{}` | Streaming toggle (grouped API for STREAMING_ENABLED). Broker/SASL infra comes from global.streaming (or brCcs.configmap.STREAMING_*). SASL password is a secret. |
| `brCcs.streaming.enabled` | bool | `false` | Enable lib-streaming (STREAMING_ENABLED) |
| `brCcs.name` | string | `br-ccs` | Service name |
| `brCcs.enabled` | bool | `true` | Enable or disable the br-ccs service |
| `brCcs.replicaCount` | int | `2` | Number of replicas for the br-ccs service |
| `brCcs.revisionHistoryLimit` | int | `10` | Number of old ReplicaSets to retain for deployment rollback |
| `brCcs.image.repository` | string | `ghcr.io/lerianstudio/br-ccs` | Repository for the br-ccs service container image |
| `brCcs.image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `brCcs.image.tag` | string | `"1.0.0"` | Image tag used for deployment |
| `brCcs.migrations` | string | `{}` | PostgreSQL migrations job (Helm hook; ArgoCD PreSync for external PG, PostSync for the bundled subchart). Runs the dedicated br-ccs-migrations image (golang-migrate runner; the app image never migrates). The chart-managed Secret is rendered as an earlier hook so it exists before the migration hook — migrations run against the chart-managed Secret with NO pre-existing Secret required. Set useExistingSecret only to read POSTGRES_PASSWORD from an operator-provisioned Secret instead. |
| `brCcs.migrations.enabled` | bool | `true` | Enable or disable the migrations job. |
| `brCcs.migrations.useExistingSecret` | bool | `false` | Optional. When true, migrations read POSTGRES_PASSWORD from a pre-existing Secret (existingSecretName) instead of the chart-managed Secret hook. |
| `brCcs.migrations.existingSecretName` | string | `""` | Name of the pre-existing Secret containing POSTGRES_PASSWORD (only used when useExistingSecret=true). |
| `brCcs.migrations.path` | string | `"/migrations"` | MIGRATIONS_PATH inside the migrations image (embedded at /migrations). |
| `brCcs.migrations.image.repository` | string | `ghcr.io/lerianstudio/br-ccs-migrations` | Repository for the migrations runner image |
| `brCcs.migrations.image.tag` | string | `""` | Tag for the migrations image. Defaults to the app image tag (brCcs.image.tag, or the chart appVersion) when left empty. |
| `brCcs.migrations.image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `brCcs.migrations.backoffLimit` | int | `3` | Maximum number of retries before the Job is considered failed |
| `brCcs.imagePullSecrets` | list | `[]` | Secrets for pulling images from a private registry |
| `brCcs.nameOverride` | string | `""` | Overrides the default generated name by Helm |
| `brCcs.fullnameOverride` | string | `""` | Overrides the full name generated by Helm |
| `brCcs.podAnnotations` | object | `{}` | Pod annotations for additional metadata |
| `brCcs.securityContext.runAsGroup` | int | `1000` | Defines the group ID for the user running the process inside the container |
| `brCcs.securityContext.runAsUser` | int | `1000` | Defines the user ID for the process running inside the container |
| `brCcs.securityContext.runAsNonRoot` | bool | `true` | Ensures the process does not run as root |
| `brCcs.securityContext.readOnlyRootFilesystem` | bool | `true` | Defines the root filesystem as read-only |
| `brCcs.pdb` | string | `{}` | PodDisruptionBudget configuration |
| `brCcs.pdb.enabled` | bool | `true` | Enable or disable PodDisruptionBudget |
| `brCcs.pdb.minAvailable` | int | `1` | Minimum number of available pods |
| `brCcs.pdb.maxUnavailable` | int | `1` | Maximum number of unavailable pods |
| `brCcs.pdb.annotations` | object | `{}` | Annotations for the PodDisruptionBudget |
| `brCcs.deploymentUpdate` | string | `{}` | Deployment update strategy |
| `brCcs.deploymentUpdate.type` | string | `RollingUpdate` | Type of deployment strategy |
| `brCcs.deploymentUpdate.maxSurge` | string | `100%` | Maximum number of pods that can be created over the desired number of pods |
| `brCcs.deploymentUpdate.maxUnavailable` | int | `0` | Maximum number of pods that can be unavailable during the update |
| `brCcs.service.type` | string | `ClusterIP` | Kubernetes service type |
| `brCcs.service.port` | int | `4030` | Port for the HTTP API |
| `brCcs.ingress.enabled` | bool | `false` | Enable or disable ingress |
| `brCcs.ingress.className` | string | `""` | Ingress class name |
| `brCcs.ingress.annotations` | object | `{}` | Additional ingress annotations |
| `brCcs.ingress.tls` | list | `[]` | TLS configuration for ingress |
| `brCcs.resources.limits` | string | `{}` | CPU and memory limits for pods |
| `brCcs.resources.requests` | string | `{}` | Minimum CPU and memory requests |
| `brCcs.autoscaling.enabled` | bool | `true` | Enable or disable horizontal pod autoscaling |
| `brCcs.autoscaling.minReplicas` | int | `2` | Minimum number of replicas |
| `brCcs.autoscaling.maxReplicas` | int | `5` | Maximum number of replicas |
| `brCcs.autoscaling.targetCPUUtilizationPercentage` | int | `80` | Target CPU utilization percentage for autoscaling |
| `brCcs.nodeSelector` | object | `{}` | Node selector for scheduling pods on specific nodes |
| `brCcs.tolerations` | list | `[]` | Tolerations for scheduling on tainted nodes |
| `brCcs.affinity` | object | `{}` | Affinity rules for pod scheduling |
| `brCcs.hostAliases` | list | `[]` | Host aliases for custom DNS resolution inside the pod |
| `brCcs.configmap` | object | `templates/configmap.yaml` | Raw ConfigMap env-var escape hatch. The clean, grouped API lives in the brCcs.<group> blocks below (server, cors, postgres, redis, broker, outbox, fetcher, sta, reporter, swagger, rateLimit, pagination, observability, m2m, readiness, shutdown, objectStorage) — each key resolves via cfgValue: brCcs.configmap.<NATIVE_KEY> (here) > brCcs.<group>.<field> > chart default. Set a raw NATIVE_KEY here only to override a value not exposed as a grouped field, or to pass an optional/opt-in key (e.g. SERVER_TLS_CERT_FILE, RABBITMQ_QUEUE, FETCHER_URL, *_OAUTH2_*, CCS_DETAIL_*). Defaults live in the template, so leaving this {} renders the documented defaults. |
| `brCcs.app` | object | `{}` | Application identity: name / env / version / logLevel / deploymentMode / runMode |
| `brCcs.server` | object | `{}` | HTTP server: address / port / grpcPort / bodyLimitBytes / tlsTerminatedUpstream / trustedProxies |
| `brCcs.cors` | object | `{}` | CORS: allowedOrigins / allowedMethods / allowedHeaders / exposeHeaders / allowCredentials |
| `brCcs.postgres` | object | `{}` | PostgreSQL tuning (host/port/user/ssl come from datastores): name / migrationsPath / systemplaneEnabled / maxOpenConns / maxIdleConns / connMaxLifetimeMins / connMaxIdleTimeMins / connectTimeoutSec / infraConnectTimeoutSec |
| `brCcs.redis` | object | `{}` | Redis tuning (host from datastores): db / protocol / poolSize / minIdleConns / readTimeout / writeTimeout / dialTimeout / poolTimeout / maxRetries / minRetryBackoff / maxRetryBackoff |
| `brCcs.broker` | object | `{}` | RabbitMQ (host/port/user from datastores): enabled / circuitBreakerEnabled / portHost / vhost / exchange / requireHealthAllowedHosts / allowInsecureHealthCheck / allowInsecureTls / publisherConfirmTimeoutMs / publisherRecoveryInitialMs / publisherRecoveryMaxMs / publisherMaxRecoveries / staDlqTtlSeconds |
| `brCcs.outbox` | object | `{}` | Outbox: enabled / tableName / dispatchIntervalSec / batchSize / publishMaxAttempts / publishBackoffMs / retryWindowSec / maxDispatchAttempts / processingTimeoutSec / maxFailedPerBatch / includeTenantMetrics / allowEmptyTenant |
| `brCcs.fetcher` | object | `{}` | Fetcher integration: enabled / httpTimeoutSec / ccsOutboxDispatchIntervalMs / ccsOutboxBatchSize / ccsOutboxMaxAttempts / ccsOutboxDlqRoutingKey |
| `brCcs.sta` | object | `{}` | STA integration: enabled / httpTimeoutSec |
| `brCcs.reporter` | object | `{}` | Reporter integration: enabled / httpTimeoutSec |
| `brCcs.swagger` | object | `{}` | Swagger: enabled / title / version / basePath / leftDelim / rightDelim |
| `brCcs.rateLimit` | object | `{}` | Rate limiting: enabled / max / windowSec / aggressiveMax / aggressiveWindowSec / relaxedMax / relaxedWindowSec / exportMax / exportWindowSec / dispatchMax / dispatchWindowSec / allowFailOpen |
| `brCcs.pagination` | object | `{}` | Pagination: limit / monthDateRange |
| `brCcs.observability` | object | `{}` | Observability: dbMetricsIntervalSec / idempotencyRetryWindowSec |
| `brCcs.m2m` | object | `{}` | M2M (non-secret): credentialCacheTtlSec / awsRegion |
| `brCcs.readiness` | object | `{}` | Readiness / startup probes: probeTimeoutSec / depSlowThresholdMs / startupMaxDurationSec / startupInitialDelayMs / startupMaxDelayMs |
| `brCcs.shutdown` | object | `{}` | Graceful shutdown: drainGracePeriodSec / totalTimeoutSec |
| `brCcs.objectStorage` | string | `{}` | Object storage (non-secret): seaweedfsS3Port / seaweedfsMasterPort / {sta,ccs,fetcher}{Endpoint, Region,Bucket,UsePathStyle,DisableSsl} / outboundRetentionDays / accs009RetentionDays |
| `brCcs.secrets` | string | `templates/secrets.yaml` | Secrets for storing sensitive data. Provide real values via an existing Secret (useExistingSecret) or a secrets manager — NEVER commit real values. |
| `brCcs.useExistingSecret` | bool | `false` | Existing secrets name |
| `brCcs.extraEnvVars` | object | `{}` | Extra environment variables (map of key: value pairs) — escape hatch for optional knobs not modeled above (e.g. RELATIONSHIP_SOURCE_*, CCS_REPORTER_POLL_*). |
| `brCcs.serviceAccount.create` | bool | `true` | Specifies whether a ServiceAccount should be created |
| `brCcs.serviceAccount.annotations` | object | `{}` | Annotations for the ServiceAccount |
| `brCcs.serviceAccount.name` | string | ``br-ccs.fullname`` | Name of the service account |

