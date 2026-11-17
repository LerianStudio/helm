# br-ccs Helm chart 1.0.0 — first stable release and migration checklist

## Scope and release status

This guide targets **chart 1.0.0**, with default application image `ghcr.io/lerianstudio/br-ccs:1.1.2` and default migration image `ghcr.io/lerianstudio/br-ccs-migrations:1.1.2`. An explicit application or migration tag override can retain another version. An empty migration tag inherits the application tag, then the chart appVersion.

This is the first stable chart, not the first chart ever: beta.1 through beta.6 preceded it. The comparison below is **1.0.0-beta.6 → 1.0.0**. Earlier beta installations require an additional comparison from their installed version. Existing custom manifests need a separate adoption/cutover plan; `helm upgrade` does not import them.

> **Deployment gate:** Chart rendering does not prove application startup, migration safety or recoverability. The chart package was retrieved from GHCR, but anonymous access to both default application images was denied during review. Obtain pull access and verified image digests/build provenance for both application and migrator, validate their exact runtime prerequisites and SQL, and complete an isolated install/upgrade/restore rehearsal before production changes. Do not select a different image tag merely to bypass this gate.

## Changes to review before leaving beta.6

- Default appVersion and application tag change from 1.0.0 to 1.1.2. Retained image overrides can prevent adoption; validate application and migration pins together.
- `lerian-common-helm` 1.4.0 adds grouped/global configuration surfaces. Application datastore precedence is native `brCcs.configmap.<KEY>`, dedicated `brCcs.datastores`, global `global.datastores`, then chart defaults. **The migration Job does not use this datastore mask**; set its five native PostgreSQL fields explicitly as shown below.
- Non-connection settings now have defaults in `templates/configmap.yaml`; `brCcs.configmap` defaults to `{}`. Review the effective rendered env, not only differences in values.yaml. Preserve intended integrations and non-default settings rather than copying an empty map over a working configuration.
- The `TRUSTED_PROXIES` default changes from `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` to empty. With the default `ENV_NAME: "production"`, the 1.1.2 application refuses to start when `TRUSTED_PROXIES` is empty (`TRUSTED_PROXIES is required in production`). A beta.6 install that relied on the old default must set `brCcs.configmap.TRUSTED_PROXIES` to its ingress/proxy CIDRs before upgrading.
- Generated application names no longer automatically incorporate the release name. With default top-level naming values the application resources are named `br-ccs` even for another release name. Compare current/target names and ownership; multiple releases in one namespace can collide. Verify the top-level `nameOverride`/`fullnameOverride` values against the render; nested similarly named values are not proof of actual naming.
- The Service no longer exposes gRPC, and the Deployment's named HTTP container port is fixed at 4030. Changing the Service port alone does not change the application listener/probe target. A deployment that depended on beta gRPC exposure or non-default listener ports needs an independently validated compatibility plan; this guide does not restore those chart features.
- The dependency wait container expects Redis as `host:port`, not a bare hostname. Defaults change PostgreSQL to `bitnamilegacy/postgresql:17.4.0` and Valkey to `bitnamilegacy/valkey:8.0.2`; independently verify pull access, supported platforms and operational suitability.
- Stable PDB rendering chooses truthy `maxUnavailable`, otherwise `minAvailable` (default 1); it does not emit both. Numeric `maxUnavailable: 0` and `minAvailable: 0` are treated as empty by these stable template branches. Review any zero-valued beta settings and rendered availability budget before upgrade.
- External bootstrap templates change, including ordering and credential handling. Do not assume beta bootstrap behavior is retained. Use separately verified provisioning and credential-rotation procedures, not this release's bootstrap Jobs as a migration prerequisite.

## Prepare configuration and recovery privately

1. Identify the actual release name, namespace, installed chart version, application/migrator pins, live datastore identities, PVCs and Secret references. Preserve a private copy of the existing manifests, user values and effective values. Helm outputs can contain secrets: use a restricted local directory, never CI logs, chat or Git.
2. Build **one complete intended values file** based on chart 1.0.0. Carry forward required image-pull references, app credentials/crypto material, datastore credentials, integrations, network/security settings, storage, ingress and naming overrides. Remove obsolete overrides deliberately. The fragments below are not a complete application deployment configuration.
3. Verify runtime requirements against the exact shipped image revisions: Reporter endpoint and credentials; accepted licence and organization scope; crypto-key formats and preservation of existing keys; STA/Fetcher/CRM integrations as used; object-storage endpoints, buckets, permissions and TLS; trusted ingress proxies and TLS termination. A legacy enable switch or a successful template is not evidence that the binary treats a dependency as optional. In particular, do not treat `REPORTER_ENABLED=false` as proof that an empty `REPORTER_URL` is safe. The chart can deliver `brCcs.configmap.REPORTER_URL` without that legacy switch.
4. Take consistent database and object-storage backups, preserving encryption keys, licences, credentials and configuration securely. Record schema revision, backup identifiers and recovery objectives. Rehearse restoring to isolated targets and validating data with the intended application version. A backup command succeeding is not a tested restore.
5. Define a maintenance/cutover window and stop or isolate old writers, consumers and scheduled work before schema/data changes. Validate compatibility before allowing old/new binaries to overlap; do not assume RollingUpdate makes concurrent schema access safe. Retain the old environment until acceptance and recovery criteria are met.

