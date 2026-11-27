<!-- {% raw %} -->
# Helm Upgrade from v5.5.2 to v5.6.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Service Account Support for Pix Component](#1-service-account-support-for-pix-component)
  - [2. Antifraud Secrets Backend Configuration](#2-antifraud-secrets-backend-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [Service Account Settings](#service-account-settings)
  - [Antifraud Secrets Backend Settings](#antifraud-secrets-backend-settings)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This minor release adds opt-in service account support for the `pix` component and introduces configuration for antifraud credential storage backend selection. The application version remains at `1.15.0` for all components.

The expected upgrade path is an in-place Helm upgrade. All new configuration fields are optional and disabled by default, maintaining backward compatibility with existing deployments. Operators using AWS IAM Roles for Service Accounts (IRSA) or HashiCorp Vault Roles Anywhere should review the new service account configuration to enable least-privilege access for antifraud credential management.

| Component | v5.5.2 | v5.6.0 |
|-----------|--------|--------|
| Chart version | `5.5.2` | `5.6.0` |
| App version | `1.15.0` | `1.15.0` |
| Components | 5 (pix, inbound, outbound, reconciliation, schedule) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Features

### 1. Service Account Support for Pix Component

The `pix` component now supports creating and using a dedicated Kubernetes service account with custom annotations. This enables integration with cloud IAM systems like AWS IRSA or HashiCorp Vault Roles Anywhere for secure credential management.

**What changed:**

A new `serviceAccount` configuration block has been added to the `pix` component:

| Setting | v5.5.2 | v5.6.0 |
|---------|--------|--------|
| `pix.serviceAccount.create` | (not present) | `false` |
| `pix.serviceAccount.name` | (not present) | `""` |
| `pix.serviceAccount.annotations` | (not present) | `{}` |

A new template file `templates/pix/serviceaccount.yaml` has been added to create the service account when enabled.

The `pix` deployment template now references the service account when configured:

**Before (v5.5.2):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: {{ $h.terminationGracePeriodSeconds }}
    {{- with .Values.pix.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
    {{- end }}
```

**After (v5.6.0):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: {{ $h.terminationGracePeriodSeconds }}
      {{- if or .Values.pix.serviceAccount.create .Values.pix.serviceAccount.name }}
      serviceAccountName: {{ include "plugin-br-pix-indirect-btg.serviceAccountName" . }}
      {{- end }}
    {{- with .Values.pix.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
    {{- end }}
```

**Why it matters:**

The `pix` component serves the antifraud credential management API endpoint. By default, all pods in a namespace run under the namespace's default service account, which may have broader permissions than necessary. Creating a dedicated service account for the `pix` component enables:

1. **Least-privilege access:** Grant only the `pix` pod permission to write antifraud credentials to AWS Secrets Manager or HashiCorp Vault
2. **Cloud IAM integration:** Use AWS IRSA annotations to bind an IAM role, or Vault Roles Anywhere annotations to bind a Vault role
3. **Audit trail:** Separate the `pix` component's cloud API calls from other components in CloudTrail or Vault audit logs

**Operational impact:**

The upgrade will not create a service account or change pod behavior unless you explicitly enable it. By default:
- `pix.serviceAccount.create: false` — no service account is created
- `pix.serviceAccount.name: ""` — the pod runs under the namespace default service account

To enable the feature, you must set `pix.serviceAccount.create: true` and optionally provide annotations for your cloud IAM system.

**Use case: AWS IRSA integration**

If you use AWS IAM Roles for Service Accounts to grant the `pix` component permission to write antifraud credentials to AWS Secrets Manager:

```yaml
pix:
  serviceAccount:
    create: true
    name: "plugin-br-pix-indirect-btg-pix"
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/pix-antifraud-secrets-writer"
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

**Use case: HashiCorp Vault Roles Anywhere**

If you use HashiCorp Vault Roles Anywhere to grant the `pix` component permission to write antifraud credentials to Vault:

```yaml
pix:
  serviceAccount:
    create: true
    name: "plugin-br-pix-indirect-btg-pix"
    annotations:
      vault.hashicorp.com/role: "pix-antifraud-writer"
      vault.hashicorp.com/agent-inject: "true"
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "vault"
```

**Use case: Reference existing service account**

If you have already created a service account outside of this chart (e.g., via a separate Helm chart or kubectl), you can reference it without creating a new one:

```yaml
pix:
  serviceAccount:
    create: false
    name: "my-existing-service-account"
```

> **Important:** The service account is created without a namespace declaration, so it follows the Helm release namespace. Ensure your IAM role trust policy or Vault role binding matches the namespace where you deploy the chart.

> **Note:** Only the `pix` component supports a dedicated service account in this release. The `inbound`, `outbound`, `reconciliation`, and `schedule` components continue to run under the namespace default service account.

### 2. Antifraud Secrets Backend Configuration

The `pix` component now supports explicit configuration of the antifraud credential storage backend through the `ANTIFRAUD_SECRETS_BACKEND` environment variable.

**What changed:**

A new optional environment variable has been added to the `pix` component's configmap:

| Setting | v5.5.2 | v5.6.0 |
|---------|--------|--------|
| `pix.configmap.ANTIFRAUD_SECRETS_BACKEND` | (not present) | (commented out, no default) |

The configmap template now conditionally renders this variable:

**Before (v5.5.2):**

```yaml
data:
  ANTIFRAUD_HOOK_CB_TIMEOUT: {{ .Values.pix.configmap.ANTIFRAUD_HOOK_CB_TIMEOUT | default "30s" | quote }}
  ANTIFRAUD_HOOK_CB_FAILURE_THRESHOLD: {{ .Values.pix.configmap.ANTIFRAUD_HOOK_CB_FAILURE_THRESHOLD | default "5" | quote }}
  ANTIFRAUD_HOOK_PREWARM_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.ANTIFRAUD_HOOK_PREWARM_ENABLED | quote }}

  SWAGGER_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.SWAGGER_ENABLED | quote }}
