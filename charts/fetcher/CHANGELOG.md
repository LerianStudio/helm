# Fetcher Changelog

## [4.2.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v4.2.0)

Features:
- Add an optional license file mount for `lib-license-go` `v5`. (@fredcamaral)

Improvements:
- Add the `4.1.3` upgrade guide. (@fredcamaral)
- Make the `4.1.3` Mongo checks actionable. (@fredcamaral)
- Reword the `4.1.3` upgrade guide for clarity. (@fredcamaral)
- Add the verified `4.1.3` upgrade guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v4.1.3...fetcher-v4.2.0)

---

## [4.1.3](https://github.com/LerianStudio/helm/releases/tag/fetcher-v4.1.3)

Fixes:
- Verified DocumentDB certificates on the AWS preset to ensure secure connections. (@fredcamaral)
- Ensured that only configuration data is hashed in pod checksums to optimize performance. (@fredcamaral)
- Maintained explicit MongoDB parameter values without alteration on AWS to preserve intended configurations. (@fredcamaral)

Improvements:
- Added the verified `4.1.2` upgrade guide to assist users in transitioning smoothly to the new version. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v4.1.2...fetcher-v4.1.3)

---

## [4.1.2](https://github.com/LerianStudio/helm/releases/tag/fetcher-v4.1.2)

Fixes:
- Emit `REDIS_TLS`, install KEDA CRDs, and drop unread keys to improve functionality. (@fredcamaral)

Improvements:
- Add verified upgrade guides for transitioning from `4.0.1` to `4.1.1`. (@fredcamaral)
- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v4.1.1...fetcher-v4.1.2)

---

## [4.1.1](https://github.com/LerianStudio/helm/releases/tag/fetcher-v4.1.1)

Fixes:
- Update fetcher to use stable images, ensuring reliability and consistency in deployments. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v4.1.0...fetcher-v4.1.1)

---

## [4.1.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v4.1.0)

Features:
- Adopt the `lerian-common` health preset to enhance the health configuration. (@fredcamaral)

Fixes:
- Refuse `pdb.enabled` and zero grace overrides to prevent incorrect configurations, and update the README to reflect these changes. (@fredcamaral)
- Refuse retired `pdb` and rollout overrides to ensure deprecated settings are not used. (@fredcamaral)

Improvements:
- Document which health keys are refused by the render to clarify configuration options. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v4.0.1...fetcher-v4.1.0)

---

## [4.0.1](https://github.com/LerianStudio/helm/releases/tag/fetcher-v4.0.1)

Features:

- Add Helm upgrade guide for `fetcher` `v4.0.0`. (@guimoreirar)
- Add Helm upgrade guide for `fetcher` `v3.4.4`. (@guimoreirar)

Improvements:

- Link the license by URL so packaged charts resolve it. (@fredcamaral)
- Relicense under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v4.0.0...fetcher-v4.0.1)

---

## [4.0.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v4.0.0)

Fixes:
- Render boolean `false` on default-true flags to ensure correct behavior. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.4.4...fetcher-v4.0.0)

---

## [3.4.4](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.4.4)

Fixes:
- Resolve vault placeholders in RabbitMQ definitions to ensure proper configuration handling. (@prymax10)

Improvements:
- Add Helm upgrade guide for `fetcher` `v3.4.1`. (@guimoreirar)
- Add Helm upgrade guide for `fetcher` `v3.4.2`. (@guimoreirar)
- Add Helm upgrade guide for `fetcher` `v3.4.3`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.4.3...fetcher-v3.4.4)

---

## [3.4.3](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.4.3)

Fixes:
- Update `fetcher-manager` to `3.1.1` and `fetcher-worker` to `3.1.1`, ensuring compatibility and stability improvements. (@lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.4.2...fetcher-v3.4.3)

---

## [3.4.2](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.4.2)

Improvements:
- Keep each fetcher release under the license it shipped with. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.4.1...fetcher-v3.4.2)

---

## [3.4.1](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.4.1)

Improvements:
- Drop the Apache 2.0 license claim for the fetcher application. (@fredcamaral)
- Add a Helm upgrade guide for fetcher `v3.4.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.4.0...fetcher-v3.4.1)

---

## [3.4.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.4.0)

Features:
- Pin `lerian-common-helm` to `2.4.0` to support the `IDP_*` declaration helper. (@qnen)
- Render the `IDP_*` permission declaration using `lerian-common`. (@qnen)

Improvements:
- Update documentation to indicate that `minDomains` can prompt an autoscaler instead of guaranteeing node provisioning. (@gandalf-at-lerian)
- Use `minDomains 2` in the spread examples and include both RabbitMQ render checks in the documentation. (@gandalf-at-lerian)
- Align the README, values, and upgrade guides with the templates. (@gandalf-at-lerian)
- Add a Helm upgrade guide for fetcher `v3.3.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.3.0...fetcher-v3.4.0)

---

## [3.3.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.3.0)

