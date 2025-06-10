## Dependencies:

This Chart has the following dependencies for the project's default installation. All dependencies are enabled by default.

### Valkey

- **Version:** 2.4.7
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `valkey.enabled` to `false` in the values file.
- **Note:** If you have an existing Valkey or Redis instance, you can disable this dependency and configure Midaz Components to use your external instance, like this:

  ```yaml
  onboarding:
    configmap:
      REDIS_HOST: { your-host }
      REDIS_PORT: { your-host-port }
      REDIS_USER: { your-host-user }

    secrets:
      REDIS_PASSWORD: { your-host-pass }

  transaction:
    configmap:
      REDIS_HOST: { your-host }
      REDIS_PORT: { your-host-port }
      REDIS_USER: { your-host-user }

    secrets:
      REDIS_PASSWORD: { your-host-pass }
  ```
  
### PostgreSQL

- **Version:** 16.3.0
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `postgresql.enabled` to `false` in the values file.
- **Note:** If you have an existing PostgreSQL instance, you can disable this dependency and configure Midaz Components to use your external PostgreSQL, like this:

  ```yaml
  onboarding:
    configmap:
      DB_HOST: { your-host }
      DB_USER: { your-host-user }
      DB_PORT: { your-host-port }
      ## DB Replication
      DB_REPLICA_HOST: { your-replication-host }
      DB_REPLICA_USER: { your-replication-host-user }
      DB_REPLICA_PORT: { your-replication-host-port}
    
    secrets:
      DB_PASSWORD: { your-host-pass }
      DB_REPLICA_PASSWORD: { your-replication-host-pass }

  transaction:
    configmap:
      DB_HOST: { your-host }
      DB_USER: { your-host-user }
      DB_PORT: { your-host-port }
      ## DB Replication
      DB_REPLICA_HOST: { your-replication-host }
      DB_REPLICA_USER: { your-replication-host-user }
      DB_REPLICA_PORT: { your-replication-host-port}
    
    secrets:
      DB_PASSWORD: { your-host-pass }
      DB_REPLICA_PASSWORD: { your-replication-host-pass }
  ```

### MongoDB

- **Version:** 15.4.5
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `mongodb.enabled` to `false` in the values file.
- **Note:** If you have an existing MongoDB instance, you can disable this dependency and configure Midaz Components to use your external MongoDB, like this:

  ```yaml

  console:
    configmap:
      MONGODB_URI: "mongodb://{your-host-user}:{your-host-pass}@{your-host}:{your-host-port}/?directConnection=true"
      MONGODB_USER: { your-host-user }
    
    secrets:
      MONGODB_PASS: { your-host-pass }

  onboarding:
    configmap:
      MONGO_HOST: { your-host }
      MONGO_NAME: { your-host-name }
      MONGO_USER: { your-host-user }
      MONGO_PORT: { your-host-port }
    
    secrets:
      MONGO_PASSWORD: { your-host-pass }

  transaction:
    configmap:
      MONGO_HOST: { your-host }
      MONGO_NAME: { your-host-name }
      MONGO_USER: { your-host-user }
      MONGO_PORT: { your-host-port }
    
    secrets:
      MONGO_PASSWORD: { your-host-pass }

  ```


### RabbitMQ

- **Version:** 16.0.0
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `rabbitmq.enabled` to `false` in the values file.
  
- **Important:** When using an external RabbitMQ instance, it is essential to load the RabbitMQ definitions from the [`load_definitions.json`](https://github.com/LerianStudio/midaz-helm/blob/main/charts/midaz/files/rabbitmq/load_definitions.json) file. These definitions contain crucial configurations (queues, exchanges, bindings) required for Midaz Components to function correctly. Without these definitions, Midaz Components will not operate as expected.

- **You have two options to load the definitions:**

1. **Automatically:**
Enable the flag below in your values.yaml to automatically create a Kubernetes Job that applies the default RabbitMQ definitions to your external RabbitMQ instance:

      ```yaml
      global:
        # -- Enable or disable loading of default RabbitMQ definitions to external host
        externalRabbitmqDefinitions:
          enabled: true
      ```
    ⚠️ **Note:** This Job runs only on the first installation of the chart because it uses a Helm post-install hook. It will not run during upgrades or re-installs unless the release is deleted and installed again. Use this option for initial setup only.

2. **Manually:**
You can also manually apply the definitions using RabbitMQ’s HTTP API with the following command:

    ```console
    curl -u { your-host-user }: { your-host-pass } -X POST -H "Content-Type: application/json" -d @load_definitions.json http://{ your-host }: { your-host-port }/api/definitions
    ```
    The load_definitions.json file is located at:

    ```console
    charts/midaz/files/rabbitmq/load_definitions.json
    ```
  
- **Note:** If you have an existing RabbitMQ instance, you can disable this dependency and configure Midaz Components to use your external RabbitMQ, like this:

    ```yaml
    onboarding:
    configmap:
      RABBITMQ_HOST: { your-host }
      RABBITMQ_DEFAULT_USER: { your-host-user }
      RABBITMQ_PORT_HOST: { your-host-port }
      RABBITMQ_PORT_AMQP: { your-host-amqp-port }
      
    secrets:
      RABBITMQ_DEFAULT_PASS: { your-host-pass }

  transaction:
    configmap:
      RABBITMQ_HOST: { your-host }
      RABBITMQ_DEFAULT_USER: { your-host-user }
      RABBITMQ_PORT_HOST: { your-host-port }
      RABBITMQ_PORT_AMQP: { your-host-amqp-port }
      
    secrets:
      RABBITMQ_DEFAULT_PASS: { your-host-pass }
  ```

## Observability

We are using [Grafana Docker OpenTelemetry LGTM](https://github.com/grafana/docker-otel-lgtm) for observability in this project. This component helps in collecting, processing, and exporting telemetry data like traces and metrics.

You can access the observability dashboard in two ways:

1. To access the observability dashboard, forward the Grafana port:

```console
$ kubectl port-forward svc/midaz-grafana 3000:3000 -n midaz
```

Then, open your browser and navigate to http://localhost:3000.

2. Configuring Internal or External Ingress with Custom DNS

If you want to access the observability dashboard internally using a custom DNS (e.g., within your Kubernetes cluster or private network), you can enable and configure the Ingress for the grafana component in the values.yaml file. Here's an example configuration for an internal Ingress:

```yaml
grafana:
  enabled: true
  name: grafana

  ingress:
    enabled: true
    className: "nginx"  # Use an internal Ingress class (e.g., nginx-internal)
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
      # Optional: Use the following annotation to restrict access to internal networks
      nginx.ingress.kubernetes.io/whitelist-source-range: ""
    hosts:
      - host: "midaz-ote.example.com"  # Replace with your custom internal DNS
        paths:
          - path: /
            pathType: Prefix
    tls: []  # TLS is optional for internal access
```

If necessary, the deployment of this component can be disabled by setting `otel.enabled` to `false` in the values file.

```yaml
grafana:
  enabled: false
```