# Plugin-br-pix-indirect-btg Changelog

## [5.3.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.3.3)

Fixes:
- Dropped the chart label from pod templates to improve configuration consistency. (@fredcamaral)

Improvements:
- Added the verified `5.3.2` upgrade guide to assist users in transitioning to the new version smoothly. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.3.2...plugin-br-pix-indirect-btg-v5.3.3)

---

## [5.3.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.3.2)

Fixes:
- Apply bundled PostgreSQL settings under the primary configuration for improved database integration. (@fredcamaral)
- Correct the upgrade guide for `plugin-br-pix-indirect-btg` `5.2` to ensure accurate instructions. (@fredcamaral)

Improvements:
- Add verified upgrade guides for transitions from `5.2.1` to `5.3.1` to assist users in updating smoothly. (@fredcamaral)
- Correct chart documentation to align with templates and application code for consistency. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.3.1...plugin-br-pix-indirect-btg-v5.3.2)

---

## [5.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.3.1)

Fixes:

- Updated to use stable images to ensure reliability and consistency. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.3.0...plugin-br-pix-indirect-btg-v5.3.1)

---

## [5.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.3.0)

Features:
- Adopt the `lerian-common` health preset to enhance the plugin's health checks. (@fredcamaral)

Fixes:
- Refuse retired PDBs and implement rollout overrides to ensure compatibility and stability. (@fredcamaral)

Improvements:
- Trim retired-key cases and document preset-owned values for better clarity and maintenance. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.2.3...plugin-br-pix-indirect-btg-v5.3.0)

---

## [5.2.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.2.3)

Fixes:
- Render `LICENSE_KEY` in the worker secrets to ensure proper configuration. (@fredcamaral)
- Raise probe `timeoutSeconds` to 3 to improve reliability. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.2.2...plugin-br-pix-indirect-btg-v5.2.3)

---

## [5.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.2.2)

Fixes:

- Roll pods when the configmap or secret changes to ensure the plugin operates with the latest configurations. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.2.1...plugin-br-pix-indirect-btg-v5.2.2)

---

## [5.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.2.1)

Features:
- Added Helm upgrade guide for `plugin-br-pix-indirect-btg` `v5.2.0`. (@guimoreirar)
- Added Helm upgrade guide for `plugin-br-pix-indirect-btg` `v5.1.0`. (@guimoreirar)
- Added Helm upgrade guide for `plugin-br-pix-indirect-btg` `v5.0.0`. (@guimoreirar)
- Added Helm upgrade guide for `plugin-br-pix-indirect-btg` `v4.2.0`. (@guimoreirar)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)
- Fixed GitHub Pages build issues related to Liquid over Helm templates. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.2.0...plugin-br-pix-indirect-btg-v5.2.1)

---

## [5.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.2.0)

Features:

- Add streaming SASL password and TLS CA secrets to the plugin. (@digocelos)
- Update to `plugin-br-pix-indirect-btg@1.12.0` with new environment variables. (@lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.1.0...plugin-br-pix-indirect-btg-v5.2.0)

---

## [5.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.1.0)

Features:
- Add a warning for plaintext external MongoDB connections and valkey usage. (@fredcamaral)

Fixes:
- Set outbound durations with appropriate units. (@fredcamaral)
- Display the actual database hosts in the installation notes. (@fredcamaral)

Improvements:
- Remove obsolete secret and database validators. (@fredcamaral)
- Document the `DB_SSL_MODE` configuration. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v5.0.0...plugin-br-pix-indirect-btg-v5.1.0)

---

## [5.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v5.0.0)

Fixes:
- Render boolean `false` on flags that default to `true`, ensuring correct behavior for default-true flags. (@fredcamaral)

Improvements:
- Refactor antifraud flags to utilize a shared helper, enhancing code maintainability and readability. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v4.2.0...plugin-br-pix-indirect-btg-v5.0.0)

---

## [4.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v4.2.0)

Features:
- Add a warning for using plaintext connections with external PostgreSQL databases. (@fredcamaral)

