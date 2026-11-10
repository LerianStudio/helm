# Br-sisbajud Changelog

## [1.4.4](https://github.com/LerianStudio/helm/releases/tag/br-sisbajud-v1.4.4)

Fixes:
- Require `LICENSE_KEY` in every environment to ensure proper configuration. (@fredcamaral)
- Render an explicit zero grace period to handle specific cases correctly. (@fredcamaral)

Improvements:
- Add verified upgrade guides for transitioning from `1.4.1` to `1.4.3`, providing clear instructions for users. (@fredcamaral)
- Correct chart documentation to align with templates and application code, ensuring accuracy and consistency. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-sisbajud-v1.4.3...br-sisbajud-v1.4.4)

---

## [1.4.3](https://github.com/LerianStudio/helm/releases/tag/br-sisbajud-v1.4.3)

Fixes:

- Stopped rendering `IS_DEVELOPMENT` in the `br-sisbajud` component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-sisbajud-v1.4.2...br-sisbajud-v1.4.3)

---

## [1.4.2](https://github.com/LerianStudio/helm/releases/tag/br-sisbajud-v1.4.2)

Fixes:
- Set shutdown drain delay and increase pod grace period to 55 seconds. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-sisbajud-v1.4.1...br-sisbajud-v1.4.2)

---

## [1.4.1](https://github.com/LerianStudio/helm/releases/tag/br-sisbajud-v1.4.1)

Features:

- Relicense the charts under Elastic License 2.0. (@fredcamaral)

Improvements:

- Add a Helm upgrade guide for `br-sisbajud` `v1.4.0`. (@victorlazari)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-sisbajud-v1.4.0...br-sisbajud-v1.4.1)

---

## [1.4.0](https://github.com/LerianStudio/helm/releases/tag/br-sisbajud-v1.4.0)

Features:
- Released app `1.1.0`. (@brunobls)
- Render and validate AWS KMS key modes. (@brunobls)

Fixes:
- Refuse leading zeros in canonical tags. (@brunobls)
- Verify only canonical image tags. (@brunobls)
- Refuse digest-pinned tags without acknowledgment. (@brunobls)

Improvements:
- Refined KMS notes in the getting started guide. (@brunobls)
- Added AWS KMS key modes to the getting started guide. (@brunobls)
- Noted that AWS KMS knobs render only with AWS. (@brunobls)
- Clarified KMS knob precedence and trimmed documentation. (@brunobls)
- Aligned tag gate notes with canonical rules. (@brunobls)
- Documented canonical tags and gate limits. (@brunobls)
- Documented the unverifiable image tag acknowledgment. (@brunobls)
- Documented AWS KMS key mode values. (@brunobls)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-sisbajud-v1.3.0...br-sisbajud-v1.4.0)

---

## [1.3.0](https://github.com/LerianStudio/helm/releases/tag/br-sisbajud-v1.3.0)

Features:
- Deploy the sisbajud mensageria. (@guimoreirar)

Fixes:
- Check the effective execution address, including extra environment variables. (@guimoreirar)
- Align configuration coverage with `sisbajud-v1.0.0`. (@guimoreirar)
- Pin application to `1.0.0` and guard the execution address. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/br-sisbajud-v1.2.0...br-sisbajud-v1.3.0)
