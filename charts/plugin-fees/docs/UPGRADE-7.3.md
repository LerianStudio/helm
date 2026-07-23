# Helm Upgrade from v7.2.0 to v7.3.0

# Topics

- ***[Features](#features)***
    - [1. Service Discovery Support](#1-service-discovery-support)
    - [2. Streaming Configuration](#2-streaming-configuration)
- ***[Configuration Reference](#configuration-reference)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Features

### 1. Service Discovery Support

The chart now includes full support for service discovery via Consul (lib-service-discovery), enabling automatic service registration and discovery in distributed deployments.

**New ConfigMap variables:**

```yaml
fees:
  configmap:
    SD_ADDRESS: "localhost:8500"
    SD_ENABLED: "false"
    SD_EXTERNAL_ADDRESS: ""
    SD_EXTERNAL_PORT: ""
    SD_TLS: "false"
    SD_TLS_SKIP_VERIFY: "false"
    SD_WORKLOAD: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `SD_ADDRESS` | `"localhost:8500"` | Consul server address and port |
| `SD_ENABLED` | `"false"` | Enable or disable service discovery |
| `SD_EXTERNAL_ADDRESS` | `""` | External address for service registration (e.g., load balancer IP) |
| `SD_EXTERNAL_PORT` | `""` | External port for service registration |
| `SD_TLS` | `"false"` | Enable TLS for Consul communication |
| `SD_TLS_SKIP_VERIFY` | `"false"` | Skip TLS certificate verification (not recommended for production) |
| `SD_WORKLOAD` | `""` | Workload identifier for service registration |

**New Secret variable:**

```yaml
fees:
  secrets:
    SD_TOKEN: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `SD_TOKEN` | `""` | Consul ACL token for authentication (required when Consul server enforces ACLs) |

**Why this matters:**

Service discovery enables the plugin-fees service to automatically register itself with Consul and discover other services in the cluster. This is particularly useful in microservices architectures where services need to communicate without hardcoded endpoints.

**Example: Enabling service discovery with Consul**

```yaml
fees:
  configmap:
    SD_ADDRESS: "consul-server.consul.svc.cluster.local:8500"
    SD_ENABLED: "true"
    SD_EXTERNAL_ADDRESS: "plugin-fees.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
    SD_WORKLOAD: "plugin-fees-production"
  secrets:
    SD_TOKEN: "your-consul-acl-token"
```

**Example: Enabling service discovery without TLS (development only)**

```yaml
fees:
  configmap:
    SD_ADDRESS: "consul-server.default.svc.cluster.local:8500"
    SD_ENABLED: "true"
    SD_WORKLOAD: "plugin-fees-dev"
```

> **Important:** The `SD_TOKEN` secret is only required when your Consul server enforces ACL authentication. If you're using ACLs, ensure the token has appropriate permissions for service registration and discovery.

> **Warning:** Setting `SD_TLS_SKIP_VERIFY: "true"` disables certificate validation and should only be used in development environments. Always use proper TLS certificates in production.

### 2. Streaming Configuration

The chart now exposes comprehensive configuration for event streaming (lib-streaming), enabling integration with message brokers like Kafka or RabbitMQ for event-driven architectures.

**New ConfigMap variables:**

```yaml
fees:
  configmap:
    STREAMING_CLOUDEVENTS_SOURCE: "lerian.midaz.fees"
    STREAMING_ENABLED: "false"
    STREAMING_IMPORTANT_EMIT_TIMEOUT_MS: "5000"
    STREAMING_SASL_ALLOW_PLAINTEXT: "false"
    STREAMING_SASL_MECHANISM: ""
    STREAMING_SASL_USERNAME: ""
    STREAMING_TLS_CA_CERT: ""
    STREAMING_TLS_ENABLED: "false"
```

| Flag | Default | Description |
|------|---------|-------------|
| `STREAMING_CLOUDEVENTS_SOURCE` | `"lerian.midaz.fees"` | CloudEvents source identifier for emitted events |
| `STREAMING_ENABLED` | `"false"` | Enable or disable event streaming |
| `STREAMING_IMPORTANT_EMIT_TIMEOUT_MS` | `"5000"` | Timeout in milliseconds for emitting critical events |
| `STREAMING_SASL_ALLOW_PLAINTEXT` | `"false"` | Allow SASL authentication over plaintext connections |
| `STREAMING_SASL_MECHANISM` | `""` | SASL authentication mechanism (e.g., `PLAIN`, `SCRAM-SHA-256`, `SCRAM-SHA-512`) |
| `STREAMING_SASL_USERNAME` | `""` | Username for SASL authentication |
| `STREAMING_TLS_CA_CERT` | `""` | Path to custom TLS CA certificate for broker connection |
| `STREAMING_TLS_ENABLED` | `"false"` | Enable TLS for streaming broker connections |

**Existing Secret variable (now documented):**

The `STREAMING_SASL_PASSWORD` secret variable was already present in v7.2.0 but is now fully integrated with the new streaming configuration:

```yaml
fees:
  secrets:
    STREAMING_SASL_PASSWORD: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `STREAMING_SASL_PASSWORD` | `""` | Password for SASL authentication (operator-provided, rendered into Secret) |

**Why this matters:**

Event streaming enables the plugin-fees service to emit domain events (e.g., fee calculations, transaction events) to a message broker, allowing other services to react to these events asynchronously. This is essential for building event-driven architectures and maintaining loose coupling between services.

**Example: Enabling streaming with Kafka and SASL/TLS**

```yaml
fees:
  configmap:
    STREAMING_ENABLED: "true"
    STREAMING_CLOUDEVENTS_SOURCE: "lerian.midaz.fees.production"
    STREAMING_IMPORTANT_EMIT_TIMEOUT_MS: "10000"
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-512"
    STREAMING_SASL_USERNAME: "plugin-fees-user"
    STREAMING_TLS_ENABLED: "true"
    STREAMING_TLS_CA_CERT: "/etc/ssl/certs/kafka-ca.crt"
  secrets:
    STREAMING_SASL_PASSWORD: "your-kafka-password"
```

**Example: Enabling streaming without authentication (development only)**

```yaml
fees:
  configmap:
    STREAMING_ENABLED: "true"
    STREAMING_CLOUDEVENTS_SOURCE: "lerian.midaz.fees.dev"
```

> **Note:** The `STREAMING_SASL_PASSWORD` and custom TLS CA certificate material are rendered into the plugin-fees Secret (never the ConfigMap) to maintain security. Only set these values when your streaming backend requires authentication or uses a private CA.

> **Warning:** Setting `STREAMING_SASL_ALLOW_PLAINTEXT: "true"` allows SASL credentials to be transmitted without encryption and should only be used in development environments. Always enable `STREAMING_TLS_ENABLED: "true"` in production.

> **Important:** When using a custom TLS CA certificate, ensure the certificate file is mounted into the pod at the path specified in `STREAMING_TLS_CA_CERT`. This typically requires additional volume mounts in your values configuration.

# Configuration Reference

**Complete example with all new v7.3.0 features:**

```yaml
fees:
  image:
    tag: "3.4.0"
  
  # Service Discovery configuration
  configmap:
    SD_ADDRESS: "consul-server.consul.svc.cluster.local:8500"
    SD_ENABLED: "true"
    SD_EXTERNAL_ADDRESS: "plugin-fees.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
    SD_TLS_SKIP_VERIFY: "false"
    SD_WORKLOAD: "plugin-fees-production"
    
    # Streaming configuration
    STREAMING_CLOUDEVENTS_SOURCE: "lerian.midaz.fees.production"
    STREAMING_ENABLED: "true"
    STREAMING_IMPORTANT_EMIT_TIMEOUT_MS: "10000"
    STREAMING_SASL_ALLOW_PLAINTEXT: "false"
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-512"
    STREAMING_SASL_USERNAME: "plugin-fees-user"
    STREAMING_TLS_CA_CERT: "/etc/ssl/certs/kafka-ca.crt"
    STREAMING_TLS_ENABLED: "true"
  
  secrets:
    SD_TOKEN: "your-consul-acl-token"
    STREAMING_SASL_PASSWORD: "your-kafka-password"
```

**Minimal configuration (features disabled):**

```yaml
fees:
  image:
    tag: "3.4.0"
  
  configmap:
    SD_ENABLED: "false"
    STREAMING_ENABLED: "false"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 7.3.0 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 7.3.0 -n plugin-fees
```
