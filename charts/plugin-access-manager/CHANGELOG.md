# Plugin-access-manager Changelog

## [11.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.2.2)

Fixes:
- Update `plugin-auth` to `3.19.0` and `plugin-identity` to `3.19.0`. (@bedatty, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v11.2.1...plugin-access-manager-v11.2.2)

---

## [11.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.2.1)

Features:
- Generate the caradhras application secret per install. (@fredcamaral)

Fixes:
- Refuse a generated app secret on a non-semver `caradhras` tag. (@fredcamaral)
- Name the kept secret in the offline refusal. (@fredcamaral)
- Refuse to generate the app client secret when the render cannot read the cluster. (@fredcamaral)
- Fail an upgrade that would generate the app-lerian client secret. (@fredcamaral)
- Require the app client secret for GitOps renders and drop dead helper branch. (@fredcamaral)
- Feed the identity client secret from the provided value only. (@fredcamaral)
- Keep the app client secret in the identity secret for the console-admin-reconciler. (@fredcamaral)
- Read the app client secret from one source and hash its input. (@fredcamaral)
- Roll pods and document the app client secret. (@fredcamaral)

Improvements:
- Keep the `10.5` guide on its own chart version. (@fredcamaral)
- State that identity always authenticates as app-lerian and shorten the secret comment. (@fredcamaral)
- Require the app client secret for renderers without cluster access. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v11.2.0...plugin-access-manager-v11.2.1)

---

## [11.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.2.0)

Features:
- Add license file mount to auth and identity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v11.1.2...plugin-access-manager-v11.2.0)

---

## [11.1.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.1.2)

Fixes:
- Stop shipping an unused seed that carries a client secret. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v11.1.1...plugin-access-manager-v11.1.2)

---

## [11.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.1.1)

Fixes:
- Quote the Caradhras database password in its DSN to ensure proper handling of special characters. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v11.1.0...plugin-access-manager-v11.1.1)

---

## [11.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.1.0)

Features:
- Add license file mount and key to migrate. (@fredcamaral)

Fixes:
- Project only the license key in the license file volume. (@fredcamaral)

Improvements:
- Name each private registry and the checksums that change. (@fredcamaral)
- Add verified `11.0` and `11.0.1` upgrade guides. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v11.0.1...plugin-access-manager-v11.1.0)

---

## [11.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.0.1)

Fixes:

- Strip the digest in the admin password gate to ensure proper functionality. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v11.0.0...plugin-access-manager-v11.0.1)

---

## [11.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v11.0.0)

Features:
- Move Caradhras to `2.1.0` with its own key, requiring a Caradhras license key. (@fredcamaral)

Fixes:
- Refuse a Caradhras server and migrations major mismatch. (@fredcamaral)
- Default the migrations tag to the server tag. (@fredcamaral)
- Anchor the Caradhras license gate on plain semver. (@fredcamaral)
- Default the Caradhras image to `2.1.0`. (@fredcamaral)
- Keep chart version off pod template labels. (@fredcamaral)

Improvements:
- Apply review fixes to chart docs and upgrade guides. (@bedatty, @gandalf-at-lerian)
- Make managed-cloud README example render and boot. (@gandalf-at-lerian)
- Clarify Caradhras ingress class and TLS secret comments. (@gandalf-at-lerian)
- Publish Caradhras ingress in managed-cloud README example. (@gandalf-at-lerian)
- Note Caradhras `2.x` tags and `LICENSE_KEY` in `10.3` guide. (@gandalf-at-lerian)
- Add the verified `10.5.1` upgrade guide. (@fredcamaral)
- Remove repeated release sections from the changelogs. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.5.1...plugin-access-manager-v11.0.0)

---

## [10.5.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.5.1)

Fixes:
- Ensure global ingress settings are inherited and require license keys for proper functionality. (@fredcamaral)

Improvements:
- Add verified upgrade guides for transitioning from `10.1.4` to `10.5.0`. (@fredcamaral)
- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.5.0...plugin-access-manager-v10.5.1)

---

## [10.5.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.5.0)

Features:
- Require the single-use first-admin contract to enhance security. (@fredcamaral)
- Create the first console admin from identity at boot, streamlining the setup process. (@fredcamaral)
- Document the effects of removing init-user on `argocd` and `helmfile`. (@fredcamaral)

Fixes:
- Repair admin secret wiring to ensure proper functionality. (@fredcamaral)
- Update `plugin-auth@3.16.0` and `plugin-identity@3.16.0` to maintain compatibility. (@lerian-studio)
- Preserve health preset to ensure consistent system status checks. (@fredcamaral)
- Cover the HTTP client timeout in the identity startup window to prevent early timeouts. (@fredcamaral)
- Provide identity a startup window that outlasts the init-user retry, ensuring smoother initialization. (@fredcamaral)

Improvements:
- Merge the main branch into the bootstrap branch to keep the codebase up-to-date. (@fredcamaral)
- Document the process of retiring the bootstrap credential, aiding in future deprecations. (@fredcamaral)
- Clarify bootstrap upgrades to assist users in understanding the upgrade process. (@fredcamaral)
- Keep the auth secret text unchanged during refactoring for consistency. (@fredcamaral)
- Remove the auth init-user job as part of a refactor to simplify the authentication process. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.4.1...plugin-access-manager-v10.5.0)

---

