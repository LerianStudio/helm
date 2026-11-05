# Plugin-br-pix-lerian Changelog

## [2.0.5](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.0.5)

Features:

- Documented the mock provider base URL as a required configuration. (@fredcamaral)
- Added the verified upgrade guide for `2.0.4`. (@fredcamaral)

Fixes:

- Stopped pod restarts on chart-only releases to improve stability. (@fredcamaral)
- Adjusted pod checksums to hash only the configuration data. (@fredcamaral)
- Removed the chart label from pod templates and set a neutral default for the mock provider. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v2.0.4...plugin-br-pix-lerian-v2.0.5)

---

## [2.0.4](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.0.4)

Fixes:
- Default the `pixauto` `SPI_BASE_URL` to the SPI port. (@fredcamaral)
- Honor `global.auth` in the `pixauto` ingress guard. (@fredcamaral)
- Enable authentication on every workload in the template. (@fredcamaral)
- Point the `pixauto` `SPI_BASE_URL` at the SPI service port. (@fredcamaral)

Improvements:
- Document that the mock image requires a pull credential. (@fredcamaral)
- Apply review fixes to chart documentation and upgrade guides. (@gandalf-at-lerian)
- Add verified upgrade guides for transitioning from `2.0.2` to `2.0.3`. (@fredcamaral)
- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v2.0.3...plugin-br-pix-lerian-v2.0.4)

---

## [2.0.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.0.3)

Fixes:
- Increased the default probe timeout to `3s` to improve reliability. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v2.0.2...plugin-br-pix-lerian-v2.0.3)

---

## [2.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.0.2)

Improvements:
- Add Helm upgrade guide for `plugin-br-pix-lerian` `v2.0.1`. (@guimoreirar)
- Add Helm upgrade guide for `plugin-br-pix-lerian` `v2.0.0`. (@guimoreirar)
- Add Helm upgrade guide for `plugin-br-pix-lerian` `v1.0.2`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v2.0.1...plugin-br-pix-lerian-v2.0.2)

---

## [2.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.0.1)

Fixes:
- Set the Pix Lerian chart to default to production posture. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v2.0.0...plugin-br-pix-lerian-v2.0.1)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.0.0)

Fixes:

- Render boolean false on flags that default to true, ensuring consistent behavior in the plugin. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v1.0.2...plugin-br-pix-lerian-v2.0.0)

---

## [1.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v1.0.2)

Features:
- Enable `pixauto` in app version `1.1.0`. (@Leonardox7)

Fixes:
- Wire `pixauto` `v1.1.0` environment variables, including adapter, CRM, and read-replica, into the chart. (@Leonardox7)

Improvements:
- Name the two `pixauto` keys in the README for better clarity. (@Leonardox7)
- Add a Helm upgrade guide for `plugin-br-pix-lerian` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v1.0.1...plugin-br-pix-lerian-v1.0.2)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v1.0.1)

Features:

- Add a Helm upgrade guide for `plugin-br-pix-lerian` `v1.0.0`. (@guimoreirar)

Fixes:

- Ensure the deployment otel gate respects `global.observability.otlpEndpoint`. (@guimoreirar, @gandalf-at-lerian)
- Disable the structural-only dict and cob proxies by default. (@gandalf-at-lerian)
- Render `configmap.ORGANIZATION_ID` on the components that require it. (@gandalf-at-lerian)
- Build against the published `lerian-common` `2.1.2`. (@fredcamaral)

Improvements:

- Update documentation to state that a supplied routes list replaces the defaults. (@gandalf-at-lerian)
- Align README and guides with the rendered chart. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-lerian-v1.0.0...plugin-br-pix-lerian-v1.0.1)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v1.0.0)

Features:
- Drive `STREAMING_ENABLED` from `global.streaming.enabled`. (@guimoreirar)
- Consolidate `SD_*` via `global.serviceDiscovery` using a chart-local helper. (@guimoreirar)
- Port the plugin-br-pix-lerian chart from develop. (@Leonardox7)

Fixes:
- Point pix-lerian at the real access-manager service. (@Leonardox7)
- Prefix the pix-lerian provider-mock callback URLs. (@Leonardox7)
- Gate pix-lerian telemetry on the resolved flag. (@Leonardox7)
- Keep the OTel endpoint when an operator overrides `HOST_IP`. (@Leonardox7)
- Accept every `ParseBool` truthy `TELEMETRY_ENABLED` in pix-lerian. (@Leonardox7)
- Align pix-lerian's chart and app versions with what is published. (@Leonardox7)
- Put the pix-lerian migration Jobs under `seccomp` `RuntimeDefault`. (@Leonardox7)
- Ship pix-lerian's template with the proxies disabled. (@Leonardox7)
- Set `ENV_NAME=production` on every component pix-lerian's template enables. (@Leonardox7)
- Stop pix-lerian `extraEnvVars` from duplicating an env name. (@Leonardox7)
- Stop pix-lerian defaults from discarding an explicit zero. (@Leonardox7)
- Give the pix-lerian bootstrap Postgres Job a security context. (@Leonardox7)

Improvements:
- Always emit `OTEL_RESOURCE_SERVICE_VERSION` into the ConfigMap. (@guimoreirar)
- Drop `DICT` outbound callback fields. (@Leonardox7)
- Adopt lerian-common masks and emit the STANDARD contract. (@guimoreirar)
- Productize configmap surface with defaults-in-template. (@guimoreirar)
- Adopt lerian-common workload fragments. (@guimoreirar)
- Rewrite runbook tone and add an English version. (@guimoreirar)
- Add a getting-started runbook. (@guimoreirar)
- Fix getting-started documentation with prefixed probe paths and correct license client number. (@guimoreirar)
- Drop internal review checklist from the published runbook. (@guimoreirar)
- Restructure the pix-lerian README. (@Leonardox7)
- Drop the license bypass from pix-lerian troubleshooting. (@Leonardox7)
- Disambiguate two version numbers in the pix-lerian changelog. (@Leonardox7)
- Scope the pix-lerian values migration to the one key that breaks. (@Leonardox7)
- State pix-lerian's `ORGANIZATION_ID` and master-key contracts once. (@Leonardox7)
- Quote `ingressClassName` in plugin-br-pix-lerian. (@Leonardox7)
- Add render assertions and a CI fixture for pix-lerian. (@Leonardox7)

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-lerian-v1.0.0)
