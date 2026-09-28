# Helm Upgrade from v3.1.3 to v3.1.4

## Topics

- **[Known issue — read before upgrading](#known-issue--read-before-upgrading)**
- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. RabbitMQ plugin user tags removed](#1-rabbitmq-plugin-user-tags-removed)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Known issue — read before upgrading

> **Warning:** In v3.1.4 the RabbitMQ `plugin` user is left with **no tags**. The fetcher manager and worker check the broker health through the RabbitMQ **management API** (`RABBITMQ_HEALTH_CHECK_URL`, default `http://rabbitmq:15672`) using the `plugin` credentials. A user without a management-capable tag gets `401 Unauthorized` from that API, the health check fails, and the RabbitMQ connection is refused. New pods, and existing pods that reconnect, cannot connect to RabbitMQ.

Who is affected:

| Setup | When it breaks |
|-------|----------------|
| External broker with `externalRabbitmqDefinitions.enabled: true` | During this upgrade: the bootstrap Job re-applies the `plugin` user with `tags: ""` |
| Bundled broker (`rabbitmq.enabled: true`) | On the next broker restart: the definitions loaded at boot set `tags: ""` on `plugin` |
| External broker whose `plugin` user is managed outside this chart (`externalRabbitmqDefinitions.enabled: false`) | Not affected by this change |

What to do:

- **Recommended:** do not upgrade to v3.1.4. Stay on v3.1.3 until a fixed release is published.
- **If you already upgraded:** give the `plugin` user the `management` tag again (it is the minimum tag the health check accepts), then restart the manager and worker:

```bash
# Run with a RabbitMQ administrator account; keep the plugin user's current password
curl -u "<admin-user>:<admin-password>" -H "content-type: application/json" \
  -X PUT --data '{"password":"<plugin-password>","tags":"management"}' \
  "http(s)://<rabbitmq-management-host>:15672/api/users/plugin"

kubectl rollout restart deployment/fetcher-manager deployment/fetcher-worker -n fetcher
```

> **Note:** With an external broker, every later `helm upgrade` / Argo CD sync of v3.1.4 runs the bootstrap Job again and removes the tag again. Repeat the step above after each sync until you move to a fixed release.

## Overview

This guide covers the `fetcher` chart upgrade from `3.1.3` to `3.1.4`. It is a **patch** release that removes the `administrator` tag from the RabbitMQ `plugin` user.

The application version (`appVersion: 3.1.0`) is unchanged. Because of the known issue above, this release **is not safe to apply** to installations that let the chart manage the `plugin` user.

## Fixes

### 1. RabbitMQ plugin user tags removed

The `plugin` user previously had the `administrator` tag. It now has no tags, in both places the chart defines it.

| Where | v3.1.3 | v3.1.4 |
|-------|--------|--------|
| Bootstrap Job PUT (`templates/bootstrap-rabbitmq.yaml`, external broker) | `"tags":"administrator"` | `"tags":""` |
| `files/rabbitmq/load_definitions.json` (bundled broker boot definitions) | `"tags": "administrator"` | `"tags": ""` |

**Before (v3.1.3):**

```yaml
--data "{\"password\":\"$PASS\",\"tags\":\"administrator\"}"
```

**After (v3.1.4):**

```yaml
--data "{\"password\":\"$PASS\",\"tags\":\"\"}"
```

**Why it was changed:** `administrator` grants full control of the broker (users, vhosts, policies), which the fetcher does not need. The intended least-privilege target is `management`, not "no tags": the application still needs management API access for its health check.

**How the bootstrap Job runs (external broker):**

- It is rendered only when `externalRabbitmqDefinitions.enabled: true` and `rabbitmq.enabled: false`.
- It is a plain Kubernetes Job, **not** a Helm hook. Its name carries the release revision (`fetcher-bootstrap-rabbitmq-<revision>`), so every `helm upgrade` creates a new Job.
- Under Argo CD it is a `Sync` hook (`BeforeHookCreation,HookSucceeded`), so it runs on every sync.
- The Job has no labels; find it by name.

## Migration Steps

Only if you decide to upgrade despite the known issue (for example, your `plugin` user is not managed by this chart):

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade.
3. If `externalRabbitmqDefinitions.enabled: true`, check the bootstrap Job of this revision:

```bash
kubectl get jobs -n fetcher | grep fetcher-bootstrap-rabbitmq
kubectl logs -n fetcher job/fetcher-bootstrap-rabbitmq-<revision> --all-containers
```

4. Restore the `management` tag as described in [Known issue](#known-issue--read-before-upgrading), then confirm the manager and worker are Ready and their logs show no `rabbitmq health check failed`:

```bash
kubectl get pods -n fetcher
kubectl logs -n fetcher deploy/fetcher-manager | grep -i rabbitmq
```

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.4 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.4 -n fetcher
```
