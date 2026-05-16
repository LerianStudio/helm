# Helm Upgrade from v0.x to v1.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Breaking changes to review](#breaking-changes-to-review)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `lerian-notification` chart upgrade from `0.1.0` to `1.0.0-beta.3`. It was generated retroactively from the chart history and focuses on major version changes; patch-only releases are intentionally ignored.

Because this is a major upgrade, review all removed values, renamed templates, and changed defaults before applying it to production.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `0.1.0` | `1.0.0-beta.3` |
| App version | `0.1.0` | `0.1.0` |

## Configuration changes

### Added values

```yaml
api.securityContext.allowPrivilegeEscalation: false
api.securityContext.seccompProfile.type: "RuntimeDefault"
migrations.securityContext.allowPrivilegeEscalation: false
migrations.securityContext.seccompProfile.type: "RuntimeDefault"
secrets.DATABASE_URL: ""
workerEmail.securityContext.allowPrivilegeEscalation: false
workerEmail.securityContext.seccompProfile.type: "RuntimeDefault"
workerSms.securityContext.allowPrivilegeEscalation: false
workerSms.securityContext.seccompProfile.type: "RuntimeDefault"
workerWebhook.securityContext.allowPrivilegeEscalation: false
workerWebhook.securityContext.seccompProfile.type: "RuntimeDefault"
```

### Removed values

_No direct values.yaml key changes detected._

### Changed operational values

_No image, env, secret, probe, ingress, service, port, or enablement changes detected in values.yaml._

## Breaking changes to review

No removed values were detected in `values.yaml`, but this is still a major chart version. Review the template changes below before rollout.

## Template changes

### Added files

- No chart files added.

### Removed files

- No chart files removed.

### Modified files

- `charts/lerian-notification/Chart.yaml`
- `charts/lerian-notification/templates/api/hpa.yaml`
- `charts/lerian-notification/templates/api/pdb.yaml`
- `charts/lerian-notification/templates/configmap.yaml`
- `charts/lerian-notification/templates/migrations-job.yaml`
- `charts/lerian-notification/templates/secret.yaml`
- `charts/lerian-notification/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/lerian-notification/values.yaml`.
2. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
3. Render the chart locally with your production values and review the manifest diff.
4. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-notification ./charts/lerian-notification \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade lerian-notification ./charts/lerian-notification \
  --namespace <namespace> \
  --values <your-values.yaml>
```
