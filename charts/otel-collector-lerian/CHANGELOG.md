# Otel-collector-lerian Changelog

## [5.0.1](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v5.0.1)

Fixes:

- Use a neutral `client.id` placeholder and update public chart links. (@fredcamaral)

Improvements:

- Apply review fixes to chart documentation and upgrade guides. (@gandalf-at-lerian)
- Add verified upgrade guides for `4.3.1`. (@fredcamaral)
- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v5.0.0...otel-collector-lerian-v5.0.1)

---

## [5.0.0](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v5.0.0)

Features:
- Bumped the otel-collector to version `0.164.0` and the subchart to version `0.178.1`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v4.3.1...otel-collector-lerian-v5.0.0)

---

## [4.3.1](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v4.3.1)

Features:
- Aligned the README, upgrade guide, and comments with the rendered chart for `otel-collector-lerian`. (@gandalf-at-lerian)

Improvements:
- Relicensed the charts under the Elastic License 2.0. (@fredcamaral)

Fixes:
- Merged updates for the release and upgrade documentation for `otel-collector-lerian` `v4.3.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v4.3.0...otel-collector-lerian-v4.3.1)

---

## [4.3.0](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v4.3.0)

Features:

- Expose rollouts-pod-template-hash on spanmetrics. (@guimoreirar)

Improvements:

- Upgrade documentation for `otel-collector-lerian` to `v4.2.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v4.2.0...otel-collector-lerian-v4.3.0)

---

## [4.2.0](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v4.2.0)

- **Fixes:**
  - Pinned spanmetrics resource key and refreshed README for better clarity.
  - Dropped volatile spanmetrics dimensions to improve stability.
  - Removed duplicate GOMEMLIMIT setting and reduced kubeletstats DPM by half.

Contributors: @gauchito91, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v4.1.0...otel-collector-lerian-v4.2.0)

---

## [4.1.0](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v4.1.0)

- **Features:**
  - Applied midaz namespace filter across all signals and performed a deprecation rename.
  - Standardized processors, pod identity, and semantic convention transformation.

- **Improvements:**
  - Refreshed otel-collector-lerian README for the 4.1 release.

Contributors: @gauchito91, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v4.0.0...otel-collector-lerian-v4.1.0)

---

## [4.0.0](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v4.0.0)

- **Features**
  - Standardized charts to align with the Lerian chart contract.
  - Introduced a per-chart `values.schema.json` generator for CI processes.

- **Fixes**
  - Addressed CodeRabbit review comments on the chart revamp PR.

- **Improvements**
  - Updated the upgrade guide format for better alignment and clarity.

Contributors: @fredcamaral, @gandalf-at-lerian, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v3.0.0...otel-collector-lerian-v4.0.0)

---

## [3.0.0](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v3.0.0)

- **Features**
  - Released version 2.2.1 of otel-collector-lerian.

- **Contributors**
  - @guimoreirar
  - @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v2.2.1...otel-collector-lerian-v3.0.0)

---

## [2.2.1](https://github.com/LerianStudio/helm/releases/tag/otel-collector-lerian-v2.2.1)

- **Features**
  - Updated to the new version of OpenTelemetry, enhancing compatibility and performance.
  - Enabled new metrics collection, providing more detailed insights and monitoring capabilities.

Contributors: @gauchito91, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v2.2.0...otel-collector-lerian-v2.2.1)
