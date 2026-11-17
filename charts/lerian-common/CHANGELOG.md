# Lerian-common Changelog

## [2.7.0](https://github.com/LerianStudio/helm/releases/tag/lerian-common-v2.7.0)

Features:
- Model the `ALLOW_INSECURE_OTEL` setting as a configuration owned by the chart. (@guimoreirar)

Improvements:
- Add test coverage for a global `ALLOW_INSECURE_OTEL` refusal scenario without a component key. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-common-v2.6.3...lerian-common-v2.7.0)

---

## [2.6.3](https://github.com/LerianStudio/helm/releases/tag/lerian-common-v2.6.3)

Fixes:
- Allow the node-local OTEL hop to boot in production environments. (@guimoreirar)

Improvements:
- Update and correct the library upgrade guide for better clarity. (@victorlazari)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-common-v2.6.2...lerian-common-v2.6.3)

---

## [2.6.2](https://github.com/LerianStudio/helm/releases/tag/lerian-common-v2.6.2)

Fixes:
- Evaluate the report-check health alert per pod to ensure accurate monitoring. (@fredcamaral)

Improvements:
- Add the verified `lerian-common` `2.6.1` upgrade guide to assist users with the update process. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-common-v2.6.1...lerian-common-v2.6.2)

---

## [2.6.1](https://github.com/LerianStudio/helm/releases/tag/lerian-common-v2.6.1)

Improvements:
- Corrected AmazonMQ ports in the preset comment. (@fredcamaral)
- Reworded AWS preset comment to be more neutral. (@fredcamaral)

Documentation:
- Added verified upgrade guides for `2.6.0`. (@fredcamaral)
- Corrected chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-common-v2.6.0...lerian-common-v2.6.1)

