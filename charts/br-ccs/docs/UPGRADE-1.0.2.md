<!-- {% raw %} -->
# Helm Upgrade from v1.0.1 to v1.0.2

## Topics

- **[Overview](#overview)**
- **[RabbitMQ removal](#rabbitmq-removal)**
  - [1. Removed chart dependency](#1-removed-chart-dependency)
  - [2. Removed configuration surface](#2-removed-configuration-surface)
  - [3. Removed templates](#3-removed-templates)
  - [4. Removed environment variables](#4-removed-environment-variables)
- **[Migration steps](#migration-steps)**
  - [Scenario 1: RabbitMQ was never enabled](#scenario-1-rabbitmq-was-never-enabled)
  - [Scenario 2: Bundled RabbitMQ was enabled](#scenario-2-bundled-rabbitmq-was-enabled)
  - [Scenario 3: External RabbitMQ with bootstrap job](#scenario-3-external-rabbitmq-with-bootstrap-job)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Chart version 1.0.2 is a **patch release** that removes all RabbitMQ integration from the br-ccs chart. This includes the bundled RabbitMQ subchart dependency, all RabbitMQ-related configuration surfaces, bootstrap templates, and environment variables.

**Breaking change for RabbitMQ users.** Installations with RabbitMQ enabled (bundled or external) must migrate away from message broker integration before upgrading. The application no longer supports RabbitMQ-based event publishing or consumption. Installations with RabbitMQ disabled are unaffected.

| Aspect | v1.0.1 | v1.0.2 |
|--------|--------|--------|
| Chart version | 1.0.1 | 1.0.2 |
| App version | 1.1.2 | 1.1.2 (unchanged) |
| Breaking changes | None | RabbitMQ dependency and all broker configuration removed |
| RabbitMQ subchart | Optional (disabled by default) | Removed entirely |
| `RABBITMQ_ENABLED` support | Yes | No |

## RabbitMQ removal

### 1. Removed chart dependency

The RabbitMQ subchart dependency has been completely removed from `Chart.yaml`:

**Before (v1.0.1):**

```yaml
dependencies:
  - name: rabbitmq
    version: "2.1.11"
    repository: "https://groundhog2k.github.io/helm-charts"
    condition: rabbitmq.enabled
```

**After (v1.0.2):**

The dependency no longer exists. Setting `rabbitmq.enabled: true` in values will have no effect.

### 2. Removed configuration surface

All RabbitMQ-related configuration blocks have been removed from `values.yaml`:

#### Removed top-level RabbitMQ subchart configuration

**Before (v1.0.1):**

```yaml
rabbitmq:
  enabled: false
  image:
    tag: "3.13.6"
  persistence:
    size: 8Gi
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi
  authentication:
    user:
      value: "br-ccs"
    password:
      value: ""
    erlangCookie:
      value: ""
  extraSecrets:
    - name: "br-ccs-rabbitmq-load-definition"
      mountPath: /etc/rabbitmq/definitions
  customConfig: |
    management.load_definitions = /etc/rabbitmq/definitions/load_definition.json
```

**After (v1.0.2):**

Entire `rabbitmq:` block removed. Any values set under `rabbitmq:` will be ignored.

#### Removed external RabbitMQ bootstrap configuration

**Before (v1.0.1):**

```yaml
global:
  externalRabbitmqDefinitions:
    enabled: false
    connection:
      protocol: "http"
      host: "br-ccs-rabbitmq"
      port: "15672"
      portAmqp: "5672"
      skipTlsVerify: false
    rabbitmqAdminLogin:
      useExistingSecret:
        name: ""
      username: "admin"
      password: ""
    brCcsCredentials:
      useExistingSecret:
        name: ""
      password: ""
```

**After (v1.0.2):**

Entire `global.externalRabbitmqDefinitions` block removed.

#### Removed broker datastore configuration

**Before (v1.0.1):**

```yaml
global:
  datastores:
    broker:
      host: ""          # RABBITMQ_HOST
      port: "5672"      # RABBITMQ_PORT_AMQP
      user: "br-ccs"    # RABBITMQ_DEFAULT_USER
```

**After (v1.0.2):**

The `global.datastores.broker` block is no longer documented or consumed by templates.

### 3. Removed templates

The following template files have been completely removed:

- `templates/bootstrap-rabbitmq.yaml` — External RabbitMQ bootstrap Job, ConfigMap, and init containers
- `templates/rabbitmq_load_definitions.yaml` — Bundled RabbitMQ definitions Secret
- `templates/_helpers.tpl` — The `rabbitmq.enabled` helper function

**Before (v1.0.1):**

```yaml
{{- define "rabbitmq.enabled" -}}
{{- if and (default true .Values.rabbitmq.enabled) (not .Values.rabbitmq.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
```

**After (v1.0.2):**

Helper removed. No template logic checks for RabbitMQ enablement.

### 4. Removed environment variables

All RabbitMQ-related environment variables have been removed from `templates/configmap.yaml`:

| Removed Variable | Purpose in v1.0.1 |
|------------------|-------------------|
| `RABBITMQ_ENABLED` | Enable/disable RabbitMQ integration |
| `RABBITMQ_HOST` | RabbitMQ server hostname |
| `RABBITMQ_PORT_AMQP` | RabbitMQ AMQP port (default 5672) |
| `RABBITMQ_PORT_HOST` | RabbitMQ management port (default 15672) |
| `RABBITMQ_DEFAULT_USER` | RabbitMQ username |
| `RABBITMQ_VHOST` | RabbitMQ virtual host (default `/`) |
| `RABBITMQ_EXCHANGE` | RabbitMQ exchange name (default `events`) |
| `RABBITMQ_QUEUE` | Optional queue name |
| `RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS` | Health check host validation |
| `RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK` | Skip TLS for health checks |
| `RABBITMQ_ALLOW_INSECURE_TLS` | Skip TLS verification |
| `RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS` | Publisher confirmation timeout |
| `RABBITMQ_PUBLISHER_RECOVERY_INITIAL_MS` | Initial recovery delay |
| `RABBITMQ_PUBLISHER_RECOVERY_MAX_MS` | Maximum recovery delay |
| `RABBITMQ_PUBLISHER_MAX_RECOVERIES` | Maximum recovery attempts |
| `RABBITMQ_HEALTH_CHECK_URL` | Custom health check URL |
| `RABBITMQ_HEALTH_CHECK_ALLOWED_HOSTS` | Allowed health check hosts |
| `CCS_STA_DLQ_TTL_SECONDS` | Dead letter queue TTL |
| `CCS_CONSUMER_MAX_REDELIVERIES` | Maximum message redeliveries |

**Before (v1.0.1):**

```yaml
data:
  RABBITMQ_ENABLED: "false"
  RABBITMQ_HOST: "br-ccs-rabbitmq.br-ccs.svc.cluster.local"
  RABBITMQ_PORT_AMQP: "5672"
  # ... (all variables above)
```

**After (v1.0.2):**

No RabbitMQ variables rendered in ConfigMap. Setting `brCcs.configmap.RABBITMQ_ENABLED` or any other `RABBITMQ_*` key will pass through as an unrecognized escape-hatch value but will not enable broker functionality.

The ConfigMap template comments have been updated to reflect the removal:

**Before (v1.0.1):**

```yaml
{{- /* TIERED model (the #1741 pattern). DEPENDENCY CONNECTIONS (postgres/redis/broker,
   multiTenant, otel, serviceDiscovery, streaming, auth) resolve via lerian-common domain
   helpers + the datastore mask */}}
```

**After (v1.0.2):**

```yaml
{{- /* TIERED model (the #1741 pattern). DEPENDENCY CONNECTIONS (postgres/redis,
   multiTenant, otel, serviceDiscovery, streaming, auth) resolve via lerian-common domain
   helpers + the datastore mask */}}
```

The `CCS_CONSUMER_MAX_REDELIVERIES` key has been removed from the optional runtime knobs list:

**Before (v1.0.1):**

```yaml
{{- range $k := (list "CCS_CONSUMER_MAX_REDELIVERIES" "CCS_DETAIL_PII_RETENTION_BUSINESS_DAYS" ...) }}
```

**After (v1.0.2):**

```yaml
{{- range $k := (list "CCS_DETAIL_PII_RETENTION_BUSINESS_DAYS" ...) }}
```

## Migration steps

### Scenario 1: RabbitMQ was never enabled

**Current configuration (v1.0.1):**

```yaml
# RabbitMQ disabled (default)
rabbitmq:
  enabled: false
brCcs:
  configmap:
    RABBITMQ_ENABLED: "false"  # or omitted
```

**Action required:** None. Remove any `rabbitmq:` or `global.externalRabbitmqDefinitions:` blocks from your values file to avoid confusion, but they will be ignored after upgrade.

**Result after upgrade:** No functional changes. Application continues without broker integration.

---

### Scenario 2: Bundled RabbitMQ was enabled

**Current configuration (v1.0.1):**

```yaml
rabbitmq:
  enabled: true
  authentication:
    user:
      value: "br-ccs"
    password:
      value: "BROKER_PASSWORD"
    erlangCookie:
      value: "ERLANG_COOKIE"
brCcs:
  configmap:
    RABBITMQ_ENABLED: "true"
  secrets:
    RABBITMQ_DEFAULT_PASS: "BROKER_PASSWORD"
```

> **Warning:** Upgrading to v1.0.2 with this configuration will remove the RabbitMQ StatefulSet, Service, and PVC. The application will start without broker connectivity and any event-driven workflows will fail.

**Required actions before upgrade:**

1. **Verify application compatibility:** Confirm that the br-ccs application version 1.1.2 (or your pinned version) no longer requires RabbitMQ for core functionality. Check application release notes and runtime requirements.

2. **Drain message queues:** If the application was actively publishing or consuming messages, ensure all pending work is completed before upgrade:

   ```bash
   kubectl -n br-ccs exec deployment/br-ccs -- curl -s http://localhost:15672/api/queues/%2F/events \
     -u "admin:ADMIN_PASSWORD" | jq '.messages'
   ```

3. **Back up RabbitMQ data:** If message history or queue state must be preserved for audit purposes, export definitions and message data before upgrade:

   ```bash
   kubectl -n br-ccs exec statefulset/br-ccs-rabbitmq -- rabbitmqctl export_definitions /tmp/definitions.json
   kubectl -n br-ccs cp br-ccs-rabbitmq-0:/tmp/definitions.json ./rabbitmq-backup-definitions.json
   ```

4. **Update values file:** Remove all `rabbitmq:` configuration and RabbitMQ-related secrets:

   ```yaml
   # Remove entire rabbitmq: block
   # Remove from brCcs.configmap:
   #   RABBITMQ_ENABLED
   #   RABBITMQ_HOST
   #   RABBITMQ_PORT_AMQP
   #   RABBITMQ_VHOST
   #   RABBITMQ_EXCHANGE
   #   (and any other RABBITMQ_* keys)
   # Remove from brCcs.secrets:
   #   RABBITMQ_DEFAULT_PASS
   #   RABBITMQ_URL
   ```

5. **Plan PVC cleanup:** The RabbitMQ PVC will not be automatically deleted. After confirming the application works without broker integration, manually delete it:

   ```bash
   kubectl -n br-ccs get pvc -l app.kubernetes.io/name=rabbitmq
   # After validation:
   kubectl -n br-ccs delete pvc data-br-ccs-rabbitmq-0
   ```

**Result after upgrade:** Application starts without `RABBITMQ_ENABLED` or any broker environment variables. RabbitMQ StatefulSet and Service are removed. Verify application health and business workflows.

---

### Scenario 3: External RabbitMQ with bootstrap job

**Current configuration (v1.0.1):**

```yaml
rabbitmq:
  enabled: false
  external: true
global:
  externalRabbitmqDefinitions:
    enabled: true
    connection:
      protocol: "https"
      host: "rabbitmq.example.com"
      port: "15671"
      portAmqp: "5671"
    rabbitmqAdminLogin:
      useExistingSecret:
        name: "rabbitmq-admin-creds"
    brCcsCredentials:
      useExistingSecret:
        name: "rabbitmq-brccs-creds"
brCcs:
  configmap:
    RABBITMQ_ENABLED: "true"
    RABBITMQ_HOST: "rabbitmq.example.com"
    RABBITMQ_PORT_AMQP: "5671"
  secrets:
    RABBITMQ_DEFAULT_PASS: "EXTERNAL_BROKER_PASSWORD"
```

> **Warning:** The bootstrap Job template and all external RabbitMQ configuration surfaces are removed in v1.0.2. The application will no longer connect to the external broker after upgrade.

**Required actions before upgrade:**

1. **Verify application compatibility:** Confirm that message broker integration is no longer required by the application runtime.

2. **Coordinate with external broker administrators:** If the external RabbitMQ instance was provisioned specifically for br-ccs, coordinate decommissioning or repurposing with the broker operations team.

3. **Drain and archive messages:** Export any required message history or audit data from the external broker before removing application connectivity.

4. **Update values file:** Remove all RabbitMQ configuration:

   ```yaml
   # Remove entire global.externalRabbitmqDefinitions: block
   # Remove from brCcs.configmap:
   #   RABBITMQ_ENABLED
   #   RABBITMQ_HOST
   #   RABBITMQ_PORT_AMQP
   #   (and any other RABBITMQ_* keys)
   # Remove from brCcs.secrets:
   #   RABBITMQ_DEFAULT_PASS
   #   RABBITMQ_URL
   ```

5. **Clean up external broker resources:** After confirming the application no longer requires broker access, remove the br-ccs user, vhost, and permissions from the external RabbitMQ instance using your broker management procedures.

**Result after upgrade:** Application starts without broker connectivity. Bootstrap Job is not created. External RabbitMQ instance remains running but br-ccs no longer publishes or consumes messages.

## Preview changes before upgrading

```bash
helm diff upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.2 -n br-ccs
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.2 -n br-ccs
```
<!-- {% endraw %} -->
