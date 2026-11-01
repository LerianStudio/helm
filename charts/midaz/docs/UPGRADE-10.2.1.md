# Helm Upgrade from v10.2.0 to v10.2.1

## Topics

- **[Fixes](#fixes)**
  - [1. Ledger terminationGracePeriodSeconds documentation update](#1-ledger-terminationgraceperiodseconds-documentation-update)

## Fixes

### 1. Ledger terminationGracePeriodSeconds documentation update

This release updates the inline documentation for the `ledger.terminationGracePeriodSeconds` setting in `values.yaml`. The comment now provides guidance for both newer and older versions of the ledger service based on the underlying `lib-commons` library version.

#### What Changed

The documentation comment for `terminationGracePeriodSeconds` has been expanded to clarify the shutdown timing requirements for different ledger image versions.

**Before (v10.2.0):**

```yaml
ledger:
  revisionHistoryLimit: 10
  # -- Seconds Kubernetes waits after SIGTERM before killing the pod. Must cover the
  # shutdown drain: in-flight HTTP requests, in-flight streaming events, producer flush.
  # 72 = 15s SHUTDOWN_DRAIN_DELAY + ~47s ledger shutdown + 10s margin.
  terminationGracePeriodSeconds: 72
```

**After (v10.2.1):**

```yaml
ledger:
  revisionHistoryLimit: 10
  # -- Seconds Kubernetes waits after SIGTERM before killing the pod. Must cover the
  # shutdown drain: in-flight HTTP requests, in-flight streaming events, producer flush.
  # Ledger images on lib-commons v7.21.0-beta.20 or later need 60 = 15s SHUTDOWN_DRAIN_DELAY
  # + 30s shutdown budget (HTTP drain, 10s event wait) + 5s producer flush + 10s margin;
  # earlier images need ~72 (15s drain + ~47s per-stage shutdown + 10s margin).
  terminationGracePeriodSeconds: 72
```

| Setting | v10.2.0 | v10.2.1 |
|---------|---------|---------|
| `ledger.terminationGracePeriodSeconds` | `72` | `72` (unchanged) |
| Documentation | Single timing formula | Version-specific guidance |

#### Why This Matters

The ledger service's graceful shutdown process changed in `lib-commons` v7.21.0-beta.20, reducing the required shutdown time from approximately 72 seconds to 60 seconds. The updated documentation helps operators:

- **Understand version-specific requirements**: Operators can now determine the appropriate `terminationGracePeriodSeconds` value based on their ledger image version
- **Optimize shutdown timing**: Newer ledger images can use a shorter grace period (60 seconds), reducing the time required for pod termination during rolling updates
- **Avoid premature termination**: The documentation ensures operators allocate sufficient time for the ledger to flush in-flight requests, streaming events, and producer messages before Kubernetes forcibly kills the pod

#### Operator Impact

This is a **documentation-only change**. The default value of `terminationGracePeriodSeconds` remains `72` seconds, which is safe for all ledger image versions.

**No action is required** for existing deployments. The current setting of 72 seconds provides sufficient time for both older and newer ledger images to shut down gracefully.

#### Action Required (Optional)

If you are running a ledger image based on `lib-commons` v7.21.0-beta.20 or later, you may optionally reduce the termination grace period to improve rolling update performance.

**Step 1:** Verify your ledger image version. Check the `lib-commons` version in your ledger image release notes or container metadata.

**Step 2:** If your ledger image uses `lib-commons` v7.21.0-beta.20 or later, you can reduce the grace period in your `values.yaml`:

```yaml
ledger:
  terminationGracePeriodSeconds: 60
```

**Step 3:** Apply the change during your next upgrade:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.2.1 -n midaz -f values.yaml
```

> **Note:** If you are unsure of your ledger image's `lib-commons` version, keep the default value of 72 seconds. This provides a safe margin for all versions.

> **Important:** Setting `terminationGracePeriodSeconds` too low can cause Kubernetes to forcibly kill the ledger pod before it completes its shutdown sequence, potentially leading to:
> - Lost in-flight HTTP requests
> - Incomplete event stream processing
> - Unflushed producer messages

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.2.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.2.1 -n midaz
```
