# System-facts Changelog

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.2.0)

Features:
- Add an optional license file mount to system-facts. (@fredcamaral)

Fixes:
- Use a placeholder ingress host for system-facts and remove the chart label from pods. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/system-facts-v1.1.3...system-facts-v1.2.0)

---

## [1.1.3](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.1.3)

Fixes:
- Ensure the system-facts values template boots correctly. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/system-facts-v1.1.2...system-facts-v1.1.3)

---

## [1.1.2](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.1.2)

Fixes:
- Adjusted the API grace period to accommodate a `15s` drain delay. (@fredcamaral)
- Set the API pod shutdown grace period to `52s`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/system-facts-v1.1.1...system-facts-v1.1.2)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.1.1)

Fixes:
- Removed the `LICENSE_ENABLED` switch from system-facts. (@fredcamaral)

Improvements:
- Added a Helm upgrade guide for system-facts `v1.0.2`. (@victorlazari)
- Reviewed and updated the system-facts `v1.1.0` upgrade guide. (@victorlazari, @gandalf-at-lerian)
- Corrected values reuse and migration hook in the system-facts `v1.0.2` upgrade guide. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/system-facts-v1.1.0...system-facts-v1.1.1)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.1.0)

Features:
- Render the system-facts RI declaration environment through `lerian-common.idp`. (@qnen)

Improvements:
- Expect the worker image at `appVersion` `1.1.0` in system-facts tests. (@qnen)

[Compare changes](https://github.com/LerianStudio/helm/compare/system-facts-v1.0.2...system-facts-v1.1.0)

---

## [1.0.2](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.0.2)

Fixes:
- Update `system-facts` to `1.1.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `system-facts` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/system-facts-v1.0.1...system-facts-v1.0.2)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.0.1)

Features:

- Documented the Access Manager prerequisite for system-facts. (@gandalf-at-lerian)
- Added a Helm upgrade guide for `system-facts` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/system-facts-v1.0.0...system-facts-v1.0.1)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/system-facts-v1.0.0)

Features:
- Introduced the system-facts chart for app `1.0.0-beta.29`. (@gandalf-at-lerian)

Fixes:
- Implemented a guard for the Postgres bootstrap and corrected the migrations tag example. (@guimoreirar)
- Addressed findings from the CodeRabbit review. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/system-facts-v1.0.0)

