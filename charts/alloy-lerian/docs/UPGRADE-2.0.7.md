# Helm Upgrade from v2.0.6 to v2.0.7

This guide covers the upgrade from `alloy-lerian` chart version **2.0.6** to **2.0.7**. This patch release updates documentation comments to anonymize client references in code examples and measurements.

---

## Topics

- **[Documentation Updates](#documentation-updates)**
  - [1. Client Name Anonymization in Comments](#1-client-name-anonymization-in-comments)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Documentation Updates

### 1. Client Name Anonymization in Comments

All inline documentation comments that referenced specific client names in capacity measurements, configuration examples, and technical notes have been anonymized to use generic placeholders.

**What changed:**

The chart replaces specific client names with generic identifiers in three locations:

1. **Queue capacity measurements** (`values.yaml` and `templates/_config.tpl`)
2. **Span metrics cardinality measurements** (`values.yaml`)
3. **Attribute normalization examples** (`templates/_config.tpl`)
4. **Namespace filtering examples** (`templates/_config.tpl`)
5. **Sanitization rule verification notes** (`templates/_sanitizacao.tpl`)

#### Queue Capacity Comments

| Location | v2.0.6 | v2.0.7 |
|----------|--------|--------|
| `values.yaml` line 154-158 | `Cappta-Prd`, `Voluti-prd` | `cliente A (prd)`, `cliente B (prd)` |
| `templates/_config.tpl` line 410 | `Cappta-Prd`, `Voluti-prd` | `cliente A (prd)`, `cliente B (prd)` |

**Before (v2.0.6):**

```yaml
# Quanto a fila aguenta, com linha média de 909 bytes medida em produção:
#
#   aws-devops     ~17 minutos
#   Cappta-Prd     ~18 segundos
#   Voluti-prd     ~1,7 SEGUNDOS
```

**After (v2.0.7):**

```yaml
# Quanto a fila aguenta, com linha média de 909 bytes medida em produção:
#
#   aws-devops     ~17 minutos
#   cliente A (prd)     ~18 segundos
#   cliente B (prd)     ~1,7 SEGUNDOS
```

#### Span Metrics Cardinality Comments

| Location | v2.0.6 | v2.0.7 |
|----------|--------|--------|
| `values.yaml` line 554-560 | `Cappta-Prd`, `Voluti-prd`, `Banqi-Prd`, `Cappta-Stg` | `cliente A (prd)`, `cliente B (prd)`, `cliente C (prd)`, `cliente A (stg)` |

**Before (v2.0.6):**

```yaml
#   aws-staging       8.676   <- the largest
#   aws-production    3.924
#   Cappta-Prd        3.024
#   Voluti-prd          996
#   Banqi-Prd           144
#   Cappta-Stg           96
```

**After (v2.0.7):**

```yaml
#   aws-staging       8.676   <- the largest
#   aws-production    3.924
#   cliente A (prd)        3.024
#   cliente B (prd)          996
#   cliente C (prd)           144
#   cliente A (stg)           96
```

#### Attribute Normalization Comments

| Location | v2.0.6 | v2.0.7 |
|----------|--------|--------|
| `templates/_config.tpl` line 178-180 | `Banqi-Prd`, `Cappta-Prd`, `Cappta-Stg`, `voluti-prd`, `voluti-stg` | `cliente C (prd)`, `cliente A (prd)`, `cliente A (stg)`, `cliente B (prd)`, `cliente B (stg)` |

**Before (v2.0.6):**

```yaml
// sem erro nenhum. MEDIDO 2026-10-06 em calls_total: Banqi-Prd,
// Cappta-Prd e Cappta-Stg tem apenas `http_status_code`; so voluti-prd e
// voluti-stg tem as duas formas.
```

**After (v2.0.7):**

```yaml
// sem erro nenhum. MEDIDO 2026-10-06 em calls_total: cliente C (prd),
// cliente A (prd) e cliente A (stg) tem apenas `http_status_code`; so cliente B (prd) e
// cliente B (stg) tem as duas formas.
```

#### Namespace Filtering Comments

| Location | v2.0.6 | v2.0.7 |
|----------|--------|--------|
| `templates/_config.tpl` line 779 | `voluti-stg` | `cliente B (stg)` |
| `templates/_config.tpl` line 795 | `examples/values-benedita.yaml` | `os values de um ambiente interno` |

**Before (v2.0.6):**

```yaml
// MEDIDO em voluti-stg (2026-10-20), primeiro BYOC migrado: 1.109 séries
```

**After (v2.0.7):**

```yaml
// MEDIDO em cliente B (stg), em 2026-10-20, primeiro BYOC migrado: 1.109 séries
```

**Before (v2.0.6):**

```yaml
// VERIFICADO: com `examples/values-benedita.yaml` o render sai idêntico ao
// anterior, fora este comentário.
```

**After (v2.0.7):**

```yaml
// VERIFICADO: com os values de um ambiente interno o render sai idêntico ao
// anterior, fora este comentário.
```

#### Sanitization Rule Comments

| Location | v2.0.6 | v2.0.7 |
|----------|--------|--------|
| `templates/_sanitizacao.tpl` line 44 | `Cappta-Prd` | `cliente A (prd)` |
| `templates/_sanitizacao.tpl` line 66 | `Banqi` | `cliente C` |

**Before (v2.0.6):**

```yaml
// a razao esta no dado real. MEDIDO em Cappta-Prd:
```

**After (v2.0.7):**

```yaml
// a razao esta no dado real. MEDIDO em cliente A (prd):
```

**Before (v2.0.6):**

```yaml
// MEDIDO contra o log do Banqi: nao mascarava nada la, porque
```

**After (v2.0.7):**

```yaml
// MEDIDO contra o log do cliente C: nao mascarava nada la, porque
```

**What this means:**

- No functional changes to the chart behavior
- No configuration changes required
- No changes to rendered manifests (verified: `helm template` output is identical except for comment content)
- Documentation comments now use generic client identifiers for privacy

**Migration Steps:**

No action required. This is a documentation-only change with no impact on chart functionality or rendered resources.

> **Note:** The anonymization applies only to inline code comments. The chart's operational behavior, default values, and rendered Kubernetes manifests remain unchanged.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.7 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.7 -n alloy-lerian
```
