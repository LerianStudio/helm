# Plugin-br-pix-jd Changelog

## [0.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.2.0)

- Features:
  - Initial release of plugin-br-pix-jd version 0.1.0.

- Contributors:
  - @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.1.0...plugin-br-pix-jd-v0.2.0)

---

## [0.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.2.0)

- Initial release of plugin-br-pix-jd.
- Basic functionality for processing PIX transactions.
- Integration with JD payment systems.

Contributors: @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.1.0...plugin-br-pix-jd-v0.2.0)

---

## [0.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.1.0)

- Features:
  - Added support for AWS IAM Roles Anywhere on API and worker.
  - Introduced the ability to accept a dedicated worker image, requiring the same tag.
  - Modeled DEPLOYMENT_MODE as a first-class configuration key.
  - Added the chart for the renamed Pix JD plugin.

- Fixes:
  - Updated dependency lerian-common-helm from version 1.3.4 to 2.1.0.
  - Removed the gate for tag parity between API and worker.
  - Resolved issue where domainEnv was joining two keys onto one line.
  - Prevented shape-checking a secret when an AVP placeholder is still present.

Contributors: @ferr3ira-gabriel, @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.0.0...plugin-br-pix-jd-v0.1.0)

---

## [0.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.1.0)

- Features:
  - Added support for AWS IAM Roles Anywhere on API and worker.
  - Introduced the ability to accept a dedicated image for the worker, requiring the same tag.
  - Modeled DEPLOYMENT_MODE as a first-class configuration key.
  - Added the chart for the renamed Pix JD plugin.

- Fixes:
  - Updated the dependency 'lerian-common-helm' from version 1.3.4 to 2.1.0.
  - Removed the gate for tag parity between API and worker.
  - Resolved an issue where domainEnv was joining two keys onto one line.
  - Prevented shape-checking of a secret that an AVP placeholder still occupies.

Contributors: @ferr3ira-gabriel, @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.0.0...plugin-br-pix-jd-v0.1.0)

