# Lender Helm Chart

This chart installs [Lender](https://github.com/LerianStudio/lender), Lerian's credit
journey engine (CDC / PJ / Cards). It is a **multi-component** chart:

- `lender` — the Go API (main component; image tag lands at `lender.image.tag`).
- `lenderConsole` — the optional Vite/React SPA UI served by `nginx-unprivileged`
  (disabled by default; enable per environment once a `lender-ui` image is published).

PostgreSQL and Valkey/Redis are **external** (Benedita DB-LXC pattern) — the chart
ships no datastore subcharts. An optional ArgoCD PreSync bootstrap Job
(`global.externalPostgresDefinitions.enabled`) provisions the DB/role/grants
idempotently; schema migrations remain operator-driven (`cmd/migrate up`, out of band).

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `lender.secrets.POSTGRES_PASSWORD` (install fails loud when unset,
  unless `lender.useExistingSecret=true` — then `lender.existingSecretName` is required
  instead). `REDIS_PASSWORD` and `AUTH_JWT_SECRET` are optional (emitted from
  `lender.secrets.*` only when set). When the bootstrap Job is enabled
  (`global.externalPostgresDefinitions.enabled=true`) without an `useExistingSecret.name`,
  `global.externalPostgresDefinitions.postgresAdminLogin.password` and
  `global.externalPostgresDefinitions.lenderCredentials.password` are also required.
- Dependency notes: No subcharts / no `dependencies:` — Postgres is external (Benedita
  DB-LXC pattern), provided via values. Therefore no `Chart.lock`.
- Production overrides: set `lender.image.tag`; provide `lender.secrets.POSTGRES_PASSWORD`
  (or `lender.useExistingSecret=true` + `lender.existingSecretName`) and, when the UI is
  used, `lenderConsole.enabled=true` with `lenderConsole.image.tag` (**required** when the
  console is enabled). Configure `lender.ingress` / `lenderConsole.ingress` hosts per
  environment. `lenderConsole.securityContext.readOnlyRootFilesystem` is intentionally
  `false` (nginx-unprivileged renders `/config.js` at start and writes pid/cache to the
  root fs — live-proven; do not flip it to `true`).
- Source/license: https://github.com/LerianStudio/lender

## Components

### Lender API (`lender`)

The Go API. Binds `0.0.0.0:4017` (`SERVER_ADDRESS`), exposes `/health` (liveness) and
`/readyz` (readiness). Non-sensitive env is rendered from `lender.configmap`; sensitive
env from `lender.secrets` (or an existing Secret). Feature flags (RabbitMQ, streaming,
outbox, multi-tenant, collection) default OFF so the service boots single-tenant.

### Lender Console (`lenderConsole`)

Optional Vite SPA served by `nginx-unprivileged` (uid/gid `101`). Disabled by default;
no chart change is needed to wire a future UI — set `lenderConsole.enabled=true` and a
`lenderConsole.image.tag`. Runtime config (e.g. `API_BASE_URL`) is delivered via
`lenderConsole.configmap` and rendered into the SPA at container start.

## Install

```console
$ helm install lender oci://registry-1.docker.io/lerianstudio/lender-helm \
    --version 1.0.2 -n lender --create-namespace
```

## Configuring Ingress (NGINX)

```yaml
lender:
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: lender.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: lender-tls
        hosts:
          - lender.example.com
```

## Support & Community

- **GitHub Issues**: https://github.com/LerianStudio/lender/issues
- **Email**: [contact@lerian.studio](mailto:contact@lerian.studio)
