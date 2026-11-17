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

Apart from documentation and the changelog, the only chart file change removes the unused `files/init_data.json` seed from the chart package. No template read it; Caradhras loads its seed from its own image.

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

When using the bundled PostgreSQL database, upgrade-mode rendering requires its current password through `auth-database.auth.password` in the private complete `your-values.yaml` file. Preserve the existing database credentials; this is not a password-rotation step. Never put real passwords in CLI `--set` arguments, decode Secrets into terminal output, or copy dependency diagnostics containing credentials into logs or Git. A client-only render cannot establish live Secret or database state.

Keep all preview output private. `--suppress-secrets` reduces Secret output in helm-diff but does not guarantee that other rendered resources or errors contain no sensitive values. Use the same complete intended values and Secret references for preview and upgrade.

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.2 --reset-values --suppress-secrets -f your-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.2 --reset-values -f your-values.yaml
```
