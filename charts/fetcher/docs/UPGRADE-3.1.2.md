# Helm Upgrade from v3.1.1 to v3.1.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Bootstrap Job immutability and Argo CD compatibility](#1-bootstrap-job-immutability-and-argo-cd-compatibility)
  - [2. Enhanced security context for bootstrap Jobs](#2-enhanced-security-context-for-bootstrap-jobs)
  - [3. Improved RabbitMQ bootstrap error handling](#3-improved-rabbitmq-bootstrap-error-handling)
  - [4. Seccomp profile for AWS Roles Anywhere sidecar](#4-seccomp-profile-for-aws-roles-anywhere-sidecar)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.1.1` to `3.1.2`. This is a **patch** release that improves security posture and fixes operational issues with bootstrap Jobs in Argo CD environments.

The application version (`appVersion: 3.1.0`) is unchanged. No breaking changes, no required `values.yaml` modifications, and no data migration are needed. This release focuses on Kubernetes resource template improvements and security hardening.

## Fixes

### 1. Bootstrap Job immutability and Argo CD compatibility

The bootstrap Jobs for MongoDB and RabbitMQ now include the Helm release revision in their names and have Argo CD hook annotations. This resolves two operational issues:

1. **Job immutability errors**: Kubernetes Job `spec.template` is immutable. Previously, running `helm upgrade` would fail if the bootstrap Job already existed, because Helm cannot update an immutable field.
2. **Argo CD sync failures**: Without hook annotations, Argo CD would not properly manage the lifecycle of these Jobs during sync operations.

**Before (v3.1.1):**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: fetcher-bootstrap-mongodb
  namespace: fetcher
  labels:
    app.kubernetes.io/component: bootstrap
```

**After (v3.1.2):**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  # spec.template is immutable: a new Job per Helm revision, an Argo CD hook re-created per sync
  name: fetcher-bootstrap-mongodb-{{ .Release.Revision }}
  namespace: fetcher
  labels:
    app.kubernetes.io/component: bootstrap
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
```

| Setting | v3.1.1 | v3.1.2 |
|---------|--------|--------|
| MongoDB bootstrap Job name | `fetcher-bootstrap-mongodb` | `fetcher-bootstrap-mongodb-{{ .Release.Revision }}` |
| RabbitMQ bootstrap Job name | `fetcher-bootstrap-rabbitmq` | `fetcher-bootstrap-rabbitmq-{{ .Release.Revision }}` |
| Argo CD hook annotation | (not set) | `argocd.argoproj.io/hook: Sync` |
| Argo CD hook delete policy | (not set) | `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded` |

> **Note:** Each Helm upgrade will now create a new Job with a unique name (e.g., `fetcher-bootstrap-mongodb-2`, `fetcher-bootstrap-mongodb-3`). Old Jobs are automatically cleaned up after 300 seconds (`ttlSecondsAfterFinished: 300`).

> **Important:** If you are using Argo CD, the new hook annotations ensure the bootstrap Jobs run during the Sync phase and are deleted before the next sync or after successful completion. This prevents stale Job resources from accumulating.

### 2. Enhanced security context for bootstrap Jobs

Both bootstrap Jobs now include pod-level and container-level security contexts to comply with Kubernetes Pod Security Standards (PSS) restricted profile.

**Before (v3.1.1):**

```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.37
      containers:
      - name: mongosh
        image: mongo:8
```

**After (v3.1.2):**

```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.37
        securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
      containers:
      - name: mongosh
        image: mongo:8
        securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
```

| Component | Setting | v3.1.1 | v3.1.2 |
|-----------|---------|--------|--------|
| MongoDB bootstrap Job | Pod `runAsNonRoot` | (not set) | `true` |
| MongoDB bootstrap Job | Pod `runAsUser` | (not set) | `999` |
| MongoDB bootstrap Job | Pod `seccompProfile.type` | (not set) | `RuntimeDefault` |
| MongoDB bootstrap Job | Container `allowPrivilegeEscalation` | (not set) | `false` |
| MongoDB bootstrap Job | Container `capabilities.drop` | (not set) | `[ALL]` |
| RabbitMQ bootstrap Job | Pod `runAsNonRoot` | (not set) | `true` |
| RabbitMQ bootstrap Job | Pod `runAsUser` | (not set) | `100` |
| RabbitMQ bootstrap Job | Pod `seccompProfile.type` | (not set) | `RuntimeDefault` |
| RabbitMQ bootstrap Job | Container `allowPrivilegeEscalation` | (not set) | `false` |
| RabbitMQ bootstrap Job | Container `capabilities.drop` | (not set) | `[ALL]` |

> **Note:** The MongoDB bootstrap Job runs as user `999` (the default `mongodb` user in the `mongo:8` image), while the RabbitMQ bootstrap Job runs as user `100` (the default user in the `curlimages/curl:8.7.1` image). These changes improve security posture and are required for clusters enforcing PSS restricted profile.

### 3. Improved RabbitMQ bootstrap error handling

The RabbitMQ bootstrap Job now captures HTTP response bodies inline instead of writing to temporary files, and removes the idempotency check that could cause silent failures.

**Before (v3.1.1):**

```yaml
echo "Checking if RabbitMQ definitions already exist..."

# Check if plugin user already exists
PLUGIN_EXISTS=$(curl -sSk -u "$RABBITMQ_ADMIN_USER:$RABBITMQ_ADMIN_PASS" \
  "$BASE_URL/api/users/plugin" 2>/dev/null || echo "not_found")

# Check if fetcher queue exists
QUEUE_EXISTS=$(curl -sSk -u "$RABBITMQ_ADMIN_USER:$RABBITMQ_ADMIN_PASS" \
  "$BASE_URL/api/queues/%2F/fetcher.generate-fetcher.queue" 2>/dev/null || echo "not_found")

if echo "$PLUGIN_EXISTS" | grep -q '"name":"plugin"' && \
   echo "$QUEUE_EXISTS" | grep -q '"name":"fetcher.generate-fetcher.queue"'; then
  echo "RabbitMQ definitions already applied (user plugin and fetcher queues exist). Skipping."
  exit 0
fi

echo "Applying RabbitMQ definitions from file..."
HTTP_CODE=$(curl -sSk -o /tmp/response.txt -w "%{http_code}" \
  -u "$RABBITMQ_ADMIN_USER:$RABBITMQ_ADMIN_PASS" \
  -H "content-type: application/json" \
  -X POST \
  --data-binary @/definitions/load_definitions.json \
  "$BASE_URL/api/definitions")
if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "Error applying definitions (HTTP $HTTP_CODE):"
  cat /tmp/response.txt
  exit 1
fi
```

**After (v3.1.2):**

```yaml
echo "Applying RabbitMQ definitions from file..."
RESPONSE=$(curl -sSk -w "\n%{http_code}" \
  -u "$RABBITMQ_ADMIN_USER:$RABBITMQ_ADMIN_PASS" \
  -H "content-type: application/json" \
  -X POST \
  --data-binary @/definitions/load_definitions.json \
  "$BASE_URL/api/definitions")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "Error applying definitions (HTTP $HTTP_CODE):"
  echo "$RESPONSE" | sed '$d'
  exit 1
fi
```

**Changes:**

1. **Removed idempotency check**: The Job no longer checks if definitions already exist before applying them. RabbitMQ's definitions API is idempotent by design, so this check was redundant and could mask configuration drift.
2. **Inline response capture**: HTTP responses are now captured in a shell variable instead of written to `/tmp/response.txt`, eliminating filesystem dependencies.
3. **Improved error output**: Error messages now display the full HTTP response body inline using `sed '$d'` to strip the trailing HTTP code.

> **Note:** The bootstrap Job will now always attempt to apply RabbitMQ definitions on every run. This ensures configuration consistency and makes troubleshooting easier, as the Job logs will always show the API response.

### 4. Seccomp profile for AWS Roles Anywhere sidecar

The AWS Roles Anywhere sidecar container in both `manager` and `worker` Deployments now includes a seccomp profile.

**Before (v3.1.1):**

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

**After (v3.1.2):**

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
```

| Component | Setting | v3.1.1 | v3.1.2 |
|-----------|---------|--------|--------|
| Manager AWS sidecar | `seccompProfile.type` | (not set) | `RuntimeDefault` |
| Worker AWS sidecar | `seccompProfile.type` | (not set) | `RuntimeDefault` |

> **Note:** This change only affects deployments where `aws.rolesAnywhere.enabled: true`. The seccomp profile is applied automatically and requires no configuration changes.

## Configuration Changes

No `values.yaml` keys were added, removed, or changed. All fixes are applied at the template level and require no operator configuration.

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will:

1. Create new bootstrap Jobs with revision-suffixed names (old Jobs will be cleaned up automatically after 300 seconds)
2. Roll the `manager` and `worker` Deployments if AWS Roles Anywhere is enabled (to apply the seccomp profile to the sidecar)

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify the bootstrap Jobs complete successfully:

```bash
kubectl get jobs -n fetcher -l app.kubernetes.io/component=bootstrap
```

4. Check bootstrap Job logs if any failures occur:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=bootstrap --tail=100
```

5. Verify manager and worker pods are healthy:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager
kubectl get pods -n fetcher -l app.kubernetes.io/component=worker
```

> **Note:** If you are using Argo CD, the bootstrap Jobs will be managed as Sync hooks. Argo CD will automatically delete old Job resources according to the `BeforeHookCreation,HookSucceeded` policy.

> **Important:** The new security contexts require the container images to support running as non-root users. The `mongo:8`, `busybox:1.37`, and `curlimages/curl:8.7.1` images used in the bootstrap Jobs all support this. If you have customized the bootstrap Job images, verify they are compatible with `runAsNonRoot: true`.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.2 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.2 -n fetcher
```