Improvements:
- Consolidate TLS warnings into a single list for better clarity. (@fredcamaral)

Fixes:
- Provide a Helm upgrade guide for `plugin-br-pix-indirect-btg` `v4.1.0`. (@brunognovaes)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v4.1.0...plugin-br-pix-indirect-btg-v4.2.0)

---

## [4.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v4.1.0)

Features:
- Update `plugin-br-pix-indirect-btg` to `@1.11.0` with new environment variables. (@lerian-studio)

Fixes:
- Move new environment variables to the standard secrets template and complete values. (@gandalf-at-lerian)

Improvements:
- Add Helm upgrade guide for `plugin-br-pix-indirect-btg` `v4.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v4.0.1...plugin-br-pix-indirect-btg-v4.1.0)

---

## [4.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v4.0.1)

Features:

- Note the replicaset MongoDB strategy in the documentation. (@fredcamaral)

Fixes:

- Boot the workers with their values to ensure correct initialization. (@fredcamaral)
- Drop unnecessary refusals from the workers to optimize performance. (@fredcamaral)
- Assign the bundled valkey its port for proper configuration. (@fredcamaral)
- Pin the bundled database majors to maintain version consistency. (@fredcamaral)
- Recreate the MongoDB pod on upgrade to ensure seamless updates. (@fredcamaral)

Improvements:

- Set the reconciliation Redis password in the external valkey example for enhanced security. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v4.0.0...plugin-br-pix-indirect-btg-v4.0.1)

---

## [4.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v4.0.0)

- **Features:**
  - Updated `plugin-br-pix-indirect-btg` to version 1.10.0, including updates to associated workers: `plugin-br-pix-indirect-btg-worker-reconciliation`, `plugin-br-pix-indirect-btg-worker-schedule`, `plugin-br-pix-indirect-btg-worker-inbound`, and `plugin-br-pix-indirect-btg-worker-outbound`.
  - Introduced new environment variables for enhanced configuration and flexibility.

- **Contributors:**
  - @guimoreirar
  - @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.8.0...plugin-br-pix-indirect-btg-v4.0.0)

---

## [3.8.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.8.0)

- **Fixes**
  - Updated `plugin-br-pix-indirect-btg` to version 1.9.1.

- **Improvements**
  - Added documentation for creating TLS secrets using `kubectl` and included notes on both registries.
  - Fixed namespace placeholder and pod selectors in the upgrade guide for version 3.7.

Contributors: @Leonardox7, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.7.0...plugin-br-pix-indirect-btg-v3.8.0)

---

## [3.7.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.7.0)

- **Features:**
  - Added outbound BTG client mTLS via mounted secret.
  - Chart can create the mTLS Secret from values with a minimal interface.
  - Default `mtls.secretName` to `<fullname>-mtls`.
  - Bumped app to version 1.9.0 (stable).

- **Fixes:**
  - Scoped mTLS volume to cert keys and bound `fsGroup`.

- **Improvements:**
  - Refactored mTLS to use `fsGroup` and 0440 direct mount, removing the need for an init container.
  - Added mTLS block to values-template for better configuration management.
  - Dropped hand-written `mTLS.md` as it is now auto-generated on release.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.6.0...plugin-br-pix-indirect-btg-v3.7.0)

---

## [3.6.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.6.0)

- Fixes:
  - Guard replicas when autoscaling is enabled to prevent potential scaling issues.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.5.0...plugin-br-pix-indirect-btg-v3.6.0)

---

## [3.5.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.5.0)

- **Fixes:**
  - Give schedule worker PDB real disruption protection.

- **Improvements:**
  - Set stable chart version 3.5.0 for main release.
  - Bump appVersion/image tags to 1.8.0 and add `WEBHOOK_SCHEDULE_CASHOUT` config keys.
  - Update helm chart for release 1.8.0.

Contributors: @gandalf-at-lerian, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.4.0...plugin-br-pix-indirect-btg-v3.5.0)

---

## [3.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.4.0)

- **Features:**
  - Added the `schedule` (Pix recurrence) worker: new `schedule` values section, Deployment, Service, ConfigMap, Secret, HPA and PDB templates, mirroring the reconciliation worker.
  - The worker listens on port 4018 with probes on `/health` (liveness) and `/readyz` (readiness) and ships active by default (`SCHEDULE_WORKER_ENABLED=true`, 15m interval).
  - Released version 3.4.0 of plugin-br-pix-indirect-btg.

- **Fixes:**
  - Updated plugin-br-pix-indirect-btg to version 1.7.6.

- **Improvements:**
  - Added upgrade guide for plugin-br-pix-indirect-btg v3.3.1.

Contributors: @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.3.1...plugin-br-pix-indirect-btg-v3.4.0)

---

## [3.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.3.1)

- **Fixes:**
  - Updated `plugin-br-pix-indirect-btg` to version 1.7.5, along with related worker components for reconciliation, inbound, and outbound processes.

- **Improvements:**
  - Added an upgrade guide for `plugin-br-pix-indirect-btg` version 3.3.0.

Contributors: @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.3.0...plugin-br-pix-indirect-btg-v3.3.1)

---

## [3.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.3.0)

- **Features:**
  - Released version 3.3.0 of the plugin-br-pix-indirect-btg.

- **Fixes:**
  - Updated plugin-br-pix-indirect-btg to version 1.7.4 to address specific issues.
  - Updated related worker components to version 1.7.4 for reconciliation, inbound, and outbound processes.

Contributors: @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.2.0...plugin-br-pix-indirect-btg-v3.3.0)

---

## [3.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.2.0)

- **Features**
  - Added ALLOW_INSECURE_TLS configuration.
  - Implemented per-chart values.schema.json generator.

- **Fixes**
  - Addressed CodeRabbit review on revamp PR #1470.
  - Single-sourced infra secrets.
  - Corrected value key typo and removed stale README notes.

- **Improvements**
  - Standardized charts to Lerian chart contract.
  - Pinned Bitnami dependency versions.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.1.0...plugin-br-pix-indirect-btg-v3.2.0)

---

## [3.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.1.0)

- **Features**
  - Added upgrade guide for plugin-br-pix-indirect-btg v3.0.0.
  - Added upgrade guide for plugin-br-pix-indirect-btg v3.0.1.

- **Fixes**
  - Updated plugin-br-pix-indirect-btg to version 1.7.3.
  - Updated plugin-br-pix-indirect-btg-worker-reconciliation to version 1.7.3.
  - Updated plugin-br-pix-indirect-btg-worker-inbound to version 1.7.3.
  - Updated plugin-br-pix-indirect-btg-worker-outbound to version 1.7.3.

- **Improvements**
  - Aligned upgrade guide format for plugin-br-pix-indirect-btg.

Contributors: @gandalf-at-lerian, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.0.1...plugin-br-pix-indirect-btg-v3.1.0)

---

## [3.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.0.1)

- Features:
  - Released version 3.0.0 of plugin-br-pix-indirect-btg.

- Fixes:
  - Implemented health readiness probe to enhance stability and monitoring.

Contributors: @gandalf-at-lerian, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v3.0.0...plugin-br-pix-indirect-btg-v3.0.1)

---

## [3.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v3.0.0)

- **Features:**
  - Released version 2.3.0-beta.4.
  - Released version 2.3.0-beta.3.
  - Released version 2.3.0-beta.2.

- **Fixes:**
  - Updated plugin-br-pix-indirect-btg and related workers to version 1.5.2.

- **Improvements:**
  - Standardized probe field set across all charts.
  - Parametrized probe path and timing using /readyz.
  - Updated readiness probe paths to /readyz across multiple deployment templates.

Contributors: @brunognovaes, @ferr3ira-gabriel, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v2.3.0...plugin-br-pix-indirect-btg-v3.0.0)

---

## [2.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v2.3.0)

- **Features:**
  - Released version 2.2.0 of the plugin-br-pix-indirect-btg.

- **Improvements:**
  - Updated BTG version to 1.5.2.

Contributors: @brunognovaes, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v2.2.0...plugin-br-pix-indirect-btg-v2.3.0)

---

## [2.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v2.2.0)

- **Fixes:**
  - Updated `pix OTEL_RESOURCE_SERVICE_VERSION` for better compatibility.

Contributors: @bedatty, @ferr3ira-gabriel, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v2.1.1...plugin-br-pix-indirect-btg-v2.2.0)

---

## [2.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v2.1.1)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.5.1.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v2.1.0...plugin-br-pix-indirect-btg-v2.1.1)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v2.0.0)

- **Features**
  - Added new environments for MED 2 BTG.

- **Fixes**
  - Updated plugin-br-pix-indirect-btg to version 1.4.1.

- **Improvements**
  - Fixed missing plural in funds recovery events.

Contributors: @brunognovaes.cm, @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.7.0...plugin-br-pix-indirect-btg-v2.0.0)

---

## [1.7.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.7.0)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.3.0.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.6.0...plugin-br-pix-indirect-btg-v1.7.0)

---

## [1.6.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.6.0)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.2.8.

Contributors: @ferr3ira-gabriel,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.5.0...plugin-br-pix-indirect-btg-v1.6.0)

---

## [1.5.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.5.0)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.2.7.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.4.0...plugin-br-pix-indirect-btg-v1.5.0)

---

## [1.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.4.0)

- Features:
  - Released version 1.4.0 with new enhancements.

- Fixes:
  - Updated to version 1.2.6 to address various bugs and improve stability.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.3.4...plugin-br-pix-indirect-btg-v1.4.0)

---

## [1.3.4](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.3.4)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.2.4.

Contributors: @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.3.3...plugin-br-pix-indirect-btg-v1.3.4)

---

## [1.3.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.3.3)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.2.3.

- Improvements:
  - Updated version environment variable in the configmap template.

Contributors: @gui.rodrigues, @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.3.2...plugin-br-pix-indirect-btg-v1.3.3)

---

## [1.3.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.3.2)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.2.2 for improved stability and performance.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.3.1...plugin-br-pix-indirect-btg-v1.3.2)

---

## [1.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.3.1)

- Fixes:
  - Updated plugin-br-pix-indirect-btg to version 1.2.1 to address minor issues and improve stability.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.3.0...plugin-br-pix-indirect-btg-v1.3.1)

---

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.3.0)

- Fixes:
  - Update plugin-br-pix-indirect-btg-worker-reconciliation to version 1.2.0.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.2.1...plugin-br-pix-indirect-btg-v1.3.0)

---

## [1.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.2.1)

- Fixes:
  - Removed trailing newline from `values.yaml`.
  - Updated `plugin-br-pix-indirect-btg-worker-reconciliation` to version 1.1.3.

Contributors: @gui.rodrigues, @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.2.0...plugin-br-pix-indirect-btg-v1.2.1)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.2.0)

- **Fixes**
  - Updated plugin-br-pix-indirect-btg to version 1.1.2.
  - Updated plugin-br-pix-indirect-btg-worker-reconciliation to version 1.1.1.

- **Improvements**
  - Adjusted webhook outbound reconciliation environment settings.

Contributors: @Leonardox7, @guimoreirar, @leonardoz5z

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.1.1...plugin-br-pix-indirect-btg-v1.2.0)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.1.1)

- **Features:**
  - Added BTG webhook validation configuration.

- **Fixes:**
  - Updated plugin-br-pix-indirect-btg to version 1.1.0.
  - Adjusted default URL for pix-btg.

- **Improvements:**
  - Removed configmap and secrets templates.
  - Reorganized templates for better structure.

Contributors: @gui.rodrigues, @guimoreirar, @leonardoz5z

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.1.0...plugin-br-pix-indirect-btg-v1.1.1)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-indirect-btg-v1.1.0)

- Improvements:
  - Adjusted securityContext settings documentation for better clarity.
  - Made adjustments to securityContext settings to enhance security configuration.

Contributors: @gui.rodrigues

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-indirect-btg-v1.0.0...plugin-br-pix-indirect-btg-v1.1.0)
