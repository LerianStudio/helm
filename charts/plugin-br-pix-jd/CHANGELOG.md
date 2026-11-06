# Plugin-br-pix-jd Changelog

## [0.7.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.7.0)

Features:
- Add an optional license file mount. (@fredcamaral)

Improvements:
- Add the `0.6.3` upgrade guide. (@fredcamaral)
- Correct restart notes in the `0.6.3` upgrade guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.6.3...plugin-br-pix-jd-v0.7.0)

---

## [0.6.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.6.3)

Fixes:
- Ensure the chart label is kept out of pod templates to maintain proper configuration. (@fredcamaral)

Improvements:
- Apply review fixes to chart documentation and upgrade guides for better clarity and accuracy. (@gandalf-at-lerian)
- Add verified upgrade guides for transitioning from versions `0.5.9` to `0.6.2`. (@fredcamaral)
- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.6.2...plugin-br-pix-jd-v0.6.3)

---

## [0.6.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.6.2)

Features:
- State the migrations pin for `1.6.1`. (@fredcamaral)

Fixes:
- Update `plugin-br-pix-jd` to `1.6.1`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.6.1...plugin-br-pix-jd-v0.6.2)

---

## [0.6.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.6.1)

Fixes:

- Use stable images for the plugin to ensure consistent performance and reliability. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.6.0...plugin-br-pix-jd-v0.6.1)

---

## [0.6.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.6.0)

Features:
- Adopt the `lerian-common` health preset to enhance the plugin's health management. (@fredcamaral)

Fixes:
- Refuse retired PDB and rollout overrides to ensure compatibility with the new health preset. (@fredcamaral)
- Pass the ALB health check and allow the preset to manage the PDB, improving the plugin's stability and reliability. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.9...plugin-br-pix-jd-v0.6.0)

---

## [0.5.9](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.9)

Fixes:
- Stop rendering `IS_DEVELOPMENT` in the plugin. (@fredcamaral)

Improvements:
- Add Helm upgrade guide for `plugin-br-pix-jd` `v0.5.6`. (@victorlazari)
- Add Helm upgrade guide for `plugin-br-pix-jd` `v0.5.7`. (@victorlazari)
- Add Helm upgrade guide for `plugin-br-pix-jd` `v0.5.8`. (@victorlazari)
- Fix `v0.5.7` upgrade guide worker image and license behavior. (@gandalf-at-lerian)
- Fix `v0.5.8` upgrade guide migration hook behavior. (@gandalf-at-lerian)
- Fix `v0.5.6` upgrade guide pod roll note. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.8...plugin-br-pix-jd-v0.5.9)

---

## [0.5.8](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.8)

Fixes:

- Update `plugin-br-pix-jd` to `1.5.0`. (@fredcamaral, @lerian-studio)
- Merge main branch changes into the `1.5.0` version bump. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.7...plugin-br-pix-jd-v0.5.8)

---

## [0.5.7](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.7)

Features:

Fixes:
- Made the chart boot the app it deploys. (@fredcamaral)
- Kept systemplane off by default on bundled Postgres. (@fredcamaral)
- Modeled `MIDAZ_URL_TRACER` and `APPLICATION_NAME`. (@fredcamaral)
- Stopped emitting environment variables that the app no longer reads. (@fredcamaral)
- Resolved migration and worker-wait Postgres like the app. (@fredcamaral)
- Enabled systemplane by default. (@fredcamaral)
- Provided the worker with the QR code environment required for production. (@fredcamaral)
- Defaulted the streaming source to the app name. (@fredcamaral)
- Required the license on API and worker in every mode. (@fredcamaral)
- Ran the worker from its published worker image. (@fredcamaral)

Improvements:
- Dropped stale worker tag and migration prose from documentation. (@fredcamaral)
- Documented pinning the worker tag with the API tag. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.6...plugin-br-pix-jd-v0.5.7)

---

## [0.5.6](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.6)

Features:
- Added a Helm upgrade guide for `plugin-br-pix-jd` `v0.5.5`. (@guimoreirar)

Fixes:
- Closed the truncated helper snippets in the `UPGRADE-0.5.3` documentation for `plugin-br-pix-jd`. (@guimoreirar, @bedatty)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.5...plugin-br-pix-jd-v0.5.6)

---

## [0.5.5](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.5)

Fixes:
- Update `plugin-br-pix-jd` to `@1.3.0`. (@bedatty, @lerian-studio)
- Pin the `1.3.0` migrations image. (@HMiguelAnjos)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.4...plugin-br-pix-jd-v0.5.5)

---

## [0.5.4](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.4)

Fixes:

- Update app version to `1.2.4`. (@jeffersonrodrigues92)
- Update app version to `1.2.3`. (@jeffersonrodrigues92)

Improvements:

- Add Helm upgrade guide for `v0.5.3`. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.3...plugin-br-pix-jd-v0.5.4)

---

## [0.5.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.3)

Features:
- Added a Helm upgrade guide for `v0.5.0`. (@guimoreirar)
- Added a Helm upgrade guide for `v0.5.2`. (@guimoreirar)

Fixes:
- Updated the app version to `1.2.1`. (@jeffersonrodrigues92)

