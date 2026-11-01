<!-- {% raw %} -->
# Helm Upgrade from v5.2.1 to v5.2.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Automatic pod restart on configuration changes](#1-automatic-pod-restart-on-configuration-changes)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that adds automatic pod restart behavior when ConfigMaps or Secrets change. The application version remains at `1.12.0` across all components. No configuration changes are required — the upgrade adds checksum annotations to all deployment templates to trigger rolling restarts when configuration data changes.

The expected upgrade path is an in-place Helm upgrade with no downtime beyond the normal rolling restart window.

| Component | v5.2.1 | v5.2.2 |
|-----------|--------|--------|
| Chart version | `5.2.1` | `5.2.2` |
| App version | `1.12.0` | `1.12.0` |
| Components | 5 (pix, inbound, outbound, reconciliation, schedule) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Fixes

### 1. Automatic pod restart on configuration changes

All five deployment templates now include checksum annotations that automatically trigger pod restarts when their associated ConfigMaps or Secrets change.

**What changed:**

Each deployment template (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) now includes checksum annotations in the pod template metadata. These annotations compute a SHA256 hash of the ConfigMap and Secret contents, causing Kubernetes to perform a rolling restart whenever the configuration data changes.

**Why it matters:**

Before this change, updating a ConfigMap or Secret value required operators to manually restart pods to pick up the new configuration. This was error-prone and could lead to configuration drift where some pods were running with old values while others had new values.

With checksum annotations, Helm automatically triggers a rolling restart whenever you change configuration values, ensuring all pods consistently use the latest configuration.

**Operational impact:**

After upgrading to v5.2.2, any future `helm upgrade` that changes ConfigMap or Secret values will automatically trigger a rolling restart of the affected deployments. This eliminates the need for manual pod restarts after configuration changes.

The upgrade to v5.2.2 itself will **not** trigger a restart unless you also change configuration values in the same upgrade operation, because the checksum annotations are computed from the rendered ConfigMap and Secret content, which remains unchanged if you don't modify any values.

**Template changes:**

#### Inbound deployment

**Before (v5.2.1):**

```yaml
  template:
    metadata:
      labels:
        {{- include "inbound.labels" (dict "context" . "name" .Values.inbound.name ) | nindent 8 }}
    spec:
```

**After (v5.2.2):**

```yaml
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/inbound/configmap.yaml") . | sha256sum }}
        {{- if not .Values.inbound.useExistingSecrets }}
        checksum/secret: {{ include (print $.Template.BasePath "/inbound/secrets.yaml") . | sha256sum }}
        {{- end }}
      labels:
        {{- include "inbound.labels" (dict "context" . "name" .Values.inbound.name ) | nindent 8 }}
    spec:
```

#### Outbound deployment

**Before (v5.2.1):**

```yaml
  template:
    metadata:
      labels:
        {{- include "outbound.labels" (dict "context" . "name" .Values.outbound.name ) | nindent 8 }}
    spec:
```

**After (v5.2.2):**

```yaml
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/outbound/configmap.yaml") . | sha256sum }}
        {{- if not .Values.outbound.useExistingSecrets }}
        checksum/secret: {{ include (print $.Template.BasePath "/outbound/secrets.yaml") . | sha256sum }}
        {{- end }}
      labels:
        {{- include "outbound.labels" (dict "context" . "name" .Values.outbound.name ) | nindent 8 }}
    spec:
```

#### Pix deployment

**Before (v5.2.1):**

```yaml
  template:
    metadata:
      {{- if and .Values.mtls.enabled (index .Values.mtls "tls.crt") }}
      annotations:
        # Roll the pods when the chart-managed mTLS cert changes (app snapshots it at startup).
        checksum/mtls: {{ include "plugin-br-pix-indirect-btg.mtlsChecksum" . }}
      {{- end }}
      labels:
        {{- include "plugin-br-pix-indirect-btg.labels" (dict "context" . "name" .Values.pix.name ) | nindent 8 }}
    spec:
```

**After (v5.2.2):**

```yaml
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/pix/configmap.yaml") . | sha256sum }}
        {{- if not .Values.pix.useExistingSecrets }}
        checksum/secret: {{ include (print $.Template.BasePath "/pix/secrets.yaml") . | sha256sum }}
        {{- end }}
        {{- if and .Values.mtls.enabled (index .Values.mtls "tls.crt") }}
        # Roll the pods when the chart-managed mTLS cert changes (app snapshots it at startup).
        checksum/mtls: {{ include "plugin-br-pix-indirect-btg.mtlsChecksum" . }}
        {{- end }}
      labels:
        {{- include "plugin-br-pix-indirect-btg.labels" (dict "context" . "name" .Values.pix.name ) | nindent 8 }}
    spec:
```

