# Product-console Changelog

## [4.5.2](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.5.2)

Fixes:
- Stop pod restarts on chart-only releases to improve stability. (@fredcamaral)
- Hash only configuration data in pod checksums to avoid unnecessary updates. (@fredcamaral)
- Exclude chart version from pod labels to prevent unintended changes. (@fredcamaral)

Improvements:
- Apply review fixes to chart documentation and upgrade guides for better clarity. (@dy-shimizu, @gandalf-at-lerian)
- Add the verified `4.5.1` upgrade guide to assist users with the update process. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.5.1...product-console-v4.5.2)

---

## [4.5.1](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.5.1)

Fixes:
- Stop rendering keys that the console never reads to improve performance. (@fredcamaral)
- Limit the NOTES MongoDB scheme to `mongodb` to prevent incorrect configurations. (@fredcamaral)

Improvements:
- Add verified upgrade guides for transitioning from `4.4.7` to `4.5.0`. (@fredcamaral)
- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.5.0...product-console-v4.5.1)

---

## [4.5.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.5.0)

Features:
- Render `LICENSE_KEY` into the Secret required for product-console. (@fredcamaral)

Improvements:
- List both secrets necessary for product-console to boot. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.8...product-console-v4.5.0)

---

## [4.4.8](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.8)

Improvements:
- Relicense product-console under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.7...product-console-v4.4.8)

---

## [4.4.7](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.7)

Features:
- Update `product-console` to `@3.0.0`. (@lerian-studio)

Improvements:
- Add Helm upgrade guide for `product-console` `v4.4.5`. (@victorlazari)
- Add Helm upgrade guide for `product-console` `v4.4.6`. (@victorlazari)

Fixes:
- Correct image tag and rollout claims in the `v4.4.5` upgrade guide. (@gandalf-at-lerian)
- Fix unverified app claims in the `v4.4.6` upgrade guide. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.6...product-console-v4.4.7)

---

## [4.4.6](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.6)

Fixes:

- Update `product-console` to `2.16.4`. (@lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.5...product-console-v4.4.6)

---

## [4.4.5](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.5)

Fixes:

- Update `product-console` to `2.16.2`. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.4...product-console-v4.4.5)

---

## [4.4.4](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.4)

Fixes:
- Update `product-console` to `@2.13.1`. (@lerian-studio)

Improvements:
- Add Helm upgrade guide for `product-console` `v4.4.3`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.3...product-console-v4.4.4)

---

## [4.4.3](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.3)

Features:
- Align README, notes, and values-template with the chart and app for improved documentation consistency. (@gandalf-at-lerian)

Fixes:
- Update `product-console@2.13.0` to address specific issues. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `product-console` `v4.4.1`. (@guimoreirar)
- Add a Helm upgrade guide for `product-console` `v4.4.2`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.2...product-console-v4.4.3)

---

## [4.4.2](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.2)

Fixes:

- Update `product-console` to `2.12.0`. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.1...product-console-v4.4.2)

---

## [4.4.1](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.1)

Fixes:
- Re-triggered the `2.9.0` release for product-console. (@guimoreirar)
- Updated product-console to `2.9.0`. (@lerian-studio)