## [10.4.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.4.1)

Fixes:
- Use stable images to enhance reliability and performance. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.4.0...plugin-access-manager-v10.4.1)

---

## [10.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.4.0)

Features:
- Adopt the `lerian-common` health preset. (@fredcamaral)

Fixes:
- Refuse retired PDB and rollout overrides. (@fredcamaral)

Improvements:
- Drop the `minImage` placeholder note from documentation. (@fredcamaral)
- Mark the health `minImage` as a placeholder in documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.3.0...plugin-access-manager-v10.4.0)

---

## [10.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.3.0)

Features:
- Add opt-in for Caradhras built-in admin password from a secret. (@fredcamaral)

Fixes:
- Raise the admin password floor to Caradhras `1.9.0-beta.25`. (@fredcamaral)
- Require Caradhras `>= 1.9.0` for the built-in admin password opt-in. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.2.3...plugin-access-manager-v10.3.0)

---

## [10.2.3](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.2.3)

Fixes:
- Set the Caradhras shutdown drain delay to 5 seconds. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.2.2...plugin-access-manager-v10.2.3)

---

## [10.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.2.2)

Fixes:

- Ensure the caradhras license is retrieved solely from an existing secret. (@fredcamaral)
- Provide names for both endpoint modes in the error message when a secret is missing. (@fredcamaral)

Improvements:

- Verify that the caradhras configmap retains the session endpoint. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.2.1...plugin-access-manager-v10.2.2)

---

## [10.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.2.1)

Fixes:
- Widened probe timeouts and ensured Caradhras is drained before stopping the service. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.2.0...plugin-access-manager-v10.2.1)

---

## [10.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.2.0)

Features:  
- Pass the Caradhras license key from a secret. (@fredcamaral)

Fixes:  
- Make the Caradhras license key secret reference optional. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.1.4...plugin-access-manager-v10.2.0)

---

## [10.1.4](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.1.4)

Features:
- Add Helm upgrade guide for `v10.0.2`. (@victorlazari)
- Add Helm upgrade guide for `v10.0.3`. (@victorlazari)
- Add Helm upgrade guide for `v10.1.0`. (@victorlazari)
- Add Helm upgrade guide for `v10.1.1`. (@victorlazari)
- Add Helm upgrade guide for `v10.1.2`. (@victorlazari)
- Add Helm upgrade guide for `v10.1.3`. (@victorlazari)

Fixes:
- Correct the scope and pod roll note in the `v10.1.3` upgrade guide. (@gandalf-at-lerian)
- Fix pod roll scope in the `v10.0.2` upgrade guide. (@gandalf-at-lerian)
- Fix pod roll scope in the `v10.0.3` upgrade guide. (@gandalf-at-lerian)
- Fix pod roll scope in the `v10.1.1` upgrade guide. (@gandalf-at-lerian)
- Correct rendered diff claim in the `v10.1.0` upgrade guide. (@gandalf-at-lerian)
- Fix image names and service credentials in the `v10.1.2` upgrade guide. (@gandalf-at-lerian)
- Correct init-user text and add app notes in the `v10.0.3` upgrade guide. (@gandalf-at-lerian)
- Fix upgrade guide for the `v10.1.1` caradhras `1.5.1` to `1.8.5` jump. (@gandalf-at-lerian)
- Fix upgrade guide for `v10.1.0` regarding `skipRBACChain` and `extraEnvVars`. (@gandalf-at-lerian)
- Correct timeout wording and pod restart note in the `v10.0.2` upgrade guide. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.1.3...plugin-access-manager-v10.1.4)

---

## [10.1.3](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.1.3)

Improvements:
- Keep the Caradhras ingress internal. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.1.2...plugin-access-manager-v10.1.3)

---

## [10.1.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.1.2)

Fixes:

- Updated `plugin-access-manager` to version `3.14.0` to ensure compatibility with `caradhras` version `1.8.6`. (@fredcamaral)
- Bumped `caradhras` dependency to version `1.8.6` for `plugin-access-manager`. (@fredcamaral)
- Set the application version to `3.14.0` for `plugin-access-manager`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.1.1...plugin-access-manager-v10.1.2)

---

## [10.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.1.1)

Fixes:
- Bumped Caradhras to `1.8.5` to address compatibility issues. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.1.0...plugin-access-manager-v10.1.1)

---

## [10.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.1.0)

Features:
- Allow the Caradhras migrate init container to skip the RBAC chain. (@qnen)

Fixes:
- Pass `MIGRATIONS_SKIP_RBAC_CHAIN` to the Caradhras container to ensure proper functionality. (@qnen)
- Validate migrate extra environment variable names in the schema to prevent errors. (@qnen)
- Quote migrate init container extra environment variable names to maintain consistency and avoid parsing issues. (@qnen)

Improvements:
- Match the environment name schema error across different Helm versions to ensure compatibility. (@qnen)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.0.3...plugin-access-manager-v10.1.0)

---

## [10.0.3](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.0.3)

Fixes:
- Update to app version `3.13.1`. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.0.2...plugin-access-manager-v10.0.3)

---

## [10.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.0.2)

Fixes:
- Capped Caradhras database connections at 5 seconds to enhance performance. (@fredcamaral)

