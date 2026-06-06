# plugin-bc-correios Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: `bc-correios.secrets.POSTGRES_PASSWORD`, `RABBITMQ_PASS`, `RABBITMQ_URL`, and `ENCRYPTION_KEY`.
- Dependency notes: Uses local PostgreSQL and RabbitMQ dependency charts unless external services are configured.
- Production overrides: Provide production database, RabbitMQ, and encryption secrets through chart secrets or an existing Secret where supported; override image tags, ingress, resources, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

Helm chart for deploying the BC Correios plugin service.

## Install

```sh
helm dependency build ./charts/plugin-bc-correios
helm upgrade --install plugin-bc-correios ./charts/plugin-bc-correios \
  --namespace plugin-bc-correios --create-namespace \
  --values ./charts/plugin-bc-correios/values-template.yaml
```

## Required Configuration

- Configure PostgreSQL, RabbitMQ, and Valkey credentials explicitly before production use.
- Review `bc-correios.configmap` for service URLs, telemetry, and plugin runtime settings.
- Prefer `bc-correios.useExistingSecret` when production secrets are managed outside Helm.

## Dependencies

This chart depends on PostgreSQL, RabbitMQ, and Valkey subcharts. Run `helm dependency build` before rendering or installing from a local checkout.

## Source

See the root repository documentation for release and chart maintenance workflows.
