# Parameters

## Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `global.externalRabbitmqDefinitions` | string | `{}` | Bootstrap job for external RabbitMQ: creates users, vhosts, and permissions |
| `global.externalRabbitmqDefinitions.enabled` | bool | `false` | Enable or disable the RabbitMQ bootstrap job |
| `global.externalRabbitmqDefinitions.connection` | string | `{}` | RabbitMQ connection settings |
| `global.externalRabbitmqDefinitions.connection.protocol` | string | `"http"` | RabbitMQ protocol (http or https) |
| `global.externalRabbitmqDefinitions.connection.host` | string | `"midaz-rabbitmq"` | RabbitMQ host (management API endpoint) |
| `global.externalRabbitmqDefinitions.connection.port` | string | `"15672"` | RabbitMQ HTTP management port |
| `global.externalRabbitmqDefinitions.connection.portAmqp` | string | `"5672"` | RabbitMQ AMQP port (for connectivity check) |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin` | string | `{}` | Admin credentials for RabbitMQ management API |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin.useExistingSecret.name` | string | `""` | Name of existing secret containing RABBITMQ_ADMIN_USER and RABBITMQ_ADMIN_PASS keys |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin.username` | string | `"midaz"` | Admin username (ignored if useExistingSecret.name is set) |
| `global.externalRabbitmqDefinitions.rabbitmqAdminLogin.password` | string | `""` | Admin password (ignored if useExistingSecret.name is set) |
| `global.externalRabbitmqDefinitions.appCredentials` | string | `{}` | Credentials for application users created by the job |
| `global.externalRabbitmqDefinitions.appCredentials.useExistingSecret.name` | string | `""` | Name of existing secret containing RABBITMQ_DEFAULT_PASS and RABBITMQ_CONSUMER_PASS keys |
| `global.externalRabbitmqDefinitions.appCredentials.transactionPassword` | string | `""` | Password for transaction user (ignored if useExistingSecret.name is set) |
| `global.externalRabbitmqDefinitions.appCredentials.consumerPassword` | string | `""` | Password for consumer user (ignored if useExistingSecret.name is set) |
| `global.externalPostgresDefinitions` | string | `{}` | Bootstrap job for external PostgreSQL: creates databases, roles, and grants privileges |
| `global.externalPostgresDefinitions.enabled` | bool | `false` | Enable or disable the PostgreSQL bootstrap job |
| `global.externalPostgresDefinitions.connection` | string | `{}` | PostgreSQL connection settings |
| `global.externalPostgresDefinitions.connection.host` | string | `"midaz-postgresql-primary"` | PostgreSQL host |
| `global.externalPostgresDefinitions.connection.port` | string | `"5432"` | PostgreSQL port |
| `global.externalPostgresDefinitions.postgresAdminLogin` | string | `{}` | Admin credentials for PostgreSQL |
| `global.externalPostgresDefinitions.postgresAdminLogin.useExistingSecret.name` | string | `""` | Name of existing secret containing DB_USER_ADMIN and DB_ADMIN_PASSWORD keys |
| `global.externalPostgresDefinitions.postgresAdminLogin.username` | string | `"postgres"` | Admin username (ignored if useExistingSecret.name is set) |
| `global.externalPostgresDefinitions.postgresAdminLogin.password` | string | `""` | Admin password (ignored if useExistingSecret.name is set) |
| `global.externalPostgresDefinitions.midazCredentials` | string | `{}` | Credentials for midaz role created by the job |
| `global.externalPostgresDefinitions.midazCredentials.useExistingSecret.name` | string | `""` | Name of existing secret containing DB_PASSWORD_MIDAZ key |
| `global.externalPostgresDefinitions.midazCredentials.password` | string | `""` | Password for midaz role (ignored if useExistingSecret.name is set) |
| `global.externalMongoDefinitions` | string | `{}` | Bootstrap job for external MongoDB: creates users and grants privileges |
| `global.externalMongoDefinitions.enabled` | bool | `false` | Enable or disable the MongoDB bootstrap job |
| `global.externalMongoDefinitions.connection` | string | `{}` | MongoDB connection settings |
| `global.externalMongoDefinitions.connection.host` | string | `"midaz-mongodb"` | MongoDB host |
| `global.externalMongoDefinitions.connection.port` | string | `"27017"` | MongoDB port |
| `global.externalMongoDefinitions.mongoAdminLogin` | string | `{}` | Admin credentials for MongoDB (rootUser from bitnami subchart) |
| `global.externalMongoDefinitions.mongoAdminLogin.useExistingSecret.name` | string | `""` | Name of existing secret containing MONGO_ROOT_USER and MONGO_ROOT_PASSWORD keys |
| `global.externalMongoDefinitions.mongoAdminLogin.username` | string | `"midaz"` | Admin username (ignored if useExistingSecret.name is set) |
| `global.externalMongoDefinitions.mongoAdminLogin.password` | string | `""` | Admin password (ignored if useExistingSecret.name is set) |
| `global.externalMongoDefinitions.midazCredentials` | string | `{}` | Credentials for midaz user created by the job |
| `global.externalMongoDefinitions.midazCredentials.useExistingSecret.name` | string | `""` | Name of existing secret containing MONGO_APP_USER and MONGO_APP_PASSWORD keys |
| `global.externalMongoDefinitions.midazCredentials.username` | string | `"midaz"` | App username (ignored if useExistingSecret.name is set) |
| `global.externalMongoDefinitions.midazCredentials.password` | string | `""` | Password for midaz user (ignored if useExistingSecret.name is set) |
| `global.externalMongoDefinitions.midazCredentials.roles` | string | `{}` | List of roles to grant to the user. Each item is a {role, db} pair. |
| `global.datastores` | object | `{}` | Shared datastore masks. Keys: postgresOnboarding / postgresTransaction / mongoOnboarding / mongoTransaction / mongoCrm / mongoFees / mongo / redis / broker. Each accepts host/port/user/ssl/replicaHost. |
| `global.observability` | object | `{}` | Env-wide observability (OTel collector): enabled / otlpEndpoint / deploymentEnvironment. |
| `global.multiTenant` | object | `{}` | Env-wide multi-tenant (tenant-manager): url / redisHost / redisPort / redisTls / ... |
| `global.streaming` | object | `{}` | Env-wide streaming (lib-streaming / RedPanda): brokers / saslMechanism / saslUsername / tlsEnabled / ... |
| `global.auth` | object | `{}` | Env-wide auth (plugin-access-manager): enabled / host. |
| `global.serviceDiscovery` | object | `{}` | Env-wide service discovery (Consul): see lerian-common.serviceDiscovery.env. |
| `ledger.readinessProbe` | object | `{}` | Readiness probe configuration. All fields override chart defaults. |
| `ledger.livenessProbe` | object | `{}` | Liveness probe configuration. All fields override chart defaults. |
| `ledger.name` | string | `ledger` | Service name |
| `ledger.enabled` | bool | `true` | NOTE: migration.allowAllServices is not in the public values.yaml - set it in your override values for internal testing |
| `ledger.replicaCount` | int | `2` | Number of replicas for the ledger service |
| `ledger.revisionHistoryLimit` | int | `10` | Number of old ReplicaSets to retain for deployment rollback |
| `ledger.image.repository` | string | `lerianstudio/midaz-ledger` | Repository for the ledger service container image |
| `ledger.image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `ledger.image.tag` | string | `"4.0.0-beta.26"` | Image tag used for deployment |
| `ledger.migrations` | string | `{}` | Dedicated migration runner (`midaz-ledger-migrations`, built FROM migrate/migrate) applying the onboarding and transaction migration sets. |
| `ledger.migrations.enabled` | string | `{}` | Run the migration Job. Unset means auto: on for 4.x ledger tags, which removed in-process migration, off for 3.x, which still migrates at startup. Set false to keep it off when the schema is applied out-of-band. |
| `ledger.migrations.image.repository` | string | `lerianstudio/midaz-ledger-migrations` | Repository for the ledger migration-runner image |
| `ledger.migrations.image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `ledger.migrations.image.tag` | string | `""` | Migration image tag. Empty tracks `ledger.image.tag` so the schema and the binary reading it cannot drift. |
| `ledger.migrations.annotations` | object | `{}` | Extra Job annotations. The Job is a plain Sync-phase resource by default because the bundled PostgreSQL Secret it reads is only created during Sync; against a pre-provisioned database, set `argocd.argoproj.io/hook: PreSync` here to order it ahead of the Deployment. |
| `ledger.migrations.deploymentSyncWave` | string | `"1"` | Argo CD sync wave stamped on the ledger Deployment while this Job renders, so the Deployment is applied only once the Job reports Complete (the Job itself stays in the default wave, with the bundled PostgreSQL Secret it reads). Set to "" to drop the annotation and let both apply together. Ignored by plain `helm install`. |
| `ledger.migrations.backoffLimit` | int | `6` | Retries before the Job is marked failed |
| `ledger.migrations.activeDeadlineSeconds` | int | `600` | Hard timeout for the whole Job |
| `ledger.migrations.ttlSecondsAfterFinished` | int | `259200` | How long the finished Job is kept for inspection |
| `ledger.migrations.waitForPostgres` | string | `{}` | Wait for the PostgreSQL endpoint before running migrate |
| `ledger.migrations.waitForPostgres.enabled` | bool | `true` | Enable or disable the wait-for-postgres init container |
| `ledger.migrations.waitForPostgres.image.repository` | string | `busybox` | Repository for the wait-for-postgres init container image |
| `ledger.migrations.waitForPostgres.image.tag` | string | `"1.37"` | Image tag for the wait-for-postgres init container image |
| `ledger.migrations.resources.limits` | string | `{}` | CPU and memory limits for the migration Job |
| `ledger.migrations.resources.requests` | string | `{}` | Minimum CPU and memory requests for the migration Job |
| `ledger.imagePullSecrets` | list | `[]` | Secrets for pulling images from a private registry |
| `ledger.nameOverride` | string | `""` | Overrides the default generated name by Helm |
| `ledger.fullnameOverride` | string | `""` | Overrides the full name generated by Helm |
| `ledger.podAnnotations` | object | `{}` | Pod annotations for additional metadata |
| `ledger.securityContext.runAsGroup` | int | `1000` | Defines the group ID for the user running the process inside the container |
| `ledger.securityContext.runAsUser` | int | `1000` | Defines the user ID for the process running inside the container |
| `ledger.securityContext.runAsNonRoot` | bool | `true` | Ensures the process does not run as root |
| `ledger.securityContext.readOnlyRootFilesystem` | bool | `true` | Defines the root filesystem as read-only |
| `ledger.pdb` | string | `{}` | PodDisruptionBudget configuration |
| `ledger.pdb.enabled` | bool | `true` | Enable or disable PodDisruptionBudget |
| `ledger.pdb.minAvailable` | int | `1` | Minimum number of available pods |
| `ledger.pdb.maxUnavailable` | int | `1` | Maximum number of unavailable pods |
| `ledger.pdb.annotations` | object | `{}` | Annotations for the PodDisruptionBudget |
| `ledger.deploymentUpdate` | string | `{}` | Deployment update strategy |
| `ledger.deploymentUpdate.type` | string | `RollingUpdate` | Type of deployment strategy |
| `ledger.deploymentUpdate.maxSurge` | string | `100%` | Maximum number of pods that can be created over the desired number of pods |
| `ledger.deploymentUpdate.maxUnavailable` | int | `0` | Maximum number of pods that can be unavailable during the update |
| `ledger.service.type` | string | `ClusterIP` | Kubernetes service type |
| `ledger.service.port` | int | `3002` | Port for the HTTP API (all APIs on single port) |
| `ledger.ingress.enabled` | bool | `false` | Enable or disable ingress |
| `ledger.ingress.className` | string | `""` | Ingress class name |
| `ledger.ingress.annotations` | object | `{}` | Additional ingress annotations |
| `ledger.ingress.tls` | list | `[]` | TLS configuration for ingress |
| `ledger.resources.limits` | string | `{}` | CPU and memory limits for pods |
| `ledger.resources.requests` | string | `{}` | Minimum CPU and memory requests |
| `ledger.autoscaling.enabled` | bool | `true` | Enable or disable horizontal pod autoscaling |
| `ledger.autoscaling.minReplicas` | int | `2` | Minimum number of replicas |
| `ledger.autoscaling.maxReplicas` | int | `9` | Maximum number of replicas |
| `ledger.autoscaling.targetCPUUtilizationPercentage` | int | `80` | Target CPU utilization percentage for autoscaling |
| `ledger.nodeSelector` | object | `{}` | Node selector for scheduling pods on specific nodes |
| `ledger.tolerations` | object | `{}` | Tolerations for scheduling on tainted nodes |
| `ledger.affinity` | object | `{}` | Affinity rules for pod scheduling |
| `ledger.datastores` | object | `templates/ledger/configmap.yaml` | Dedicated datastore masks for this component (override global.datastores). Sub-keys: postgresOnboarding / postgresTransaction / mongoOnboarding / mongoTransaction / mongoCrm / mongoFees / redis / broker (host/port/user/ssl/replicaHost). |
| `ledger.configmap` | object | `{}` | Escape hatch: any native env var (e.g. DB_ONBOARDING_MAX_OPEN_CONNS) overrides the template default. |
| `ledger.useExistingSecret` | bool | `false` | Existing secrets name |
| `ledger.extraEnvVars` | object | `{}` | Extra environment variables |
| `ledger.secrets` | string | `templates/ledger/secrets.yaml` | Secrets for storing sensitive data |
| `ledger.secrets.DB_ONBOARDING_PASSWORD` | string | `""` | Onboarding module passwords. DB_ONBOARDING_PASSWORD / DB_ONBOARDING_REPLICA_PASSWORD are single-sourced from the Bitnami postgresql subchart Secret (keys `password` / `replication-password`) and MONGO_ONBOARDING_PASSWORD from the mongodb subchart Secret (key `mongodb-root-password`). Only set these for an EXTERNAL backend (subchart disabled / .external=true) without an existingSecret override. |
| `ledger.secrets.DB_TRANSACTION_PASSWORD` | string | `""` | Transaction module passwords (same single-source rule as onboarding; both DB_* authenticate as role `midaz`, both MONGO_* as the mongo root user). |
| `ledger.secrets.MONGO_CRM_PASSWORD` | string | `""` | CRM and Fees module passwords. The unified ledger binary (midaz v4) opens these Mongo databases in-process; same single-source rule as the modules above. Rendered into the ledger Secret, never the ConfigMap. |
| `ledger.secrets.LCRYPTO_HASH_SECRET_KEY` | string | `""` | CRM holder-field crypto (lib-crypto). Operator-provided key material protecting PII at rest. Required when the ledger serves CRM and KMS_VENDOR is unset or "none" (legacy mode, local symmetric keys). |
| `ledger.secrets.KMS_VAULT_SECRET_ID` | string | `""` | Vault AppRole SecretID, the credential half of the KMS auth pair. Only set when ledger.configmap.KMS_VENDOR="hashicorp-vault" (envelope encryption). The RoleID counterpart is not secret and stays in the ConfigMap. |
| `ledger.secrets.REDIS_PASSWORD` | string | `""` | Shared passwords. REDIS_PASSWORD is single-sourced from the Bitnami valkey subchart Secret (key `valkey-password`); only set it for an EXTERNAL Valkey/Redis without an existingSecret override. RABBITMQ_* remain operator-provided (see README "Known limitation" — RabbitMQ is not yet single-sourced). |
| `ledger.secrets.SD_TOKEN` | string | `""` | Service discovery (lib-service-discovery) Consul ACL token. Operator-provided; only set when the Consul server enforces ACLs. Rendered into the ledger Secret. |
| `ledger.secrets.STREAMING_SASL_PASSWORD` | string | `""` | Streaming (lib-streaming) SASL/TLS material. Operator-provided; only set when the streaming backend uses SASL auth and/or a private TLS CA. When set, they are rendered into the ledger Secret (never the ConfigMap). |
| `ledger.serviceAccount.create` | bool | `true` | Specifies whether a ServiceAccount should be created |
| `ledger.serviceAccount.annotations` | object | `{}` | Annotations for the ServiceAccount |
| `ledger.serviceAccount.name` | string | ``midaz-ledger.fullname`` | Name of the service account |
| `tracer.readinessProbe` | object | `{}` | Readiness probe configuration. All fields override chart defaults. |
| `tracer.livenessProbe` | object | `{}` | Liveness probe configuration. All fields override chart defaults. |
| `tracer.name` | string | `tracer` | Service name |
| `tracer.enabled` | bool | `false` | Enable or disable the Tracer service (disabled by default; opt-in per env) |
| `tracer.replicaCount` | int | `1` | Number of replicas for the Tracer service |
| `tracer.revisionHistoryLimit` | int | `10` | Number of old ReplicaSets to retain for deployment rollback |
| `tracer.image.repository` | string | `lerianstudio/midaz-tracer` | Repository for the Tracer service container image. In midaz v4 tracer ships from the monorepo (`components/tracer`) and the release pipeline publishes it as `midaz-tracer`; the standalone `lerianstudio/tracer` 1.x image predates the configuration contract this chart renders. |
| `tracer.image.pullPolicy` | string | `Always` | Image pull policy |
| `tracer.image.tag` | string | `"4.0.0-beta.26"` | Image tag used for deployment |
| `tracer.migrations` | string | `{}` | Dedicated migration runner (`midaz-tracer-migrations`, built FROM migrate/migrate). The v4 tracer no longer migrates at startup: it boots against an already-migrated schema, so this Job has to apply it. |
| `tracer.migrations.enabled` | bool | `true` | Enable or disable the tracer migration Job |
| `tracer.migrations.image.repository` | string | `lerianstudio/midaz-tracer-migrations` | Repository for the tracer migration-runner image |
| `tracer.migrations.image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `tracer.migrations.image.tag` | string | `""` | Migration image tag. Empty tracks `tracer.image.tag` so the schema and the binary reading it cannot drift. |
| `tracer.migrations.annotations` | object | `{}` | Extra Job annotations. The Job is a plain Sync-phase resource by default because the bundled PostgreSQL Secret it reads is only created during Sync; against a pre-provisioned database, set `argocd.argoproj.io/hook: PreSync` here to order it ahead of the Deployment. |
| `tracer.migrations.deploymentSyncWave` | string | `"1"` | Argo CD sync wave stamped on the tracer Deployment while this Job renders, so the Deployment is applied only once the Job reports Complete (the Job itself stays in the default wave, with the bundled PostgreSQL Secret it reads). Set to "" to drop the annotation and let both apply together. Ignored by plain `helm install`. |
| `tracer.migrations.backoffLimit` | int | `6` | Retries before the Job is marked failed (also absorbs a database that is reachable but not yet provisioned by the bootstrap Job) |
| `tracer.migrations.activeDeadlineSeconds` | int | `600` | Hard timeout for the whole Job |
| `tracer.migrations.ttlSecondsAfterFinished` | int | `259200` | How long the finished Job is kept for inspection |
| `tracer.migrations.waitForPostgres` | string | `{}` | Wait for the PostgreSQL endpoint before running migrate |
| `tracer.migrations.waitForPostgres.enabled` | bool | `true` | Enable or disable the wait-for-postgres init container |
| `tracer.migrations.waitForPostgres.image.repository` | string | `busybox` | Repository for the wait-for-postgres init container image |
| `tracer.migrations.waitForPostgres.image.tag` | string | `"1.37"` | Image tag for the wait-for-postgres init container image |
| `tracer.migrations.resources.limits` | string | `{}` | CPU and memory limits for the migration Job |
| `tracer.migrations.resources.requests` | string | `{}` | Minimum CPU and memory requests for the migration Job |
| `tracer.imagePullSecrets` | list | `[]` | Secrets for pulling images from a private registry |
| `tracer.nameOverride` | string | `""` | Overrides the default generated name by Helm |
| `tracer.fullnameOverride` | string | `""` | Overrides the full name generated by Helm |
| `tracer.podAnnotations` | object | `{}` | Pod annotations for additional metadata |
| `tracer.securityContext.runAsGroup` | int | `1000` | Defines the group ID for the user running the process inside the container |
| `tracer.securityContext.runAsUser` | int | `1000` | Defines the user ID for the process running inside the container |
| `tracer.securityContext.runAsNonRoot` | bool | `true` | Ensures the process does not run as root |
| `tracer.securityContext.readOnlyRootFilesystem` | bool | `true` | Defines the root filesystem as read-only |
| `tracer.pdb` | string | `{}` | PodDisruptionBudget configuration |
| `tracer.pdb.enabled` | bool | `true` | Enable or disable PodDisruptionBudget |
| `tracer.pdb.minAvailable` | int | `1` | Minimum number of available pods. Setting `maxUnavailable` in an override takes precedence over this value. |
| `tracer.pdb.annotations` | object | `{}` | Annotations for the PodDisruptionBudget |
| `tracer.deploymentUpdate` | string | `{}` | Deployment update strategy |
| `tracer.deploymentUpdate.type` | string | `RollingUpdate` | Type of deployment strategy |
| `tracer.deploymentUpdate.maxSurge` | int | `1` | Maximum number of pods that can be created over the desired number of pods |
| `tracer.deploymentUpdate.maxUnavailable` | int | `1` | Maximum number of pods that can be unavailable during the update |
| `tracer.service.type` | string | `ClusterIP` | Kubernetes service type |
| `tracer.service.port` | int | `4020` | Service port (HTTP API) |
| `tracer.service.grpcPort` | int | `4021` | gRPC reservation seam port. Only exposed when `tracer.configmap.TRACER_GRPC_PORT` is set; the seam is off in the app until then, so the port would otherwise route to a closed socket. |
| `tracer.ingress.enabled` | bool | `false` | Enable or disable ingress |
| `tracer.ingress.className` | string | `""` | Ingress class name |
| `tracer.ingress.annotations` | object | `{}` | Additional ingress annotations |
| `tracer.ingress.tls` | list | `[]` | TLS configuration for ingress |
| `tracer.resources.limits` | string | `{}` | CPU and memory limits for pods |
| `tracer.resources.requests` | string | `{}` | Minimum CPU and memory requests |
| `tracer.autoscaling.enabled` | bool | `true` | Enable or disable horizontal pod autoscaling |
| `tracer.autoscaling.minReplicas` | int | `1` | Minimum number of replicas |
| `tracer.autoscaling.maxReplicas` | int | `5` | Maximum number of replicas |
| `tracer.autoscaling.targetCPUUtilizationPercentage` | int | `80` | Target CPU utilization percentage for autoscaling |
| `tracer.nodeSelector` | object | `{}` | Node selector for scheduling pods on specific nodes |
| `tracer.tolerations` | object | `{}` | Tolerations for scheduling on tainted nodes |
| `tracer.affinity` | object | `{}` | Affinity rules for pod scheduling |
| `tracer.datastores` | object | `templates/tracer/configmap.yaml` | Dedicated datastore mask (override global.datastores). Sub-key: postgres (host/port/user/ssl). |
| `tracer.configmap` | object | `{}` | Escape hatch: any native env var overrides the template default. |
| `tracer.extraEnvVars` | object | `{}` | Extra environment variables |
| `tracer.secrets` | string | `templates/tracer/secrets.yaml` | Secrets for storing sensitive data |
| `tracer.secrets.DB_PASSWORD` | string | `""` | PostgreSQL password. Single-sourced from the Bitnami postgresql subchart Secret (key `password`) when internal; only set for an EXTERNAL PostgreSQL (subchart disabled / .external=true) without an existingSecret override. |
| `tracer.secrets.API_KEY` | string | `""` | API Key value (read by the app as $API_KEY when API_KEY_ENABLED=true). |
| `tracer.secrets.SD_TOKEN` | string | `""` | Service discovery (lib-service-discovery) Consul ACL token. Operator-provided; only set when the Consul server enforces ACLs. Emitted into the tracer Secret only when set. |
| `grafana.ingress` | string | `{}` | Configure the ingress for Access Grafana Dashboard |
| `otel-collector-lerian` | string | `{}` | OTEL exporter configuration for midaz services. When enabled, HOST_IP, POD_IP, OTEL_EXPORTER_OTLP_ENDPOINT and OTEL_RESOURCE_ATTRIBUTES are injected into the `ledger` and `crm` deployments only. Port is fixed at 4317. If you need a different collector endpoint, leave enabled=false and configure OTEL env vars directly in the application configmap (ledger.configmap / crm.configmap). |
| `otel-collector-lerian.enabled` | bool | `true` | Inject OTEL env vars into the midaz ledger and crm deployments |