Improvements:
- Added a Helm upgrade guide for `plugin-access-manager` `v10.0.1`. (@guimoreirar)
- Added a Helm upgrade guide for `plugin-access-manager` `v10.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.0.1...plugin-access-manager-v10.0.2)

---

## [10.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.0.1)

Fixes:
- Resolved issues with the GitHub Pages build by switching from Helm templates to Liquid templates to ensure compatibility. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v10.0.0...plugin-access-manager-v10.0.1)

---

## [10.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v10.0.0)

Features:

- Add Helm upgrade guide for `plugin-access-manager` `v9.8.2`. (@guimoreirar)

Fixes:

- Render boolean false on default-true flags to ensure correct behavior. (@fredcamaral)
- Cover an empty string on default-true flags to improve test coverage. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.8.2...plugin-access-manager-v10.0.0)

---

## [9.8.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.8.2)

Features:
- Add Helm upgrade guide for `plugin-access-manager` `v9.8.1`. (@guimoreirar)

Fixes:
- Correct the spelling of "plugin access manager" in documentation. (@fredcamaral)

Improvements:
- Remove claims of source-available and open-source from documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.8.1...plugin-access-manager-v9.8.2)

---

## [9.8.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.8.1)

Features:
- Add Helm upgrade guide for `plugin-access-manager` `v9.8.0`. (@guimoreirar)

Fixes:
- Derive OTEL environment from `ENV_NAME`. (@guimoreirar, @gandalf-at-lerian)

Improvements:
- Merge main into the OTEL environment branch for `plugin-access-manager`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.8.0...plugin-access-manager-v9.8.1)

---

## [9.8.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.8.0)

Features:

- Treat an explicit false as set in the Google Directory duplicate check. (@rodrigodh)
- Check the Google Directory key length and value types. (@rodrigodh)
- Pass Google Workspace Directory settings to identity. (@rodrigodh)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.7.2...plugin-access-manager-v9.8.0)

---

## [9.7.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.7.2)

Fixes:
- Require an existing secret name and align the README with the chart to ensure consistency. (@guimoreirar, @gandalf-at-lerian)

Improvements:
- Add a Helm upgrade guide for `plugin-access-manager` `v9.7.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.7.1...plugin-access-manager-v9.7.2)

---

## [9.7.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.7.1)

Fixes:
- Update app version to `3.11.1`. (@jeffersonrodrigues92)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.7.0...plugin-access-manager-v9.7.1)

---

## [9.7.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.7.0)

Features:
- Bump to app `3.11.0` and caradhras `1.5.1`. (@fredcamaral)

Improvements:
- Point the `9.7` upgrade guide at the `v3.11.0` tag. (@fredcamaral)

