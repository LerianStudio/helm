# Midaz Helm Chart

Source code can be found here:
* https://github.com/LerianStudio/midaz-helm/tree/main/charts/midaz
* https://github.com/LerianStudio/midaz

This helm chart installs [Midaz](https://lerian.studio/midaz#about), a high-performance and open-source ledger.

The default installation is similar to the one provided in the [Midaz repo](https://github.com/LerianStudio/midaz?tab=readme-ov-file#quick-installation-guide-localhost).

---

## Install Midaz Helm Chart:

To install Midaz using Helm, run the following command:

```console
$ helm install midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 1.59.0 -n midaz --create-namespace
```

This will create a new namespace called midaz if it doesn't already exist and deploy the Midaz Helm chart.

After installation, you can verify that the release was successful by listing the Helm releases in the midaz namespace:

```console
$ helm list -n midaz
```

---
## Configuring Ingress for Different Controllers

The Midaz Helm Chart optionally supports different Ingress Controllers for exposing services when necessary. It is possible to enable Ingress for the following services: Transaction, Onboarding and Console. Below are the configurations for commonly used controllers.

- **Note:** Before configuring Ingress, ensure that you have an Ingress Controller installed in your cluster. The Ingress Controller is responsible for managing external access to the services. Examples of popular Ingress Controllers include NGINX, AWS ALB, and Traefik.

### NGINX Ingress Controller
To use the **NGINX Ingress Controller**, configure the `values.yaml` as follows:

```yaml
ingress:
  enabled: true
  className: "nginx"
  // The `annotations` field is used to add custom metadata to the Nginx resource.
  // Annotations are key-value pairs that can be used to attach arbitrary non-identifying metadata to objects.
  // These annotations can be used by various tools and libraries to augment the behavior of the Nginx resource.
  // See more https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md
  annotations: {} 
  hosts:
    - host: midaz.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: midaz-tls  # Ensure this secret exists or is managed by cert-manager
      hosts:
        - midaz.example.com
```

---

### AWS ALB (Application Load Balancer)
For **AWS ALB Ingress Controller**, use the following configuration:

```yaml
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internal  # Use "internet-facing" for public ALB
    alb.ingress.kubernetes.io/target-type: ip   # Use "instance" if targeting EC2 instances
    alb.ingress.kubernetes.io/group.name: "midaz"  # Group ALB resources under this name
    alb.ingress.kubernetes.io/healthcheck-path: "/healthz"  # Health check path
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'  # Listen on HTTP and HTTPS
  hosts:
    - host: midaz.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []  # TLS is managed by the ALB using ACM certificates
```

---

### Traefik Ingress Controller
For **Traefik**, configure the `values.yaml` as follows:

```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "web, websecure"  # Entrypoints defined in Traefik
    traefik.ingress.kubernetes.io/router.tls: "true"  # Enable TLS for this route
  hosts:
    - host: midaz.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: midaz-tls  # Ensure this secret exists and contains the TLS certificate
      hosts:
        - midaz.example.com
```


## Midaz Components:

The Midaz system runs on four distinct layers that work together, distributed in segregated workloads:

### Onboarding:

| Parameter                                      | Description                                                                                | Default Value                                   |
|-----------------------------------------------|-------------------------------------------------------------------------------------------|------------------------------------------------|
| `onboarding.name`                                 | Service name.                                                                             | `"onboarding"`                                 |
| `onboarding.replicaCount`                         | Number of replicas for the onboarding service.                                            | `2`                                            |
| `onboarding.image.repository`                     | Repository for the onboarding service container image.                                    | `"lerianstudio/midaz-onboarding"`             |
| `onboarding.image.pullPolicy`                     | Image pull policy.                                                                        | `"IfNotPresent"`                               |
| `onboarding.image.tag`                            | Image tag used for deployment.                                                           | `"2.1.0"`                                      |
| `onboarding.imagePullSecrets`                     | Secrets for pulling images from a private registry.                                       | `[]`                                           |
| `onboarding.nameOverride`                         | Overrides the default generated name by Helm.                                             | `""`                                           |
| `onboarding.fullnameOverride`                     | Overrides the full name generated by Helm.                                                | `""`                                           |
| `onboarding.podAnnotations`                       | Pod annotations for additional metadata.                                                  | `{}`                                           |
| `onboarding.podSecurityContext`                   | Security context applied at the pod level.                                                | `{}`                                           |
| `onboarding.securityContext.runAsGroup`           | Defines the group ID for the user running the process inside the container.               | `1000`                                         |
| `onboarding.securityContext.runAsUser`            | Defines the user ID for the process running inside the container.                         | `1000`                                         |
| `onboarding.securityContext.runAsNonRoot`         | Ensures the process does not run as root.                                                 | `true`                                         |
| `onboarding.securityContext.capabilities.drop`    | List of capabilities to drop.                                                            | `["ALL"]`                                      |
| `onboarding.securityContext.readOnlyRootFilesystem` | Defines the root filesystem as read-only.                                                | `true`                                         |
| `onboarding.pdb.enabled`                          | Specifies whether PodDisruptionBudget is enabled.                                         | `true`                                         |
| `onboarding.pdb.minAvailable`                     | Minimum number of available pods.                                                        | `1`                                            |
| `onboarding.pdb.maxUnavailable`                   | Maximum number of unavailable pods.                                                      | `1`                                            |
| `onboarding.pdb.annotations`                      | Annotations for the PodDisruptionBudget.                                                 | `{}`                                           |
| `onboarding.deploymentUpdate.type`                | Type of deployment strategy.                                                             | `"RollingUpdate"`                              |
| `onboarding.deploymentUpdate.maxSurge`            | Maximum number of pods that can be created over the desired number of pods.              | `"100%"`                                       |
| `onboarding.deploymentUpdate.maxUnavailable`      | Maximum number of pods that can be unavailable during the update.                        | `0`                                            |
| `onboarding.service.type`                         | Kubernetes service type.                                                                 | `"ClusterIP"`                                  |
| `onboarding.service.port`                         | Port for the HTTP API.                                                                   | `3000`                                         |
| `onboarding.ingress.enabled`                      | Specifies whether Ingress is enabled.                                                    | `false`                                        |
| `onboarding.ingress.className`                    | Ingress class name.                                                                      | `""`                                           |
| `onboarding.ingress.annotations`                  | Additional ingress annotations.                                                          | `{}`                                           |
| `onboarding.ingress.hosts`                        | Configured hosts for Ingress and associated paths.                                        | `""`                                           |
| `onboarding.ingress.tls`                          | TLS configurations for Ingress.                                                          | `[]`                                           |
| `onboarding.resources.limits.cpu`                 | CPU limit allocated for the pods.                                                        | `"1500m"`                                      |
| `onboarding.resources.limits.memory`              | Memory limit allocated for the pods.                                                     | `"512Gi"`                                      |
| `onboarding.resources.requests.cpu`               | Minimum CPU request for the pods.                                                        | `"768m"`                                       |
| `onboarding.resources.requests.memory`            | Minimum memory request for the pods.                                                     | `"256Mi"`                                      |
| `onboarding.autoscaling.enabled`                  | Specifies whether autoscaling is enabled.                                                | `true`                                         |
| `onboarding.autoscaling.minReplicas`              | Minimum number of replicas for autoscaling.                                              | `2`                                            |
| `onboarding.autoscaling.maxReplicas`              | Maximum number of replicas for autoscaling.                                              | `5`                                            |
| `onboarding.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                       | `80`                                           |
| `onboarding.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling.                                    | `80`                                           |
| `onboarding.nodeSelector`                         | Node selectors for pod scheduling.                                                       | `{}`                                           |
| `onboarding.tolerations`                          | Tolerations for pod scheduling.                                                          | `{}`                                           |
| `onboarding.affinity`                             | Affinity rules for pod scheduling.                                                       | `{}`                                           |
| `onboarding.configmap`                            | Additional configurations in ConfigMap.                                                  | See default values in the configuration.       |
| `onboarding.secrets`                              | Additional secrets for the service.                                                      | See default values in the configuration.       |
| `onboarding.serviceAccount.create`                | Specifies whether the service account should be created.                                 | `true`                                         |
| `onboarding.serviceAccount.annotations`           | Annotations for the service account.                                                     | `{}`                                           |
| `onboarding.serviceAccount.name`                  | Service account name. If not defined, it will be generated automatically.                | `""`                                           |

### Transaction Configuration

| Parameter                                    | Description                                                                                     | Default Value                                   |
|---------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------|
| `transaction.name`                         | Service name.                                                                                 | `"transaction"`                                |
| `transaction.replicaCount`                 | Number of replicas for the transaction service.                                               | `1`                                            |
| `transaction.image.repository`             | Repository for the transaction service container image.                                       | `"lerianstudio/midaz-transaction"`            |
| `transaction.image.pullPolicy`             | Image pull policy.                                                                            | `"IfNotPresent"`                               |
| `transaction.image.tag`                    | Image tag used for deployment.                                                               | `"2.1.0"`                                      |
| `transaction.imagePullSecrets`             | Secrets for pulling images from a private registry.                                           | `[]`                                           |
| `transaction.nameOverride`                 | Overrides the default generated name by Helm.                                                 | `""`                                           |
| `transaction.fullnameOverride`             | Overrides the full name generated by Helm.                                                    | `""`                                           |
| `transaction.podAnnotations`               | Pod annotations for additional metadata.                                                      | `{}`                                           |
| `transaction.podSecurityContext`           | Security context for the pod.                                                                 | `{}`                                           |
| `transaction.securityContext.runAsGroup`   | Defines the group ID for the user running the process inside the container.                   | `1000`                                         |
| `transaction.securityContext.runAsUser`    | Defines the user ID for the process running inside the container.                             | `1000`                                         |
| `transaction.securityContext.runAsNonRoot` | Ensures the process does not run as root.                                                     | `true`                                         |
| `transaction.securityContext.capabilities.drop` | List of Linux capabilities to drop.                                                          | `["ALL"]`                                      |
| `transaction.securityContext.readOnlyRootFilesystem` | Defines the root filesystem as read-only.                                                    | `true`                                         |
| `transaction.pdb.enabled`                  | Enable or disable PodDisruptionBudget.                                                       | `true`                                         |
| `transaction.pdb.minAvailable`             | Minimum number of available pods.                                                            | `2`                                            |
| `transaction.pdb.maxUnavailable`           | Maximum number of unavailable pods.                                                          | `1`                                            |
| `transaction.pdb.annotations`              | Annotations for the PodDisruptionBudget.                                                     | `{}`                                           |
| `transaction.deploymentUpdate.type`        | Type of deployment strategy.                                                                 | `"RollingUpdate"`                              |
| `transaction.deploymentUpdate.maxSurge`    | Maximum number of pods that can be created over the desired number of pods.                  | `"100%"`                                       |
| `transaction.deploymentUpdate.maxUnavailable` | Maximum number of pods that can be unavailable during the update.                            | `0`                                            |
| `transaction.service.type`                 | Kubernetes service type.                                                                     | `"ClusterIP"`                                  |
| `transaction.service.port`                 | Port for the HTTP API.                                                                       | `3001`                                         |
| `transaction.ingress.enabled`              | Enable or disable ingress.                                                                   | `false`                                        |
| `transaction.ingress.className`            | Ingress class name.                                                                          | `""`                                           |
| `transaction.ingress.annotations`          | Additional ingress annotations.                                                              | `{}`                                           |
| `transaction.ingress.hosts`                | Configured hosts for ingress and associated paths.                                           | `[{host: "", paths: [{path: "/", pathType: "Prefix"}]}]` |
| `transaction.ingress.tls`                  | TLS configuration for ingress.                                                               | `[]`                                           |
| `transaction.resources.limits.cpu`         | CPU limit allocated for the pods.                                                            | `"2000m"`                                      |
| `transaction.resources.limits.memory`      | Memory limit allocated for the pods.                                                         | `"512Gi"`                                      |
| `transaction.resources.requests.cpu`       | Minimum CPU request for the pods.                                                            | `"768m"`                                       |
| `transaction.resources.requests.memory`    | Minimum memory request for the pods.                                                         | `"256Mi"`                                      |
| `transaction.autoscaling.enabled`          | Enable or disable horizontal pod autoscaling.                                                | `true`                                         |
| `transaction.autoscaling.minReplicas`      | Minimum number of replicas for autoscaling.                                                  | `3`                                            |
| `transaction.autoscaling.maxReplicas`      | Maximum number of replicas for autoscaling.                                                  | `9`                                            |
| `transaction.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                      | `70`                                           |
| `transaction.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling.                                  | `80`                                           |
| `transaction.nodeSelector`                 | Node selector for scheduling pods on specific nodes.                                         | `{}`                                           |
| `transaction.tolerations`                  | Tolerations for scheduling on tainted nodes.                                                 | `{}`                                           |
| `transaction.affinity`                     | Affinity rules for pod scheduling.                                                          | `{}`                                           |
| `transaction.configmap`                    | ConfigMap for environment variables and configurations.                                      | See default values in the configuration.       |
| `transaction.secrets`                      | Secrets for storing sensitive data.                                                         | See default values in the configuration.       |
| `transaction.serviceAccount.create`        | Specifies whether a ServiceAccount should be created.                                        | `true`                                         |
| `transaction.serviceAccount.annotations`   | Annotations for the ServiceAccount.                                                         | `{}`                                           |
| `transaction.serviceAccount.name`          | Name of the service account.                                                                | `""`                                           |


### Console:

| Parameter                                     | Description                                                                                     | Default Value                                   |
|----------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------|
| `console.name`                                | Service name.                                                                      | `"console"`                                   |
| `console.enabled`                             | Enable or disable the console service.                                                         | `true`                                         |
| `console.replicaCount`                        | Number of replicas for the deployment.                                                         | `1`                                            |
| `console.image.repository`                    | Docker image repository for Console.                                                           | `"lerianstudio/midaz-console"`                |
| `console.image.pullPolicy`                    | Docker image pull policy.                                                                      | `"IfNotPresent"`                              |
| `console.image.tag`                           | Docker image tag used for deployment.                                                          | `"1.25.1"`                                    |
| `console.imagePullSecrets`                    | Secrets for pulling Docker images from a private registry.                                     | `[]`                                           |
| `console.nameOverride`                        | Overrides the resource name.                                                                   | `""`                                          |
| `console.fullnameOverride`                    | Overrides the full resource name.                                                              | `""`                                          |
| `console.podAnnotations`                      | Annotations for the pods.                                                                      | `{}`                                           |
| `console.podSecurityContext`                  | Security context applied at the pod level.                                                     | `{}`                                           |
| `console.securityContext.runAsGroup`          | Defines the group ID for the user running the process inside the container.                    | `1000`                                         |
| `console.securityContext.runAsUser`           | Defines the user ID for the process running inside the container.                              | `1000`                                         |
| `console.securityContext.runAsNonRoot`        | Ensures the process does not run as root.                                                      | `true`                                         |
| `console.securityContext.capabilities.drop`   | List of Linux capabilities to drop.                                                            | `["ALL"]`                                      |
| `console.securityContext.readOnlyRootFilesystem` | Defines the root filesystem as read-only.                                                     | `true`                                         |
| `console.pdb.enabled`                         | Specifies whether PodDisruptionBudget is enabled.                                              | `false`                                        |
| `console.pdb.minAvailable`                    | Minimum number of available pods for PodDisruptionBudget.                                      | `1`                                            |
| `console.pdb.maxUnavailable`                  | Maximum number of unavailable pods for PodDisruptionBudget.                                    | `1`                                            |
| `console.pdb.annotations`                     | Annotations for the PodDisruptionBudget.                                                      | `{}`                                           |
| `console.deploymentUpdate.type`               | Type of deployment strategy.                                                                   | `"RollingUpdate"`                              |
| `console.deploymentUpdate.maxSurge`           | Maximum number of pods that can be created over the desired number of pods.                   | `"100%"`                                       |
| `console.deploymentUpdate.maxUnavailable`     | Maximum number of pods that can be unavailable during the update.                              | `0`                                            |
| `console.service.type`                        | Kubernetes service type.                                                                       | `"ClusterIP"`                                  |
| `console.service.port`                        | Service port.                                                                                  | `8081`                                         |
| `console.ingress.enabled`                     | Specifies whether Ingress is enabled.                                                          | `false`                                        |
| `console.ingress.className`                   | Ingress class name.                                                                            | `""`                                           |
| `console.ingress.annotations`                 | Additional annotations for Ingress.                                                           | `{}`                                           |
| `console.ingress.hosts`                       | Configured hosts for Ingress and associated paths.                                             | `[{ "host": "", "paths": [{ "path": "/", "pathType": "Prefix" }] }]` |
| `console.ingress.tls`                         | TLS configurations for Ingress.                                                               | `[]`                                           |
| `console.resources.limits.cpu`                | CPU limit allocated for the pods.                                                             | `"200m"`                                       |
| `console.resources.limits.memory`             | Memory limit allocated for the pods.                                                          | `"256Mi"`                                      |
| `console.resources.requests.cpu`              | Minimum CPU request for the pods.                                                             | `"100m"`                                       |
| `console.resources.requests.memory`           | Minimum memory request for the pods.                                                          | `"128Mi"`                                      |
| `console.autoscaling.enabled`                 | Specifies whether horizontal pod autoscaling is enabled.                                       | `true`                                         |
| `console.autoscaling.minReplicas`             | Minimum number of replicas for autoscaling.                                                   | `1`                                            |
| `console.autoscaling.maxReplicas`             | Maximum number of replicas for autoscaling.                                                   | `3`                                            |
| `console.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                            | `80`                                           |
| `console.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling.                                         | `80`                                           |
| `console.nodeSelector`                        | Node selectors for pod scheduling.                                                            | `{}`                                           |
| `console.tolerations`                         | Tolerations for pod scheduling.                                                               | `{}`                                           |
| `console.affinity`                            | Affinity rules for pod scheduling.                                                            | `{}`                                           |
| `console.configmap`                           | Additional configurations in ConfigMap.                                                       | See default values in the configuration.       |
| `console.secrets`                             | Additional secrets for the service.                                                          | `{}`                                           |
| `console.serviceAccount.create`               | Specifies whether the service account should be created.                                      | `true`                                         |
| `console.serviceAccount.annotations`          | Annotations for the service account.                                                         | `{}`                                           |
| `console.serviceAccount.name`                 | Service account name. If not defined, it will be generated automatically.                    | `""`                                           |

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
- **Note:** If you have an existing RabbitMQ instance, you can disable this dependency and configure Midaz Components to use your external RabbitMQ, like this:
  
- **Important:** When using an external RabbitMQ instance, it is essential to load the RabbitMQ definitions from the [`load_definitions.json`](https://github.com/LerianStudio/midaz-helm/blob/main/charts/midaz/files/rabbitmq/load_definitions.json) file. These definitions contain crucial configurations (queues, exchanges, bindings) required for Midaz Components to function correctly. Without these definitions, Midaz Components will not operate as expected.

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
