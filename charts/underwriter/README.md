# underwriter Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render.
- Dependency notes: Uses local PostgreSQL and MongoDB dependency charts unless external services are configured.
- Production overrides: Provide production database credentials through chart secrets or dependency Secret settings; override image tags, ingress, resources, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

Helm chart for deploying the Lerian underwriter service.

## Install

```sh
helm dependency build ./charts/underwriter
helm upgrade --install underwriter ./charts/underwriter \
  --namespace underwriter --create-namespace \
  --values ./charts/underwriter/values-template.yaml
```

## Required Configuration

- Configure PostgreSQL and Valkey credentials explicitly before production use.
- Review `underwriter.configmap` for service URLs, multi-tenant settings, and telemetry configuration.
- Prefer existing Kubernetes Secrets when production secret material is managed outside Helm.

## Dependencies

This chart depends on PostgreSQL and Valkey subcharts. Run `helm dependency build` before rendering or installing from a local checkout.

## Source

See the root repository documentation for release and chart maintenance workflows.
