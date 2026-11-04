# Helm Upgrade from v2.6.0 to v2.6.1

## Topics ToC

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. AWS Cloud Preset Documentation Clarification](#1-aws-cloud-preset-documentation-clarification)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.6.1 is a **patch release** that updates inline documentation in the `_cloud.tpl` template file. This release contains **no functional changes** to templates, helpers, or configuration.

**What changed:**

- Inline documentation in `templates/_cloud.tpl` has been clarified for the AWS cloud preset
- Chart version bumped from `2.6.0` to `2.6.1` in `Chart.yaml`
- No changes to template logic, values, or helper functions

**Who should upgrade:**

- Chart maintainers who want to reference the latest documentation for AWS cloud presets
- Operators who want to stay current with the latest release (optional)

**Backward compatibility:**

This release is **fully backward-compatible**. All templates, helpers, and configuration remain functionally identical to v2.6.0. Upgrading from v2.6.0 to v2.6.1 will produce **no changes** to rendered Kubernetes resources.

**Operational impact:**

> **Note:** Since this release contains only documentation updates with no functional changes, upgrading is **optional**. Existing deployments on v2.6.0 will continue to function identically. No configuration changes, migration steps, or operational actions are required.

## Fixes

### 1. AWS Cloud Preset Documentation Clarification

The inline documentation for the AWS cloud preset in `templates/_cloud.tpl` has been simplified and clarified to improve readability for chart maintainers.

**What changed:**

The documentation comment block describing AWS service defaults (ElastiCache, RDS, AmazonMQ, DocumentDB) has been condensed. The updated documentation:

- Removes references to specific internal CloudFormation templates and GitOps repository paths
- Clarifies that AmazonMQ for RabbitMQ uses AMQPS on port **5671** (not 443) for the AMQP connection
- Clarifies that the management API port is **443** (AWS also accepts 15671 as an alternative)
- Retains all technical details about service defaults (ElastiCache TransitEncryptionEnabled, RDS ForceSSL, DocumentDB EnableTLS)

**Before (v2.6.0):**

```yaml
# AWS values verified against this org's own CloudFormation provisioning
# (lerian-cloudformation-foundation/templates/{elasticache,rds,amazonmq,documentdb}.yaml)
# AND a real production GitOps values file (lerian-aws-gitops
# environments/staging/helmfile/applications/midaz-mt/values.yaml):
# ElastiCache TransitEncryptionEnabled=true+required, RDS ForceSSL default "1".
# AmazonMQ: the CFN security group opens 5671 (AMQPS)/15671/443, but the actual
# production values file uses RABBITMQ_PORT_AMQP=443 (+ RABBITMQ_PROTOCOL=https)
# — not 15671 — so `broker.port` here is 443 to match what this org actually
# runs, even though AWS's own docs call 443/15671 interchangeable. DocumentDB
# EnableTLS default "enabled" — the mongo.params below are the exact
# connection-string shape this org runs against DocumentDB in production:
```

**After (v2.6.1):**

```yaml
# AWS preset: ElastiCache TransitEncryptionEnabled=true+required, RDS ForceSSL
# default "1". AmazonMQ for RabbitMQ: AMQPS on 5671, management API on 443 (AWS also
# accepts 15671), so `amqpPort` is 5671 and the management `port` is 443.
# DocumentDB EnableTLS default "enabled" — the
# mongo.params below are the connection-string shape used for DocumentDB:
```

**Why it matters:**

The documentation now correctly reflects that the `amqpPort` field in the AWS cloud preset is set to **5671** (the standard AMQPS port), not 443. This clarification helps chart maintainers understand the expected port configuration when using AmazonMQ for RabbitMQ with the AWS preset.

**Operational impact:**

> **Important:** This is a **documentation-only change**. The actual template logic and default values for the AWS cloud preset remain unchanged. If you are using the AWS cloud preset with AmazonMQ for RabbitMQ, verify that your configuration uses port 5671 for AMQPS connections (this was already the case in v2.6.0).

**Configuration reference:**

No configuration changes are required. The AWS cloud preset continues to use the following defaults:

| Service | Setting | Default | Description |
|---------|---------|---------|-------------|
| ElastiCache | `redis.tls` | `true` | TransitEncryptionEnabled=true+required |
| RDS | `postgres.sslmode` | `require` | ForceSSL default "1" |
| AmazonMQ | `broker.amqpPort` | `5671` | AMQPS port for RabbitMQ connections |
| AmazonMQ | `broker.port` | `443` | Management API port (AWS also accepts 15671) |
| DocumentDB | `mongo.params` | `tlsInsecure=true&directConnection=true` | Connection string shape for DocumentDB |

> **Note:** If you have overridden these defaults in your values, no action is required. The documentation update does not affect existing configurations.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.1 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v2.6.1, run `helm diff` on the **product charts** that consume it after updating the dependency version. Since this release contains no functional changes, the diff will show no changes to rendered resources.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.1 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.6.1` and run `helm dependency update`, then upgrade the parent chart.
