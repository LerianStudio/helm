# Plugin-br-bank-transfer Changelog

## [3.4.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.4.1)

🧰 Maintenance:
- Automated update of the Helm chart components to reference `plugin-br-bank-transfer@3.9.0`. (#3351, @lerian-studio-midaz-push-bot)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.4.0...plugin-br-bank-transfer-v3.4.1)

---

## [3.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.4.0)

✨ Features:
- The bank transfer plugin now renders the antifraud destination lists. (#3341, @fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.3.1...plugin-br-bank-transfer-v3.4.0)

---

## [3.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.3.1)

Features:

- Provide upgrade and migration guidance for `plugin-br-bank-transfer`. (@victorlazari)

Fixes:

- Update `plugin-br-bank-transfer` to `3.8.0`. (@lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.3.0...plugin-br-bank-transfer-v3.3.1)

---

## [3.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.3.0)

Features:
- Update `plugin-br-bank-transfer` to version `3.7.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.2.4...plugin-br-bank-transfer-v3.3.0)

---

## [3.2.4](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.2.4)

Features:
- Add a Helm upgrade guide for `plugin-br-bank-transfer` `v3.2.3`. (@victorlazari)
- Add a Helm upgrade guide for `plugin-br-bank-transfer` `v3.2.2`. (@victorlazari)
- Add a Helm upgrade guide for `plugin-br-bank-transfer` `v3.2.1`. (@victorlazari)

Fixes:
- Render `ALLOW_INSECURE_OTEL` with the collector off and test for null values. (@guimoreirar)
- Take `ALLOW_INSECURE_OTEL` from the modeled setting. (@guimoreirar)
- Allow the node-local OTEL hop to boot in production. (@guimoreirar)

Improvements:
- Show `allowInsecureOtel` in the `global.observability` example. (@guimoreirar)
- Document `ALLOW_INSECURE_OTEL` in the configmap telemetry block. (@guimoreirar)
- Align the `3.1` upgrade guide with renders and app `3.5.0`/`3.6.0`. (@gandalf-at-lerian)
- Bound rollout claims. (@victorlazari)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.2.3...plugin-br-bank-transfer-v3.2.4)

---

## [3.2.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.2.3)

Fixes:
- Updated the plugin to roll pods when there are changes in the configmap and secret, ensuring that the latest configurations are always applied. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.2.2...plugin-br-bank-transfer-v3.2.3)

---

## [3.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-bank-transfer-v3.2.2)

Fixes:
- Corrected the indentation of the commented secrets examples under `bankTransfer.secrets` to maintain consistency. (@Leonardox7, @gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-bank-transfer-v3.2.1...plugin-br-bank-transfer-v3.2.2)

---

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

