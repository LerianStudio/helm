# Helm Upgrade from v9.3.0 to v9.4.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 4.1.2](#1-application-version-bump-to-412)
  - [2. Common library update to 2.1.2](#2-common-library-update-to-212)
  - [3. Tracer reservation seam authentication](#3-tracer-reservation-seam-authentication)
  - [4. AWS IAM Roles Anywhere support for multi-tenant ledger](#4-aws-iam-roles-anywhere-support-for-multi-tenant-ledger)
- **[Configuration Reference](#configuration-reference)**
  - [New ledger environment variables](#new-ledger-environment-variables)
  - [New ledger secrets](#new-ledger-secrets)
  - [New AWS IAM Roles Anywhere configuration](#new-aws-iam-roles-anywhere-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 4.1.2

The midaz application components have been updated from version `4.1.0` to `4.1.2`.

| Component | v9.3.0 | v9.4.0 |
|-----------|--------|--------|
| appVersion | 4.1.0 | 4.1.2 |
| ledger.image.tag | 4.1.0 | 4.1.2 |
| tracer.image.tag | 4.1.0 | 4.1.2 |

This is a patch release that includes bug fixes and improvements. Refer to the [midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md) for detailed application-level changes.

### 2. Common library update to 2.1.2

The `lerian-common-helm` dependency has been updated from version `2.1.0` to `2.1.2`.

| Dependency | v9.3.0 | v9.4.0 |
|------------|--------|--------|
| lerian-common-helm | 2.1.0 | 2.1.2 |

This update brings improvements to the shared template library, including enhanced support for AWS IAM Roles Anywhere integration.

### 3. Tracer reservation seam authentication

New authentication options have been added for the ledger's communication with the tracer service through the reservation seam. The ledger now supports two authentication modes:

#### Token-based authentication (PLUGIN_AUTH_ENABLED=true)

For single-tenant deployments using Access Manager, the ledger can authenticate to the tracer using M2M (machine-to-machine) credentials.

**New ConfigMap variables:**

```yaml
ledger:
  configmap:
    TRACER_M2M_CLIENT_ID: ""
    TRACER_M2M_WAIT_TIMEOUT_MS: ""
```

**New Secret variables:**

```yaml
ledger:
  secrets:
    TRACER_M2M_CLIENT_SECRET: ""
```

| Variable | Location | Description |
|----------|----------|-------------|
| TRACER_M2M_CLIENT_ID | ConfigMap | The ledger's Access Manager application client ID for tracer authentication |
| TRACER_M2M_CLIENT_SECRET | Secret | The corresponding client secret (pairs with TRACER_M2M_CLIENT_ID) |
| TRACER_M2M_WAIT_TIMEOUT_MS | ConfigMap | Milliseconds a reservation seam call may wait for an M2M token before the TRACER_TIMEOUT_MS budget starts. Empty uses the ledger default (3000) |

#### API key authentication (PLUGIN_AUTH_ENABLED=false)

For deployments where the tracer runs with `API_KEY_ENABLED=true`, the ledger can authenticate using an API key.

**New Secret variable:**

```yaml
ledger:
  secrets:
    TRACER_API_KEY: ""
```

| Variable | Location | Description |
|----------|----------|-------------|
| TRACER_API_KEY | Secret | API key for tracer authentication when PLUGIN_AUTH_ENABLED=false |

> **Note:** These variables are optional and only rendered when explicitly set. Choose the authentication method that matches your tracer configuration.

### 4. AWS IAM Roles Anywhere support for multi-tenant ledger

A new AWS credential source mechanism has been added for multi-tenant ledger deployments. The ledger can now read per-tenant tracer M2M credentials from AWS Secrets Manager at runtime using IAM Roles Anywhere.

This feature provides two mutually exclusive authentication options for AWS:

#### Option 1: EKS with IRSA (recommended for EKS clusters)

For clusters running on Amazon EKS, use IAM Roles for Service Accounts (IRSA). Keep `ledger.aws.rolesAnywhere.enabled: false` and configure the role ARN via service account annotations:

```yaml
ledger:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/midaz-ledger-role"
  extraEnvVars:
    - name: AWS_REGION
      value: "us-east-1"
```

#### Option 2: IAM Roles Anywhere (for non-EKS clusters)

For clusters outside EKS, enable the `aws-signing-helper` sidecar that trades an X.509 client certificate for temporary AWS credentials:

```yaml
ledger:
  aws:
    rolesAnywhere:
      enabled: true
      trustAnchorArn: "arn:aws:rolesanywhere:us-east-2:123456789012:trust-anchor/abc123"
      profileArn: "arn:aws:rolesanywhere:us-east-2:123456789012:profile/def456"
      roleArn: "arn:aws:iam::123456789012:role/midaz-ledger-role"
      region: "us-east-2"
      sessionDuration: 3600
      certificateSecretName: ""  # defaults to <midaz-ledger.fullname>-iam-tls
      sidecar:
        image:
          repository: public.ecr.aws/rolesanywhere/credential-helper
          tag: latest-amd64
          pullPolicy: IfNotPresent
        port: 9911
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi
  extraEnvVars:
    - name: AWS_REGION
      value: "us-east-2"
```

> **Important:** The certificate Secret referenced by `certificateSecretName` is NOT created by this chart. You must provision it separately (using cert-manager or another method) with keys `tls.crt` and `tls.key`.

> **Warning:** Never enable both IRSA and Roles Anywhere simultaneously. Choose one method per cluster.

**Template changes:**

When `ledger.aws.rolesAnywhere.enabled: true`, the chart automatically:

1. Adds the `aws-signing-helper` sidecar to the ledger pod
2. Mounts the certificate Secret read-only
3. Replaces `ledger.podSecurityContext` with `fsGroup: 65532` so the sidecar (running as user 65532) can read the certificate
4. Injects `AWS_CONTAINER_CREDENTIALS_FULL_URI` environment variable pointing to the sidecar's loopback IMDS endpoint

**Before (v9.3.0):**

```yaml
spec:
  template:
    spec:
      securityContext:
        {{- toYaml .Values.ledger.podSecurityContext | nindent 8 }}
      containers:
        - name: ledger
          # ... ledger container spec
```

**After (v9.4.0):**

```yaml
spec:
  template:
    spec:
      {{- include "lerian-common.rolesAnywhere.podSecurityContext" (dict "aws" .Values.ledger.aws "podSecurityContext" .Values.ledger.podSecurityContext) | nindent 6 }}
      containers:
        - name: ledger
          env:
            {{- if include "midaz.ledgerRolesAnywhereEnabled" . }}
            {{- include "lerian-common.rolesAnywhere.imdsEnv" (dict "aws" .Values.ledger.aws) | nindent 12 }}
            {{- end }}
          # ... rest of ledger container spec
        {{- if include "midaz.ledgerRolesAnywhereEnabled" . }}
        {{- include "lerian-common.rolesAnywhere.sidecar" (dict "aws" .Values.ledger.aws) | nindent 8 }}
        {{- end }}
      {{- if include "midaz.ledgerRolesAnywhereEnabled" . }}
      {{- include "lerian-common.rolesAnywhere.volume" (dict "aws" .Values.ledger.aws "iamTlsDefault" (printf "%s-iam-tls" (include "midaz-ledger.fullname" .))) | nindent 6 }}
      {{- end }}
```

**Operational impact:**

- The sidecar runs continuously, refreshing credentials before expiry (controlled by `sessionDuration`)
- The AWS SDK inside the ledger automatically discovers credentials from the sidecar's IMDS endpoint
- The ledger reads per-tenant tracer credentials from Secrets Manager path: `tenants/{env}/{tenant}/ledger/m2m/tracer/credentials`
- The ledger refuses to boot in multi-tenant mode without `AWS_REGION` set

## Configuration Reference

### New ledger environment variables

The following environment variables have been added to the ledger ConfigMap:

| Variable | Default | Description |
|----------|---------|-------------|
| TRACER_M2M_CLIENT_ID | "" | Access Manager application client ID for tracer authentication (single-tenant, PLUGIN_AUTH_ENABLED=true). Rendered only when set. |
| TRACER_M2M_WAIT_TIMEOUT_MS | "" | Milliseconds a reservation seam call may wait for an M2M token that is not cached yet, before the TRACER_TIMEOUT_MS budget starts. Empty uses the ledger default (3000). Rendered only when set. |

**Example configuration:**

```yaml
ledger:
  configmap:
    TRACER_M2M_CLIENT_ID: "ledger-tracer-client"
    TRACER_M2M_WAIT_TIMEOUT_MS: "5000"
```

### New ledger secrets

The following secret variables have been added to the ledger Secret:

| Variable | Description |
|----------|-------------|
| TRACER_M2M_CLIENT_SECRET | Client secret pairing with TRACER_M2M_CLIENT_ID for Access Manager token authentication. Rendered only when set. |
| TRACER_API_KEY | API key for tracer authentication when PLUGIN_AUTH_ENABLED=false and the tracer runs with API_KEY_ENABLED=true. Rendered only when set. |

**Example configuration:**

```yaml
ledger:
  secrets:
    TRACER_M2M_CLIENT_SECRET: "your-client-secret-here"
    # OR
    TRACER_API_KEY: "your-api-key-here"
```

> **Note:** Choose either M2M credentials or API key based on your tracer authentication mode. Do not set both.

### New AWS IAM Roles Anywhere configuration

The following configuration block has been added under `ledger.aws`:

```yaml
ledger:
  aws:
    rolesAnywhere:
      enabled: false
      trustAnchorArn: ""
      profileArn: ""
      roleArn: ""
      region: "us-east-2"
      sessionDuration: 3600
      certificateSecretName: ""
      sidecar:
        image:
          repository: public.ecr.aws/rolesanywhere/credential-helper
          tag: latest-amd64
          pullPolicy: IfNotPresent
        port: 9911
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi
```

| Field | Default | Required | Description |
|-------|---------|----------|-------------|
| enabled | false | No | Enable the aws-signing-helper sidecar. Keep false on EKS with IRSA. |
| trustAnchorArn | "" | Yes (when enabled) | ARN of the IAM Roles Anywhere trust anchor |
| profileArn | "" | Yes (when enabled) | ARN of the IAM Roles Anywhere profile |
| roleArn | "" | Yes (when enabled) | ARN of the IAM role to assume |
| region | "us-east-2" | No | AWS region where credentials are minted |
| sessionDuration | 3600 | No | Credential lifetime in seconds; the helper refreshes before expiry |
| certificateSecretName | "" | No | Secret holding tls.crt / tls.key. Defaults to `<midaz-ledger.fullname>-iam-tls` |
| sidecar.port | 9911 | No | Loopback port the IMDS shim listens on |

> **Important:** When `enabled: true`, the render fails if `trustAnchorArn`, `profileArn`, or `roleArn` are empty.

## Migration Steps

This is a minor version upgrade with no breaking changes. Follow these steps to upgrade:

1. **Review authentication requirements** for the ledger-tracer communication:
   - If using Access Manager (PLUGIN_AUTH_ENABLED=true), set `TRACER_M2M_CLIENT_ID` and `TRACER_M2M_CLIENT_SECRET`
   - If using API key authentication, set `TRACER_API_KEY`
   - If not using either, no action required

2. **For multi-tenant deployments requiring AWS Secrets Manager integration:**
   - **On EKS:** Configure IRSA by setting the role ARN in `ledger.serviceAccount.annotations`
   - **Outside EKS:** Provision an X.509 certificate Secret, then enable and configure `ledger.aws.rolesAnywhere`
   - Set `AWS_REGION` in `ledger.extraEnvVars` to the region where your secrets live

3. **Update your values file** with any new configuration from the sections above

4. **Preview the changes** using helm diff (see next section)

5. **Run the upgrade command** (see final section)

> **Note:** The application version bump from 4.1.0 to 4.1.2 is a patch release. Review the [midaz changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md) for application-specific changes.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.4.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.4.0 -n midaz
```