Improvements:
- Added a Helm upgrade guide for product-console `v4.4.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.4.0...product-console-v4.4.1)

---

## [4.4.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.4.0)

Features:
- Spread console pods across nodes to improve distribution and resilience. (@guimoreirar)
- Expose configuration options for `minDomains` and `nodeTaintsPolicy` in `lerian-common` `2.3.0`. (@guimoreirar)
- Spread console pods across nodes and zones for enhanced fault tolerance. (@guimoreirar)

Fixes:
- Disable zone spread by default to prevent unintended distribution across zones. (@guimoreirar)
- Ensure the `mongodb existingSecret` template remains on a single line for consistency. (@guimoreirar)
- Update `product-console` to `2.8.0` to incorporate the latest fixes and improvements. (@lerian-studio)

Improvements:
- Accurately describe the default spread configuration in the documentation to provide clearer guidance. (@guimoreirar)
- Add a Helm upgrade guide for `product-console` `v4.3.0` to assist users in transitioning smoothly. (@guimoreirar)
- Add a Helm upgrade guide for `product-console` `v4.3.1` to ensure users have the latest upgrade instructions. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.3.1...product-console-v4.4.0)

---

## [4.3.1](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.3.1)

Fixes:

- Update `product-console` to `2.6.0`. (@lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.3.0...product-console-v4.3.1)

---

## [4.3.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.3.0)

Features:
- Declare lender and matcher base paths in the product-console. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.7...product-console-v4.3.0)

---

## [4.2.7](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.7)

Fixes:
- Deploy the `2.5.0` image for product-console. (@guimoreirar)
- Update product-console to `2.5.0`. (@lerian-studio)

Improvements:
- Add Helm upgrade guide for product-console `v4.2.6`. (@guimoreirar)
- Add Helm upgrade guide for product-console `v4.2.4`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.6...product-console-v4.2.7)

---

## [4.2.6](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.6)

- **Fixes:**
  - Updated product-console to version 2.4.1.
  - Applied the 2.4.1 tag to image.tag.

- **Improvements:**
  - Added Helm upgrade guide for product-console v4.2.5.
  - Corrected upgrade guide for v4.2.5.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.5...product-console-v4.2.6)

---

## [4.2.5](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.5)

- **Fixes:**
  - Let the bootstrap job finish under a mesh sidecar.

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.4...product-console-v4.2.5)

---

## [4.2.4](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.4)

- **Fixes**
  - Ensure the database and its password are retained on uninstall.
  - Correctly locate the stored password where it is written.
  - Prevent acceptance of an empty MongoDB existingSecret.

- **Improvements**
  - Document the process to uninstall within its namespace before deleting data.
  - Add a Helm upgrade guide for product-console v4.2.3.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.3...product-console-v4.2.4)

---

## [4.2.3](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.3)

- **Fixes**
  - Bumped the real image.tag to 2.2.1 and removed obsolete values block.
  - Updated product-console to version 2.2.1.

- **Documentation**
  - Added Helm upgrade guide for product-console v4.2.2.
  - Added upgrade guide for product-console v4.2.2.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.2...product-console-v4.2.3)

---

## [4.2.2](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.2)

- **Fixes:**
  - Updated product-console to version 2.1.0.

- **Documentation:**
  - Added upgrade guide for product-console v4.2.1.

Contributors: @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.1...product-console-v4.2.2)

---

## [4.2.1](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.1)

- Fixes:
  - Updated product-console to version 2.0.0.
  - Bumped image tag to 2.0.0 and restored chart from main.

- Improvements:
  - Added Helm upgrade guide for product-console v4.1.0.
  - Added Helm upgrade guide for product-console v4.2.0.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.2.0...product-console-v4.2.1)

---

## [4.2.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.2.0)

- Features:
  - Declare `MIDAZ_V2_BASE_PATH` as a named key in product-console.

Contributors: @jeffersonrodrigues92, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.1.0...product-console-v4.2.0)

---

## [4.0.6](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.0.6)

- **Features**
  - Added getting-started installation runbook in both English and Portuguese.
  - Introduced documentation on volume warnings and their implications.
  
- **Fixes**
  - Instructed operators to back up the database.
  - Clarified that moving the subchart will empty its volume.
  - Ensured values are retained when repairing splits.
  - Implemented refusal for secret names that consist only of spaces.
  - Provided a reliable namespace remedy.
  - Corrected the service name created by Bitnami.
  - Refused existing secrets with no name.

- **Improvements**
  - Enhanced documentation with a Helm upgrade guide for version 4.0.5.
  - Updated documentation to address authentication credentials, CORS settings, and DocumentDB TLS caveats.
  - Improved port-forward readiness checks before executing curl commands.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.0.5...product-console-v4.0.6)

---

## [4.0.5](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.0.5)

- **Fixes:**
  - Refuse a MongoDB host the chart cannot name.
  - Print the remedy that works for this split.
  - Let a null clear the trusted proxy value.
  - Read the bundled MongoDB password from its secret.
  - Resolve the MongoDB host through lerian-common.

- **Improvements:**
  - Put the service account in the chart namespace.
  - Come up on the chart's own shipped defaults.

- **Documentation:**
  - Specify which password the console's own must match.
  - Indicate which subchart template reads the override.
  - Name the key that carries the secret name.
  - Specify when the MongoDB password is wired.
  - Correct the client IP and MongoDB notes.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.0.4...product-console-v4.0.5)

---

## [4.0.4](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.0.4)

- Improvements:
  - Clarified the session condition as either switch in the documentation.
  - Described the server value and the browser fallback separately in the documentation.
  - Separated the session requirement from the authorization switch in the documentation.
  - Stated the auth switch precedence and the browser-key fallback in the documentation.
  - Noted that authorization is off unless explicitly switched on in the documentation.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.0.3...product-console-v4.0.4)

---

## [4.0.3](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.0.3)

- **Features**
  - Made the probe port configurable for enhanced flexibility.

- **Fixes**
  - Defaulted liveness endpoint to `/api/admin/health/alive` to ensure consistent health checks.
  
- **Improvements**
  - Clarified documentation on readiness/liveness/port framing and provided compatibility caveats for probe-port.
  - Documented the MongoDB requirement for readiness checks.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.0.2...product-console-v4.0.3)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.0.2)

- Fixes:
  - Updated product-console to version 1.12.0.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.0.1...product-console-v4.0.2)

---

## [4.0.1](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.0.1)

- **Fixes**
  - Resolved an issue with the readiness probe dependency endpoint to ensure accurate status reporting.

- **Improvements**
  - Clarified the documentation regarding readiness rollback override for better understanding.
  - Aligned the readiness endpoint documentation to reflect the latest changes.

Contributors: @gandalf-at-lerian, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v4.0.0...product-console-v4.0.1)

---

## [4.0.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v4.0.0)

- **Features:**
  - Default inter-service hosts to cross-namespace FQDN.
  - Adopt lerian-common-helm cloud masks.

- **Fixes:**
  - Default ALLOWED_ORIGINS from the ingress host.
  - Use correct flags for mongosh, replacing the non-existent `--tlsInsecure` flag.
  - Mark bootstrap-mongodb Job as a native Helm hook and make it self-healing on ArgoCD Sync.
  - Address bootstrap-mongodb Job hanging against TLS-required managed MongoDB.
  - Drop dead environment variable, derive `NEXTAUTH_URL` from ingress, sync `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED`, and allow `client_id` via secret.

- **Improvements:**
  - Pin lerian-common-helm to stable 2.0.0.
  - Move configmap keys and defaults out of `values.yaml` to reduce duplication.
  - Use `lerian-common.auth.env` helper for plugin-auth mask.
  - Pass namespace to HPA/PDB/ingress lerian-common includes.
  - Sync README with lerian-common adoption and document `global.cloud=aws` mongo preset.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v3.3.0...product-console-v4.0.0)

---

## [3.3.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v3.3.0)

- **Features**
  - Added requirement for Helm 3.8.0+ for the OCI install in documentation.
  
- **Fixes**
  - Updated installation documentation to use Docker Hub OCI registry.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v3.2.0...product-console-v3.3.0)

---

## [3.2.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v3.2.0)

- **Features**
  - Released version 3.2.0 of product-console.

- **Improvements**
  - Updated appVersion and image tag to 1.10.0 for product-console.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v3.1.0...product-console-v3.2.0)

---

## [3.1.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v3.1.0)

- **Features:**
  - Released version 3.1.0 of product-console.
  - Introduced a per-chart `values.schema.json` generator to enhance CI processes.

- **Fixes:**
  - Addressed issues in `values.schema.json` files to allow additional properties.
  - Resolved feedback from CodeRabbit review on chart revamp.

- **Improvements:**
  - Standardized charts to align with the Lerian chart contract.
  - Updated documentation to reflect changes in chart standards.
  - Added an upgrade guide for product-console v3.0.0.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v3.0.0...product-console-v3.1.0)

---

## [3.0.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v3.0.0)

- **Fixes**
  - Added `MONGO_PARAMETERS` to configmap for MongoDB configuration.
  - Updated readiness probe path to default to root.
  - Parametrized probes that were missed in the initial commit.

- **Improvements**
  - Aligned upgrade guide format.

Contributors: @ferr3ira-gabriel, @gandalf-at-lerian, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v2.3.0...product-console-v3.0.0)

---

## [2.3.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v2.3.0)

- Features:
  - Released version 2.3.0.
  - Released version 2.3.0-beta.1.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v2.2.0...product-console-v2.3.0)

---

## [2.2.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v2.2.0)

- **Features**
  - Update to version 1.6.0 for product-console.

- **Fixes**
  - Remove inconsistent artifacthub image annotation.
  - Add image annotation for product-console 1.6.0.

Contributors: @ferr3ira-gabriel, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v2.1.0...product-console-v2.2.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v2.1.0)

- Features:
  - Added bootstrap-mongodb.yaml for idempotent MongoDB user/db provisioning.
  - Made app user and roles configurable via values in bootstrap-mongodb.

- Fixes:
  - Used /bin/bash instead of /bin/sh for mongosh container in bootstrap-mongodb.
  - Standardized VERSION/OTEL_RESOURCE_SERVICE_VERSION in remaining charts.
  - Used updateUser + process.env for safer reconciliation in bootstrap-mongodb.

Contributors: @bedatty, @ferr3ira-gabriel, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v2.0.1...product-console-v2.1.0)

---

## [2.0.1](https://github.com/LerianStudio/helm/releases/tag/product-console-v2.0.1)

- Features:
  - Released version 2.0.0 of product-console.

Contributors:

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v2.0.0...product-console-v2.0.1)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v2.0.0)

- Features:
  - Update image tag to 1.5.0 and add upgrade guide.
  - Add MONGO_PARAMETERS environment variable for TLS/auth options.
  - Add dynamic OTEL host injection support.

Contributors: @ferr3ira-gabriel, @ferr3ira.gabriel,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v1.3.0...product-console-v2.0.0)

---

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v1.3.0)

- Fixes:
  - Derive MongoDB service name dynamically in NOTES.txt.
  - Set image tag to 1.3.0 in values.yaml.
  - Update appVersion to 1.3.0.
  - Address CodeRabbit review on NOTES.txt.
  - Add MongoDB connection info to NOTES.txt.

Contributors: @gandalf

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v1.2.0...product-console-v1.3.0)

---

## [1.2.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v1.2.0)

- **Features**
  - Added MongoDB dependency and configuration to the product-console chart.

Contributors: @gui.rodrigues,

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v1.1.0...product-console-v1.2.0)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/product-console-v1.1.0)

- **Features**
  - Added tracer Helm chart.

Contributors: @ferr3ira.gabriel

[Compare changes](https://github.com/LerianStudio/helm/compare/product-console-v1.0.0...product-console-v1.1.0)

---

## [1.0.0] - 2026-01-15

### Added
- Initial release of Product Console Helm chart
- Deployment with configurable replicas and rolling update strategy
- ConfigMap for environment configuration
- Secret management for sensitive data
- Ingress support with TLS configuration
- Horizontal Pod Autoscaler (HPA) support
- Pod Disruption Budget (PDB) support
- Service Account configuration
