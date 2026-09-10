# Plugin-br-pix-lerian Changelog

## [2.1.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.1.0)

- **Removals**
  - `LICENSE_ORGANIZATION_IDS` removed from `values.yaml` and
    `values-template.yaml`. Use `ORGANIZATION_IDS` for the license organization
    list. No runtime behaviour changes; rename the key if your own values carry
    it.
  - `BRSFN_TOKEN_URL` removed from `adapterLerianSystemplane.secrets`. The
    application does not read it: there is no environment binding for it in the
    published release and it is not among the keys that component seeds. The
    key was the only place it appeared in the chart. Releases with
    `adapterLerianSystemplane` enabled lose one key from that component's
    Secret, so its pods roll once on the next upgrade; values of your own that
    still set the key are passed through unchanged and remain inert.

- **Breaking changes**
  - `global.externalPostgresDefinitions.pixswitchCredentials` renamed to
    `pixLerianCredentials`. There is no alias, and `values.schema.json` rejects
    the retired key so a stale override cannot silently stop taking effect.
    Rename the key in your values; the chart README has the two-row migration
    table. It is the only key of the retired chart this one refuses -- a values
    file that never set `global.externalPostgresDefinitions`, which is the shape
    the retired chart's own `values-template.yaml` had, renders here unchanged.
  - The bootstrap Jobs' environment variable `DB_PASSWORD_PIXSWITCH` renamed to
    `DB_PASSWORD_PIX_LERIAN`. An external Secret named by
    `pixLerianCredentials.useExistingSecret.name` must carry the new key.
  - Migration and bootstrap resources are now all `pre-install,pre-upgrade`
    hooks, ordered by weight: bootstrap Secret `-30`, bootstrap Jobs `-20`,
    migration Secret `-10`, migration Job `-5`. The migration Job was
    `pre-upgrade,post-install`, which on a fresh install applied the workloads
    before the schema and, under `--wait`, put the workloads' readiness gate in
    front of the hook meant to unblock them. Migrations now complete before any
    workload is created or updated, and a failing migration aborts the release
    with no Deployment created. Two consequences for operators: the database in
    `DATABASE_URL` must be reachable when the hook runs, so a DSN pointing at
    the bundled `postgresql` subchart no longer works on a fresh install
    (install once with `<component>.migrations.enabled: false`, then enable it
    — external and chart-bootstrapped databases are unaffected); and the
    bootstrap Jobs now run on every upgrade instead of only where Helm happened
    to re-create them, which is a no-op on already-provisioned databases.

- **Features**
  - `appVersion` moves to `1.0.0-beta.337`, so every workload that leaves
    `image.tag` empty now runs that cohort. `1.0.0-beta.337` is the first
    application release that no longer reads `AUTH_JWT_VERIFY_CERT` or
    `AUTH_JWT_ISSUER` on `pixauto`, which is what this chart's README already
    documents; on `1.0.0-beta.318` `pixauto` still refused to boot without both
    whenever authentication was enabled outside `local`/`development`. Between
    the two releases those two names are the only change to the environment
    contract of any of the 14 components, so nothing else in this chart's
    documented surface moves with the bump.
  - Inline bootstrap credentials are collected into a chart-managed Secret
    (`templates/bootstrap-secret.yaml`, renamed from
    `bootstrap-postgres-secret.yaml`; the Secret's own resource name is
    unchanged) and read by the Jobs through `secretKeyRef`. Previously an
    operator who supplied them inline got the Postgres admin password as a
    literal `env.value` in the Job spec, readable by any principal holding
    `get job` in the namespace. Both supply paths now reach the container
    identically, and the Secret carries only the halves that are actually
    inline.
  - An inline credential left empty now fails at render time with a message
    naming the key, instead of producing a Secret the Jobs would authenticate
    with and surfacing as an opaque PostgreSQL authentication error.
  - `VALKEY_URL` added to `cobHub.secrets`, matching `spi`, `dictHub`,
    `dictHubVsync` and `pixauto`. The component already read the variable; the
    chart was the only place it was missing, so enabling the cache meant adding
    the key by hand. It defaults to `""` and the cache stays optional. Existing
    releases that set it through the open map keep the same effective value,
    but the component's Secret changes content, so its pods roll once on the
    next upgrade.
  - `values-template.yaml` now sets `ORGANIZATION_IDS: "global"` on every
    workload that builds a license client: added to `spi`, `dictHub`,
    `dictProxy`, `dictHubVsync`, `cobHub` and `cobProxy`, alongside the
    `adapterLerian` and `pixauto` entries that already carried it. The template
    supplies `LICENSE_KEY` to each of them, and the license client refuses to
    initialise with a key and an empty allow-list, so the workload exited at
    boot. The Systemplane workloads and `adapterProviderMock` build no license
    client and are unchanged. `values.yaml` defaults are unchanged.
  - Initial release of the `plugin-br-pix-lerian` chart, forked from
    `plugin-br-pix-switch` at tag `plugin-br-pix-switch-v2.1.0-beta.12` as part
    of the Pix Switch to Pix Lerian product rename.
  - Chart identity renamed end to end: chart name (`plugin-br-pix-lerian-helm`),
    helper templates, resource names and selectors, the 14 component image
    repositories (`ghcr.io/lerianstudio/plugin-br-pix-lerian-*`), the 14
    `OTEL_LIBRARY_NAME` values (`github.com/LerianStudio/plugin-br-pix-lerian`)
    and the in-cluster `*_BASE_URL` defaults that resolve to this chart's own
    Services.
  - The two adapter-lerian components now carry component-scoped
    `APPLICATION_NAME` values (`pix-adapter-lerian`,
    `pix-adapter-lerian-systemplane`), matching the other twelve components.
  - Version history starts fresh here; the pre-fork history stays in the
    `plugin-br-pix-switch` chart, which remains published and unchanged.
  - MongoDB removed from the chart entirely: the `mongodb` subchart dependency,
    the `global.externalMongoDefinitions` bootstrap Job, the `MONGO_URL` /
    `MONGO_DB_NAME` env vars on `dict-hub` and the Mongo branch of the
    wait-for-dependencies init container. No Pix Lerian component reads Mongo -
    `dict-hub` state lives entirely in Postgres.