> **Note:** The `pix` deployment already had a conditional `checksum/mtls` annotation for mTLS certificate changes. The new checksum annotations are added alongside the existing mTLS checksum, and the `annotations:` block is now always present (not conditional).

#### Reconciliation deployment

**Before (v5.2.1):**

```yaml
  template:
    metadata:
      {{- if and .Values.mtls.enabled (index .Values.mtls "tls.crt") }}
      annotations:
        # Roll the pods when the chart-managed mTLS cert changes (app snapshots it at startup).
        checksum/mtls: {{ include "plugin-br-pix-indirect-btg.mtlsChecksum" . }}
      {{- end }}
      labels:
        {{- include "reconciliation.labels" (dict "context" . "name" .Values.reconciliation.name ) | nindent 8 }}
    spec:
```

**After (v5.2.2):**

```yaml
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/reconciliation/configmap.yaml") . | sha256sum }}
        {{- if not .Values.reconciliation.useExistingSecrets }}
        checksum/secret: {{ include (print $.Template.BasePath "/reconciliation/secrets.yaml") . | sha256sum }}
        {{- end }}
        {{- if and .Values.mtls.enabled (index .Values.mtls "tls.crt") }}
        # Roll the pods when the chart-managed mTLS cert changes (app snapshots it at startup).
        checksum/mtls: {{ include "plugin-br-pix-indirect-btg.mtlsChecksum" . }}
        {{- end }}
      labels:
        {{- include "reconciliation.labels" (dict "context" . "name" .Values.reconciliation.name ) | nindent 8 }}
    spec:
```

> **Note:** The `reconciliation` deployment already had a conditional `checksum/mtls` annotation for mTLS certificate changes. The new checksum annotations are added alongside the existing mTLS checksum, and the `annotations:` block is now always present (not conditional).

#### Schedule deployment

**Before (v5.2.1):**

```yaml
  template:
    metadata:
      labels:
        {{- include "schedule.labels" (dict "context" . "name" .Values.schedule.name ) | nindent 8 }}
    spec:
```

**After (v5.2.2):**

```yaml
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/schedule/configmap.yaml") . | sha256sum }}
        {{- if not .Values.schedule.useExistingSecrets }}
        checksum/secret: {{ include (print $.Template.BasePath "/schedule/secrets.yaml") . | sha256sum }}
        {{- end }}
      labels:
        {{- include "schedule.labels" (dict "context" . "name" .Values.schedule.name ) | nindent 8 }}
    spec:
```

**Checksum annotation behavior:**

Each deployment now includes two checksum annotations:

| Annotation | Computed From | Conditional |
|------------|---------------|-------------|
| `checksum/config` | ConfigMap template content | Always present |
| `checksum/secret` | Secret template content | Only present when `useExistingSecrets` is `false` |

The `checksum/secret` annotation is conditional because when `useExistingSecrets` is `true`, the chart does not manage the Secret resource, so changes to external secrets will not trigger automatic restarts. Operators using external secrets must manually restart pods when secret values change.

> **Important:** If you use `useExistingSecrets: true` for any component, the checksum annotation for that component's secrets will **not** be rendered. You must manually restart pods when you update external secrets:

```bash
kubectl rollout restart deployment/plugin-br-pix-indirect-btg-pix -n plugin-br-pix-indirect-btg
```

## Migration Steps

This upgrade requires no configuration changes or manual intervention. The checksum annotations are automatically added to all deployments during the upgrade.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg
```

3. Verify all pods are running and healthy:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

4. Verify the checksum annotations are present on all deployments:

```bash
kubectl get deployment -n plugin-br-pix-indirect-btg -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.metadata.annotations}{"\t"}{@}{"\n"}{end}{"\n"}{end}'
```

You should see `checksum/config` and (if not using external secrets) `checksum/secret` annotations on all five deployments.

> **Note:** The upgrade itself will **not** trigger a pod restart unless you also change configuration values in the same upgrade operation. The checksum annotations are computed from the current ConfigMap and Secret content, which remains unchanged if you don't modify any values.

**Testing the automatic restart behavior:**

After upgrading, you can verify that configuration changes trigger automatic restarts by modifying a ConfigMap value:

1. Update a configuration value in your values file:

```yaml
pix:
  configmap:
    SWAGGER_ENABLED: "false"  # Change from default "true"
```

2. Run the upgrade with the modified values:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

3. Observe that the `pix` deployment automatically performs a rolling restart:

```bash
kubectl rollout status deployment/plugin-br-pix-indirect-btg-pix -n plugin-br-pix-indirect-btg
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
