# Br-sta Changelog

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/br-sta-v1.0.0)

Features:
- Drop the default image pull secret for `br-sta` as images are now public. (@guimoreirar)
- Add secretRefs to the `br-sta` chart. (@brunobls)
- Expose multi-tenant client tuning for `br-sta` as grouped values. (@guimoreirar)
- Track the first stable STA release (`app 1.0.0`) in `br-sta`. (@guimoreirar)
- Name the `br-sta` ingress after the manager Service and add deployment annotations. (@guimoreirar)
- Allow `br-sta` to keep an existing manager Service address. (@guimoreirar)
- Add a self-contained `br-sta` development bundle. (@guimoreirar)
- Add the `br-sta` chart (manager + worker) on lerian-common for `app 1.2.0-beta.16`. (@guimoreirar)
- Add extra volumes and mounts to the `br-sta` manager and worker. (@guimoreirar)

Fixes:
- Require the `br-sta` license in every environment. (@guimoreirar)
- Default `br-sta` streaming on again. (@brunobls)
- Keep `br-sta` streaming off by default like the other charts. (@brunobls)
- Keep `br-sta` streaming off by default in the template. (@brunobls)
- Enable streaming in the `br-sta` values template. (@brunobls)
- Run the `br-sta` migrations as Helm pre-install/pre-upgrade hooks against external Postgres. (@guimoreirar)
- Derive the `br-sta` RabbitMQ health check and fix the topics Job readiness. (@guimoreirar)
- Tighten `br-sta` extraEnvVars and CORS gates, and fix the README table. (@guimoreirar)
- Count `br-sta` extraEnvVars only when every app pod gets them, and emit `ACCESS_CONTROL_*` CORS keys. (@guimoreirar)

Improvements:
- Keep the `br-sta` license key out of Helm arguments. (@guimoreirar)
- Trim validation narrative and version history from the `br-sta` docs. (@guimoreirar)
- Flag the `br-sta` S3 endpoint and streaming coupling. (@brunobls)
- Describe the `br-sta` migrations as a hook Job. (@brunobls)
- Fold the `br-sta` production-mode validation into the runbook. (@guimoreirar)
- Add `br-sta` rollback, pull secret, and owners to the runbook. (@guimoreirar)
- State that the `br-sta` bundled infrastructure is for development and quickstart only. (@guimoreirar)
- Add the `br-sta` getting-started runbook. (@guimoreirar)
- Document the `br-sta` chart. (@guimoreirar)

[View all changes](https://github.com/LerianStudio/helm/commits/br-sta-v1.0.0)

