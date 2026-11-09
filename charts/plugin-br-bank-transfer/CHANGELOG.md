# Plugin-br-bank-transfer Changelog

## [3.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.2.1)

Fixes:
- Default the chart to the stable `3.6.0` image. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.2.0...plugin-br-bank-transfer-v3.2.1)

---

## [3.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.2.0)

Features:
- Serve probes and metrics on the health port `8099`. (@fredcamaral)

Fixes:
- Quote PDB annotations and skip the PDB for a singleton. (@fredcamaral)
- Refuse retired PDB and rollout overrides. (@fredcamaral)
- Keep the component label in the PDB selector. (@fredcamaral)
- Publish the health port only on a ClusterIP service. (@fredcamaral)
- Update `plugin-br-bank-transfer@3.5.1`. (@lerian-studio)

Improvements:
- Keep the ALB health check on the traffic port. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.1.0...plugin-br-bank-transfer-v3.2.0)

---

## [3.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.1.0)

Features:
- Add migrator license key and file mount. (@fredcamaral)

Fixes:
- Project only the license key in the license file volume. (@fredcamaral)

Improvements:
- Keep the `2.0` upgrade guide free of environment names. (@fredcamaral)
- Add the `3.0.6` upgrade guide. (@fredcamaral)
- Use the README namespace in the `3.0.6` guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.0.6...plugin-br-bank-transfer-v3.1.0)

---

## [3.0.6](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.0.6)

Fixes:
- Dropped unread keys and updated the pod chart label to prevent unnecessary resource usage. (@fredcamaral)
- Stopped rendering keys that are not read by the application image, optimizing resource handling. (@fredcamaral)
- Ensured chart releases do not cause pods to restart unnecessarily, improving stability. (@fredcamaral)

Improvements:
- Fixed the installation command and updated chart sources in the documentation for better clarity. (@fredcamaral)
- Added a verified upgrade guide for version `3.0.5`, providing users with clear instructions for updating. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.0.5...plugin-br-bank-transfer-v3.0.6)

---

## [3.0.5](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.0.5)

Fixes:
- Keep MongoDB password secure in the configuration. (@fredcamaral)
- Use version `3.5.0` for compatibility improvements. (@fredcamaral)
- Stop rendering the `IS_DEVELOPMENT` flag to ensure consistent behavior across environments. (@fredcamaral)

Improvements:
- Sync the default image documentation to ensure it is up-to-date. (@fredcamaral)
- Apply review fixes to chart documentation and upgrade guides for clarity and accuracy. (@gandalf-at-lerian)
- Add verified upgrade guides for version `3.0.4` to assist users with the update process. (@fredcamaral)
- Correct chart documentation to align with templates and application code for better user guidance. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.0.4...plugin-br-bank-transfer-v3.0.5)

