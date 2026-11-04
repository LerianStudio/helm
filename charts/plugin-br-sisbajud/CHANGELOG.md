# Plugin-br-sisbajud Changelog

## [1.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.1)

Fixes:

- Align the chart text with app `1.2.0`. (@fredcamaral)
- Keep pod checksums stable across chart releases. (@fredcamaral)
- Align text with app `1.2.0` and remove chart label from pods. (@fredcamaral)

Improvements:

- Add the reviewed `1.3.0` upgrade guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.3.0...plugin-br-sisbajud-v1.3.1)

---

## [1.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.1)

Features:

- Add the reviewed `1.3.0` upgrade guide. (@fredcamaral)

Fixes:

- Align the chart text with app `1.2.0`. (@fredcamaral)
- Keep pod checksums stable across chart releases. (@fredcamaral)
- Align text with app `1.2.0` and remove chart label from pods. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.3.0...plugin-br-sisbajud-v1.3.1)

---

## [1.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.1)

Fixes:
- Align the chart text with app `1.2.0` to ensure consistency. (@fredcamaral)
- Keep pod checksums stable across chart releases to maintain reliability. (@fredcamaral)
- Drop chart label from pods while aligning text with app `1.2.0`. (@fredcamaral)

Improvements:
- Add the reviewed `1.3.0` upgrade guide to assist users in transitioning smoothly. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.3.0...plugin-br-sisbajud-v1.3.1)

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

## [1.3.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.1)

Fixes:

- Align the chart text with app `1.2.0`. (@fredcamaral)
- Keep pod checksums stable across chart releases. (@fredcamaral)
- Align text with app `1.2.0` and remove the chart label from pods. (@fredcamaral)

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

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.0)

Features:
- Expose the direct channel settings to enhance configuration flexibility. (@brunobls)
- Enable the permanent block by default to improve default security settings. (@brunobls)
- Ship app `1.2.0` to provide the latest features and improvements. (@brunobls)
- Default the Midaz CRM mode to embedded to streamline user setup. (@gandalf-at-lerian)
- Expose streaming for the permanent block to allow better data handling. (@brunobls)
- Expose purge refresh, sweep, and maintenance keys to enhance maintenance capabilities. (@brunobls)

Fixes:
- Honor the `extraEnvVars` streaming flag to ensure correct environment variable handling. (@brunobls)
- Gate the permanent block as app `1.2.0` does to maintain consistency with the new version. (@brunobls)
- Refuse zero durations in the configmap to prevent configuration errors. (@brunobls)
- Gate global streaming on the permanent block to ensure proper feature gating. (@brunobls)
- Default `OTEL_LIBRARY_NAME` to the module path for improved observability setup. (@brunobls)
- Refuse a zero purge alarm duration to avoid misconfigurations. (@brunobls)
- Read the configmap in the notes to ensure accurate documentation. (@brunobls)
- Require authentication in DIRECT-only mode to enhance security. (@brunobls)
- Emit the drainer cap in every mode to ensure consistent feature availability. (@brunobls)

Improvements:
- Apply review fixes to chart docs and upgrade guides for better documentation clarity. (@gandalf-at-lerian)
- Add verified upgrade guides for transitioning from `1.1.1` to `1.2.0`. (@fredcamaral)
- Correct chart docs against templates and app code to ensure documentation accuracy. (@fredcamaral)
- Note when global streaming applies to clarify feature applicability. (@brunobls)
- Describe streaming and the permanent rollback to provide comprehensive feature documentation. (@brunobls)
- Describe the audited purge and its retention to inform users about data management. (@brunobls)
- Mark `ALLOW_RATELIMIT_DISABLED` as ignored to clarify configuration behavior. (@brunobls)
- Document the permanent block switch-off to guide users on feature deactivation. (@brunobls)
- Document which Midaz CRM mode to set for user guidance. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.2.0...plugin-br-sisbajud-v1.3.0)

---

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.0)

Features:
- Expose the direct channel settings to enhance configuration options. (@brunobls)
- Enable the permanent block feature by default, providing a more robust setup. (@brunobls)
- Ship app `1.2.0`, introducing new functionalities and improvements. (@brunobls)
- Default the Midaz CRM mode to embedded, simplifying the initial setup. (@gandalf-at-lerian)
- Expose streaming capabilities for the permanent block, allowing for more flexible data handling. (@brunobls)
- Expose purge refresh, sweep, and maintenance keys to improve system maintenance and data management. (@brunobls)