Improvements:
- Scoped the production `ALLOW_*` note and mapped the removed multi-tenant key. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.2...plugin-br-pix-jd-v0.5.3)

---

## [0.5.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.2)

Features:
- Bump app to `1.2.0` and model the permission declaration. (@jeffersonrodrigues92)
- Bump app to `1.1.2` to include QR listing date window. (@jeffersonrodrigues92)

Fixes:
- Skip blank declaration overrides and unrendered secret to improve functionality. (@jeffersonrodrigues92)
- Accept the declaration from every source operators use, ensuring broader compatibility. (@jeffersonrodrigues92)
- Check the effective declaration auth and secret for enhanced security. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.1...plugin-br-pix-jd-v0.5.2)

---

## [0.5.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.1)

Improvements:

- Updated the README to focus on what a client can open and set, ensuring clarity and usability. (@jeffersonrodrigues92)
- Made the README the single source for installing and configuring the chart, consolidating all necessary information in one place. (@jeffersonrodrigues92)
- Titled the upgrade note with its version, specifically naming it after the published `0.5.0`, to maintain consistency and clarity in documentation. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.5.0...plugin-br-pix-jd-v0.5.1)

---

## [0.5.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.5.0)

Features:
- Introduced payment order signing values for single-tenant setups. (@jeffersonrodrigues92)

Fixes:
- Made payment-order signing values optional. (@jeffersonrodrigues92)
- Clarified the naming of each signing value in the render refusal process. (@jeffersonrodrigues92)
- Updated the app to `1.1.1`, focusing on JD payment-order signing. (@jeffersonrodrigues92)

Improvements:
- Fixed the workflow comment list and reflowed the upgrade note in the documentation. (@jeffersonrodrigues92)
- Differentiated between `JDPISPI017` and `PIX-0136` in the `0.4.9` checks within the documentation. (@jeffersonrodrigues92)
- Clarified what JDPI Cabine receives in the `0.4.9` upgrade documentation. (@jeffersonrodrigues92)
- Documented payment signing specifically for the operator's installation. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.8...plugin-br-pix-jd-v0.5.0)

---

## [0.4.8](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.8)

Fixes:
- Bump app to `1.1.0` for plugin-br-pix-jd. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.7...plugin-br-pix-jd-v0.4.8)

---

## [0.4.7](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.7)

Fixes:

- Bumped the app to the hotfix version `1.0.1`. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.6...plugin-br-pix-jd-v0.4.7)

---

## [0.4.6](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.6)

Fixes:

- Bumped the app to `1.0.0` following the release-train reset. (@jeffersonrodrigues92)
- Built against the published `lerian-common` `2.1.2`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.5...plugin-br-pix-jd-v0.4.6)

---

## [0.4.5](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.5)

Features:
- Align migration guidance with job behavior to ensure consistency in documentation. (@gandalf-at-lerian)

Fixes:
- Bump the app to version `2.0.1` and pin published migrations to maintain stability and compatibility. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.4...plugin-br-pix-jd-v0.4.5)

---

## [0.4.4](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.4)

- **Fixes**
  - Adjusted the QR payload path default and budget gate to comply with JDPI's 77-character limit.

- **Improvements**
  - Added an upgrade guide for version 0.4.3 to assist users in transitioning smoothly.

Contributors: @guimoreirar, @jeffersonrodrigues92, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.3...plugin-br-pix-jd-v0.4.4)

---

## [0.4.3](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.3)

- **Features:**
  - Released version 0.4.3 of plugin-br-pix-jd.

- **Improvements:**
  - Added upgrade guide for plugin-br-pix-jd v0.4.2.
  - Added upgrade guide for plugin-br-pix-jd v0.4.1.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.2...plugin-br-pix-jd-v0.4.3)

---

## [0.4.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.2)

- Fixes:
  - Removed the JD_ISPB render guard as the app now handles its own boot process.

Contributors: @jeffersonrodrigues92, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.1...plugin-br-pix-jd-v0.4.2)

---

## [0.4.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.1)

- **Fixes**
  - Emit the ISPB environment variable consumed by the app.

Contributors: @gandalf-at-lerian, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.4.0...plugin-br-pix-jd-v0.4.1)

---

## [0.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.4.0)

- **Features:**
  - Added support for Valkey embedded, similar to existing Postgres support.

- **Fixes:**
  - Aligned the embedded Postgres with the boilerplate, similar to Valkey.

Contributors: @ferr3ira-gabriel, @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.3.0...plugin-br-pix-jd-v0.4.0)

---

## [0.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.3.0)

- **Features:**
  - Released version 0.3.0 of the plugin-br-pix-jd.
  - Added upgrade guide for version 0.2.0.
  - Added upgrade guide for version 0.1.0.

- **Fixes:**
  - Consumed a dedicated image for migrations to enhance stability.

- **Improvements:**
  - Automated the process to avoid manual bumping of chart versions.

Contributors: @ferr3ira-gabriel, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-jd-v0.2.0...plugin-br-pix-jd-v0.3.0)

---

## [0.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-jd-v0.2.0)

- Features:
  - Initial release of plugin-br-pix-jd version 0.1.0.

- Contributors:
  - @lerian-studio

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