```

**After (v5.6.0):**

```yaml
data:
  ANTIFRAUD_HOOK_CB_TIMEOUT: {{ .Values.pix.configmap.ANTIFRAUD_HOOK_CB_TIMEOUT | default "30s" | quote }}
  ANTIFRAUD_HOOK_CB_FAILURE_THRESHOLD: {{ .Values.pix.configmap.ANTIFRAUD_HOOK_CB_FAILURE_THRESHOLD | default "5" | quote }}
  ANTIFRAUD_HOOK_PREWARM_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.ANTIFRAUD_HOOK_PREWARM_ENABLED | quote }}

  {{- /* Antifraud credential store: aws or vault; rendered only when set (a key in extraEnvVars wins). */}}
  {{- with .Values.pix.configmap.ANTIFRAUD_SECRETS_BACKEND }}
  {{- if not (hasKey ($.Values.pix.extraEnvVars | default dict) "ANTIFRAUD_SECRETS_BACKEND") }}
  ANTIFRAUD_SECRETS_BACKEND: {{ . | quote }}
  {{- end }}
  {{- end }}

  SWAGGER_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.SWAGGER_ENABLED | quote }}
```

**Why it matters:**

The `pix` component exposes an API endpoint for partner antifraud credential management. This endpoint allows partners to register their antifraud service credentials, which the plugin stores in a secure backend (AWS Secrets Manager or HashiCorp Vault).

The `ANTIFRAUD_SECRETS_BACKEND` variable controls which backend the `pix` component uses:
- `"aws"` — Store credentials in AWS Secrets Manager
- `"vault"` — Store credentials in HashiCorp Vault
- Not set — The antifraud credential API denies all requests

**Operational impact:**

The upgrade will not add the `ANTIFRAUD_SECRETS_BACKEND` environment variable to the `pix` deployment unless you explicitly set it in your values file. By default, the variable is not rendered, and the antifraud credential API will deny all requests.

To enable antifraud credential storage, you must:
1. Set `pix.configmap.ANTIFRAUD_SECRETS_BACKEND` to `"aws"` or `"vault"`
2. Configure the appropriate cloud IAM permissions (see [Feature 1](#1-service-account-support-for-pix-component))
3. Ensure the `pix` component can reach the secrets backend (AWS Secrets Manager API or Vault API)

**Valid backend values:**

| Value | Description | Required IAM Permissions |
|-------|-------------|--------------------------|
| `"aws"` | AWS Secrets Manager | `secretsmanager:CreateSecret`, `secretsmanager:PutSecretValue` |
| `"vault"` | HashiCorp Vault | Vault policy allowing `write` to the antifraud secrets path |
| (not set) | Disabled | None (credential API denies all requests) |

**Example configuration for AWS Secrets Manager:**

```yaml
pix:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/pix-antifraud-secrets-writer"
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

