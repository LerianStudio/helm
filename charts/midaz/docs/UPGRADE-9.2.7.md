# Helm Upgrade from v9.2.6 to v9.2.7

## Topics

- **[Fixes](#fixes)**
  - [1. Enhanced Security Context for Bootstrap Jobs](#1-enhanced-security-context-for-bootstrap-jobs)
  - [2. Security Context for Ledger Init Container](#2-security-context-for-ledger-init-container)

## Fixes

### 1. Enhanced Security Context for Bootstrap Jobs

The bootstrap jobs for MongoDB, PostgreSQL, and RabbitMQ have been hardened with pod-level and container-level security contexts to meet stricter security policies and compliance requirements.

#### What Changed

All three bootstrap job templates now include:

- **Pod-level security context:**
  - `runAsNonRoot: true`
  - `runAsUser` set to the appropriate UID for each service
  - `seccompProfile.type: RuntimeDefault`

- **Container-level security context** (applied to all init and main containers):
  - `allowPrivilegeEscalation: false`
  - `capabilities.drop: [ALL]`

#### Before (v9.2.6):

**bootstrap-mongodb.yaml:**
```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.37
        # no securityContext
      containers:
      - name: mongosh
        image: mongo:8
        # no securityContext
```

**bootstrap-postgres.yaml:**
```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.37
        # no securityContext
      containers:
      - name: psql
        image: postgres:16
        # no securityContext
```

**bootstrap-rabbitmq.yaml:**
```yaml
spec:
  template:
    spec:
      restartPolicy: OnFailure
      initContainers:
        - name: wait-for-dependencies
          image: busybox:1.37
          # no securityContext
      containers:
        - name: apply-definitions
          image: curlimages/curl:8.7.1
          # no securityContext
```

#### After (v9.2.7):

**bootstrap-mongodb.yaml:**
```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 999 # the mongo image's own user
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

**bootstrap-postgres.yaml:**
```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 999 # the postgres image's own user
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.37
        securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
      containers:
      - name: psql
        image: postgres:16
        securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
```

**bootstrap-rabbitmq.yaml:**
```yaml
spec:
  template:
    spec:
      restartPolicy: OnFailure
      securityContext:
        runAsNonRoot: true
        runAsUser: 100 # the curl image's own user
        seccompProfile:
          type: RuntimeDefault
      initContainers:
        - name: wait-for-dependencies
          image: busybox:1.37
          securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
      containers:
        - name: apply-definitions
          image: curlimages/curl:8.7.1
          securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
```

#### Why This Matters

- **Compliance:** Many Kubernetes environments enforce Pod Security Standards (PSS) at the `restricted` level. Without these settings, bootstrap jobs may fail to schedule or run.
- **Security:** Dropping all capabilities and preventing privilege escalation reduces the attack surface of these jobs.
- **Best Practice:** Running as non-root with seccomp profiles aligns with container security hardening guidelines.

#### Operator Impact

| Setting | v9.2.6 | v9.2.7 |
|---------|--------|--------|
| Pod-level `runAsNonRoot` | Not set | `true` |
| Pod-level `runAsUser` | Not set | `999` (MongoDB, PostgreSQL), `100` (RabbitMQ) |
| Pod-level `seccompProfile` | Not set | `RuntimeDefault` |
| Container-level `allowPrivilegeEscalation` | Not set | `false` |
| Container-level `capabilities.drop` | Not set | `[ALL]` |

> **Note:** If your cluster enforces Pod Security Admission at the `restricted` level, this change ensures bootstrap jobs will pass validation. No action is required from operators unless you have custom PodSecurityPolicies or admission controllers that conflict with these settings.

> **Important:** The `runAsUser` values (`999` for MongoDB/PostgreSQL, `100` for RabbitMQ) match the default non-root users in the respective container images. If you use custom images with different UIDs, you may need to override these values via a custom template or image configuration.

### 2. Security Context for Ledger Init Container

The `wait-for-dependencies` init container in the ledger deployment now inherits the security context defined in `values.yaml` under `ledger.securityContext`.

#### What Changed

**Before (v9.2.6):**
```yaml
initContainers:
  - name: wait-for-dependencies
    image: busybox:1.37
    # no securityContext applied
```

**After (v9.2.7):**
```yaml
initContainers:
  - name: wait-for-dependencies
    image: busybox:1.37
    securityContext:
      {{- toYaml .Values.ledger.securityContext | nindent 12 }}
```

#### Why This Matters

Previously, the ledger's init container did not inherit the security context from `values.yaml`, creating an inconsistency with the main container. This change ensures uniform security posture across all containers in the ledger pod.

#### Operator Impact

| Setting | v9.2.6 | v9.2.7 |
|---------|--------|--------|
| Init container `securityContext` | Not applied | Inherits from `ledger.securityContext` |

> **Note:** Review your `values.yaml` to ensure `ledger.securityContext` is configured appropriately. The default values typically include:

```yaml
ledger:
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    runAsNonRoot: true
    runAsUser: 1000
```

If you have overridden `ledger.securityContext` with custom values, those will now also apply to the init container. Verify that your custom settings are compatible with the `busybox:1.37` image used by the init container.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.7 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.7 -n midaz
```
