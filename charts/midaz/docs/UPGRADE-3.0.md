# Upgrade from v2.x to v3.x

## Breaking Changes

### 1. Consolidation of REDIS_PORT into REDIS_HOST

The REDIS_PORT environment variable has been removed. Its value must now be included directly in the REDIS_HOST variable as <host>:<port>. For example:

  This change affects the following components:
  - `onboarding`
  - `transaction`

    ### Old configuration
        REDIS_HOST=redis_host
        REDIS_PORT=redis_port 

    ### New configuration
        REDIS_HOST=redis_host:redis_port

    ⚠️ Make sure to remove REDIS_PORT from your environment and update REDIS_HOST accordingly to avoid connectivity issues.

## Additions

### 1. Onboarding: New Environment Variable ACCOUNT_TYPE_VALIDATION

A new environment variable has been introduced to the onboarding service:

```
#ACCOUNTING CONFIG
#List of <organization-id>:<ledger-id> separated by comma

ACCOUNT_TYPE_VALIDATION=
```

Use this to specify which ledgers are valid for account creation per organization.

### 2. Transaction: New Environment Variable TRANSACTION_ROUTE_VALIDATION

A new environment variable has been introduced to the transaction service:

```
#ACCOUNTING CONFIG
#List of <organization-id>:<ledger-id> separated by comma

TRANSACTION_ROUTE_VALIDATION=
```

Use this to define which ledgers are allowed per organization for transaction routing validation.

### 3. Redis: New Environment Variables

The following environment variables have been introduced to the onboarding and transaction services:

```yaml
onboarding:
    configmap:
        # USE ONLY ON SENTINEL
        REDIS_MASTER_NAME=

        # TLS CONFIGURATION
        REDIS_TLS=false
        REDIS_CA_CERT=

        # GCP IAM AUTHENTICATION
        REDIS_USE_GCP_IAM=false
        REDIS_SERVICE_ACCOUNT=
        GOOGLE_APPLICATION_CREDENTIALS=
        # <= 60 minutes
        REDIS_TOKEN_LIFETIME=60
        # minutes
        REDIS_TOKEN_REFRESH_DURATION=45

        # AUTH & DB SELECTION
        REDIS_PASSWORD=lerian
        REDIS_DB=0
        REDIS_PROTOCOL=3

        # POOL & RETRY CONFIGURATION
        REDIS_POOL_SIZE=10
        REDIS_MIN_IDLE_CONNS=0
        # Seconds
        REDIS_READ_TIMEOUT=3
        REDIS_WRITE_TIMEOUT=3
        REDIS_DIAL_TIMEOUT=5
        REDIS_POOL_TIMEOUT=2

        REDIS_MAX_RETRIES=3
        # Milliseconds
        REDIS_MIN_RETRY_BACKOFF=8
        # Seconds
        REDIS_MAX_RETRY_BACKOFF=1
```
***Notes:*** you can keep these default values.

### 4. Enterprise: Plugin Gateway with NGINX Proxy for UIs

A new optional NGINX component has been introduced to serve as a gateway/proxy for the UI of activated plugins in enterprise deployments.

    •	By default, this dependency is disabled.
    •	It can be enabled per customer based on the plugins they have access to.
    •	This gateway simplifies the routing and mounting of plugin frontends under the midaz-console domain.

New environment variables have been added to the midaz-console to support this feature:

```yaml
console:
    configmap:
        NEXT_PUBLIC_MIDAZ_CONSOLE_BASE_URL: #if you use a custom domain, update this value accordingly. Example: https://midaz-console.yourdomain.io
        NGINX_PORT: 8080
        NGINX_HOST: midaz-nginx.midaz.svc.cluster.local
        NGINX_BASE_PATH: http://midaz-nginx.midaz.svc.cluster.local:8080
```

New Helm parameters were also introduced:

```yaml
console:
  # Plugins UIs
  pluginsUi:
    enabled: false
    plugins:
      plugin-smart-templates-ui:
        enabled: false
        port: 8083
      plugin-crm-ui:
        enabled: false
        port: 8084
      plugin-fees-ui:
        enabled: false
        port: 8082
  ...
```

```yaml
nginx:
  enabled: false

  service:
    type: ClusterIP
    ports:
      http: 8080

  existingServerBlockConfigmap: "midaz-console-nginx-config"

  # Mount the plugins configmap as a volume
  extraVolumes:
    - name: nginx-plugins-config
      configMap:
        name: midaz-console-nginx-config-plugins

  # Mount the volume into the nginx container
  extraVolumeMounts:
    - name: nginx-plugins-config
      mountPath: /opt/bitnami/nginx/conf/plugins_blocks
  
  ingress:
    enabled: false
    pathType: Prefix
    hostname: ""
    path: /
    annotations: {}
    ingressClassName: ""
``` 

### 5. Enterprise: OTEL Collector for Enterprise Support

A new optional OTEL Collector component has been introduced for enterprise clients who want to send metrics to Lerian's telemetry stack. This collector is disabled by default and can be enabled in values:

```yaml
otel-collector-lerian:
  enabled: true
```

To redirect metrics to a custom Prometheus adapter on the customer's side, modify:

```yaml
otel-collector-lerian:
  exporters:
    prometheus/local:
      endpoint: "http://<customer-prometheus-endpoint>:9090"
```