## Datastore choices and credentials

Chart dependencies are PostgreSQL 16.3.5, Valkey 2.4.7, RabbitMQ 2.1.11 and library `lerian-common-helm` 1.4.0. These are **chart versions**, not necessarily server image versions.

Defaults enable bundled PostgreSQL and Valkey; bundled RabbitMQ is disabled, as is application `RABBITMQ_ENABLED`. For an external datastore set its `enabled: false` and `external: true` explicitly: dependency inclusion is controlled by the enabled condition; do not rely on `external: true` alone to suppress a subchart.

### External PostgreSQL and Valkey fragment

Provision the external PostgreSQL database, role, grants and matching password **before** installing or upgrading with migrations enabled. Verify DNS, routing, TLS and authenticated connectivity from the workload network. Keep bootstrap flags false; the PostgreSQL bootstrap is a regular Job and cannot create a database before an external `pre-install` migration hook.

Merge this fragment into the complete intended file, replacing example endpoints and Secret names privately. It illustrates a single-tenant path with no broker use; it is not a certified application quickstart.

```yaml
postgresql:
  enabled: false
  external: true
valkey:
  enabled: false
  external: true
rabbitmq:
  enabled: false
  external: true
global:
  externalPostgresDefinitions:
    enabled: false
  externalRabbitmqDefinitions:
    enabled: false
  datastores:
    redis:
      host: "redis.example.com:6379"
brCcs:
  useExistingSecret: true
  existingSecretName: "ccs-application-env"
  migrations:
    enabled: true
    useExistingSecret: true
    existingSecretName: "ccs-application-env"
  configmap:
    POSTGRES_HOST: "postgres.example.com"
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "br-ccs"
    POSTGRES_NAME: "br-ccs"
    POSTGRES_SSLMODE: "require"
    RABBITMQ_ENABLED: "false"
    REPORTER_URL: "https://reporter.example.com"
```

The pre-existing application Secret must contain the complete required application secret set, including `POSTGRES_PASSWORD`, and Redis credentials where required. The external migration Secret must contain `POSTGRES_PASSWORD` matching the provisioned role. If different app and migration roles are deliberately used, first validate their privileges and the chart's shared connection-field limitations. Do not put passwords in ConfigMaps or command-line `--set` arguments.

With chart-managed external credentials instead, set `brCcs.useExistingSecret: false` and supply the required fields in `brCcs.secrets` through a private secrets-delivery process. The chart creates an earlier migration-only Secret hook when needed. The same database identity and password must be used consistently; changing a values file or Kubernetes Secret does not rotate the PostgreSQL role password.

### Bundled PostgreSQL and Valkey

Use `postgresql.enabled: true`, `postgresql.external: false`, `valkey.enabled: true`, `valkey.external: false`. Bundled passwords come from the subchart Secret: PostgreSQL uses key `password`, Valkey uses `valkey-password`. Configure the subchart auth fields or their compatible existing Secrets; setting only `brCcs.secrets.POSTGRES_PASSWORD` or `REDIS_PASSWORD` does not set bundled server passwords.

Preserve existing credentials and storage identities on upgrades. PostgreSQL bundled persistence defaults to 8Gi; Valkey primary persistence is disabled by default. A new PVC or newly generated password is not data adoption. Compare live and target claims, mounts and Secret references and prove a restore/cutover where identities change. Do not assume TLS is configured merely because application and migration `POSTGRES_SSLMODE` defaults to `require`; validate server TLS and client trust together. Do not downgrade production transport security to make a sample start.

### Optional RabbitMQ fragment (bundled or external)

Bundled broker use requires **both** subchart and application configuration. Merge the following fragment only if broker use is intended, supply stable private credentials, and align the application password with the broker definition password:

