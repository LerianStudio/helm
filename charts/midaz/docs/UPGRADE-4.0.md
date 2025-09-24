# Helm Upgrade from v3.x to v4.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. RabbitMQ dependency change to Groundhog2k](#1-rabbitmq-dependency-change-to-groundhog2k)
- **[Features](#features)**
  - [1. Switch Bitnami -> BitnamiSecure (latest) for Postgres, MongoDB and Valkey](#1-switch-bitnami---bitnamisecure-latest-for-postgres-mongodb-and-valkey)
  - [2. Replace Bitnami NGINX dependency with internal solution using the official NGINX image](#2-replace-bitnami-nginx-dependency-with-internal-solution-using-the-official-nginx-image)
  - [3. App version bump to 3.3.1](#3-app-version-bump-to-331)
- **[Migration Steps](#migration-steps)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### 1. RabbitMQ dependency change to Groundhog2k

The RabbitMQ chart dependency has been replaced from Bitnami to Groundhog2k: https://groundhog2k.github.io/helm-charts

This change may lead to PersistentVolumeClaim (PVC) data loss when upgrading existing installations because the underlying StatefulSet, volume mounts, and configuration differ from the previous dependency.

Important notes:
- The Groundhog2k chart requires a valid Erlang cookie. Set `rabbitmq.authentication.erlangCookie.value` to a 32+ character printable string with no spaces. If missing/empty, RabbitMQ will fail to start.
- If you need to preserve existing data, back up and plan a controlled migration of PVCs and definitions before upgrading.

> Note: This breaking change only impacts deployments that use the chart's default RabbitMQ (`rabbitmq.enabled: true`). If you run an external or managed RabbitMQ (i.e., `rabbitmq.enabled: false`) and integrate via configuration, you are not affected by this change.

## Features

### 1. Switch Bitnami -> BitnamiSecure (latest) for Postgres, MongoDB and Valkey

The default images for core data services now use the BitnamiSecure repositories with the `latest` tag:
- `postgresql`: BitnamiSecure image with tag `latest`
- `mongodb`: BitnamiSecure image with tag `latest`
- `valkey`: BitnamiSecure image with tag `latest`

This provides hardened images by default. If you require pinning to a specific version, override the tag in `values.yaml`.

### 2. Replace Bitnami NGINX dependency with internal solution using the official NGINX image

The previous Bitnami NGINX dependency used for Microfrontends was replaced with an internal template based on the official `nginx` image.

Benefits:
- Simpler and more controllable configuration for plugin UI proxying.
- Reduced abstraction layer by relying directly on upstream NGINX.

If you previously customized the Bitnami-based NGINX configuration, review the new templates under `templates/console/` and adjust your values accordingly.

### 3. App version bump to 3.3.1

All midaz application components were bumped to version `3.3.1`. See the project changelog for application-level changes.

## Migration Steps

- **Back up data before upgrading RabbitMQ.** Due to the dependency switch, PVC layout and config differ and may lead to data loss.
- **Set the Erlang cookie** for RabbitMQ:
  ```yaml
  rabbitmq:
    authentication:
      erlangCookie:
        value: "<32+ printable characters>"
  ```
- **Review NGINX configuration** if you rely on Microfrontends. Compare your overrides with the new official NGINX-based templates under `templates/console/`.
- **Review database/cache images** if you need version pinning. Default tags are now `latest` from BitnamiSecure.

#### Why we changed (Bitnami-related issues)

Move away from Bitnami dependencies due to policy changes in bitnamisecure (#83267) impacting stability and operations.s

- https://github.com/bitnami/charts/issues/36215
- https://github.com/bitnami/containers/issues/86191
- https://github.com/bitnami/containers/issues/83267

## Production recommendation

We do not recommend using the Midaz Helm chart’s default dependencies (databases, cache, and message broker) in production environments. For production-grade deployments, follow our best practices to operate these dependencies with proper security, observability, backups, disaster recovery, and SLOs.

Reference: [Midaz Production Best Practices](https://docs.lerian.studio/docs/midaz-production-best-practices)

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 4.0.0 -n midaz
```