Fixes:
- Ensure the extraEnvVars streaming flag is honored, maintaining expected behavior. (@brunobls)
- Gate the permanent block feature as app `1.2.0` does, ensuring consistent functionality. (@brunobls)
- Refuse zero durations in the configmap to prevent misconfigurations. (@brunobls)
- Gate global streaming on the permanent block to ensure compatibility. (@brunobls)
- Default `OTEL_LIBRARY_NAME` to the module path, ensuring proper tracing configuration. (@brunobls)
- Refuse a zero purge alarm duration to avoid configuration errors. (@brunobls)
- Read the configmap in the notes for accurate documentation. (@brunobls)
- Require authentication in DIRECT-only mode to enhance security. (@brunobls)
- Emit the drainer cap in every mode to ensure consistent operation. (@brunobls)

Improvements:
- Apply review fixes to chart documentation and upgrade guides, enhancing clarity and usability. (@gandalf-at-lerian)
- Add verified upgrade guides for transitioning from `1.1.1` to `1.2.0`, assisting users in the upgrade process. (@fredcamaral)
- Correct chart documentation against templates and app code for accuracy. (@fredcamaral)
- Note when global streaming applies, providing clearer guidance on feature usage. (@brunobls)
- Describe streaming and the permanent rollback to inform users of available options. (@brunobls)
- Describe the audited purge and its retention, offering insights into data management practices. (@brunobls)
- Mark `ALLOW_RATELIMIT_DISABLED` as ignored, clarifying its status in the configuration. (@brunobls)
- Document the permanent block switch-off, informing users of available controls. (@brunobls)
- Document which Midaz CRM mode to set, guiding users in configuration choices. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.2.0...plugin-br-sisbajud-v1.3.0)

---

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.0)

Features:
- Expose the direct channel settings to allow configuration of direct communication channels. (@brunobls)
- Enable the permanent block by default to enhance security measures. (@brunobls)
- Ship app `1.2.0` to provide the latest features and improvements. (@brunobls)
- Default the Midaz CRM mode to embedded to streamline user experience. (@gandalf-at-lerian)
- Expose streaming for the permanent block to facilitate data flow management. (@brunobls)
- Expose purge refresh, sweep, and maintenance keys for better system maintenance. (@brunobls)

Fixes:
- Honor the extraEnvVars streaming flag to ensure correct environmental variable handling. (@brunobls)
- Gate the permanent block as app `1.2.0` does to maintain consistency with the application version. (@brunobls)
- Refuse zero durations in configmap to prevent configuration errors. (@brunobls)
- Gate global streaming on the permanent block to ensure proper streaming control. (@brunobls)
- Default OTEL_LIBRARY_NAME to the module path for accurate telemetry reporting. (@brunobls)
- Refuse a zero purge alarm duration to avoid misconfigurations. (@brunobls)
- Read the configmap in the notes to ensure accurate documentation. (@brunobls)
- Require authentication in DIRECT-only mode to enhance security. (@brunobls)
- Emit the drainer cap in every mode to ensure consistent system behavior. (@brunobls)

Improvements:
- Apply review fixes to chart docs and upgrade guides for better documentation clarity. (@gandalf-at-lerian)
- Add verified upgrade guides for transitioning from `1.1.1` to `1.2.0`. (@fredcamaral)
- Correct chart documentation against templates and app code for accuracy. (@fredcamaral)
- Note when global streaming applies to provide clear usage guidelines. (@brunobls)
- Describe streaming and the permanent rollback for better understanding of system behavior. (@brunobls)
- Describe the audited purge and its retention to inform users about data management. (@brunobls)
- Mark ALLOW_RATELIMIT_DISABLED as ignored to clarify its status. (@brunobls)
- Document the permanent block switch-off to guide users on disabling the feature. (@brunobls)
- Document which Midaz CRM mode to set for user guidance. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.2.0...plugin-br-sisbajud-v1.3.0)

---

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.3.0)

Features:
- Expose the direct channel settings to enhance configuration flexibility. (@brunobls)
- Enable the permanent block by default to improve security. (@brunobls)
- Ship app `1.2.0` to provide the latest features and fixes. (@brunobls)
- Default the Midaz CRM mode to embedded for better integration. (@gandalf-at-lerian)
- Expose streaming for the permanent block to enhance data handling capabilities. (@brunobls)
- Expose purge refresh, sweep, and maintenance keys to allow for better management of system resources. (@brunobls)