```yaml
rabbitmq:
  enabled: true
  external: false
  authentication:
    user:
      value: "br-ccs"
    password:
      value: "REPLACE_WITH_PRIVATE_BROKER_PASSWORD"
    erlangCookie:
      value: "REPLACE_WITH_STABLE_PRIVATE_COOKIE"
brCcs:
  configmap:
    RABBITMQ_ENABLED: "true"
    RABBITMQ_VHOST: "/"
  secrets:
    RABBITMQ_DEFAULT_PASS: "REPLACE_WITH_PRIVATE_BROKER_PASSWORD"
```

These uppercase strings are placeholders, not credentials. Retain existing broker password/cookie on upgrade. If `brCcs.useExistingSecret=true`, supply the app's `RABBITMQ_DEFAULT_PASS` in that complete existing Secret instead; the `brCcs.secrets` fragment does not populate an external Secret.

Groundhog2k RabbitMQ does **not** use `rabbitmq.auth.existingSecret`. Its subchart surface is `rabbitmq.authentication.existingSecret` with field-specific `secretKey` entries. However, this parent chart still requires `rabbitmq.authentication.password.value` to generate imported broker definitions when bundled RabbitMQ is enabled; a secret-only subchart override does not remove that requirement. Plan protected Helm release/manifests handling accordingly.

For an external broker, disable the subchart, enable app broker use explicitly, configure `global.datastores.broker.host/port/user` (or matching native app overrides), and provision its user, vhost, permissions and topology separately before cutover. This chart's definitions use vhost `/`, not `/br-ccs`. Verify all producer/consumer topology and credentials rather than assuming optional bootstrap provides a complete integration. Keep `global.externalRabbitmqDefinitions.enabled=false` on this documented path; do not send administrator credentials over plain HTTP or skip certificate verification in production.

## Migration ordering and effective configuration

- **External PostgreSQL:** migration Job is a `pre-install,pre-upgrade` hook. Database/role/credentials must already exist. Set `brCcs.configmap.POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_NAME` and `POSTGRES_SSLMODE` explicitly. Global/dedicated datastore values alone can configure the application while leaving the migrator on its bundled default host.
- **Bundled PostgreSQL:** migration Job is a `post-install,post-upgrade` hook with a PostgreSQL TCP wait init container. The application Deployment is already submitted; no general schema-before-app-start guarantee exists. Rehearse this ordering and readiness behavior in isolation; do not infer safety from `--wait` or prescribe it blindly on first bundled installation.
- Successful migration hooks have `hook-succeeded` deletion policy. Capture status and logs while running in a private evidence sink; an absent Job after success is not proof of failure, and an absent Job alone is not proof of success. Inspect the target database's migration revision and dirty state using the verified migrator's procedure.
- Do not disable migrations as a workaround unless an independently approved process has already applied and verified the exact required schema.
- Application existing-Secret updates are not hashed into the chart's Secret checksum. Coordinate required rollout with credential rotation and verify the effective pod configuration; do not assume a Secret edit restarts pods.
- Observability has a chart-specific exception: `brCcs.configmap.ENABLE_TELEMETRY: "true"` adds explicit Deployment OTLP env pointing at `$(HOST_IP):4317`. That overrides a ConfigMap collector endpoint. For a central collector, prefer `global.observability.enabled` and `global.observability.otlpEndpoint`, leave that native toggle absent, and inspect the rendered Deployment plus ConfigMap together.
- Global multi-tenancy, service discovery, streaming and authentication values are chart wiring, not independently certified binary support. Enable only integrations validated for the exact runtime revision and supply their complete credentials/TLS requirements. Authentication defaults off. The app container's non-root/read-only/capability settings do not establish production readiness of every dependency or bootstrap resource.

## Preview and execute only after the gates pass

Use a private local directory: exported values and rendered manifests can include secret material. The following exports are read-only against an **existing Helm release**; skip them for a genuinely new installation and inventory the old custom-manifest deployment separately.

```bash
umask 077
mkdir -p ccs-upgrade-private
helm get values br-ccs -n br-ccs -o yaml > ccs-upgrade-private/installed-user-values.yaml
helm get values br-ccs -n br-ccs --all -o yaml > ccs-upgrade-private/installed-effective-values.yaml
helm get manifest br-ccs -n br-ccs > ccs-upgrade-private/installed-manifest.yaml
helm history br-ccs -n br-ccs > ccs-upgrade-private/installed-history.txt
```

Prepare `ccs-upgrade-private/intended-values.yaml` separately; do not overwrite the backup. It must be the **complete intended configuration**, not one of this guide's fragments. Reset semantics below deliberately discard omitted user overrides: preserve every still-required setting and Secret reference explicitly. Do not use `--reuse-values` to hide migration work.

