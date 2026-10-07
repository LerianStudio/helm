# Helm Upgrade from v4.3.7 to v4.3.8

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Removed unused podSecurityContext fields](#1-removed-unused-podsecuritycontext-fields)
  - [2. Enhanced security context for bootstrap-mongodb Job](#2-enhanced-security-context-for-bootstrap-mongodb-job)
  - [3. Worker deployment filesystem hardening](#3-worker-deployment-filesystem-hardening)
  - [4. Worker KEDA ScaledJob security context alignment](#4-worker-keda-scaledjob-security-context-alignment)
  - [5. Fixed AWS Roles Anywhere volume template rendering](#5-fixed-aws-roles-anywhere-volume-template-rendering)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that removes unused configuration fields, hardens security contexts for the MongoDB bootstrap Job, and adds filesystem isolation for the worker component. The application version remains unchanged at `4.2.0`.

| Field | v4.3.7 | v4.3.8 |
|-------|--------|--------|
| Chart version | `4.3.7` | `4.3.8` |
| App version | `4.2.0` | `4.2.0` |

## Fixes

### 1. Removed unused podSecurityContext fields

The `manager.podSecurityContext` and `worker.podSecurityContext` fields have been removed from `values.yaml`. These fields were present but never referenced in the Deployment templates, so their removal has no operational impact.

| Setting | v4.3.7 | v4.3.8 |
|---------|--------|--------|
| `manager.podSecurityContext` | `{}` | removed |
| `worker.podSecurityContext` | `{}` | removed |

**Before (v4.3.7):**

```yaml
manager:
  podSecurityContext: {}
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
```

**After (v4.3.8):**

```yaml
manager:
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
```

> **Note:** If you have overridden `manager.podSecurityContext` or `worker.podSecurityContext` in your values, remove these overrides before upgrading. The fields are no longer valid and will be ignored.

### 2. Enhanced security context for bootstrap-mongodb Job

The `bootstrap-mongodb` Job now enforces a hardened security context that complies with the Kubernetes "restricted" Pod Security Standard. Both the Job's pod-level security context and the container-level security contexts for the `wait-for-dependencies` and `mongosh` containers have been updated.

**Pod-level security context changes:**

| Setting | v4.3.7 | v4.3.8 |
|---------|--------|--------|
| `spec.template.spec.securityContext` | not set | `runAsNonRoot: true`, `runAsUser: 65532`, `seccompProfile.type: RuntimeDefault` |

**Container-level security context changes:**

| Container | v4.3.7 | v4.3.8 |
|-----------|--------|--------|
| `wait-for-dependencies` | not set | `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` |
| `mongosh` | not set | `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` |

**Before (v4.3.7):**

```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.37
        # No securityContext
      containers:
      - name: mongosh
        image: mongo:8
        # No securityContext
```

**After (v4.3.8):**

```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.37
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
      containers:
      - name: mongosh
        image: mongo:8
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
```

> **Important:** The bootstrap Job now runs as user `65532` (the `nonroot` user in distroless images) instead of root. Both the `busybox:1.37` and `mongo:8` images support non-root execution. If the Job fails to start after upgrade, verify that your cluster's Pod Security admission controller allows the "restricted" profile.

### 3. Worker deployment filesystem hardening

The worker Deployment now mounts a writable `/tmp` directory via an `emptyDir` volume and sets the `HOME` environment variable to `/tmp`. This change supports the existing `readOnlyRootFilesystem: true` security context by providing a writable location for temporary files.

**New volume and volume mount:**

| Setting | v4.3.7 | v4.3.8 |
|---------|--------|--------|
| `spec.template.spec.volumes` | AWS Roles Anywhere volume only (if enabled) | `tmp` emptyDir volume added |
| `spec.template.spec.containers[0].volumeMounts` | not set | `/tmp` mount added |

**New environment variable:**

| Variable | v4.3.8 Default | Description |
|----------|----------------|-------------|
| `HOME` | `/tmp` | Sets the home directory for the worker process to a writable location |

**Before (v4.3.7):**

```yaml
spec:
  template:
    spec:
      containers:
      - name: worker
        image: "reporter-worker:4.2.0"
        securityContext:
          readOnlyRootFilesystem: true
        # No volumeMounts
        # No HOME environment variable
      # No tmp volume
```

**After (v4.3.8):**

```yaml
spec:
  template:
    spec:
      containers:
      - name: worker
        image: "reporter-worker:4.2.0"
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
          - name: tmp
            mountPath: /tmp
        env:
        - name: HOME
          value: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

> **Note:** The worker container's read-only root filesystem now has a dedicated writable `/tmp` directory. If your worker image writes temporary files to other paths, you may need to add additional `emptyDir` mounts or adjust the application configuration.

### 4. Worker KEDA ScaledJob security context alignment

The worker KEDA ScaledJob template now includes the same security context and filesystem hardening changes as the worker Deployment. The `securityContext` block is now rendered from `values.worker.securityContext`, and the `/tmp` volume mount and `HOME` environment variable have been added.

**New fields:**

| Setting | v4.3.7 | v4.3.8 |
|---------|--------|--------|
| `spec.jobTargetRef.template.spec.template.spec.containers[0].securityContext` | not set | rendered from `values.worker.securityContext` |
| `spec.jobTargetRef.template.spec.template.spec.containers[0].volumeMounts` | not set | `/tmp` mount added |
| `spec.jobTargetRef.template.spec.template.spec.containers[0].env[HOME]` | not set | `HOME=/tmp` added |
| `spec.jobTargetRef.template.spec.template.spec.volumes` | AWS Roles Anywhere volume only (if enabled) | `tmp` emptyDir volume added |

**Before (v4.3.7):**

```yaml
spec:
  jobTargetRef:
    template:
      spec:
        template:
          spec:
            containers:
            - name: worker
              image: "reporter-worker:4.2.0"
              # No securityContext
              # No volumeMounts
              # No HOME environment variable
            # No tmp volume
```

**After (v4.3.8):**

```yaml
spec:
  jobTargetRef:
    template:
      spec:
        template:
          spec:
            containers:
            - name: worker
              image: "reporter-worker:4.2.0"
              securityContext:
                runAsGroup: 1000
                runAsUser: 1000
                runAsNonRoot: true
                capabilities:
                  drop:
                    - ALL
                readOnlyRootFilesystem: true
                allowPrivilegeEscalation: false
                seccompProfile:
                  type: RuntimeDefault
              volumeMounts:
                - name: tmp
                  mountPath: /tmp
              env:
              - name: HOME
                value: /tmp
            volumes:
              - name: tmp
                emptyDir: {}
```

> **Note:** If you have customized `worker.securityContext` in your values, those customizations will now apply to both the Deployment and the KEDA ScaledJob.

### 5. Fixed AWS Roles Anywhere volume template rendering

The AWS Roles Anywhere volume template helper now correctly strips the `volumes:` prefix when included in the worker Deployment and KEDA ScaledJob templates. This fix prevents duplicate `volumes:` keys in the rendered YAML.

**Template change:**

| Location | v4.3.7 | v4.3.8 |
|----------|--------|--------|
| `templates/worker/deployment.yaml` | `{{- include "lerian-common.rolesAnywhere.volume" ... | nindent 6 }}` | `{{- include "lerian-common.rolesAnywhere.volume" ... | trimPrefix "volumes:\n" | nindent 6 }}` |
| `templates/worker/keda-scaled-job.yaml` | `{{- include "lerian-common.rolesAnywhere.volume" ... | nindent 8 }}` | `{{- include "lerian-common.rolesAnywhere.volume" ... | trimPrefix "volumes:\n" | nindent 8 }}` |

**Before (v4.3.7):**

```yaml
spec:
  template:
    spec:
      volumes:
        - name: tmp
          emptyDir: {}
      volumes:  # Duplicate key
        - name: iam-tls
          secret:
            secretName: reporter-iam-tls
```

**After (v4.3.8):**

```yaml
spec:
  template:
    spec:
      volumes:
        - name: tmp
          emptyDir: {}
        - name: iam-tls
          secret:
            secretName: reporter-iam-tls
```

> **Important:** If you have AWS Roles Anywhere enabled (`aws.rolesAnywhere.enabled=true`), this fix ensures the worker Deployment and KEDA ScaledJob render correctly. No configuration changes are required.

## Configuration Changes

No `values.yaml` keys were added or renamed. Two unused keys were removed:

| Setting | v4.3.7 | v4.3.8 | Notes |
|---------|--------|--------|-------|
| `manager.podSecurityContext` | `{}` | removed | Field was never referenced in templates |
| `worker.podSecurityContext` | `{}` | removed | Field was never referenced in templates |

All other changes are in template defaults and rendering logic.

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the worker Deployment and recreate the bootstrap-mongodb Job if it runs again.

**Recommended upgrade process:**

1. Remove any overrides for `manager.podSecurityContext` or `worker.podSecurityContext` from your values file:

```yaml
# Remove these lines if present:
manager:
  podSecurityContext: {}
worker:
  podSecurityContext: {}
```

2. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Run the upgrade command during a maintenance window.

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. Check worker logs to confirm `/tmp` mount is working:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

6. If the bootstrap-mongodb Job runs again (e.g., during a fresh install or manual trigger), verify it completes successfully:

```bash
kubectl get jobs -n <namespace> -l app.kubernetes.io/name=reporter
kubectl logs -n <namespace> job/reporter-bootstrap-mongodb
```

> **Note:** The upgrade triggers a rolling restart of the worker Deployment. The manager Deployment is not affected. If AWS Roles Anywhere is enabled, verify that the IAM TLS volume mounts correctly after the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.8 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.8 -n <namespace>
```
