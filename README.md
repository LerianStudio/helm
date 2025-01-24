Source code can be found here:
* https://github.com/LerianStudio/midaz-helm/tree/main/charts/midaz
* https://github.com/LerianStudio/midaz

This helm chart installs [Midaz](https://lerian.studio/midaz#about), a high-performance and open-source ledger.

The default installation is similar to the one provided in the [Midaz repo](https://github.com/LerianStudio/midaz?tab=readme-ov-file#quick-installation-guide-localhost).

---
## Install:

```console
$ helm install midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 1.0.0 -n midaz --create-namespace
```

---
## Midaz Components:

The Midaz system runs on four distinct layers that work together, distributed in segregated workloads:

### Ledger:

| Parameter                                    | Description                                                                                     | Default Value                                   |
|---------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------|
| **ledger.name**                              | Resource name.                                                                      | `"ledger"`                                     |
| **ledger.replicaCount**                      | Number of replicas.                                                              | `2`                                            |
| **ledger.image.repository**                  | Docker image repository for Ledger.                                                     | `"lerianstudio/midaz-ledger"`                 |
| **ledger.image.pullPolicy**                  | Docker image pull policy.                                                          | `"IfNotPresent"`                               |
| **ledger.image.tag**                         | Docker image tag.                                                                        | `"latest"`                                     |
| **ledger.podAnnotations**                   | Annotations for the pods.                                                                     | `{}`                                           |
| **ledger.service.type**                      | Service type.                                                                             | `"ClusterIP"`                                  |
| **ledger.service.port**                      | Service port.                                                                            | `3000`                                         |
| **ledger.ingress.enabled**                   | Specifies whether Ingress is enabled.                                                        | `false`                                         |
| **ledger.ingress.className**                 | Ingress class.                                                                           | `{}`                                        |
| **ledger.ingress.annotations**               | Annotations for Ingress, including ALB configurations.                                    |  `{}`       |
| **ledger.ingress.hosts**                     | Configured hosts for Ingress and associated paths.                                     | `""`                  |
| **ledger.ingress.tls**                       | TLS configurations for Ingress.                                                           | `[]`                                           |
| **ledger.resources.limits.cpu**              | CPU limit allocated for the pods.                                                         | `"200m"`                                       |
| **ledger.resources.limits.memory**           | Memory limit allocated for the pods.                                                     | `"256Mi"`                                      |
| **ledger.resources.requests.cpu**            | Minimum CPU request for the pods.                                                      | `"100m"`                                       |
| **ledger.resources.requests.memory**         | Minimum memory request for the pods.                                                  | `"128Mi"`                                      |
| **ledger.autoscaling.enabled**               | Specifies whether autoscaling is enabled.                                                    | `true`                                         |
| **ledger.autoscaling.minReplicas**           | Minimum number of replicas for autoscaling.                                                 | `1`                                            |
| **ledger.autoscaling.maxReplicas**           | Maximum number of replicas for autoscaling.                                                 | `3`                                            |
| **ledger.autoscaling.targetCPUUtilizationPercentage** | Target CPU utilization percentage for autoscaling.                                      | `80`                                           |
| **ledger.nodeSelector**                      | Node selectors for pod scheduling.                                     | `{}`                                           |
| **ledger.tolerations**                       | Tolerations for pod scheduling.                                                     |      `{}`              |
| **ledger.affinity**                          | Affinity rules for pod scheduling.                                              | `{}`                                           |
| **ledger.configmap**                         | Additional configurations in ConfigMap.                                                     | `{}`                                           |
| **ledger.secrets**                           | Additional secrets for the service.                                                        | `{}`                                           |
| **ledger.serviceAccount.create**             | Specifies whether the service account should be created.                                               | `true`                                         |
| **ledger.serviceAccount.annotations**        | Annotations for the service account.                                                         | `{}`                                           |
| **ledger.serviceAccount.name**               | Service account name. If not defined, it will be generated automatically.                    | `""`                                           |

### Transaction:

| Parameter                                    | Description                                                                                     | Default Value                                   |
|---------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------|
| **transaction.name**                         | Transaction resource name.                                                                 | `"transaction"`                                |
| **transaction.replicaCount**                 | Number of service replicas.                                                              | `1`                                            |
| **transaction.image.repository**             | Docker image repository for Transaction.                                                | `"lerianstudio/midaz-transaction"`            |
| **transaction.image.pullPolicy**             | Docker image pull policy.                                                          | `"IfNotPresent"`                               |
| **transaction.image.tag**                    | Docker image tag.                                                                        | `"1.44.0"`                                    |
| **transaction.podAnnotations**               | Annotations for the pods.                                                                     | `{}`                                           |
| **transaction.service.type**                 | Service type.                                                                             | `"ClusterIP"`                                  |
| **transaction.service.port**                 | Service port.                                                                            | `3002`                                         |
| **transaction.ingress.enabled**              | Specifies whether Ingress is enabled.                                                        | `false`                                        |
| **transaction.ingress.className**            | Ingress class.                                                                           | `""`                                           |
| **transaction.ingress.annotations**          | Annotations for Ingress.                                                                   | `{}`                                           |
| **transaction.ingress.hosts**                | Configured hosts for Ingress and associated paths.                                     |     `""`              |
| **transaction.ingress.tls**                  | TLS configurations for Ingress.                                                           | `[]`                                           |
| **transaction.resources.limits.cpu**         | CPU limit allocated for the pods.                                                         | `"200m"`                                       |
| **transaction.resources.limits.memory**      | Memory limit allocated for the pods.                                                     | `"256Mi"`                                      |
| **transaction.resources.requests.cpu**       | Minimum CPU request for the pods.                                                      | `"100m"`                                       |
| **transaction.resources.requests.memory**    | Minimum memory request for the pods.                                                  | `"128Mi"`                                      |
| **transaction.autoscaling.enabled**          | Specifies whether autoscaling is enabled.                                                    | `true`                                         |
| **transaction.autoscaling.minReplicas**      | Minimum number of replicas for autoscaling.                                                 | `1`                                            |
| **transaction.autoscaling.maxReplicas**      | Maximum number of replicas for autoscaling.                                                 | `3`                                            |
| **transaction.autoscaling.targetCPUUtilizationPercentage** | Target CPU utilization percentage for autoscaling.                                      | `80`                                           |
| **transaction.nodeSelector**                 | Node selectors for pod scheduling.                                     | `{}`                                           |
| **transaction.tolerations**                  | Tolerations for pod scheduling.                                                     |     `{}`                  |
| **transaction.affinity**                     | Affinity rules for pod scheduling.                                              | `{}`                                           |
| **transaction.configmap**                    | Additional configurations in ConfigMap.                                                     | `{}`                                           |
| **transaction.secrets**                      | Additional secrets for the service.                                                        | `{}`                                           |
| **transaction.serviceAccount.create**        | Specifies whether the service account should be created.                                               | `true`                                         |
| **transaction.serviceAccount.annotations**   | Annotations for the service account.                                                         | `{}`                                           |
| **transaction.serviceAccount.name**          | Service account name. If not defined, it will be generated automatically.                    | `""`                                           |

### Audit:
| Parameter                                    | Description                                                                 | Default Value                                  |
|----------------------------------------------|---------------------------------------------------------------------------|----------------------------------------------|
| `audit.name`                                 | Application deployment name.                                          | `"audit"`                                     |
| `audit.replicaCount`                         | Number of application replicas.                                          | `1`                                           |
| `audit.image.repository`                     | Docker image repository for the application.                                | `"lerianstudio/midaz-audit"`                 |
| `audit.image.pullPolicy`                     | Docker image pull policy.                                        | `"IfNotPresent"`                              |
| `audit.image.tag`                            | Docker image tag.                                                     | `"1.44.0"`                                    |
| `audit.imagePullSecrets`                     | Image pull secrets.                                             | `[]`                                          |
| `audit.nameOverride`                         | Application name override.                                        | `""`                                          |
| `audit.fullnameOverride`                     | Full application name override.                               | `""`                                          |
| `audit.podAnnotations`                       | Additional annotations for the pods.                                        | `{}`                                          |
| `audit.podSecurityContext`                   | Security context for the pods.                                       | `{}`                                          |
| `audit.securityContext`                      | Security context for the container.                                   | `{}`                                          |
| `audit.service.type`                         | Kubernetes service type.                                               | `"ClusterIP"`                                 |
| `audit.service.port`                         | Main service port.                                               | `3005`                                        |
| `audit.ingress.enabled`                      | Enable or disable Ingress.                                         | `false`                                       |
| `audit.ingress.className`                    | Ingress class.                                                        | `""`                                          |
| `audit.ingress.annotations`                  | Additional annotations for Ingress.                                      | `{}`                                          |
| `audit.ingress.hosts`                        | List of configured hosts for Ingress.                               | `""`        |
| `audit.ingress.tls`                          | TLS configuration for Ingress.                                       | `[]`                                          |
| `audit.resources.limits.cpu`                 | CPU limit for the main container.                                 | `"200m"`                                      |
| `audit.resources.limits.memory`              | Memory limit for the main container.                             | `"256Mi"`                                     |
| `audit.resources.requests.cpu`               | CPU request for the main container.                             | `"100m"`                                      |
| `audit.resources.requests.memory`            | Memory request for the main container.                         | `"128Mi"`                                     |
| `audit.server.image.repository`              | Trillian Log Server image repository.                             | `"gcr.io/trillian-opensource-ci/log_server"` |
| `audit.server.service.httpPort`              | Server HTTP port.                                                   | `8091`                                        |
| `audit.server.service.grpcPort`              | Server gRPC port.                                                   | `8090`                                        |
| `audit.server.resources.limits.cpu`          | CPU limit for the server.                                            | `"200m"`                                      |
| `audit.server.resources.limits.memory`       | Memory limit for the server.                                        | `"256Mi"`                                     |
| `audit.server.resources.requests.cpu`        | CPU request for the server.                                        | `"100m"`                                      |
| `audit.server.resources.requests.memory`     | Memory request for the server.                                    | `"128Mi"`                                     |
| `audit.signer.image.repository`              | Trillian Log Signer image repository.                             | `"gcr.io/trillian-opensource-ci/log_signer"` |
| `audit.signer.service.httpPort`              | Signer HTTP port.                                                     | `8092`                                        |
| `audit.signer.service.grpcPort`              | Signer gRPC port.                                                     | `8093`                                        |
| `audit.signer.resources.limits.cpu`          | CPU limit for the signer.                                              | `"200m"`                                      |
| `audit.signer.resources.limits.memory`       | Memory limit for the signer.                                          | `"256Mi"`                                     |
| `audit.signer.resources.requests.cpu`        | CPU request for the signer.                                          | `"100m"`                                      |
| `audit.signer.resources.requests.memory`     | Memory request for the signer.                                      | `"128Mi"`                                     |
| `audit.autoscaling.enabled`                  | Enable horizontal autoscaling.                                        | `true`                                        |
| `audit.autoscaling.minReplicas`              | Minimum number of replicas for autoscaling.                             | `1`                                           |
| `audit.autoscaling.maxReplicas`              | Maximum number of replicas for autoscaling.                             | `3`                                           |
| `audit.autoscaling.targetCPUUtilizationPercentage` | CPU utilization percentage for autoscaling.                   | `80`                                          |
| `audit.nodeSelector`                         | Node selector for pod scheduling.                               | `{}`                                          |
| `audit.tolerations`                          | Tolerations for pod scheduling.                                  | `{}` |
| `audit.affinity`                             | Affinity configuration for pod scheduling.                    | `{}`                                          |
| `audit.configmap`                            | Additional configurations for ConfigMap.                                | `{}`                                          |
| `audit.secrets`                              | Additional configurations for Secrets.                                 | `{}`                                          |
| `audit.serviceAccount.create`                | Create a ServiceAccount for the pods.                               | `true`                                        |
| `audit.serviceAccount.annotations`           | Annotations for the ServiceAccount.                                          | `{}`                                          |
| `audit.serviceAccount.name`                  | ServiceAccount name.                                                   | `""`                                          |

### Console:

| Parameter                                     | Description                                                                                     | Default Value                                   |
|----------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------|
| `console.name`                                | Resource name.                                                                      | `"console"`                                   |
| `console.replicaCount`                        | Number of replicas.                                                              | `1`                                            |
| `console.image.repository`                    | Docker image repository for Console.                                                     | `"lerianstudio/midaz-console"`                |
| `console.image.pullPolicy`                    | Docker image pull policy.                                                          | `"IfNotPresent"`                              |
| `console.image.tag`                           | Docker image tag.                                                                        | `"1.2.0"`                                     |
| `console.imagePullSecrets`                    | Secrets for pulling Docker images.                                                        | `[]`                                           |
| `console.nameOverride`                        | Overrides the resource name.                                                              | `""`                                          |
| `console.fullnameOverride`                    | Overrides the full resource name.                                                         | `""`                                          |
| `console.podAnnotations`                      | Annotations for the pods.                                                                     | `{}`                                           |
| `console.podSecurityContext`                  | Security context for the pod level.                                                        | `{}`                                           |
| `console.securityContext`                     | Security context for the container level.                                                  | `{}`                                           |
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
| `console.tolerations`                         | Tolerations for pod scheduling.                                                     |      `{}`                                     |
| `console.affinity`                            | Affinity rules for pod scheduling.                                              | `{}`                                           |
| `console.configmap`                           | Additional configurations in ConfigMap.                                                     | `{ "NEXTAUTH_URL": "http://localhost:8081" }` |
| `console.secrets`                             | Additional secrets for the service.                                                        | `{}`                                           |
| `console.serviceAccount.create`               | Specifies whether the service account should be created.                                               | `true`                                         |
| `console.serviceAccount.annotations`          | Annotations for the service account.                                                         | `{}`                                           |
| `console.serviceAccount.name`                 | Service account name. If not defined, it will be generated automatically.                    | `""`                                          |
## Dependencies:

This Chart has the following dependencies for the project's default installation:

### Redis

- **Version:** 19.3.4
- **Repository:** https://charts.bitnami.com/bitnami

### PostgreSQL

- **Version:** 16.3.0
- **Repository:** https://charts.bitnami.com/bitnami

### PostgreSQL (Alias: casdoordb)

- **Version:** 16.3.0
- **Repository:** https://charts.bitnami.com/bitnami

### MongoDB

- **Version:** 15.4.5
- **Repository:** https://charts.bitnami.com/bitnami

### MariaDB

- **Version:** 20.2
- **Repository:** https://charts.bitnami.com/bitnami

### RabbitMQ

- **Version:** 16.0.0
- **Repository:** https://charts.bitnami.com/bitnami

### Casdoor Helm Charts

- **Version:** v1.799.0
- **Repository:** oci://registry-1.docker.io/casbin
