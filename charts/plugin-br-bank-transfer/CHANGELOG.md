# Plugin-br-bank-transfer Changelog

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