The GHCR chart publication was verified during review; Docker Hub returned anonymous authorization failure. Chart availability is independent of application-image access.

```bash
helm template br-ccs oci://ghcr.io/lerianstudio/br-ccs-helm \
  --version 1.0.0 -n br-ccs \
  -f ccs-upgrade-private/intended-values.yaml \
  > ccs-upgrade-private/target-install.yaml
```

For an existing beta release, render upgrade mode and preview with the same intended file. `helm diff` requires the separately installed [helm-diff plugin](https://github.com/databus23/helm-diff); verify its compatibility with your Helm version before use.

```bash
helm template br-ccs oci://ghcr.io/lerianstudio/br-ccs-helm \
  --version 1.0.0 -n br-ccs --is-upgrade \
  -f ccs-upgrade-private/intended-values.yaml \
  > ccs-upgrade-private/target-upgrade.yaml
helm diff upgrade br-ccs oci://ghcr.io/lerianstudio/br-ccs-helm \
  --version 1.0.0 -n br-ccs --reset-values \
  -f ccs-upgrade-private/intended-values.yaml \
  > ccs-upgrade-private/upgrade.diff
```

Inspect application/migrator image references, Secret names/keys, both PostgreSQL destinations, Redis host:port, hook ordering, resource names/ownership/selectors, PVCs/mounts, listener/probe targets, PDB, effective env and network/TLS settings. Compare the current release's render with the target using the intended settings. Do not accept replacement storage or a naming collision as a routine diff.

After all release, rehearsal and recovery gates pass, choose **one** operation:

```bash
# Existing beta release only:
helm upgrade br-ccs oci://ghcr.io/lerianstudio/br-ccs-helm \
  --version 1.0.0 -n br-ccs --reset-values \
  -f ccs-upgrade-private/intended-values.yaml
```

```bash
# New release only, after custom-manifest ownership/data cutover is separately validated:
helm install br-ccs oci://ghcr.io/lerianstudio/br-ccs-helm \
  --version 1.0.0 -n br-ccs --create-namespace \
  -f ccs-upgrade-private/intended-values.yaml
```

Do not run both commands. Do not adopt existing resources by relabeling them blindly or remove old data/PVCs to clear an ownership error. These commands are not evidence of a completed runtime acceptance test.

## Validate, cut over and recover

For the unmodified default naming shown above, use release-scoped observations and the rendered Deployment name. Adjust `deployment/br-ccs` if the verified top-level naming override changes it.

```bash
helm status br-ccs -n br-ccs
kubectl -n br-ccs get pods,jobs,pvc -l app.kubernetes.io/instance=br-ccs
kubectl -n br-ccs rollout status deployment/br-ccs --timeout=10m
kubectl -n br-ccs get events --sort-by=.lastTimestamp
```

The event listing is namespace-wide context; correlate it with the exact release resources and keep sensitive outputs private. Obtain migration hook logs/status while available and confirm schema revision/dirty state independently. Verify the effective image digests, `/health` and `/readyz` probe results and actual enabled business integrations. Readiness alone is not proof that Reporter, asynchronous business processing or data restoration works. Reconcile representative records and pending work against the pre-cutover baseline before routing traffic or resuming writers.

If validation fails, stop cutover and isolate new writers/workers. **Helm rollback changes Kubernetes release state; it does not reverse SQL migrations, restore a database/object store, recover lost PVC data or make an old binary compatible with a new schema.** Use an older release only after its compatibility with the current data/schema is proven. Otherwise execute the rehearsed restore into isolated targets, verify restored data and preserved crypto keys, configure the compatible release with its complete intended values and perform a controlled recutover. Do not restart a newer writer against restored data before its startup/migration effects are understood. Keep backups and the old environment until acceptance is signed off.

## Public exact-release chart sources

- [Chart metadata and dependencies](https://github.com/LerianStudio/helm/blob/00adb7d4c274876230a4e4c8efbf98680e5736d0/charts/br-ccs/Chart.yaml)
- [Stable chart values](https://github.com/LerianStudio/helm/blob/00adb7d4c274876230a4e4c8efbf98680e5736d0/charts/br-ccs/values.yaml)
- [Stable templates](https://github.com/LerianStudio/helm/tree/00adb7d4c274876230a4e4c8efbf98680e5736d0/charts/br-ccs/templates)
- [Beta.6 to stable chart comparison](https://github.com/LerianStudio/helm/compare/br-ccs-v1.0.0-beta.6...br-ccs-v1.0.0)

These public chart sources document template behavior, not image-source provenance or a successful live migration.
