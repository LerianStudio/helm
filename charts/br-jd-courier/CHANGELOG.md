# Br-jd-courier Changelog

## [2.1.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.1)

Fixes:
- Fit the chart to a BYOC install of `courier@1.2.0`. (@fredcamaral)
- Update `br-jd-courier` to `@1.2.0`. (@lerian-studio)
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
- Document what a BYOC install of `courier@1.2.0` needs. (@fredcamaral)
- Flag the stale `1.1.0` tag inside the Pix transit examples. (@gandalf-at-lerian)
- Align README and upgrade notes with chart behavior. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.1.0...br-jd-courier-v2.1.1)

---

## [2.1.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.1)

Features:
- Updated `br-jd-courier` to `1.2.0`. (@lerian-studio)

Fixes:
- Adjusted the chart to fit a BYOC install of `courier` `1.2.0`. (@fredcamaral)
- Enabled the access manager declaration by default. (@fredcamaral)
- Adjusted the readiness probe to match the time `readyz` takes. (@fredcamaral)
- Scheduled the migration job with the appropriate roles. (@fredcamaral)
- Prevented the access manager M2M secret from being exposed under config. (@fredcamaral)

Improvements:
- Removed old applications before upgrading to `1.2.0`. (@fredcamaral)
- Deleted old client applications at the partner change. (@fredcamaral)
- Named the transit's service segments key. (@fredcamaral)
- Added the transit secret key without removing others. (@fredcamaral)
- Documented the requirements for a BYOC install of `courier` `1.2.0`. (@fredcamaral)
- Placed the access manager floor first in the `1.1.x` upgrade. (@fredcamaral)
- Corrected the BYOC access manager, region, and upgrade notes. (@fredcamaral)
- Flagged the stale `1.1.0` tag inside the Pix transit examples. (@gandalf-at-lerian)
- Aligned the README and upgrade notes with chart behavior. (@gandalf-at-lerian)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- Document the pix transit's image, callers, and JD keys for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0` to prevent deployment issues. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Improve compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users with the upgrade process. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Improve resilience against `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist with the transition. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Improve compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users with the upgrade process. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in documentation. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users in transitioning smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation to provide clearer guidance. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users in transitioning smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users in transitioning smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- Document the pix transit's image, callers, and JD keys. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- Document the pix transit's image, callers, and JD keys for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to facilitate smoother transitions. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0` to maintain consistent behavior. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation to provide clearer guidance. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users in transitioning to the new version. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

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

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in documentation. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users with the transition. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Survive `--reuse-values` from `2.0.0`, maintaining compatibility with previous configurations. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist with the transition to the new version. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Improve compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users with the transition. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for better clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users in transitioning smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for clarity. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v2.0.0` to assist users in transitioning smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Enhance compatibility to survive `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- Document the pix transit's image, callers, and JD keys for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- Document the pix transit's image, callers, and JD keys. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- Document the pix transit's image, callers, and JD keys. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table to ensure proper configuration. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation for clearer understanding. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v2.0.0...br-jd-courier-v2.1.0)

---

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.1.0)

Features:
- Serve the outbound pix transit on the admin role. (@fredcamaral)

Fixes:
- List `JD_PASSWORD` in the chart's secrets table. (@fredcamaral)
- Ensure compatibility with `--reuse-values` from `2.0.0`. (@fredcamaral)

Improvements:
- State the pix transit's image, callers, and JD keys in the documentation. (@fredcamaral)

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

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the serviceAccount values and trim the telemetry environment. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service. (@fredcamaral)
- Update `br-jd-courier@1.1.0`. (@lerian-studio)

Improvements:
- Point values comments at the readme and fix the `1.0` examples. (@fredcamaral)
- Use a vendor timeout the app accepts in the upgrade guide. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the `serviceAccount` values and trim the telemetry environment. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service. (@fredcamaral)
- Update `br-jd-courier@1.1.0`. (@lerian-studio)

Improvements:
- Point values comments at the README and fix the `1.0` examples. (@fredcamaral)
- Use a vendor timeout the app accepts in the upgrade guide. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the serviceAccount values and trim the telemetry environment. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service. (@fredcamaral)
- Update `br-jd-courier@1.1.0`. (@lerian-studio)

Improvements:
- Point values comments at the readme and fix the `1.0` examples. (@fredcamaral)
- Use a vendor timeout the app accepts in the upgrade guide. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the serviceAccount values and trim the telemetry environment. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service. (@fredcamaral)
- Update `br-jd-courier@1.1.0`. (@lerian-studio)

