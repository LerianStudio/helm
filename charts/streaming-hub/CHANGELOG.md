# Streaming-hub Changelog

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/streaming-hub-v2.1.0)

Features:
- Mounted an optional `lib-license-go` `v5` license file. (@fredcamaral)

Fixes:
- Projected only the license key in the license file volume. (@fredcamaral)

Improvements:
- Added the verified `2.0.4` upgrade guide. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/streaming-hub-v2.0.4...streaming-hub-v2.1.0)

---

## [2.0.4](https://github.com/LerianStudio/helm/releases/tag/streaming-hub-v2.0.4)

Fixes:
- Align chart defaults with the `3.1.0` app. (@fredcamaral)

Improvements:
- Add Helm upgrade guide for `v2.0.3`. (@dy-shimizu)
- Fix `v2.0.3` upgrade guide. (@gandalf-at-lerian)
- Apply review fixes to chart documentation and upgrade guides. (@dy-shimizu, @gandalf-at-lerian)
- Include values file in upgrade preview. (@gandalf-at-lerian)
- Align final upgrade command with Step 4 in the documentation. (@gandalf-at-lerian)

[Compare changes](https://github.com/LerianStudio/helm/compare/streaming-hub-v2.0.3...streaming-hub-v2.0.4)

---

## [2.0.3](https://github.com/LerianStudio/helm/releases/tag/streaming-hub-v2.0.3)

Features:

- Add verified upgrade guides for transitioning from `2.0.1` to `2.0.2`. (@fredcamaral)

Fixes:

- Update `streaming-hub` to `3.1.0`. (@fredcamaral)

Improvements:

- Correct chart documentation to align with templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/streaming-hub-v2.0.2...streaming-hub-v2.0.3)

---

## [2.0.2](https://github.com/LerianStudio/helm/releases/tag/streaming-hub-v2.0.2)

Fixes:

- Prevent the rendering of `IS_DEVELOPMENT` in the streaming-hub component. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/streaming-hub-v2.0.1...streaming-hub-v2.0.2)

---

## [2.0.1](https://github.com/LerianStudio/helm/releases/tag/streaming-hub-v2.0.1)

Improvements:
- Relicense streaming-hub under Elastic License `2.0`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/streaming-hub-v2.0.0...streaming-hub-v2.0.1)

---

## [2.0.0](https://github.com/LerianStudio/helm/releases/tag/streaming-hub-v2.0.0)

Features:
- Add streaming-hub chart for the license-gated `3.0.0` line. (@guimoreirar)

Fixes:
- Correct the role count in the double-consume rule documentation. (@guimoreirar)

Improvements:
- Remove orphaned streaming-hub documentation left after the removal of the chart. (@guimoreirar)
- Remove the streaming-hub chart, which has been moved to helm-internal. (@guimoreirar)
- Add a Helm upgrade guide for streaming-hub `v1.1.1`. (@guimoreirar)
- Add a Helm upgrade guide for streaming-hub `v1.1.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/streaming-hub-v1.1.1...streaming-hub-v2.0.0)

