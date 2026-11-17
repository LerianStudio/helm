<!-- {% raw %} -->
# Helm Upgrade from v10.3.4 to v10.4.0

## Topics

- **[Changes](#changes)**
  - [1. Licence file for the ledger and the tracer](#1-licence-file-for-the-ledger-and-the-tracer)
  - [2. Partition runner reads the licence key and the Valkey password](#2-partition-runner-reads-the-licence-key-and-the-valkey-password)
- **[BYOC: what the licence-validating images need](#byoc-what-the-licence-validating-images-need)**
- **[Action required](#action-required)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Changes

The default `ledger.image.tag` and `tracer.image.tag` (`4.4.0`) and the chart `appVersion` do not change in this release. Images that do not read a licence file ignore everything added here, so the upgrade is safe before you move to a licence-validating image.

### 1. Licence file for the ledger and the tracer

New optional values `ledger.licenseFile.existingSecret` and `tracer.licenseFile.existingSecret` (default `""`). When set, the chart mounts that Secret as the read-only directory `/etc/lerian/license` on the component and sets `LICENSE_FILE_PATH` to `/etc/lerian/license/license`. The Secret holds the signed licence file under the key `license`. The chart mounts the Secret as a directory, never as a single file, so a renewed file reaches the pod without a restart.

`LICENSE_KEY` stays the way to get a licence. A component with a licence file does not need its `secrets.LICENSE_KEY`. File mode needs an image on lib-license-go v5.

```yaml
ledger:
  licenseFile:
    existingSecret: midaz-ledger-license
tracer:
  licenseFile:
    existingSecret: midaz-tracer-license
```

The partition CronJob and the partition reconcile Job mount the ledger's licence file too. Create the Secret before the upgrade: the reconcile Job runs as an upgrade hook.

### 2. Partition runner reads the licence key and the Valkey password

When `ledger.secrets.LICENSE_KEY` is set (and `ledger.useExistingSecret` is `false`), a hook Secret named `<ledger fullname>-license-hook` carries only `LICENSE_KEY` ahead of the partition reconcile Job, so the Job has the key on the first upgrade that sets it. With `useExistingSecret: true` the Job reads the key from your Secret, as the ledger does.

With `ledger.configmap.MULTI_TENANT_ENABLED: "true"`, the partition CronJob and reconcile Job now receive `REDIS_PASSWORD` the same way the ledger Deployment does.

## BYOC: what the licence-validating images need

These apply when you move `ledger.image.tag` and `tracer.image.tag` to an image built on lib-license-go v5:

- **Every process start:** without a mounted licence file, each pod start and each run of the partition CronJob or reconcile Job needs outbound access to `license.lerian.io` on port 443. A mounted licence file (`licenseFile.existingSecret`) removes that need, also during a licence-service outage.
- **Storage:** from Midaz 4.5.0-rc.2 on (lib-license-go v5.3.0), the licence lives only in memory and needs no database grant and no Valkey key. Ledger migration 000073 and tracer migration 000053 drop the `lerian_license_file` table, and the multi-tenant ledger deletes its Valkey key at boot. Earlier v5 images (4.5.0-rc.1 and the 4.5.0 betas) still create the table at runtime and need `CREATE` on the schema.
- **Pre-created table:** the migrations run as the application database user. If another role owns `lerian_license_file`, the drop fails and blocks the upgrade. Before the upgrade, check the owner with `SELECT tableowner FROM pg_tables WHERE tablename = 'lerian_license_file';` and have that role or a DBA drop the table.
- **Renewal:** the licence is renewed every 6 hours.

## Action required

No action is required to upgrade. Before you move an image to lib-license-go v5, set the licence key (`ledger.secrets.LICENSE_KEY`, `tracer.secrets.LICENSE_KEY`, or the key in your existing Secret) or a `licenseFile.existingSecret`, and meet the requirements above.

## Preview changes before upgrading

The commands below are examples. Replace `midaz` (release name) and `-n midaz` (namespace) with the values used at install time.

The release keeps its stored values, so the commands pass no `-f` or `--set`.

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.4.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

With the default image tags the diff shows no change to the ledger or tracer Deployments.

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.4.0 -n midaz
```

## Verify

```bash
kubectl get pods -n midaz -l app.kubernetes.io/instance=midaz
kubectl rollout status deployment/midaz-ledger -n midaz
helm status midaz -n midaz
```

All pods reach `Running` and `Ready`, and `helm status` shows `deployed`.
<!-- {% endraw %} -->