- **Fixes**
  - `values.schema.json` now rejects the retired
    `global.externalPostgresDefinitions.pixswitchCredentials` with an error that
    names the key, by putting a `false` subschema on the property instead of a
    `not` on the parent object. The rejection itself is not new; the message
    was `'not' failed` and named nothing an operator could act on. The chart
    README gained a "Migrating values from the retired key" section with the
    exact error text and the two edits a values file needs.
  - `ORGANIZATION_ID` is documented the same way in all three places that
    describe it. The README claimed it was "not read by `dictProxy` or
    `pixauto`" in the same sentence that said a value on `pixauto` refuses the
    boot, and `values-template.yaml` called it inert. Six workloads bind it --
    `spi`, `dictHub`, `dictHubVsync`, `dictProxy`, `cobHub` and `pixauto` -- as
    the single-tenant fallback behind the domain's Systemplane
    `organization_id` key; on `pixauto` with neither source set every request
    answers 403 `TENANT_CONFIG_NOT_FOUND`. The multi-tenant rule is unchanged.
  - `values-template.yaml` now states, at each of the five Systemplane
    workloads, that `SYSTEMPLANE_SECRET_MASTER_KEY` is required and must be
    non-empty, and which gate applies (`ENV_NAME` for four of them,
    `DEPLOYMENT_MODE` for `adapterLerianSystemplane`). The template ships
    `ENV_NAME: "production"` on the workloads it enables, which turns that
    requirement on, while the key itself was an unannotated empty string. The
    value stays empty on purpose -- the template carries no credential material
    -- and now points at `useExistingSecret` / `existingSecretName` instead.
  - The migration Jobs now declare `seccompProfile.type: RuntimeDefault` at pod
    level. They already ran as UID/GID 1000 with `runAsNonRoot`,
    `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]` and a
    read-only root filesystem, but a namespace enforcing Pod Security
    `restricted` rejects a pod that leaves the seccomp profile unset, so the
    pre-install hook failed there before any schema was applied.
  - `ingressClassName` is quoted at all three sites in this chart
    (`_helpers.tpl`, `adapter-lerian/ingress.yaml`,
    `adapter-provider-mock/ingress.yaml`). An unquoted class name that looks
    like a scalar of another type -- `className: "123"` -- rendered as the YAML
    integer `123`, which the API server rejects for a string field.
  - `values-template.yaml` now ships `dictProxy` and `cobProxy` as
    `enabled: false`. The template enabled both while the chart's own README
    states that hub-only is the supported production shape, that the proxy tier
    carries no business flow, and that every business request sent to a proxy
    returns 404 while `health` and `readyz` stay green -- and its "Example
    topologies" section spells out this exact pair as `false`. The value was
    inherited from the fork source, `plugin-br-pix-switch/values-template.yaml`,
    which had the same. Operators who genuinely need the tier can still enable
    it; the template no longer stands two workloads up by default.
  - `values-template.yaml` now sets `ENV_NAME: "production"` on every component
    it enables. It enables nine (`spi`, `spiSystemplane`, `dictHub`,
    `dictHubVsync`, `dictProxy`, `dictSystemplane`, `cobHub`, `cobProxy`,
    `cobSystemplane`) and only `spi` carried the key, so the other eight
    inherited `"development"` from `values.yaml`. Two consequences, both in a
    file whose whole purpose is to describe a production deployment: a
    Systemplane skips the `SYSTEMPLANE_SECRET_MASTER_KEY` requirement when
    `ENV_NAME` is `local` or `development`, and the template ships that key
    empty, so the three enabled Systemplanes booted with secret encryption
    disabled under `DEPLOYMENT_MODE: byoc`; and `SWAGGER_ENABLED`, unset in both
    values files, resolves to `envName != "production"`, so `dictHub`,
    `dictProxy`, `cobHub` and `cobProxy` served `/docs` and `/openapi.json`. The
    `values.yaml` default is deliberately unchanged -- flipping it is a separate
    and breaking decision.
  - `extraEnvVars` no longer produces a duplicate `env` entry. All 14
    deployments emit `HOST_IP` and `OTEL_EXPORTER_OTLP_ENDPOINT` from the
    downward API when telemetry is on and `configmap.OTEL_EXPORTER_OTLP_ENDPOINT`
    is empty, then iterate `extraEnvVars` -- and the guard only ever inspected
    the configmap, so an `extraEnvVars` entry with either name rendered a second
    entry of the same name. The guard now also checks the resolved
    `extraEnvVars`, suppressing the chart's default for exactly the name the
    operator claims. Precedence is unchanged: the operator's value still wins,
    now as the only entry rather than as the last of two. The chart's
    `OTEL_EXPORTER_OTLP_ENDPOINT` default is also dropped when the operator
    claims `HOST_IP`, since its `$(HOST_IP)` would otherwise be a forward
    reference that Kubernetes does not expand. A render with no colliding key is
    unchanged.
  - An explicit `0` is no longer discarded on four Job/probe knobs. Go templates
    treat `0` as empty, so `default` silently substituted the chart default:
    `migrations.ttlSecondsAfterFinished: 0` rendered as `300`,
    `migrations.backoffLimit: 0` as `3`, and
    `readinessProbe`/`livenessProbe.initialDelaySeconds: 0` as `10`/`5`. The
    migration knobs are typed `{"type":"integer","minimum":0}` in
    `values.schema.json` on all five migrating components, so `0` was always an
    admitted value that never took effect. `_migrations.tpl` now reads both keys
    with `hasKey`, the idiom the same file already uses for `migrations.enabled`,
    and the 28 probe lines across the 14 deployments go through a new
    `plugin-br-pix-lerian.probeInitialDelay` helper that defaults on key
    presence. Only `initialDelaySeconds` changed: `periodSeconds`,
    `timeoutSeconds`, `successThreshold` and `failureThreshold` have a
    Kubernetes minimum of 1, so `default` is harmless there. A render with no
    overrides is byte-identical to before.
  - The bootstrap Postgres Jobs (`templates/bootstrap-postgres.yaml`) now carry a
    security context. They were the only workload in the chart without one,
    while the chart's own migration Job has been hardened since it was written:
    the two containers (`busybox:1.37`, `postgres:17`) now run as UID/GID 65532
    with `runAsNonRoot`, `allowPrivilegeEscalation: false`,
    `readOnlyRootFilesystem: true` and `capabilities.drop: ["ALL"]`, under a
    pod-level `seccompProfile: RuntimeDefault`. This is what the Jobs need to be
    admitted in a namespace enforcing PodSecurity `restricted`. Because the
    bootstrap script writes `/tmp/bootstrap-set-password.sql` to keep the role
    password off the process table, the `psql` container also gets an `emptyDir`
    mounted at `/tmp`. The script itself is unchanged. Modelled on
    `charts/streaming-hub/templates/bootstrap-postgres.yaml`.