Fixes:
- Add Helm upgrade guide for `plugin-access-manager` `v9.6.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.6.0...plugin-access-manager-v9.7.0)

---

## [9.6.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.6.0)

Features:
- Expose `spread minDomains` and `nodeTaintsPolicy` settings for enhanced configuration flexibility. This change is part of the `lerian-common` `2.3.0` update. (@guimoreirar)
- Implement spreading of auth, identity, and caradhras pods across nodes and zones to improve resource distribution and fault tolerance. (@guimoreirar)

Fixes:
- Disable zone spreading by default to prevent unintended distribution of resources across zones. (@guimoreirar)

Improvements:
- Add a Helm upgrade guide for `plugin-access-manager` `v9.5.10` to assist users in updating their deployments smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.10...plugin-access-manager-v9.6.0)

---

## [9.5.10](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.10)

Fixes:
- Bumped Caradhras to `1.4.0`. (@jeffersonrodrigues92)

Improvements:
- Added a Helm upgrade guide for `plugin-access-manager` `v9.5.9`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.9...plugin-access-manager-v9.5.10)

---

## [9.5.9](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.9)

Features:

- Add Helm upgrade guide for `plugin-access-manager` `v9.5.3`. (@guimoreirar)
- Add Helm upgrade guide for `plugin-access-manager` `v9.5.5`. (@guimoreirar)
- Add Helm upgrade guide for `plugin-access-manager` `v9.5.8`. (@guimoreirar)

Fixes:

- Validate the `3.9.0` startup contract to ensure proper functionality. (@guimoreirar)
- Validate the remaining aspects of the `3.9.0` startup contract. (@guimoreirar)
- Require HTTPS for JWKS to enhance security. (@dy-shimizu)

Improvements:

- Provide an upgrade guide for `9.5.8` focusing on startup checks. (@guimoreirar)
- Clarify the SD skip process in the documentation. (@dy-shimizu)
- Note the use of HTTPS for Caradhras in the documentation. (@dy-shimizu)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.8...plugin-access-manager-v9.5.9)

---

## [9.5.8](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.8)

Features:
- Document the optional configmap keys added for `3.9.0`. (@guimoreirar)

Fixes:
- Bump app images to `3.9.0` and expose new environment variables. (@guimoreirar)

Improvements:
- Add Helm upgrade guide for `plugin-access-manager` `v9.5.2`. (@guimoreirar)
- Add Helm upgrade guide for `plugin-access-manager` `v9.5.4`. (@guimoreirar)
- Add Helm upgrade guide for `plugin-access-manager` `v9.5.6`. (@guimoreirar)
- Add Helm upgrade guide for `plugin-access-manager` `v9.5.7`. (@guimoreirar)
- Correct upgrade guide for `v9.5.2`. (@guimoreirar)
- Correct upgrade guide for `v9.5.4`. (@guimoreirar)
- Correct upgrade guide for `v9.5.7`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.7...plugin-access-manager-v9.5.8)

---

## [9.5.7](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.7)

- Fixes:
  - Pin the bundled database majors to ensure compatibility (#2324).

- Improvements:
  - Removed the date from the pin comments for better clarity.

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.6...plugin-access-manager-v9.5.7)

---

## [9.5.6](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.6)

- Fixes:
  - Restart pods when their configmap changes to ensure configuration updates are applied correctly.

Contributors: @fredcamaral, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.5...plugin-access-manager-v9.5.6)

---

## [9.5.5](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.5)

- **Fixes:**
  - Let the init job finish under a mesh sidecar to ensure proper initialization.
  - Restart pods when their secret changes to maintain security and functionality.

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.4...plugin-access-manager-v9.5.5)

---

## [9.5.4](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.4)

- **Fixes:**
  - Ensure continuous service by keeping Caradhras operational while a new pod migrates.
  - Maintain service availability by keeping an old pod serving during rollouts.
  - Allow `helm install --wait` to complete successfully.

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.3...plugin-access-manager-v9.5.4)

---

## [9.5.3](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.3)

- Fixes:
  - Pass pod security restricted (#2243)
  - Drop a comment as the pod block already states the necessary information

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.2...plugin-access-manager-v9.5.3)

---

## [9.5.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.2)

- **Fixes**
  - Resolved an issue where the database password was not retained on uninstall.
  - Prevented the use of an empty `auth-database existingSecret`.

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.1...plugin-access-manager-v9.5.2)

---

## [9.5.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.1)

- **Fixes:**
  - Deliver Caradhras 1.3.2 RBAC migrations.
  - Bump Caradhras images to 1.3.2.

- **Improvements:**
  - Added Helm upgrade guides for versions v9.3.0, v9.4.0, and v9.5.0.

Contributors: @gandalf-at-lerian, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.5.0...plugin-access-manager-v9.5.1)

---

## [9.5.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.5.0)

- **Features:**
  - Guard the console SSO callback path to enhance security.
  - Compose the SSO callback URL from a client base for better flexibility.
  - Add named MFA and SSO callback chart keys for improved configuration options.

Contributors: @jeffersonrodrigues92, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.4.0...plugin-access-manager-v9.5.0)

---

## [9.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.3.0)

- **Features:**
  - Added named Caradhras session store keys.

- **Fixes:**
  - Delivered Caradhras session password by Secret.

Contributors: @jeffersonrodrigues92, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.2.4...plugin-access-manager-v9.3.0)

---

## [9.2.4](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.2.4)

- **Improvements**
  - Scoped the silent-failure claim to existing-tag mis-pins.
  - Reflected render-time guard in casdoor-migrations warnings.
  - Added warnings about casdoor-migrations override and guard.

- **Documentation**
  - Added an upgrade guide for plugin-access-manager v9.2.3.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.2.3...plugin-access-manager-v9.2.4)

---

## [9.2.3](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.2.3)

- **Fixes:**
  - Lowered `HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST` default to 10.

- **Contributors:**
  - @guimoreirar
  - @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.2.2...plugin-access-manager-v9.2.3)

---

## [9.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.2.2)

- **Fixes**
  - Pin `caradhras-user-init` default to version 3.3.1 for improved stability.

- **Improvements**
  - Added upgrade guide for transitioning from version 8.6 to 9.2.1.
  - Included a walkthrough for preparing `values.yaml` in the context of Caradhras.
  - Compressed and streamlined the upgrade guide from version 8.6 to 9.2.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.2.1...plugin-access-manager-v9.2.2)

---

## [9.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.2.1)

- **Fixes:**
  - Use curl-based wait init for HTTPS authorizer.

Contributors: @fredcamaral, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.2.0...plugin-access-manager-v9.2.1)

---

## [9.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.2.0)

- **Features:**
  - Explicitly specify `caradhras.image` and collapse `initUser` default.
  - Bump `caradhras` image defaults to stable version 1.2.0.
  - Add `caradhras.ingress` as the main component.
  - Promote `auth.backend` to a top-level `caradhras` component.

- **Fixes:**
  - Ensure `caradhras-ui` backend address uses FQDN instead of a short name.
  - Resolve port, environment, and probe mismatches in `caradhras-ui`.
  - Fix `EACCES` error on `nginx conf.d` by setting `runAsGroup` for `caradhras-ui`.
  - Correct `caradhras` readiness probe default path.
  - Wire `ALLOW_INSECURE_TLS` into `caradhras`.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.1.0...plugin-access-manager-v9.2.0)

---

## [9.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.1.0)

- **Features:**
  - Introduced cloud masking capabilities for plugin-access-manager.
  - Added datastore masks and telemetry features.
  - Integrated service discovery through the lerian-common mask.
  
- **Fixes:**
  - Derived `AUTHORIZER_PORT/ADDRESS` from the backend port and fixed invalid YAML comments.
  - Restored backward compatibility for `SD_*` and improved ingress global mask handling.
  - Bound Job names and `ADMIN_PASSWORD` secret references to 63 characters to prevent overflow.
  - Routed `ENV_NAME/MULTI_TENANT_ENABLED` through the global mask for consistency.

- **Improvements:**
  - Pinned `lerian-common-helm` to stable version 2.0.0.
  - Documented external DB/Redis credentials in the managed-cloud example.
  - Enhanced documentation with examples and guidance for global masks and observability.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v9.0.0...plugin-access-manager-v9.1.0)

---

## [9.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v9.0.0)

- **Features**
  - Reconcile the initial-admin password contract.

- **Fixes**
  - Require an explicit initUser admin password.
  - Derive component names from the release.
  - Render the real authorizer client id.

- **Improvements**
  - Add upgrade guide for plugin-access-manager v8.6.0.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.6.0...plugin-access-manager-v9.0.0)

---

## [8.6.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.6.0)

- Features:
  - Fail the render on `PLATFORM_INTERNAL_CIDRS` skew.
  - Expose `PLATFORM_INTERNAL_CIDRS` on auth.

Contributors: @jeffersonrodrigues92, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.5.0...plugin-access-manager-v8.6.0)

---

## [8.5.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.5.0)

- **Features**
  - Expose `PLATFORM_INTERNAL_CIDRS` on identity.

- **Documentation**
  - Added upgrade guide for plugin-access-manager v8.4.0.

Contributors: @jeffersonrodrigues92, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.4.0...plugin-access-manager-v8.5.0)

---

## [8.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.4.0)

- **Features**
  - Bumped app version to 3.1.0 and synchronized environment variables.

- **Fixes**
  - Guarded replicas when autoscaling is enabled to prevent potential issues.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.3.0...plugin-access-manager-v8.4.0)

---

## [8.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.3.0)

- **Features:**
  - Added optional configurable `startupProbe` for identity and auth components in the plugin-access-manager.

- **Contributors:**
  - @gandalf-at-lerian
  - @guimoreirar
  - @lerian-studio
  - @qnen

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.2.0...plugin-access-manager-v8.3.0)

---

## [8.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.2.0)

- **Features**
  - Added ALLOW_INSECURE_TLS configuration to multiple charts and updated image tags.
  - Implemented per-chart values.schema.json generator for CI.

- **Fixes**
  - Adjusted security context for Casdoor container and updated logConfig path.
  - Updated logConfig path and added volume for log storage.
  - Addressed CodeRabbit review on revamp PR #1470.

- **Improvements**
  - Pinned Bitnami dependency versions.
  - Standardized charts to Lerian chart contract.
  - Removed redundant dependency helpers and updated CI.
  - Aligned documentation with chart standard revamp.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.1.0...plugin-access-manager-v8.2.0)

---

## [8.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.1.0)

- **Features:**
  - Released version 8.1.0.
  - Released version 8.1.0-beta.1.

- **Fixes:**
  - Handled HTTPS URLs in wait-for-dependencies initContainer.

- **Improvements:**
  - Added upgrade guide for version 8.0.1.
  - Added upgrade guide for version 8.0.0.

Contributors: @fredcamaral, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.0.1...plugin-access-manager-v8.1.0)

---

## [8.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.0.1)

- Fixes:
  - Wired resources block into auth-backend deployment to ensure proper authentication flow. (#1430)

Contributors: @lerian-studio, @prymax10

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v8.0.0...plugin-access-manager-v8.0.1)

---

## [8.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v8.0.0)

- **Features:**
  - Released version 8.0.0 of plugin-access-manager.

- **Fixes:**
  - Updated image tag to 2.6.7 for plugin-access-manager.
  - Updated plugin-auth to version 2.6.7.

- **Documentation:**
  - Added upgrade guide for plugin-access-manager v7.0.0.

Contributors: @guimoreirar, @lerian-studio,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v7.0.0...plugin-access-manager-v8.0.0)

---

## [7.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v7.0.0)

- **Features:**
  - Released version 7.0.0 of plugin-access-manager.
  - Updated appVersion and image tags to 2.6.6 and 2.4.5 respectively.

- **Improvements:**
  - Added an upgrade guide for plugin-access-manager v6.5.0.

- **Contributors:**
  - @guimoreirar
  - @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.5.0...plugin-access-manager-v7.0.0)

---

## [6.5.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.5.0)

- **Features**
  - Parametrized probe path and timing for charts using `/readyz`.

- **Fixes**
  - Updated appVersion to 2.6.5.
  - Updated image tags for identity and auth components to latest versions.

- **Improvements**
  - Standardized probe field set across all charts.

Contributors: @ferr3ira-gabriel, @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.4.1...plugin-access-manager-v6.5.0)

---

## [6.4.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.4.1)

- Fixes:
  - Update appVersion and image tags to 2.6.3 for improved compatibility and performance.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.4.0...plugin-access-manager-v6.4.1)

---

## [6.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.4.0)

- Fixes:
  - Updated appVersion and image tags to 2.6.2.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.3.0...plugin-access-manager-v6.4.0)

---

## [6.3.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.3.0)

- **Features:**
  - Released version 6.3.0.
  - Released version 6.3.0-beta.1.
  - Released version 6.2.0.

Contributors: @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.2.0...plugin-access-manager-v6.3.0)

---

## [6.2.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.2.0)

- **Features**
  - Released version 6.2.0 with new updates and improvements.

- **Fixes**
  - Updated plugin-auth to version 2.6.1 to resolve compatibility issues.

- **Improvements**
  - Updated image tag to 2.6.1 in values.yaml for better integration and performance.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.1.1...plugin-access-manager-v6.2.0)

---

## [6.1.1](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.1.1)

- **Fixes:**
  - Updated dependency to `plugin-identity@2.4.2` to address compatibility issues.

Contributors: @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.1.0...plugin-access-manager-v6.1.1)

---

## [6.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.1.0)

- **Features:**
  - Added new configuration options for logging, rate limiting, and MFA in `configmap.yaml`.
  - Introduced CORS, rate limiting, multi-tenancy, and circuit breaker configurations.

- **Fixes:**
  - Removed `imagePullSecrets` from `values.yaml` for identity and auth sections.
  - Updated image tags to ensure compatibility with the latest configurations.

- **Improvements:**
  - Updated to `plugin-auth@2.6.0`.

Contributors: @gandalf, @gui.rodrigues, @guimoreirar,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v6.0.0...plugin-access-manager-v6.1.0)

---

## [6.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v6.0.0)

- Fixes:
  - Add kindIs guard for backward compatibility with string image values.
  - Split migrations and initUser image into repository/tag fields.

Contributors: @gandalf,

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v5.4.0...plugin-access-manager-v6.0.0)

---

## [5.4.0](https://github.com/LerianStudio/helm/releases/tag/plugin-access-manager-v5.4.0)

- Improvements:
  - Updated initDataFile setup for auth backend to enhance configuration process.

Contributors: @gui.rodrigues, @guimoreirar

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v5.3.0...plugin-access-manager-v5.4.0)

---

## [plugin-access-manager-2.3.0-beta.2] - 2025-07-21

This release brings enhanced integration capabilities and improved security management, along with several bug fixes and maintenance updates to ensure a smoother user experience.

### ✨ Features  
- **User Consumer Configuration for RabbitMQ**: Now you can configure RabbitMQ more flexibly, allowing for tailored message handling setups that enhance integration with other systems. This feature improves your ability to manage messaging workflows effectively.
- **Support for External Secrets**: Securely manage and deploy secrets across different environments with the new support for external secrets. This enhancement ensures that sensitive information is handled more securely and is easier to manage.

### 🐛 Bug Fixes
- **Transaction Deployment Template**: Fixed an issue that could cause incorrect deployment configurations, reducing potential errors and ensuring smoother deployments.
- **RabbitMQ Job Defaults**: Resolved a problem where default definitions were not being applied, ensuring consistent and reliable execution of RabbitMQ jobs.
- **Plugin-Access-Manager and Midaz Stability**: Rolled back versions to address stability issues, enhancing overall system reliability and preventing potential disruptions.

### 🔧 Maintenance
- **Release Version Updates**: Updated release versions to maintain consistency and ensure proper version tracking across components.
- **CI Pipeline Enhancements**: Fixed issues in the continuous integration pipeline, improving the reliability and efficiency of build processes.
- **Documentation Updates**: Enhanced the CHANGELOG for midaz-v2.6.0-beta.3, providing users with detailed insights into recent changes and improvements.

This release focuses on improving integration capabilities and security management while addressing critical bugs to enhance overall system stability and user experience.

## [plugin-access-manager-2.2.0-beta.3] - 2025-06-23

This release focuses on enhancing system reliability and ensuring up-to-date documentation, providing a more stable and user-friendly experience.

### 🐛 Bug Fixes
- **Authentication & Backend**: Fixed an issue where an uninitialized variable was causing erratic behavior during user authentication and backend operations. This improvement ensures smoother and more reliable login experiences, reducing unexpected errors and enhancing overall system stability.

### 📚 Documentation
- **Changelog Update**: The CHANGELOG for the plugin-access-manager has been updated to include the latest changes from version 2.2.0-beta.2. This update provides users with clear and accurate information about recent enhancements and fixes, improving transparency and understanding of the plugin's development.

### 🔧 Maintenance
- **Database Preparation**: The database component has been prepared for the upcoming version 2.2.0-beta.3 release. This maintenance task aligns the database with the latest standards, ensuring smoother future updates and easier maintenance.

These updates collectively enhance the reliability of the system and keep users informed with the latest documentation, contributing to a more seamless and transparent user experience.

## [plugin-access-manager-2.2.0-beta.2] - 2025-06-23

This release introduces a new values template file, enhancing the flexibility and efficiency of Helm chart deployments. Users can now streamline their configuration processes, making deployments more standardized and manageable.

### ✨ Features  
- **Values Template File**: A new values template file has been added, allowing users to define default values in a structured and reusable manner. This enhancement simplifies configuration management, reducing setup time and increasing deployment consistency across environments.

### 🔧 Maintenance
- **Release Update**: The project has been updated to version 2.2.0-beta.2, ensuring users have access to the latest features and improvements. This update supports ongoing development and enhances stability for future releases.

This changelog highlights the key feature introduced in this release, focusing on its benefits for users. The maintenance section notes the version update, underscoring the project's commitment to continuous improvement.

##  (2025-06-04)


### Bug Fixes

* **console:** bump image tag to 2.2.1 ([9dfde6e](https://github.com/LerianStudio/helm/commit/9dfde6ee7deb61ef67376dd84d3396845f88fe9f))
* **chart:** fix typo in environment variable name ([2f57d53](https://github.com/LerianStudio/helm/commit/2f57d53b1b47b8ef0829729a37d819949efd03c4))
* **console:** update mongodb default port ([fd58b09](https://github.com/LerianStudio/helm/commit/fd58b09788b9f7ccc03937ac5e950060110cedf3))

##  (2025-06-02)


### ⚠ BREAKING CHANGES

* **valkey:** Valkey no longer uses StatefulSet. Persistent volume claims from StatefulSet will not be reused automatically.

### Features

* **dependencies:** add job to apply default definitions to external rabbitmq host ([c91db90](https://github.com/LerianStudio/helm/commit/c91db90f8311960f818d7f0b0046bc9eda1a4e6b))
* **console:** add mongodb environments ([256757e](https://github.com/LerianStudio/helm/commit/256757eb38cff41510d114572f4d18d92569fd6f))
* **console:** add mongodb environments ([88db3ba](https://github.com/LerianStudio/helm/commit/88db3bad7e8f2ec4fe5056980cbb7e41cdd02c38))
* **console:** add mongodb environments ([7c86ca0](https://github.com/LerianStudio/helm/commit/7c86ca00a65680a99b642d976ac36578c39c31f9))
* **console:** add mongodb port ([73ec8e2](https://github.com/LerianStudio/helm/commit/73ec8e27a619c333a6f2cfe60fcc0c8d49fd8295))
* **valkey:** migrate from StatefulSet to Deployment ([3854dfe](https://github.com/LerianStudio/helm/commit/3854dfe3430eaf7f4d99e39d032103eca4ff10fd))
* **helm:** update app version ([fb2f841](https://github.com/LerianStudio/helm/commit/fb2f84162e5951495e2ab12296f6855edb09fce7))
* **values:** update auth version ([b549735](https://github.com/LerianStudio/helm/commit/b54973599235c3f52058e68dcd499c8c21c8dac7))
* **values:** update identity version ([f8ee875](https://github.com/LerianStudio/helm/commit/f8ee875bb51ac52300d683e366f976aa903077b2))
* **docs:** update rabbitmq documentation ([cae5467](https://github.com/LerianStudio/helm/commit/cae54677bcf8a2a26949ed341df9caea50cea762))
* **docs:** update readme file ([314da0e](https://github.com/LerianStudio/helm/commit/314da0e538e7534a79cbea9423d2d6b5c08c3a8e))

##  (2025-06-02)


### ⚠ BREAKING CHANGES

* **valkey:** Valkey no longer uses StatefulSet. Persistent volume claims from StatefulSet will not be reused automatically.

### Features

* **dependencies:** add job to apply default definitions to external rabbitmq host ([c91db90](https://github.com/LerianStudio/helm/commit/c91db90f8311960f818d7f0b0046bc9eda1a4e6b))
* **console:** add mongodb environments ([256757e](https://github.com/LerianStudio/helm/commit/256757eb38cff41510d114572f4d18d92569fd6f))
* **console:** add mongodb environments ([88db3ba](https://github.com/LerianStudio/helm/commit/88db3bad7e8f2ec4fe5056980cbb7e41cdd02c38))
* **console:** add mongodb environments ([7c86ca0](https://github.com/LerianStudio/helm/commit/7c86ca00a65680a99b642d976ac36578c39c31f9))
* **console:** add mongodb port ([73ec8e2](https://github.com/LerianStudio/helm/commit/73ec8e27a619c333a6f2cfe60fcc0c8d49fd8295))
* **valkey:** migrate from StatefulSet to Deployment ([3854dfe](https://github.com/LerianStudio/helm/commit/3854dfe3430eaf7f4d99e39d032103eca4ff10fd))
* **helm:** update app version ([fb2f841](https://github.com/LerianStudio/helm/commit/fb2f84162e5951495e2ab12296f6855edb09fce7))
* **values:** update auth version ([b549735](https://github.com/LerianStudio/helm/commit/b54973599235c3f52058e68dcd499c8c21c8dac7))
* **values:** update identity version ([f8ee875](https://github.com/LerianStudio/helm/commit/f8ee875bb51ac52300d683e366f976aa903077b2))
* **docs:** update rabbitmq documentation ([cae5467](https://github.com/LerianStudio/helm/commit/cae54677bcf8a2a26949ed341df9caea50cea762))
* **docs:** update readme file ([314da0e](https://github.com/LerianStudio/helm/commit/314da0e538e7534a79cbea9423d2d6b5c08c3a8e))

##  (2025-05-29)


### Features

* **dependencies:** create job to apply migrations in casdoor db ([5a74bcc](https://github.com/LerianStudio/helm/commit/5a74bcc6ca8691159c4a3d11826a5afb34909e49))


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))
* update casdoor backend images ([ea9e82b](https://github.com/LerianStudio/helm/commit/ea9e82bfce3259bf88fb13b0b39b0a2f6280c7a1))
* update casdoor backend images ([8c1741d](https://github.com/LerianStudio/helm/commit/8c1741dcd6e3c7df86ed6f5f59d07309792754ba))


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

##  (2025-05-29)


### Bug Fixes

* update casdoor backend images ([ea9e82b](https://github.com/LerianStudio/helm/commit/ea9e82bfce3259bf88fb13b0b39b0a2f6280c7a1))
* update casdoor backend images ([8c1741d](https://github.com/LerianStudio/helm/commit/8c1741dcd6e3c7df86ed6f5f59d07309792754ba))

##  (2025-05-20)


### Features

* **dependencies:** create job to apply migrations in casdoor db ([5a74bcc](https://github.com/LerianStudio/helm/commit/5a74bcc6ca8691159c4a3d11826a5afb34909e49))


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

##  (2025-05-07)


### Features

* **doc:** update charts documentation ([422e771](https://github.com/LerianStudio/helm/commit/422e7717a8f7c79d96f4cdd110421f0c68857d82))
* **doc:** update charts documentation ([b9618c4](https://github.com/LerianStudio/helm/commit/b9618c462cf3f0ad6b3f237347ffae01fc23cb09))

##  (2025-05-07)


### Features

* **ingress:** add ingress templates ([020369a](https://github.com/LerianStudio/helm/commit/020369a13b9696eb2e6e12c389ed211d2feb95f1))
* **ingress:** add ingress templates ([816fcee](https://github.com/LerianStudio/helm/commit/816fcee9d905744bcd47003fb16b974104c2d2d3))
* **pipe:** add release step for ghcr ([f0e4f3f](https://github.com/LerianStudio/helm/commit/f0e4f3f5221b392bb68b2a5f87aa85facc5cfbee))
* **helm:** create chart file to plugin crm ([69b01c8](https://github.com/LerianStudio/helm/commit/69b01c868752eb91973e2d292eb2e7ffaa57c1e0))
* **helm:** create chart file to plugin-fees ([38a0e81](https://github.com/LerianStudio/helm/commit/38a0e81c29d53bb81bb1895869b058942bc1d116))
* **helm:** create chart templates to plugin crm ([777ea2f](https://github.com/LerianStudio/helm/commit/777ea2fa1582d1530fbc4946c4ef184ae90598e9))
* **chart:** create chart templates to plugin-fees ([adabbaa](https://github.com/LerianStudio/helm/commit/adabbaaf405b471b111abe208408fce9c0772e99))
* **chart:** create chart templates to plugin-fees ([303caf0](https://github.com/LerianStudio/helm/commit/303caf06a48ff63e20fcdd13fd2c5d0629aae33c))
* **helm:** create doc to plugin crm ([4cbaa9d](https://github.com/LerianStudio/helm/commit/4cbaa9d4e8377260508c5687f292cfec8dbeee36))
* **helm:** create values file to plugin crm ([de6b154](https://github.com/LerianStudio/helm/commit/de6b1547947f91d580a9ff5f7fb14c1e5efa4d0d))
* **values:** create values file to plugin-fees ([304f228](https://github.com/LerianStudio/helm/commit/304f22871b76180f4b299daa3ecaac06571ffd92))
* **values:** create values file to plugin-fees ([f383281](https://github.com/LerianStudio/helm/commit/f383281421b709744823d9de1bc053288ab6d747))


### Bug Fixes

* generate multiples CHANGELOG's ([3f60787](https://github.com/LerianStudio/helm/commit/3f607875b618db474e4055c44a2cffd8216f4261))

##  (2025-05-07)


### Features

* **ingress:** add ingress templates ([020369a](https://github.com/LerianStudio/helm/commit/020369a13b9696eb2e6e12c389ed211d2feb95f1))
* **ingress:** add ingress templates ([816fcee](https://github.com/LerianStudio/helm/commit/816fcee9d905744bcd47003fb16b974104c2d2d3))
* **pipe:** add release step for ghcr ([f0e4f3f](https://github.com/LerianStudio/helm/commit/f0e4f3f5221b392bb68b2a5f87aa85facc5cfbee))
* **helm:** create chart file to plugin crm ([69b01c8](https://github.com/LerianStudio/helm/commit/69b01c868752eb91973e2d292eb2e7ffaa57c1e0))
* **helm:** create chart file to plugin-fees ([38a0e81](https://github.com/LerianStudio/helm/commit/38a0e81c29d53bb81bb1895869b058942bc1d116))
* **helm:** create chart templates to plugin crm ([777ea2f](https://github.com/LerianStudio/helm/commit/777ea2fa1582d1530fbc4946c4ef184ae90598e9))
* **chart:** create chart templates to plugin-fees ([adabbaa](https://github.com/LerianStudio/helm/commit/adabbaaf405b471b111abe208408fce9c0772e99))
* **chart:** create chart templates to plugin-fees ([303caf0](https://github.com/LerianStudio/helm/commit/303caf06a48ff63e20fcdd13fd2c5d0629aae33c))
* **helm:** create doc to plugin crm ([4cbaa9d](https://github.com/LerianStudio/helm/commit/4cbaa9d4e8377260508c5687f292cfec8dbeee36))
* **helm:** create values file to plugin crm ([de6b154](https://github.com/LerianStudio/helm/commit/de6b1547947f91d580a9ff5f7fb14c1e5efa4d0d))
* **values:** create values file to plugin-fees ([304f228](https://github.com/LerianStudio/helm/commit/304f22871b76180f4b299daa3ecaac06571ffd92))
* **values:** create values file to plugin-fees ([f383281](https://github.com/LerianStudio/helm/commit/f383281421b709744823d9de1bc053288ab6d747))

##  (2025-04-22)


### Bug Fixes

* generate multiples CHANGELOG's ([3f60787](https://github.com/LerianStudio/helm/commit/3f607875b618db474e4055c44a2cffd8216f4261))

