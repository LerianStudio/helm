# go-boilerplate-ddd Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render.
- Dependency notes: No local dependency chart is required by the default chart configuration.
- Production overrides: Override image, ingress, resources, probes, and any application-specific secret values before production use.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

Helm chart for deploying the Lerian Go boilerplate DDD service.

## Install

```sh
helm upgrade --install go-boilerplate-ddd ./charts/go-boilerplate-ddd \
  --namespace go-boilerplate-ddd --create-namespace \
  --values ./charts/go-boilerplate-ddd/values-template.yaml
```

## Required Configuration

- Set PostgreSQL credentials through `boilerplate.secrets` or an external secret workflow before production use.
- Review `global.externalPostgresDefinitions` when the chart must bootstrap external PostgreSQL users/databases.
- Do not use published defaults for production secrets.

## Dependencies

This chart is a single-service application chart. It does not vendor dependency archives in git.

## Source

See the root repository documentation for release and chart maintenance workflows.
