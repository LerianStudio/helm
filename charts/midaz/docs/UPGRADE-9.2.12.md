# Helm Upgrade from v9.2.11 to v9.2.12

## Topics

- **[Fixes](#fixes)**
  - [1. Automatic pod restart on secret changes](#1-automatic-pod-restart-on-secret-changes)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Automatic pod restart on secret changes

This release adds automatic pod restart detection when secrets are updated. A checksum annotation is now injected into pod templates for the `crm`, `ledger`, and `tracer` components, ensuring pods are automatically restarted when their associated secrets change.

#### What changed

Pod template annotations now include a `checksum/secret` field that computes a SHA256 hash of the component's secret manifest. When the secret content changes, the checksum changes, triggering a rolling restart of the pods.

**Before (v9.2.11):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "midaz-crm.labels" (dict "context" . "name" .Values.crm.name ) | nindent 8 }}
      {{- with .Values.crm.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

**After (v9.2.12):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "midaz-crm.labels" (dict "context" . "name" .Values.crm.name ) | nindent 8 }}
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/crm/secrets.yaml") . | sha256sum }}
        {{- with .Values.crm.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
```

#### Why it matters

Previously, when secrets were updated (e.g., database passwords, API keys), pods would continue running with stale secret values until manually restarted. This could lead to:
- Authentication failures after credential rotation
- Inconsistent behavior between old and new pods during deployments
- Manual intervention required to restart pods after secret updates

With this change, Helm automatically detects secret changes and triggers a rolling restart, ensuring all pods use the latest secret values without manual intervention.

#### Components affected

This fix applies to the following components:
- `crm` (Customer Relationship Management service)
- `ledger` (Ledger service)
- `tracer` (Tracer service)

#### Operational impact

| Aspect | Behavior |
|--------|----------|
| **Secret updates** | Pods now restart automatically when secrets change |
| **Upgrade behavior** | First upgrade to v9.2.12 will restart affected pods once (checksum annotation added) |
| **Downtime** | Rolling restart ensures zero-downtime during secret updates |
| **Manual restarts** | No longer required after secret rotation |

> **Note:** The initial upgrade to v9.2.12 will trigger a rolling restart of `crm`, `ledger`, and `tracer` pods as the checksum annotation is added to their pod templates. This is expected behavior and ensures the mechanism is active going forward.

> **Important:** If you use `useExistingSecrets: true` with external secret management (e.g., External Secrets Operator, Sealed Secrets), the checksum will still be computed from the Helm template. Ensure your external secret updates are synchronized with Helm upgrades to trigger restarts correctly.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.12 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.12 -n midaz
```
