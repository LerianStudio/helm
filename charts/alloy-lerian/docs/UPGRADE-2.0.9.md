<!-- {% raw %} -->
# Helm Upgrade from v2.0.8 to v2.0.9

This guide covers the upgrade from `alloy-lerian` chart version **2.0.8** to **2.0.9**. This patch release updates documentation comments to remove outdated internal references and clarify the operational context of span metrics generation.

---

## Topics

- **[Documentation Updates](#documentation-updates)**
  - [1. Span Metrics Comment Clarification](#1-span-metrics-comment-clarification)
  - [2. Fleet Management Error Message Cleanup](#2-fleet-management-error-message-cleanup)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Documentation Updates

### 1. Span Metrics Comment Clarification

The `spanMetrics` section in `values.yaml` contained outdated internal references that have been updated to reflect the current operational context.

| Setting | v2.0.8 | v2.0.9 |
|---------|--------|--------|
| Comment references | Contained specific internal cluster migration date and metrics | Generalized to describe the architectural context |

**What changed:**

The comment block above `spanMetrics.enabled` has been updated to remove time-specific internal references:

**Before (v2.0.8):**

```yaml
# ⚠️ THIS IS NOT OPTIONAL IN PRACTICE — it replaces a producer that exists
# today. The connector lives in the otel-collector-client being retired, so an
# agent without it silently stops producing the RED series. MEASURED: an internal cluster
# migrated to Alloy on 2026-08-11 and `calls_total` disappeared for that
# cluster while it still exists for the six clusters that kept the old agent.
```

**After (v2.0.9):**

```yaml
# ⚠️ THIS IS NOT OPTIONAL IN PRACTICE — it replaces a producer that exists
# today. The connector lives in the OpenTelemetry Collector agent this chart
# replaces, so an agent without it silently stops producing the RED series.
```

**What this means:**

- The operational requirement remains unchanged: `spanMetrics.enabled` must be `true` to maintain RED metrics continuity
- The comment now describes the architectural reason (replacing the OpenTelemetry Collector agent) without referencing specific internal migration dates
- The warning that disabling span metrics will silently stop RED series production remains in effect

**Migration Steps:**

No action required. This is a documentation-only change with no impact on chart behavior or configuration.

> **Important:** The `spanMetrics.enabled` setting defaults to `true` and should remain enabled unless you have verified that no downstream systems consume the RED metrics series produced by the span metrics connector.

The Portuguese-language comment block explaining the centralization requirement has also been updated:

**Before (v2.0.8):**

```yaml
# POR QUE: o papel `node` e um DaemonSet, logo ha UM ACUMULADOR POR NO. Cada
# um mantem estado proprio e escreve a MESMA serie com valores diferentes no
# mesmo timestamp — o destino rejeita com `new-value-for-timestamp`. Foi
# exatamente o que os ambientes internos mediram (~4.200 amostras/min em
# devops) antes de mover a geracao para o concentrador.
#
# O destino do BYOC JA E o collector-server, que desde o PR #759 tem conector
# unico roteado por `service`. A infraestrutura para centralizar ja existe.
```

**After (v2.0.9):**

```yaml
# POR QUE: o papel `node` e um DaemonSet, logo ha UM ACUMULADOR POR NO. Cada
# um mantem estado proprio e escreve a MESMA serie com valores diferentes no
# mesmo timestamp — o destino rejeita com `new-value-for-timestamp`. Foi
# exatamente o que os ambientes internos mediram antes de mover a geracao
# para o concentrador.
#
# O destino do BYOC JA E o collector-server, que tem conector unico roteado
# por `service`. A infraestrutura para centralizar ja existe.
```

**What changed:**

- Removed the specific sample rate measurement (`~4.200 amostras/min em devops`)
- Removed the specific pull request reference (`PR #759`)
- The architectural explanation remains: span metrics must be centralized to avoid timestamp conflicts from multiple DaemonSet replicas

### 2. Fleet Management Error Message Cleanup

The Fleet Management validation error message in the `_fleet.tpl` template has been simplified to remove an unnecessary function call.

| Setting | v2.0.8 | v2.0.9 |
|---------|--------|--------|
| Error message template | Included `(include "alloy-lerian.originId" $)` at the end | Removed the trailing function call |

**What changed:**

**Before (v2.0.8):**

```yaml
{{- fail (printf "\n\nalloy-lerian: fleetManagement está habilitado, mas `%s.alloy.extraEnv` não\ndeclara ALLOY_FLEET_POD_NAME.\n\nO bloco remotecfg lê essa variável. Sem ela o agente não inicia, e a falha só\napareceria no log do pod.\n\nAcrescente ao values do papel %s:\n\n  %s:\n    alloy:\n      extraEnv:\n        - name: ALLOY_FLEET_POD_NAME\n          valueFrom:\n            fieldRef:\n              fieldPath: metadata.name\n        - name: ALLOY_FLEET_TOKEN\n          valueFrom:\n            secretKeyRef:\n              name: alloy-lerian\n              key: fleet-token\n" $papel $papel $papel (include "alloy-lerian.originId" $)) -}}
```

**After (v2.0.9):**

```yaml
{{- fail (printf "\n\nalloy-lerian: fleetManagement está habilitado, mas `%s.alloy.extraEnv` não\ndeclara ALLOY_FLEET_POD_NAME.\n\nO bloco remotecfg lê essa variável. Sem ela o agente não inicia, e a falha só\napareceria no log do pod.\n\nAcrescente ao values do papel %s:\n\n  %s:\n    alloy:\n      extraEnv:\n        - name: ALLOY_FLEET_POD_NAME\n          valueFrom:\n            fieldRef:\n              fieldPath: metadata.name\n        - name: ALLOY_FLEET_TOKEN\n          valueFrom:\n            secretKeyRef:\n              name: alloy-lerian\n              key: fleet-token\n" $papel $papel $papel) -}}
```

**What this means:**

- The error message displayed when Fleet Management is enabled but `ALLOY_FLEET_POD_NAME` is missing from `extraEnv` is now cleaner
- The trailing `(include "alloy-lerian.originId" $)` was not being used in the error message format string and has been removed
- The validation logic and error message content remain unchanged

**Migration Steps:**

No action required. This is a template cleanup with no impact on chart behavior or error detection.

> **Note:** The validation that triggers this error remains active. If you enable Fleet Management (`fleetManagement.enabled: true`) without declaring `ALLOY_FLEET_POD_NAME` in `node.alloy.extraEnv` or `singleton.alloy.extraEnv`, the chart will still fail to render with the same instructional error message.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm -n monitoring --version 2.0.9
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm -n monitoring --version 2.0.9
```
<!-- {% endraw %} -->