Features:
- Expose spread `minDomains` and `nodeTaintsPolicy` in `lerian-common` `2.3.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.2.0...fetcher-v3.3.0)

---

## [3.2.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.2.0)

Features:
- Added topology spread preset and ensured component secrets take precedence over shared ones. (@guimoreirar)
- Adopted lerian-common cloud masks for datastores, object storage, authentication, streaming, and multi-tenancy. (@guimoreirar)

Fixes:
- Merged worker service account annotations and documented `global.streaming.enabled`. (@guimoreirar)
- Addressed review comments on telemetry, extra environment variables, and empty secrets. (@guimoreirar)
- Defaulted `STREAMING_CLOUDEVENTS_SOURCE` to the roster name. (@guimoreirar)
- Stopped the bundled RabbitMQ from shipping with a public password. (@fredcamaral)
- Allowed bootstrap jobs to finish under a mesh sidecar. (@fredcamaral)
- Reserved `VERSION/OTEL_RESOURCE_SERVICE_VERSION` in the worker deduplication list. (@guimoreirar)
- Filtered mask-generated keys from `worker.extraEnvVars`. (@guimoreirar)
- Pinned stable `lerian-common` `2.0.0`, derived management scheme, deduplicated streaming keys, and allow-listed kind readiness. (@guimoreirar)
- Wired up a previously non-functional top-level secrets block, added `ALLOW_INSECURE_TLS`, and configured streaming. (@guimoreirar)

Improvements:
- Added Helm upgrade guides for `fetcher` `v3.1.2`, `v3.1.3`, and `v3.1.4`. (@guimoreirar)
- Corrected the upgrade guide for `v3.1.4`. (@guimoreirar)
- Maintained the mesh sidecar comment to its invariant. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.1.4...fetcher-v3.2.0)

---

## [3.1.4](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.1.4)

Fixes:

- Adjust the RabbitMQ plugin to ensure the user does not have a management tag. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.1.3...fetcher-v3.1.4)

---

## [3.1.3](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.1.3)

- Fixes:
  - RabbitMQ bootstrap now sets the configured password first.

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.1.2...fetcher-v3.1.3)

---

## [3.1.2](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.1.2)

- **Fixes**
  - Pass pod security restricted to ensure compliance with security policies.
  - Implement new bootstrap jobs per revision and converge RabbitMQ retries for improved stability.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.1.1...fetcher-v3.1.2)

---

## [3.1.1](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.1.1)

- **Features:**
  - Released fetcher v3.1.0 with updated documentation and upgrade guide.
  
- **Fixes:**
  - Updated fetcher-manager and fetcher-worker to version 3.1.0 to address compatibility issues.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.1.0...fetcher-v3.1.1)

---

## [3.1.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.1.0)

- **Features**
  - Released version 3.1.0 of the fetcher component.

- **Fixes**
  - Updated fetcher-manager to version 3.0.2 and fetcher-worker to version 3.0.2 to address specific issues.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v3.0.0...fetcher-v3.1.0)

---

## [3.0.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v3.0.0)

- **Features:**
  - Added ALLOW_INSECURE_TLS configuration to multiple charts and updated image tags.

- **Fixes:**
  - Addressed CodeRabbit review on revamp PR #1470.

- **Improvements:**
  - Aligned upgrade guide format.
  - Added v2.2 upgrade guide.
  - Parametrized probe path and timing for all charts using /readyz.

Contributors: @ferr3ira-gabriel, @fredcamaral, @gandalf-at-lerian, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v2.1.1...fetcher-v3.0.0)

---

## [2.1.1](https://github.com/LerianStudio/helm/releases/tag/fetcher-v2.1.1)

- Features:
  - Released version 2.1.0 of fetcher.

Contributors: @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v2.1.0...fetcher-v2.1.1)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v2.1.0)

- **Features:**
  - Added missing NEU app environment variables to fetcher.
  - Updated fetcher-manager to version 1.3.0 and fetcher-worker to version 1.3.0 with new environment variables.
  - Auto-set VERSION and OTEL_RESOURCE_SERVICE_VERSION from image tag.
  - Added ServiceAccount support for fetcher worker.

- **Fixes:**
  - Removed common secret to match reporter pattern.

Contributors: @ferr3ira-gabriel, @ferr3ira.gabriel, @guimoreirar, @lucas.bedatty

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v2.0.3...fetcher-v2.1.0)

---

## [2.0.4](https://github.com/LerianStudio/helm/releases/tag/fetcher-v2.0.4)

- Fixes:
  - Remove common secret to match reporter chart pattern
  - Secrets now managed via `useExistingSecret` on manager/worker only

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v2.0.3...fetcher-v2.0.4)

---

## [2.0.3](https://github.com/LerianStudio/helm/releases/tag/fetcher-v2.0.3)

- Features:
  - Released version 2.0.3-beta.1
  - Released version 2.0.3

- Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v2.0.2...fetcher-v2.0.3)

---

## [2.0.2](https://github.com/LerianStudio/helm/releases/tag/fetcher-v2.0.2)

- Fixes:
  - Add http:// prefix to OTEL_EXPORTER_OTLP_ENDPOINT in fetcher.

Contributors: @ferr3ira.gabriel

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v2.0.1...fetcher-v2.0.2)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v2.0.0)

Features:
- Added IAM Roles Anywhere sidecar support for fetcher.

Fixes:
- Added required validation for Roles Anywhere ARNs.

Contributors: @ferr3ira.gabriel, @gandalf, @guimoreirar,

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v1.3.0...fetcher-v2.0.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v1.2.0)

Features:
- Updated to fetcher-manager@1.1.0 and fetcher-worker@1.1.0, introducing new environment variables.

Fixes:
- Added RabbitMQ and storage configuration options.
- Removed unused secret template.

Contributors: @gui.rodrigues,

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v1.1.0...fetcher-v1.2.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/fetcher-v1.1.0)

- Features:
  - Add OpenTelemetry HOST_IP injection support to fetcher.

Contributors: @ferr3ira.gabriel, @gui.rodrigues, @guimoreirar,

[Compare changes](https://github.com/LerianStudio/helm/compare/fetcher-v1.0.0...fetcher-v1.1.0)

