Source code can be found here:
* https://github.com/LerianStudio/midaz-helm/tree/main/charts/midaz
* https://github.com/LerianStudio/midaz

This helm chart installs [Midaz](https://lerian.studio/midaz#about), a high-performance and open-source ledger.

The default installation is similar to the one provided in the [Midaz repo](https://github.com/LerianStudio/midaz?tab=readme-ov-file#quick-installation-guide-localhost).

---
## Install:

To install Midaz using Helm, run the following command:

```console
$ helm install midaz oci://registry-1.docker.io/lerianstudio/midaz-helm-standalone --version 1.48.0 -n midaz --create-namespace
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
| `onboarding.name`                                 | Resource name.                                                                            | `"onboarding"`                                     |
| `onboarding.replicaCount`                         | Number of replicas.                                                                       | `2`                                            |
| `onboarding.image.repository`                     | Docker image repository for onboarding.                                                       | `"lerianstudio/midaz-onboarding"`                 |
| `onboarding.image.pullPolicy`                     | Docker image pull policy.                                                                 | `"IfNotPresent"`                               |
| `onboarding.image.tag`                            | Docker image tag. Overrides the chart appVersion.                                         | `"1.46.0"`                                     |
| `onboarding.imagePullSecrets`                     | Secrets for pulling images from private registries.                                       | `[]`                                           |
| `onboarding.nameOverride`                         | Overrides the name of the release.                                                        | `""`                                           |
| `onboarding.fullnameOverride`                     | Overrides the full name of the release.                                                   | `""`                                           |
| `onboarding.podAnnotations`                       | Annotations for the pods.                                                                 | `[]`                                           |
| `onboarding.podSecurityContext`                   | Security context applied at the pod level.                                                | `{}`                                           |
| `onboarding.securityContext`                      | Security context applied at the container level.                                          | `{}`                                           |
| `onboarding.service.type`                         | Service type.                                                                             | `"ClusterIP"`                                  |
| `onboarding.service.port`                         | Service port.                                                                             | `3000`                                         |
| `onboarding.service.grpcPort`                     | gRPC service port.                                                                        | `3001`                                         |
| `onboarding.ingress.enabled`                      | Specifies whether Ingress is enabled.                                                     | `false`                                        |
| `onboarding.ingress.className`                    | Ingress class.                                                                            | `""`                                           |
| `onboarding.ingress.annotations`                  | Annotations for Ingress, including ALB configurations.                                    | `[]`                                           |
| `onboarding.ingress.hosts`                        | Configured hosts for Ingress and associated paths.                                        | `""`                                           |
| `onboarding.ingress.tls`                          | TLS configurations for Ingress.                                                           | `[]`                                           |
| `onboarding.resources.limits.cpu`                 | CPU limit allocated for the pods.                                                         | `"200m"`                                       |
| `onboarding.resources.limits.memory`              | Memory limit allocated for the pods.                                                      | `"256Mi"`                                      |
| `onboarding.resources.requests.cpu`               | Minimum CPU request for the pods.                                                         | `"100m"`                                       |
| `onboarding.resources.requests.memory`            | Minimum memory request for the pods.                                                      | `"128Mi"`                                      |
| `onboarding.autoscaling.enabled`                  | Specifies whether autoscaling is enabled.                                                 | `true`                                         |
| `onboarding.autoscaling.minReplicas`              | Minimum number of replicas for autoscaling.                                               | `1`                                            |
| `onboarding.autoscaling.maxReplicas`              | Maximum number of replicas for autoscaling.                                               | `3`                                            |
| `onboarding.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                        | `80`                                           |
| `onboarding.nodeSelector`                         | Node selectors for pod scheduling.                                                        | `{}`                                           |
| `onboarding.tolerations`                          | Tolerations for pod scheduling.                                                           | `{}`                                           |
| `onboarding.affinity`                             | Affinity rules for pod scheduling.                                                        | `{}`                                           |
| `onboarding.configmap`                            | Additional configurations in ConfigMap.                                                   | `{}`                                           |
| `onboarding.secrets`                              | Additional secrets for the service.                                                       | `{}`                                           |
| `onboarding.serviceAccount.create`                | Specifies whether the service account should be created.                                  | `true`                                         |
| `onboarding.serviceAccount.annotations`           | Annotations for the service account.                                                      | `{}`                                           |
| `onboarding.serviceAccount.name`                  | Service account name. If not defined, it will be generated automatically.                 | `""`                                           |

### Transaction:

| Parameter                                    | Description                                                                                     | Default Value                                   |
|---------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------|
| `transaction.name`                         | Transaction resource name.                                                                 | `"transaction"`                                |
| `transaction.replicaCount`                 | Number of service replicas.                                                              | `1`                                            |
| `transaction.image.repository`             | Docker image repository for Transaction.                                                | `"lerianstudio/midaz-transaction"`            |
| `transaction.image.pullPolicy`             | Docker image pull policy.                                                          | `"IfNotPresent"`                               |
| `transaction.image.tag`                    | Docker image tag.                                                                        | `"1.46.0"`                                     |
| `transaction.podAnnotations`               | Annotations for the pods.                                                                     | `{}`                                           |
| `transaction.service.type`                 | Service type.                                                                             | `"ClusterIP"`                                  |
| `transaction.service.port`                 | Service port.                                                                            | `3001`                                         |
| `transaction.ingress.enabled`              | Specifies whether Ingress is enabled.                                                        | `false`                                        |
| `transaction.ingress.className`            | Ingress class.                                                                           | `""`                                           |
| `transaction.ingress.annotations`          | Annotations for Ingress.                                                                   | `{}`                                           |
| `transaction.ingress.hosts`                | Configured hosts for Ingress and associated paths.                                     | `""`                                           |
| `transaction.ingress.tls`                  | TLS configurations for Ingress.                                                           | `[]`                                           |
| `transaction.resources.limits.cpu`         | CPU limit allocated for the pods.                                                         | `"200m"`                                       |
| `transaction.resources.limits.memory`      | Memory limit allocated for the pods.                                                     | `"256Mi"`                                      |
| `transaction.resources.requests.cpu`       | Minimum CPU request for the pods.                                                      | `"100m"`                                       |
| `transaction.resources.requests.memory`    | Minimum memory request for the pods.                                                  | `"128Mi"`                                      |
| `transaction.autoscaling.enabled`          | Specifies whether autoscaling is enabled.                                                    | `true`                                         |
| `transaction.autoscaling.minReplicas`      | Minimum number of replicas for autoscaling.                                                 | `1`                                            |
| `transaction.autoscaling.maxReplicas`      | Maximum number of replicas for autoscaling.                                                 | `3`                                            |
| `transaction.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                      | `80`                                           |
| `transaction.nodeSelector`                 | Node selectors for pod scheduling.                                     | `{}`                                           |
| `transaction.tolerations`                  | Tolerations for pod scheduling.                                                     | `{}`                                           |
| `transaction.affinity`                     | Affinity rules for pod scheduling.                                              | `{}`                                           |
| `transaction.configmap`                    | Additional configurations in ConfigMap.                                                     | `{}`                                           |
| `transaction.secrets`                      | Additional secrets for the service.                                                        | `{}`                                           |
| `transaction.serviceAccount.create`        | Specifies whether the service account should be created.                                               | `true`                                         |
| `transaction.serviceAccount.annotations`   | Annotations for the service account.                                                         | `{}`                                           |
| `transaction.serviceAccount.name`          | Service account name. If not defined, it will be generated automatically.                    | `""`                                           |                                    |


### Console:

| Parameter                                     | Description                                                                                     | Default Value                                   |
|----------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------|
| `console.name`                                | Resource name.                                                                      | `"console"`                                   |
| `console.replicaCount`                        | Number of replicas.                                                              | `1`                                            |
| `console.image.repository`                    | Docker image repository for Console.                                                     | `"lerianstudio/midaz-console"`                |
| `console.image.pullPolicy`                    | Docker image pull policy.                                                          | `"IfNotPresent"`                              |
| `console.image.tag`                           | Docker image tag. Overrides the default chart appVersion.                                  | `"1.2.0"`                                     |
| `console.imagePullSecrets`                    | Secrets for pulling Docker images.                                                        | `[]`                                           |
| `console.nameOverride`                        | Overrides the resource name.                                                              | `""`                                          |
| `console.fullnameOverride`                    | Overrides the full resource name.                                                         | `""`                                          |
| `console.podAnnotations`                      | Annotations for the pods.                                                                     | `{}`                                           |
| `console.podSecurityContext`                  | Security context applied at the pod level.                                                  | `{}`                                           |
| `console.securityContext`                     | Security context applied at the container level.                                            | `{}`                                           |
| `console.service.type`                        | Service type.                                                                             | `"ClusterIP"`                                 |
| `console.service.port`                        | Service port.                                                                            | `8081`                                         |
| `console.ingress.enabled`                     | Specifies whether Ingress is enabled.                                                        | `false`                                        |
| `console.ingress.className`                   | Ingress class.                                                                           | `""`                                         |
| `console.ingress.annotations`                 | Annotations for Ingress, including ALB configurations.                                    |  `[]`                                          |
| `console.ingress.hosts`                       | Configured hosts for Ingress and associated paths.                                     | `""` |
| `console.ingress.tls`                         | TLS configurations for Ingress.                                                           | `[]`                                           |
| `console.resources.limits.cpu`                | CPU limit allocated for the pods.                                                         | `"200m"`                                     |
| `console.resources.limits.memory`             | Memory limit allocated for the pods.                                                     | `"256Mi"`                                    |
| `console.resources.requests.cpu`              | Minimum CPU request for the pods.                                                      | `"100m"`                                     |
| `console.resources.requests.memory`           | Minimum memory request for the pods.                                                  | `"128Mi"`                                    |
| `console.autoscaling.enabled`                 | Specifies whether autoscaling is enabled.                                                    | `true`                                         |
| `console.autoscaling.minReplicas`             | Minimum number of replicas for autoscaling.                                                 | `1`                                            |
| `console.autoscaling.maxReplicas`             | Maximum number of replicas for autoscaling.                                                 | `3`                                            |
| `console.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                      | `80`                                           |
| `console.nodeSelector`                        | Node selectors for pod scheduling.                                     | `{}`                                           |
| `console.tolerations`                         | Tolerations for pod scheduling.                                                     | `{}`                                     |
| `console.affinity`                            | Affinity rules for pod scheduling.                                              | `{}`                                           |
| `console.configmap`                           | Additional configurations in ConfigMap.                                                     | `{ "NEXTAUTH_URL": "http://localhost:8081" }` |
| `console.secrets`                             | Additional secrets for the service.                                                        | `{}`                                           |
| `console.serviceAccount.create`               | Specifies whether the service account should be created.                                               | `true`                                         |
| `console.serviceAccount.annotations`          | Annotations for the service account.                                                         | `{}`                                           |
| `console.serviceAccount.name`                 | Service account name. If not defined, it will be generated automatically.                    | `""`                                          |

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

### Redis

- **Version:** 19.3.4
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `redis.enabled` to `false` in the values file.
- **Note:** If you have an existing Redis instance, you can disable this dependency and configure Midaz Components to use your external Redis.
  
### PostgreSQL

- **Version:** 16.3.0
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `postgresql.enabled` to `false` in the values file.
- **Note:** If you have an existing PostgreSQL instance, you can disable this dependency and configure Midaz Components to use your external PostgreSQL.

### MongoDB

- **Version:** 15.4.5
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `mongodb.enabled` to `false` in the values file.
- **Note:** If you have an existing MongoDB instance, you can disable this dependency and configure Midaz Components to use your external MongoDB.

### RabbitMQ

- **Version:** 16.0.0
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `rabbitmq.enabled` to `false` in the values file.
- **Note:** If you have an existing RabbitMQ instance, you can disable this dependency and configure Midaz Components to use your external RabbitMQ.

