# Helm Upgrade from v2.x to v3.x

# Topics  

- ***[Breaking Changes](#breaking-changes)***
    - [1. Consolidation of REDIS_PORT into REDIS_HOST](#1-consolidation-of-redis_port-into-redis_host)
    - [2. App Bump Version](#2-app-bump-version)
- ***[Additions](#additions)***
    - [1. Onboarding: New Environment Variable ACCOUNT_TYPE_VALIDATION](#1-onboarding-new-environment-variable-account_type_validation)
    - [2. Transaction: New Environment Variable TRANSACTION_ROUTE_VALIDATION](#2-transaction-new-environment-variable-transaction_route_validation)
    - [3. Redis: New Environment Variables](#3-redis-new-environment-variables)
    - [4. Enterprise: A Gateway with NGINX Proxy for Plugins UIs](#4-enterprise-a-gateway-with-nginx-proxy-for-plugins-uis)
    - [5. Enterprise: OTEL Collector](#5-enterprise-otel-collector)
    - [6. External Secrets Support](#6-external-secrets-support)
- ***[Command to upgrade](#command-to-upgrade)***

## Breaking Changes

### 1. Consolidation of REDIS_PORT into REDIS_HOST

The REDIS_PORT environment variable has been removed. Its value must now be included directly in the REDIS_HOST variable as <host>:<port>. For example:

This change affects the following components:
- `onboarding`
- `transaction`

#### Old configuration
```yaml
    REDIS_HOST=redis_host
    REDIS_PORT=redis_port 
```

#### New configuration
```yaml
    REDIS_HOST=redis_host:redis_port
```

***Note:*** See the [onboarding configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/onboarding/configmap.yaml) and [transaction configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/transaction/configmap.yaml) templates for more details.


⚠️ Make sure to remove REDIS_PORT from your environment and update REDIS_HOST accordingly to avoid connectivity issues.

### 2. App Bump Version

#### The app version has been bumped to v3.0.0.

For more details, refer to the [app changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).



## Additions

### 1. Onboarding: New Environment Variable ACCOUNT_TYPE_VALIDATION

A new environment variable has been introduced to the onboarding service:

```yaml
#ACCOUNTING CONFIG
#List of <organization-id>:<ledger-id> separated by comma

ACCOUNT_TYPE_VALIDATION=
```
***Note:*** See the [onboarding configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/onboarding/configmap.yaml) template for more details.

Use this to specify which ledgers are valid for account creation per organization.

### 2. Transaction: New Environment Variable TRANSACTION_ROUTE_VALIDATION

A new environment variable has been introduced to the transaction service:

```yaml
#ACCOUNTING CONFIG
#List of <organization-id>:<ledger-id> separated by comma

TRANSACTION_ROUTE_VALIDATION=
```
***Note:*** See the [transaction configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/transaction/configmap.yaml) template for more details.

Use this to define which ledgers are allowed per organization for transaction routing validation.

### 3. Redis: New Environment Variables

The following environment variables have been introduced to the onboarding and transaction services:

```yaml
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
***Note:*** you can keep these default values. See the [onboarding configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/onboarding/configmap.yaml) and [transaction configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/transaction/configmap.yaml) templates for more details.


### 4. Enterprise: A Gateway with NGINX Proxy for Plugins UIs

A new optional NGINX component has been introduced to serve as a gateway/proxy for the plugins UIs of activated plugins in enterprise deployments.

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
***Note:*** See the [console configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/console/configmap.yaml) template for more details.

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
***Note:*** See the [console section in values](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/midaz/values.yaml#L14-L22) for more details.

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
***Note:*** See the [nginx section in values](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/midaz/values.yaml#L24-L36) for more details.

### 5. Enterprise: OTEL Collector

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
***Note:*** See the [otel-collector-lerian section in values](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/midaz/values.yaml#L38-L46) for more details.

### 6. External Secrets Support

Now you can use external secrets to store sensitive data.

```yaml
console:
    useExistingSecrets: true
    existingSecretName: <existing-secret-name>
```

***Note:*** See the [console secrets template](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/midaz/templates/console/secrets.yaml) for get the secrets names.

```yaml
onboarding:
    useExistingSecrets: true
    existingSecretName: <existing-secret-name>
```

***Note:*** See the [onboarding secrets template](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/midaz/templates/onboarding/secrets.yaml) for get the secrets names.

```yaml
transaction:
    useExistingSecrets: true
    existingSecretName: <existing-secret-name>
```

***Note:*** See the [transaction secrets template](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/midaz/templates/transaction/secrets.yaml) for get the secrets names.

## Command to upgrade

```bash
$ helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 3.0.0 -n midaz
```