Fixes:
- Honor the `extraEnvVars` streaming flag to ensure proper environment variable handling. (@brunobls)
- Gate the permanent block as app `1.2.0` does to maintain consistency with the application version. (@brunobls)
- Refuse zero durations in the configmap to prevent configuration errors. (@brunobls)
- Gate global streaming on the permanent block to ensure proper feature gating. (@brunobls)
- Default `OTEL_LIBRARY_NAME` to the module path for accurate telemetry reporting. (@brunobls)
- Refuse a zero purge alarm duration to prevent configuration errors. (@brunobls)
- Read the configmap in the notes for accurate documentation. (@brunobls)
- Require authentication in DIRECT-only mode to enhance security. (@brunobls)
- Emit the drainer cap in every mode to ensure consistent behavior across configurations. (@brunobls)

Improvements:
- Apply review fixes to chart docs and upgrade guides for better documentation quality. (@gandalf-at-lerian)
- Add verified upgrade guides for transitioning from `1.1.1` to `1.2.0` to assist users with updates. (@fredcamaral)
- Correct chart documentation against templates and app code for accuracy. (@fredcamaral)
- Note when global streaming applies to clarify configuration scenarios. (@brunobls)
- Describe streaming and the permanent rollback for better understanding of feature interactions. (@brunobls)
- Describe the audited purge and its retention to provide clarity on data management. (@brunobls)
- Mark `ALLOW_RATELIMIT_DISABLED` as ignored to inform users of deprecated settings. (@brunobls)
- Document the permanent block switch-off to guide users in feature management. (@brunobls)
- Document which Midaz CRM mode to set for better configuration guidance. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.2.0...plugin-br-sisbajud-v1.3.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:

- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:

- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component to prevent unnecessary exposure of development flags. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin, ensuring it does not appear in the output. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.2.0)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin-br-sisbajud component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.1...plugin-br-sisbajud-v1.2.0)

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

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`, providing detailed instructions for users on how to upgrade to the new version. (@victorlazari)

Improvements:
- Relicensed the charts under the Elastic License 2.0, ensuring compliance with the new licensing terms. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed charts under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`, providing users with detailed instructions on how to upgrade to the new version. (@victorlazari)

Improvements:

- Relicense the charts under Elastic License 2.0, ensuring compliance with the updated licensing terms. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense the charts under the Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`, providing detailed instructions on how to upgrade to the new version. (@victorlazari)

Improvements:
- Relicensed the charts under Elastic License 2.0 to ensure compliance and clarity regarding usage rights. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0 for charts. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed the charts under the Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed the charts under the Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:
- Added a Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:
- Relicensed the charts under the Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.1.0...plugin-br-sisbajud-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.1)

Features:

- Add Helm upgrade guide for `plugin-br-sisbajud` `v1.1.0`. (@victorlazari)

Improvements:

- Relicense the charts under Elastic License 2.0. (@fredcamaral)

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

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app version `1.1.0`. (@brunobls)
- Implemented refusal of images without key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Prevented leading zeros in canonical tags. (@brunobls)
- Ensured verification is only for canonical image tags. (@brunobls)

Improvements:
- Updated documentation to include AWS KMS key modes in the getting started guide. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Clarified KMS trim behavior in the documentation. (@brunobls)
- Aligned tag gate notes with canonical rules in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Added notes on digest-only tag limits in the documentation. (@brunobls)
- Documented image tag gate and its limits. (@brunobls)
- Provided documentation for AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Ship app `1.1.0`. (@brunobls)
- Refuse images without key modes. (@brunobls)
- Render and validate AWS KMS key modes. (@brunobls)

Fixes:
- Refuse leading zeros in canonical tags. (@brunobls)
- Verify only canonical image tags. (@brunobls)

Improvements:
- Add AWS KMS key modes to getting started documentation. (@brunobls)
- Note AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Clarify KMS trim behavior in the documentation. (@brunobls)
- Align tag gate notes with canonical rule in the documentation. (@brunobls)
- Document canonical tags and limits. (@brunobls)
- Note digest-only tag limit in the documentation. (@brunobls)
- Document image tag gate and limits. (@brunobls)
- Document AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app `1.1.0`. (@brunobls)
- Added functionality to refuse images without key modes. (@brunobls)
- Implemented rendering and validation of AWS KMS key modes. (@brunobls)

Fixes:
- Addressed issue to refuse leading zeros in canonical tags. (@brunobls)
- Ensured verification of only canonical image tags. (@brunobls)

Improvements:
- Added AWS KMS key modes to the getting started documentation. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Clarified KMS trim behavior in the documentation. (@brunobls)
- Aligned tag gate notes with canonical rules in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Noted the digest-only tag limit in the documentation. (@brunobls)
- Documented image tag gate and limits. (@brunobls)
- Documented AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Ship app `1.1.0`. (@brunobls)
- Refuse images without key modes. (@brunobls)
- Render and validate AWS KMS key modes. (@brunobls)

Fixes:
- Refuse leading zeros in canonical tags. (@brunobls)
- Verify only canonical image tags. (@brunobls)

Improvements:
- Add AWS KMS key modes to getting started documentation. (@brunobls)
- Note that AWS KMS knobs render only with AWS. (@brunobls)
- Clarify KMS trim behavior in documentation. (@brunobls)
- Align tag gate notes with canonical rule. (@brunobls)
- Document canonical tags and limits. (@brunobls)
- Note digest-only tag limit in documentation. (@brunobls)
- Document image tag gate and limits. (@brunobls)
- Document AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app version `1.1.0`. (@brunobls)
- Implemented refusal of images without key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Corrected the verification process to only allow canonical image tags. (@brunobls)
- Implemented a check to refuse leading zeros in canonical tags. (@brunobls)

Improvements:
- Added documentation on AWS KMS key mode values. (@brunobls)
- Updated the getting started guide to include AWS KMS key modes. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Clarified the KMS trim behavior in the documentation. (@brunobls)
- Aligned tag gate notes with the canonical rule in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Added notes on the digest-only tag limit in the documentation. (@brunobls)
- Documented the image tag gate and its limits. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app `1.1.0`. (@brunobls)
- Implemented refusal of images without key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Addressed issue with leading zeros in canonical tags. (@brunobls)
- Ensured verification only for canonical image tags. (@brunobls)

Improvements:
- Updated documentation to include AWS KMS key modes in the getting started guide. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Clarified KMS trim behavior in the documentation. (@brunobls)
- Aligned tag gate notes with canonical rules in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Added a note on the digest-only tag limit in the documentation. (@brunobls)
- Documented image tag gate and limits. (@brunobls)
- Documented AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app `1.1.0`. (@brunobls)
- Added functionality to refuse images that do not specify key modes. (@brunobls)
- Implemented rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Corrected the verification process to only allow canonical image tags. (@brunobls)
- Implemented a check to refuse leading zeros in canonical tags. (@brunobls)

Improvements:
- Updated documentation to include AWS KMS key modes in the getting started guide. (@brunobls)
- Clarified documentation regarding the trimming behavior of KMS. (@brunobls)
- Noted that AWS KMS knobs are rendered only when using AWS in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Aligned tag gate notes with the canonical rule in the documentation. (@brunobls)
- Added a note about the digest-only tag limit in the documentation. (@brunobls)
- Documented the image tag gate and its limits. (@brunobls)
- Provided documentation on AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app `1.1.0`. (@brunobls)
- Implemented refusal of images without key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Corrected behavior to refuse leading zeros in canonical tags. (@brunobls)
- Ensured verification only for canonical image tags. (@brunobls)

Improvements:
- Updated documentation to include AWS KMS key modes in the getting started guide. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Clarified KMS trim behavior in the documentation. (@brunobls)
- Aligned tag gate notes with canonical rules in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Noted the digest-only tag limit in the documentation. (@brunobls)
- Documented the image tag gate and its limits. (@brunobls)
- Documented AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app `1.1.0`. (@brunobls)
- Implemented refusal of images without key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Resolved issue with leading zeros in canonical tags. (@brunobls)
- Ensured verification only for canonical image tags. (@brunobls)

Improvements:
- Updated documentation to include AWS KMS key modes in the getting started guide. (@brunobls)
- Clarified the behavior of KMS trim in the documentation. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Aligned tag gate notes with the canonical rule in the documentation. (@brunobls)
- Documented canonical tags, limits, and image tag gate in the documentation. (@brunobls)
- Added notes on digest-only tag limits in the documentation. (@brunobls)
- Documented AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Ship app `1.1.0`. (@brunobls)
- Refuse images that do not specify key modes. (@brunobls)
- Render and validate AWS KMS key modes. (@brunobls)

Fixes:
- Refuse leading zeros in canonical tags. (@brunobls)
- Verify only canonical image tags. (@brunobls)

Improvements:
- Add AWS KMS key modes to the getting started documentation. (@brunobls)
- Note that AWS KMS knobs render only with AWS. (@brunobls)
- Clarify KMS trim behavior. (@brunobls)
- Align tag gate notes with canonical rule. (@brunobls)
- Document canonical tags and their limits. (@brunobls)
- Note the digest-only tag limit. (@brunobls)
- Document image tag gate and limits. (@brunobls)
- Document AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app version `1.1.0`. (@brunobls)
- Implemented refusal of images without key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Corrected the verification process to only accept canonical image tags. (@brunobls)
- Addressed the issue of refusing leading zeros in canonical tags. (@brunobls)

Improvements:
- Updated documentation to include AWS KMS key modes in the getting started guide. (@brunobls)
- Noted that AWS KMS knobs render only with AWS in the documentation. (@brunobls)
- Clarified KMS trim behavior in the documentation. (@brunobls)
- Aligned tag gate notes with canonical rules in the documentation. (@brunobls)
- Documented canonical tags and their limits. (@brunobls)
- Noted the digest-only tag limit in the documentation. (@brunobls)
- Documented the image tag gate and its limits. (@brunobls)
- Documented AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-sisbajud-v1.0.0...plugin-br-sisbajud-v1.1.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.1.0)

Features:
- Released app `1.1.0`. (@brunobls)
- Implemented refusal of images without key modes. (@brunobls)
- Added rendering and validation for AWS KMS key modes. (@brunobls)

Fixes:
- Corrected behavior to refuse leading zeros in canonical tags. (@brunobls)
- Ensured verification is only performed on canonical image tags. (@brunobls)

Improvements:
- Added AWS KMS key modes to the getting started documentation. (@brunobls)
- Noted that AWS KMS knobs render only with AWS. (@brunobls)
- Clarified KMS trim behavior in the documentation. (@brunobls)
- Aligned tag gate notes with canonical rule. (@brunobls)
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

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on lerian-common `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on lerian-common. (@guimoreirar)

