<!-- {% raw %} -->
# Helm Upgrade from v10.3.1 to v10.3.2

## Topics

- **[Fixes](#fixes)**
  - [1. Partition runner auto-enablement logic updated](#1-partition-runner-auto-enablement-logic-updated)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Partition runner auto-enablement logic updated

The automatic enablement logic for the ledger partition health runner has been refined to correctly enable the feature for all ledger images from version `4.5.0-beta.1` onwards, including pre-release versions.

#### What changed

The partition runner is a scheduled job that creates transaction partitions ahead of time and reports their health; in multi-tenant mode it visits every active tenant. Previously, the auto-enablement logic only activated for stable semantic versions (`>=4.5.0`), which incorrectly excluded beta and release candidate versions that actually ship with the runner binary.

This patch corrects the version comparison to include all versions from `4.5.0-beta.1` forward, ensuring the runner is automatically enabled for any ledger image that includes it.

| Setting | v10.3.1 | v10.3.2 |
|---------|---------|---------|
| Auto-enable threshold | `>=4.5.0` (stable only) | `>=4.5.0-beta.1` (includes pre-releases) |
| Comment clarity | "stable tags >= 4.5.0 only" | "tags >= 4.5.0-beta.1 (every ledger image from that tag on)" |

#### Template logic changes

**Before (v10.3.1):**
```yaml
{{- if semverCompare ">=4.5.0" $tag -}}true{{- end -}}
```

**After (v10.3.2):**
```yaml
{{- if semverCompare ">=4.5.0-beta.1" $tag -}}true{{- end -}}
```

#### Operational impact

This change affects clusters running ledger images with a pre-release tag at or above `4.5.0-beta.1`. If you are using one of these versions:

- **Before this patch:** The partition runner CronJob was not automatically created unless you explicitly set `ledger.partition.enabled: true`
- **After this patch:** The partition runner CronJob will be automatically created and scheduled

The same switch also renders the `midaz-ledger-partition-reconcile-<tag>` hook Job (`/partition reconcile-indexes --tolerate-unavailable`). It runs on every install and upgrade, including this one. To skip only that Job, set `ledger.partition.reconcile.enabled: false`.

> **Note:** If you have explicitly set `ledger.partition.enabled` to `true` or `false` in your `values.yaml`, that explicit setting always takes precedence over the auto-detection logic. This change only affects deployments that leave the setting unset (the default behavior).

#### Who is affected

You are affected if **all** of the following are true:

1. You are running a ledger image with a pre-release tag at or above `4.5.0-beta.1` (e.g., `4.5.0-beta.1`, `4.5.0-beta.94`, `4.5.0-rc.1`)
2. You have **not** explicitly set `ledger.partition.enabled` in your values

The chart's default `ledger.image.tag` is `4.5.0-beta.94`, so a release that keeps the default tag and leaves `ledger.partition.enabled` unset gains both workloads on this upgrade. To keep them off, set `ledger.partition.enabled: false`.

#### Configuration reference

The partition runner configuration remains unchanged:

```yaml
ledger:
  partition:
    # -- Run the scheduled runner. Unset enables tags >= 4.5.0-beta.1 (every ledger
    # image from that tag on ships the runner); older and non-SemVer tags default off.
    # Set true or false to override.
    enabled:
    # -- Cron schedule in `timeZone`, defaulting to 06:00 outside common managed
    # PostgreSQL maintenance windows; choose a time outside your database's windows.
    schedule: "0 6 * * *"
```

| Flag | Default | Description |
|------|---------|-------------|
| `ledger.partition.enabled` | `nil` (auto-detect) | Explicitly enable (`true`) or disable (`false`) the partition runner, overriding version-based auto-detection |
| `ledger.partition.schedule` | `"0 6 * * *"` | Cron schedule of the partition runner CronJob |

#### No action required

This is a bug fix that aligns the auto-enablement behavior with the documented feature availability. No operator action is required unless you want the runner off (set `ledger.partition.enabled: false`):

- If you are running ledger `4.5.0` or later (stable), behavior is unchanged
- If you are running a pre-release version with the runner, it will now be correctly enabled
- If you have an explicit `enabled` setting, it continues to override auto-detection
- If you are running older versions without the runner binary, auto-detection continues to leave it disabled

> **Important:** The partition runner requires ledger images that include the `/partition` binary. This binary is present in all images from `4.5.0-beta.1` onwards. Attempting to enable the runner on older images will result in CronJob failures.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.3.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.3.2
```
<!-- {% endraw %} -->