**Example configuration for HashiCorp Vault:**

```yaml
pix:
  serviceAccount:
    create: true
    annotations:
      vault.hashicorp.com/role: "pix-antifraud-writer"
      vault.hashicorp.com/agent-inject: "true"
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "vault"
```

> **Important:** The template logic checks for `ANTIFRAUD_SECRETS_BACKEND` in `pix.extraEnvVars` first. If you set the variable via `extraEnvVars`, the `configmap` value is ignored. This allows you to override the backend selection using environment-specific configuration without modifying the base values file.

> **Note:** The values.yaml file includes a commented-out example of this variable with the note: "Partner antifraud credential store, 'aws' or 'vault'; not set by default, and an enabled flow then denies." This indicates that leaving the variable unset is a safe default that prevents accidental credential storage without proper IAM configuration.

## Configuration Reference

### Service Account Settings

Service account configuration is defined in the `pix.serviceAccount` block.

| Flag | Default | Description |
|------|---------|-------------|
| `pix.serviceAccount.create` | `false` | Create a dedicated service account for the pix component |
| `pix.serviceAccount.name` | `""` | Name of the service account; with `create: false`, names an existing service account to use |
| `pix.serviceAccount.annotations` | `{}` | Annotations for the service account (e.g., AWS IRSA role ARN or Vault role binding) |

**Service account behavior:**

| Configuration | Result |
|---------------|--------|
| `create: false`, `name: ""` | Pod runs under namespace default service account (v5.5.2 behavior) |
| `create: true`, `name: ""` | Chart generates a service account name and creates it |
| `create: true`, `name: "custom-name"` | Chart creates a service account with the specified name |
| `create: false`, `name: "existing-sa"` | Pod runs under the existing service account (must exist before upgrade) |

**Example configuration:**

```yaml
pix:
  serviceAccount:
    create: true
    name: "plugin-br-pix-indirect-btg-pix"
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/pix-antifraud-secrets-writer"
```

### Antifraud Secrets Backend Settings

Antifraud credential storage backend is configured through the `pix.configmap.ANTIFRAUD_SECRETS_BACKEND` environment variable.

| Flag | Default | Valid Values | Description |
|------|---------|--------------|-------------|
| `ANTIFRAUD_SECRETS_BACKEND` | (not set) | `"aws"`, `"vault"`, (not set) | Backend for storing partner antifraud credentials |

**Backend behavior:**

| Value | Credential Storage | API Behavior |
|-------|-------------------|--------------|
| (not set) | Disabled | Antifraud credential API denies all requests |
| `"aws"` | AWS Secrets Manager | API stores credentials in AWS Secrets Manager |
| `"vault"` | HashiCorp Vault | API stores credentials in HashiCorp Vault |

**Example configuration:**

```yaml
pix:
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

> **Note:** If you set `ANTIFRAUD_SECRETS_BACKEND` via `pix.extraEnvVars`, that value takes precedence over the `configmap` value. This allows environment-specific overrides without modifying the base values file.

## Migration Steps

This upgrade requires no mandatory configuration changes. All new features are opt-in and disabled by default. However, operators using antifraud credential management should review the new configuration options and consider enabling dedicated service account support for improved security.

### Recommended migration process

**1. Review current antifraud configuration:**

Check whether you are using antifraud credential management:

```bash
helm get values plugin-br-pix-indirect-btg -n midaz-plugins
```

Look for any antifraud-related configuration in the `pix.configmap` or `pix.extraEnvVars` blocks.

**2. Preview the upgrade:**

Use the helm-diff plugin to see what will change:

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.6.0 -n midaz-plugins
```

