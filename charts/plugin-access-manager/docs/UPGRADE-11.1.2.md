# Helm Upgrade from v11.1.1 to v11.1.2

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that increments the chart version from 11.1.1 to 11.1.2. No changes were made to:

- Application versions (appVersion remains `3.17.0`)
- Template files
- Configuration values
- Dependencies

**What this means for operators:**

No application version or values-schema migration is introduced. However, chart metadata participates in rendered configuration checksums: with identical values, the auth and identity `checksum/config` and Caradhras `checksum/auth-config` annotations change between these releases. All three Deployment pod templates therefore change and Kubernetes schedules rolling updates. New Caradhras pods run the migration init container again, even though this chart release introduces no new application version. Plan for authentication and login availability during the rollout; do not treat this as a no-restart metadata update.

| Component | v11.1.1 | v11.1.2 |
|-----------|---------|---------|
| Chart version | 11.1.1 | 11.1.2 |
| App version | 3.17.0 | 3.17.0 |
| Identity image | *(unchanged)* | *(unchanged)* |
| Auth image | *(unchanged)* | *(unchanged)* |
| Auth Backend image | *(unchanged)* | *(unchanged)* |

**Action required:**

Before the rollout:

1. Record the release history and the pre-upgrade revision. Keep owner-only backups of the current user-supplied values, rendered manifests, complete maintained configuration and existing Secret references in an approved private location. Values and manifests may contain credentials; do not commit or post them.
2. Prepare `your-values.yaml` as the complete intended configuration, preserving all unrelated overrides, identity-provider settings and Secret references. The preview and upgrade commands below explicitly reset stored overrides and apply this file, so an incomplete file can remove required configuration.
3. Take a database backup using your established procedure and verify that recovery is available before permitting new Caradhras pods to run their migration init container.
4. Preview the rollout, schedule an appropriate window, and check auth, identity and Caradhras readiness plus a representative login/token flow after the upgrade. Existing images are unchanged, but a rollout can still affect availability.

If recovery is necessary, select the recorded pre-upgrade revision from release history and use your established Helm rollback procedure. A Helm rollback changes Kubernetes resources; it does not restore database contents or reverse migration side effects. Coordinate database recovery separately if required, and validate readiness and login before reopening traffic. No live upgrade or restore has been exercised for this guide.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.2 --reset-values -f your-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.2 --reset-values -f your-values.yaml
```
