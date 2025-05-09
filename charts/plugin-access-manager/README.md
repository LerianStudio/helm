# Plugin Access Manager Helm Chart

This helm chart installs [Plugin Acess Manager](https://docs.lerian.studio/docs/auth-identity) for Midaz, a high-performance and open-source ledger.

---

## Install Plugin Access Manager Helm Chart:

To install Plugin Access Manager using Helm, run the following command:

```console
$ helm install plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version <> -n midaz-plugins --create-namespace
```

This will create a new namespace called midaz-plugins if it doesn't already exist and deploy the Plugin Access Manager Helm chart.

After installation, you can verify that the release was successful by listing the Helm releases in the midaz-plugins namespaces:

```console
$ helm list -n midaz-plugins
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

## Plugin Access Manager Components:


### Identity:

| Parameter                                      | Description                                                                                | Default Value                                   |
|-----------------------------------------------|-------------------------------------------------------------------------------------------|------------------------------------------------|
| `identity.name`                               | Service name.                                                                             | `"plugin-access-manager-identity"`            |
| `identity.replicaCount`                       | Number of replicas for the identity service.                                             | `1`                                            |
| `identity.image.repository`                   | Repository for the identity service container image.                                     | `"lerianstudio/plugin-identity"`              |
| `identity.image.pullPolicy`                   | Image pull policy.                                                                        | `"Always"`                                     |
| `identity.image.tag`                          | Image tag used for deployment.                                                           | `"latest"`                                     |
| `identity.imagePullSecrets`                   | Secrets for pulling images from a private registry.                                       | `[{"name": "regcred"}]`                        |
| `identity.nameOverride`                       | Overrides the default generated name by Helm.                                             | `""`                                           |
| `identity.fullnameOverride`                   | Overrides the full name generated by Helm.                                                | `""`                                           |
| `identity.service.type`                       | Kubernetes service type.                                                                 | `"ClusterIP"`                                  |
| `identity.service.port`                       | Port for the HTTP API.                                                                   | `4001`                                         |
| `identity.deploymentStrategy.type`            | Type of deployment strategy.                                                             | `"RollingUpdate"`                              |
| `identity.deploymentStrategy.rollingUpdate.maxSurge` | Maximum number of pods that can be created over the desired number of pods.              | `1`                                            |
| `identity.deploymentStrategy.rollingUpdate.maxUnavailable` | Maximum number of pods that can be unavailable during the update.                        | `1`                                            |
| `identity.pdb.enabled`                        | Specifies whether PodDisruptionBudget is enabled.                                         | `true`                                         |
| `identity.pdb.minAvailable`                   | Minimum number of available pods.                                                        | `0`                                            |
| `identity.pdb.maxUnavailable`                 | Maximum number of unavailable pods.                                                      | `1`                                            |
| `identity.pdb.annotations`                    | Annotations for the PodDisruptionBudget.                                                 | `{}`                                           |
| `identity.resources.limits.cpu`               | CPU limit allocated for the pods.                                                        | `"200m"`                                       |
| `identity.resources.limits.memory`            | Memory limit allocated for the pods.                                                     | `"256Mi"`                                      |
| `identity.resources.requests.cpu`             | Minimum CPU request for the pods.                                                        | `"100m"`                                       |
| `identity.resources.requests.memory`          | Minimum memory request for the pods.                                                     | `"128Mi"`                                      |
| `identity.autoscaling.enabled`                | Specifies whether autoscaling is enabled.                                                | `true`                                         |
| `identity.autoscaling.minReplicas`            | Minimum number of replicas for autoscaling.                                              | `1`                                            |
| `identity.autoscaling.maxReplicas`            | Maximum number of replicas for autoscaling.                                              | `3`                                            |
| `identity.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                       | `80`                                           |
| `identity.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling.                                    | `80`                                           |
| `identity.nodeSelector`                       | Node selectors for pod scheduling.                                                       | `{}`                                           |
| `identity.tolerations`                        | Tolerations for pod scheduling.                                                          | `{}`                                           |
| `identity.affinity`                           | Affinity rules for pod scheduling.                                                       | `{}`                                           |
| `identity.configmap`                          | Additional configurations in ConfigMap.                                                  | See default values in the configuration.       |
| `identity.secrets`                            | Additional secrets for the service.                                                      | See default values in the configuration.       |

### Auth:

| Parameter                                      | Description                                                                                | Default Value                                   |
|-----------------------------------------------|-------------------------------------------------------------------------------------------|------------------------------------------------|
| `auth.name`                                   | Service name.                                                                             | `"plugin-access-manager-auth"`                |
| `auth.replicaCount`                           | Number of replicas for the auth service.                                                 | `3`                                            |
| `auth.image.repository`                       | Repository for the auth service container image.                                         | `"lerianstudio/plugin-auth"`                  |
| `auth.image.pullPolicy`                       | Image pull policy.                                                                        | `"Always"`                                     |
| `auth.image.tag`                              | Image tag used for deployment.                                                           | `"latest"`                                     |
| `auth.imagePullSecrets`                       | Secrets for pulling images from a private registry.                                       | `[{"name": "regcred"}]`                        |
| `auth.nameOverride`                           | Overrides the default generated name by Helm.                                             | `""`                                           |
| `auth.fullnameOverride`                       | Overrides the full name generated by Helm.                                                | `""`                                           |
| `auth.namespaceOverride`                      | Overrides the namespace generated by Helm.                                                | `""`                                           |
| `auth.service.type`                           | Kubernetes service type.                                                                 | `"ClusterIP"`                                  |
| `auth.service.port`                           | Port for the HTTP API.                                                                   | `4000`                                         |
| `auth.deploymentStrategy.type`                | Type of deployment strategy.                                                             | `"RollingUpdate"`                              |
| `auth.deploymentStrategy.rollingUpdate.maxSurge` | Maximum number of pods that can be created over the desired number of pods.              | `1`                                            |
| `auth.deploymentStrategy.rollingUpdate.maxUnavailable` | Maximum number of pods that can be unavailable during the update.                        | `1`                                            |
| `auth.pdb.enabled`                            | Specifies whether PodDisruptionBudget is enabled.                                         | `true`                                         |
| `auth.pdb.minAvailable`                       | Minimum number of available pods.                                                        | `0`                                            |
| `auth.pdb.maxUnavailable`                     | Maximum number of unavailable pods.                                                      | `1`                                            |
| `auth.pdb.annotations`                        | Annotations for the PodDisruptionBudget.                                                 | `{}`                                           |
| `auth.resources.limits.cpu`                   | CPU limit allocated for the pods.                                                        | `1`                                            |
| `auth.resources.limits.memory`                | Memory limit allocated for the pods.                                                     | `"756Mi"`                                      |
| `auth.resources.requests.cpu`                 | Minimum CPU request for the pods.                                                        | `"500m"`                                       |
| `auth.resources.requests.memory`              | Minimum memory request for the pods.                                                     | `"256Mi"`                                      |
| `auth.autoscaling.enabled`                    | Specifies whether autoscaling is enabled.                                                | `true`                                         |
| `auth.autoscaling.minReplicas`                | Minimum number of replicas for autoscaling.                                              | `1`                                            |
| `auth.autoscaling.maxReplicas`                | Maximum number of replicas for autoscaling.                                              | `3`                                            |
| `auth.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling.                                       | `80`                                           |
| `auth.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling.                                    | `80`                                           |
| `auth.nodeSelector`                           | Node selectors for pod scheduling.                                                       | `{}`                                           |
| `auth.tolerations`                            | Tolerations for pod scheduling.                                                          | `{}`                                           |
| `auth.affinity`                               | Affinity rules for pod scheduling.                                                       | `{}`                                           |
| `auth.configmap`                              | Additional configurations in ConfigMap.                                                  | See default values in the configuration.       |
| `auth.secrets`                                | Additional secrets for the service.                                                      | See default values in the configuration.       |

## Dependencies: 

### PostgreSQL

- **Version:** 16.3.0
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `auth-database.enabled` to `false` in the values file.
- **Note:** If you have an existing PostgreSQL instance, you can disable this dependency and configure Midaz Components to use your external PostgreSQL, like this:
- **Important:** When using an external Postgres instance, make sure to load the init SQL file [`00_init.sql`](https://github.com/LerianStudio/midaz-helm/blob/main/charts/plugin-access-manager/files/00_init.sql) into your database.

  ```yaml
  auth:
    configmap:
      DB_HOST: { your-host }
      CASDOOR_DB_USER: { your-host-user }
      CASDOOR_DB_PORT: { your-host-port }
    
    secrets:
      CASDOOR_DB_PASSWORD: { your-host-pass }

  ```

### Valkey

- **Version:** 2.4.7
- **Repository:** https://charts.bitnami.com/bitnami
- **How to disable:** Set `valkey.enabled` to `false` in the values file.
- **Note:** If you have an existing Valkey or Redis instance, you can disable this dependency and configure Midaz Components to use your external instance, like this:

  ```yaml
  auth:
    configmap:
      REDIS_HOST: { your-host }
      REDIS_PORT: { your-host-port }
      REDIS_USER: { your-host-user }

    secrets:
      REDIS_PASSWORD: { your-host-pass }
  ```