**3. Decide on service account configuration:**

#### Option 1: Keep existing behavior (no dedicated service account)

If you are not using antifraud credential management or do not require cloud IAM integration, no configuration changes are required. The upgrade will maintain existing behavior with the `pix` component running under the namespace default service account.

#### Option 2: Enable dedicated service account with AWS IRSA

If you use AWS IAM Roles for Service Accounts and want to grant the `pix` component least-privilege access to AWS Secrets Manager:

**Step 1:** Create an IAM role with the required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:PutSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:antifraud/*"
    }
  ]
}
```

**Step 2:** Configure the trust policy to allow the service account:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:midaz-plugins:plugin-br-pix-indirect-btg-pix"
        }
      }
    }
  ]
}
```

**Step 3:** Update your values file:

```yaml
pix:
  serviceAccount:
    create: true
    name: "plugin-br-pix-indirect-btg-pix"
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/pix-antifraud-secrets-writer"
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

#### Option 3: Enable dedicated service account with HashiCorp Vault

If you use HashiCorp Vault Roles Anywhere and want to grant the `pix` component least-privilege access to Vault:

**Step 1:** Create a Vault policy with the required permissions:

```hcl
path "secret/data/antifraud/*" {
  capabilities = ["create", "update"]
}
```

**Step 2:** Create a Vault role bound to the service account:

```bash
vault write auth/kubernetes/role/pix-antifraud-writer \
  bound_service_account_names=plugin-br-pix-indirect-btg-pix \
  bound_service_account_namespaces=midaz-plugins \
  policies=pix-antifraud-writer \
  ttl=1h
```

**Step 3:** Update your values file:

```yaml
pix:
  serviceAccount:
    create: true
    name: "plugin-br-pix-indirect-btg-pix"
    annotations:
      vault.hashicorp.com/role: "pix-antifraud-writer"
      vault.hashicorp.com/agent-inject: "true"
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "vault"
```

#### Option 4: Reference existing service account

If you have already created a service account with the necessary annotations outside of this chart:

```yaml
pix:
  serviceAccount:
    create: false
    name: "my-existing-pix-service-account"
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

> **Important:** Ensure the existing service account exists in the same namespace where you deploy the chart before running the upgrade.

**4. Run the upgrade:**

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.6.0 -n midaz-plugins -f your-values.yaml
```

**5. Verify deployment health:**

Check that all pods are running and healthy:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

**6. Verify service account configuration (if enabled):**

If you enabled a dedicated service account, verify it was created and attached to the `pix` pod:

```bash
kubectl get serviceaccount -n midaz-plugins plugin-br-pix-indirect-btg-pix
kubectl get pod -n midaz-plugins -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-pix -o jsonpath='{.items[0].spec.serviceAccountName}'
```

**7. Verify antifraud backend configuration (if enabled):**

If you set `ANTIFRAUD_SECRETS_BACKEND`, verify the environment variable is present in the `pix` deployment:

```bash
kubectl get configmap -n midaz-plugins plugin-br-pix-indirect-btg-pix -o yaml | grep ANTIFRAUD_SECRETS_BACKEND
```

**8. Test antifraud credential API (if enabled):**

If you enabled antifraud credential storage, test the API endpoint to ensure credentials can be stored:

```bash
kubectl port-forward -n midaz-plugins svc/plugin-br-pix-indirect-btg-pix 8080:8080
curl -X POST http://localhost:8080/v1/antifraud/credentials \
  -H "Content-Type: application/json" \
  -d '{"partner_id": "test-partner", "api_key": "test-key"}'
```

> **Note:** The exact API endpoint and payload format depend on your antifraud integration. Consult your antifraud provider documentation for the correct API usage.

**9. Monitor service logs for IAM errors:**

If you enabled cloud IAM integration, monitor the `pix` component logs for any permission errors:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-pix --tail=100 | grep -i "access denied\|permission\|unauthorized"
```

> **Warning:** If you see IAM permission errors, verify that your IAM role trust policy or Vault role binding matches the service account name and namespace exactly. A mismatch will prevent the `pix` component from accessing the secrets backend.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.6.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.6.0
```
<!-- {% endraw %} -->
