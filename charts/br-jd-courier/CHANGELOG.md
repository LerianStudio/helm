# Br-jd-courier Changelog

## [2.2.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.2.1)

Improvements:
- Tie the shutdown budget comment to the SPB budgets to provide clearer documentation. (@fredcamaral)
- Correct the shutdown timeline in the values to ensure accuracy in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.2.0...br-jd-courier-v2.2.1)

---

## [2.2.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.2.0)

Features:
- Added a Helm upgrade guide for `br-jd-courier` `v2.1.2`, providing detailed instructions for users on how to upgrade to the latest version. (@victorlazari)

Fixes:
- Corrected the release notes and registry note in the `v2.1.2` upgrade guide for `br-jd-courier`, ensuring accurate and clear documentation. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.1.2...br-jd-courier-v2.2.0)

---

## [2.1.2](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.2)

Fixes:
- Update `br-jd-courier@1.2.1` to address existing issues. (@lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v2.1.1`. (@victorlazari)
- Fix the `v2.1.1` upgrade guide to accommodate breaking changes in Courier `1.2.0`. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.1.1...br-jd-courier-v2.1.2)

---

## [2.1.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.1)

Fixes:
- Fit the chart to a BYOC install of courier `1.2.0`. (@fredcamaral)
- Update `br-jd-courier@1.2.0`. (@lerian-studio)
- Turn the access manager declaration on by default. (@fredcamaral)
- Give the readiness probe the time `readyz` takes. (@fredcamaral)
- Schedule the migration job with the roles. (@fredcamaral)
- Refuse the access manager M2M secret under config. (@fredcamaral)

Improvements:
- Delete JD's old applications before the `1.2.0` upgrade. (@fredcamaral)
- Delete JD's old client applications at the partner change. (@fredcamaral)
- Name the transit's service segments key. (@fredcamaral)
- Add the transit secret key without dropping the others. (@fredcamaral)
- Put the access manager floor first in the `1.1.x` upgrade. (@fredcamaral)
- Give the `1.1.x` upgrade its real order and trim duplicates. (@fredcamaral)
- Correct the BYOC access manager, region, and upgrade notes. (@fredcamaral)
- Document what a BYOC install of courier `1.2.0` needs. (@fredcamaral)
- Flag the stale `1.1.0` tag inside the Pix transit examples. (@gandalf-at-lerian)
- Align readme and upgrade notes with chart behavior. (@gandalf-at-lerian)
- Close the truncated YAML fence in `br-jd-courier` `UPGRADE-2.0`. (@guimoreirar)
- Add Helm upgrade guide for `br-jd-courier` `v2.1.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.1.0...br-jd-courier-v2.1.1)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional `ServiceAccount` for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the `serviceAccount` values and trim the telemetry environment. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service. (@fredcamaral)
- Update `br-jd-courier@1.1.0`. (@lerian-studio)

Improvements:
- Point values comments at the readme and fix the `1.0` examples. (@fredcamaral)
- Use a vendor timeout the app accepts in the upgrade guide. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Features:

- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

Fixes:

- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.0)

- Features:
  - Added the JD Courier chart.

- Fixes:
  - Addressed issues identified in review round 1 for br-jd-courier.

Contributors: @fredcamaral, @lerian-studio,

[View all changes](https://github.com/LerianStudio/helm/commits/br-jd-courier-v1.0.0)
