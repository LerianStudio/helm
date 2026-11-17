# Plugin-br-ted-lerian Changelog

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.2.0)

Features:
- Serve health on port `8099`. (@fredcamaral)

Fixes:
- Name the refused key and check the ingress port in tests. (@fredcamaral)

Improvements:
- Add the `1.1.4` upgrade guide. (@fredcamaral)
- Fix host check in the `1.1.4` upgrade guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.1.4...plugin-br-ted-lerian-v1.2.0)

---

## [1.1.4](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.1.4)

Fixes:
- Use a placeholder ingress host by default to ensure proper configuration. (@fredcamaral)

Improvements:
- Add the verified `1.1.3` upgrade guide to the documentation, providing users with clear instructions for updating. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.1.3...plugin-br-ted-lerian-v1.1.4)

---

## [1.1.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.1.3)

Fixes:
- Align the rendered configuration with what the app reads to ensure consistency. (@fredcamaral)
- Maintain validity of zero-surge rollouts and environment overrides. (@fredcamaral)

Improvements:
- Apply review fixes to chart documentation and upgrade guides. (@gandalf-at-lerian)
- Streamline the `1.0` upgrade guide to reflect actual chart functionality. (@fredcamaral)
- Add verified upgrade guides for transitions from `1.0.1` to `1.1.2`. (@fredcamaral)
- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.1.2...plugin-br-ted-lerian-v1.1.3)

---

## [1.1.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.1.2)

Fixes:
- Carry CRM M2M credentials in secrets and install values to enhance security and configuration management. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.1.1...plugin-br-ted-lerian-v1.1.2)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.1.1)

Fixes:
- Set shutdown drain delay and raise pod grace to `55s`. (@fredcamaral)
- Align shutdown drain environment indentation with included entries. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.1.0...plugin-br-ted-lerian-v1.1.1)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.1.0)

Features:

- Pass the license key from a secret. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.0.2...plugin-br-ted-lerian-v1.1.0)

---

## [1.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.0.2)

Fixes:
- Moved the chart to app `1.0.0-beta.64`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.0.1...plugin-br-ted-lerian-v1.0.2)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.0.1)

Features:
- Added a Helm upgrade guide for `plugin-br-ted-lerian` `v1.0.0`. (@guimoreirar)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-ted-lerian-v1.0.0...plugin-br-ted-lerian-v1.0.1)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-ted-lerian-v1.0.0)

Features:

- Add the TED plugin chart on lerian-common. (@ferr3ira-gabriel)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-ted-lerian-v1.0.0)