- **Notes**
  - This chart releases as `2.1.0`. `2.1.0-beta.2` was published to
    `oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm` carrying
    `appVersion: 1.0.0-beta.101`, and a published OCI artifact is immutable, so
    that version is not reused here. `2.1.0` continues the line the chart it
    replaces occupied (`plugin-br-pix-switch-helm` 2.0.0) and is not yet
    published under either name.
  - The `pixswitch` Postgres role keeps its name. An audit of
    `lerian-internal-gitops` at commit `65836367` found the value pinned in four
    of the six environments, in three keys each, each backed by existing state;
    the `initdb` script that creates the role only runs against an empty data
    directory and will not re-run, and the remaining two environments provision
    the role outside the chart's tree with their DSNs in Vault. Changing the
    default would create a second role with no privileges on the five existing
    databases while the applications kept authenticating as the old one.
    Renaming the role is a data operation and belongs in its own change,
    sequenced with the GitOps values that pin it. See the chart README,
    "Why the Postgres role is still named `pixswitch`".
  - Selectors are a new identity: this chart is installed as a new release, not
    upgraded in place over an existing `plugin-br-pix-switch` release.
  - Database identifiers are deliberately unchanged (`pix-spi`, `pix-dict`,
    `pix-cob`, `pix-adapter-lerian`, `pix-pixauto`), as is the shared
    `pixswitch` Postgres role - renaming those would require migrating existing
    GRANTs.
  - Pix Automatico (`pixauto`, `pixautoSystemplane`) stays `enabled: false` by
    default, so this single chart serves both of the `plugin-br-pix-switch`
    deployment lines it replaces (`plugin-br-pix-switch-v2.1.0-beta.7` and
    `plugin-br-pix-switch-v2.1.0-beta.12`).
