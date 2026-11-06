# Plugin-br-sisbajud Changelog

## [1.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.4.0)

Features:
- Add license file mount and pass the license key to migrators. (@fredcamaral)

Fixes:
- Project only the license key in the license file volume. (@fredcamaral)

Improvements:
- Add the `1.3.1` upgrade guide. (@fredcamaral)
- Name the removed readiness note in the `1.3.1` guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.3.1...plugin-br-sisbajud-v1.4.0)

---

## [1.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.1)

Fixes:
- Align the chart text with app `1.2.0`. (@fredcamaral)
- Keep pod checksums stable across chart releases. (@fredcamaral)
- Align text with app `1.2.0` and remove chart label from pods. (@fredcamaral)

Improvements:
- Add the reviewed `1.3.0` upgrade guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.3.0...plugin-br-sisbajud-v1.3.1)

---

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.0)

Features:
- Expose the direct channel settings to enhance configuration options. (@brunobls)
- Enable the permanent block by default to streamline user experience. (@brunobls)
- Ship app `1.2.0`, introducing new functionalities and improvements. (@brunobls)
- Default the Midaz CRM mode to embedded, simplifying initial setup. (@gandalf-at-lerian)
- Expose streaming for the permanent block, allowing more flexible data handling. (@brunobls)
- Expose purge refresh, sweep, and maintenance keys to provide better control over system maintenance. (@brunobls)

Fixes:
- Honor the `extraEnvVars` streaming flag to ensure proper environment variable handling. (@brunobls)
- Gate the permanent block to match app `1.2.0` behavior, ensuring consistency. (@brunobls)
- Refuse zero durations in the configmap to prevent configuration errors. (@brunobls)
- Gate global streaming on the permanent block to maintain system integrity. (@brunobls)
- Default `OTEL_LIBRARY_NAME` to the module path for improved observability. (@brunobls)
- Refuse a zero purge alarm duration to avoid misconfigurations. (@brunobls)
- Read the configmap in the notes to ensure accurate documentation. (@brunobls)
- Require authentication in DIRECT-only mode to enhance security. (@brunobls)
- Emit the drainer cap in every mode to ensure consistent system behavior. (@brunobls)

Improvements:
- Apply review fixes to chart documentation and upgrade guides for better clarity. (@gandalf-at-lerian)
- Add verified upgrade guides for transitioning from `1.1.1` to `1.2.0`. (@fredcamaral)
- Correct chart documentation against templates and app code for accuracy. (@fredcamaral)
- Note when global streaming applies to provide clear guidance. (@brunobls)
- Describe streaming and the permanent rollback to inform users of system capabilities. (@brunobls)
- Describe the audited purge and its retention for better data management. (@brunobls)
- Mark `ALLOW_RATELIMIT_DISABLED` as ignored to clarify its status. (@brunobls)
- Document the permanent block switch-off to guide users in configuration. (@brunobls)
- Document which Midaz CRM mode to set for optimal system performance. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.2.0...plugin-br-sisbajud-v1.3.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released version `1.1.0` of the plugin. (@brunobls)
- Implemented refusal of images without specified key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Corrected the handling of canonical image tags to refuse leading zeros. (@brunobls)
- Ensured only canonical image tags are verified. (@brunobls)

Improvements:
- Updated documentation to include AWS KMS key modes in the getting started guide. (@brunobls)
- Clarified the behavior of KMS trim in the documentation. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Aligned tag gate notes with canonical rules in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Noted the digest-only tag limit in the documentation. (@brunobls)
- Documented the image tag gate and its limits. (@brunobls)
- Documented AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Released `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the default application setting as false. (@guimoreirar)
- Pinned the application to version `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