Fixes:
- Fixed the STREAMING_ENABLED comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the app default as `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name to the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the app default as `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the application default as `false`. (@guimoreirar)
- Pinned the application to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mutual TLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect the app default as false. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the app default as `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the STREAMING_ENABLED comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Released `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned the application to version `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mutual TLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the application default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned the app to version `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made `mensageria` MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the application default as `false`. (@guimoreirar)
- Pinned the application to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Released `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned the app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned the app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mutual TLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect the app default as false. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the STREAMING_ENABLED comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Ship `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Add the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pin app `1.0.0` and address review findings. (@guimoreirar)
- Require the streaming hub tenant in executor mode. (@guimoreirar)
- Point the telemetry library name at the plugin repository. (@guimoreirar)
- Default the telemetry identity to `plugin-br-sisbajud` and ship app `1.0.0-beta.2`. (@guimoreirar)
- Let an explicit `POSTGRES_PASSWORD` win for the migrations hook. (@guimoreirar)
- Make mensageria MTLS optional and fix render gates. (@guimoreirar)

Improvements:
- Fix the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the STREAMING_ENABLED comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mtls optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned the app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the STREAMING_ENABLED comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Released `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Released `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name to the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mutual TLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to correctly reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Released `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart to `lerian-common`. (@guimoreirar)

Fixes:
- Corrected the STREAMING_ENABLED comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned the app to `1.0.0` and addressed review findings. (@guimoreirar)
- Made the streaming hub tenant a requirement in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Set the default telemetry identity to `plugin-br-sisbajud` and released `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mutual TLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the default app setting as false. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned the app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` using `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repo. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect the app default as false. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Ship `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Add the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pin app `1.0.0` and address review findings. (@guimoreirar)
- Require the streaming hub tenant in executor mode. (@guimoreirar)
- Point the telemetry library name at the plugin repository. (@guimoreirar)
- Default the telemetry identity to `plugin-br-sisbajud` and ship app `1.0.0-beta.2`. (@guimoreirar)
- Let an explicit `POSTGRES_PASSWORD` take precedence for the migrations hook. (@guimoreirar)
- Make mensageria MTLS optional and fix render gates. (@guimoreirar)

Improvements:
- Fix the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence in the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Released `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned the app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Updated the telemetry library name to point at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned the app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mutual TLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria mutual TLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)
- Pinned app to `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-sisbajud-v1.0.0)

Features:
- Shipped `1.0.0-beta.1` on `lerian-common` `2.3.0`. (@guimoreirar)
- Added the SISBAJUD executor chart on `lerian-common`. (@guimoreirar)

Fixes:
- Pinned app `1.0.0` and addressed review findings. (@guimoreirar)
- Required the streaming hub tenant in executor mode. (@guimoreirar)
- Pointed the telemetry library name at the plugin repository. (@guimoreirar)
- Defaulted the telemetry identity to `plugin-br-sisbajud` and shipped app `1.0.0-beta.2`. (@guimoreirar)
- Allowed an explicit `POSTGRES_PASSWORD` to take precedence for the migrations hook. (@guimoreirar)
- Made mensageria MTLS optional and fixed render gates. (@guimoreirar)

Improvements:
- Fixed the `STREAMING_ENABLED` comment to reflect that the app default is `false`. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-sisbajud-v1.0.0)