Improvements:
- Point values comments at the readme and fix the `1.0` examples. (@fredcamaral)
- Use a vendor timeout the app accepts in the upgrade guide. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes, ensuring compatibility with the environment. (@fredcamaral)
- Type the `serviceAccount` values and trim the telemetry environment for better performance. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service to streamline operations. (@fredcamaral)
- Update `br-jd-courier@1.1.0` to incorporate the latest changes and improvements. (@lerian-studio)

Improvements:
- Point values comments at the readme and fix the `1.0` examples for clarity. (@fredcamaral)
- Use a vendor timeout that the app accepts in the upgrade guide to enhance user experience. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.1` to assist with version transitions. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the `serviceAccount` values and trim the telemetry environment. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service. (@fredcamaral)
- Update `br-jd-courier@1.1.0`. (@lerian-studio)

Improvements:
- Point values comments at the README and fix the `1.0` examples. (@fredcamaral)
- Use a vendor timeout the app accepts in the upgrade guide. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the `serviceAccount` values and trim the telemetry environment. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service. (@fredcamaral)
- Update `br-jd-courier@1.1.0`. (@lerian-studio)

Improvements:
- Point values comments at the README and fix the `1.0` examples. (@fredcamaral)
- Use a vendor timeout the app accepts in the upgrade guide. (@fredcamaral)
- Add Helm upgrade guide for `br-jd-courier` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes, ensuring compatibility with the service. (@fredcamaral)
- Type the `serviceAccount` values and trim the telemetry environment for better accuracy. (@fredcamaral)
- Leave datastore and SOAP TLS checks to the service, improving reliability. (@fredcamaral)
- Update `br-jd-courier@1.1.0` to ensure compatibility and performance improvements. (@lerian-studio)

Improvements:
- Point values comments at the README and fix the `1.0` examples for clarity. (@fredcamaral)
- Use a vendor timeout that the app accepts in the upgrade guide for better guidance. (@fredcamaral)
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.1` to assist users in transitioning smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.1...br-jd-courier-v2.0.0)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v2.0.0)

Features:
- Add an optional ServiceAccount for AWS access. (@fredcamaral)

Fixes:
- Require `ENVIRONMENT_NAME` and add SOAP TLS shapes. (@fredcamaral)
- Type the serviceAccount values and trim the telemetry environment. (@fredcamaral)
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

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Features:
- Added a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

Fixes:
- Updated `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Features:

- Added a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

Fixes:

- Updated `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Features:

- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

Fixes:

- Update `br-jd-courier` to `@1.0.0`, ensuring compatibility and addressing any issues in the initial release. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier@1.0.0` to address issues. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Features:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier@1.0.0` to address unspecified issues. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier@1.0.0` to address unspecified issues. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0` to assist users with the upgrade process. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Features:
- Added a Helm upgrade guide for `br-jd-courier` `v1.0.0`. (@guimoreirar)

Fixes:
- Updated `br-jd-courier` to `@1.0.0`. (@guimoreirar, @lerian-studio)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

Fixes:
- Update `br-jd-courier` to `@1.0.0`, ensuring compatibility and addressing any issues with the previous version. (@guimoreirar, @lerian-studio)

Improvements:
- Add a Helm upgrade guide for `br-jd-courier` `v1.0.0`, providing users with detailed instructions on how to upgrade smoothly. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.1)

- Fixes:
  - Updated br-jd-courier to version 1.0.0 to address various issues.

- Improvements:
  - Added a Helm upgrade guide for br-jd-courier version 1.0.0 to assist users in transitioning smoothly.

Contributors: @guimoreirar, @lerian-studio

[Compare changes](https://github.com/LerianStudio/helm/compare/br-jd-courier-v1.0.0...br-jd-courier-v1.0.1)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.0)

- Features:
  - Added the JD Courier chart.

- Fixes:
  - Addressed issues identified in review round 1 for br-jd-courier.

Contributors: @fredcamaral, @lerian-studio,

[View all changes](https://github.com/LerianStudio/helm/commits/br-jd-courier-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/br-jd-courier-v1.0.0)

- Features:
  - Added the JD courier chart.

- Fixes:
  - Addressed review comments from round 1.

Contributors: @fredcamaral, @lerian-studio,

[View all changes](https://github.com/LerianStudio/helm/commits/br-jd-courier-v1.0.0)

