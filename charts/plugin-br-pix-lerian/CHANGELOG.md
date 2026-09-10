# Plugin-br-pix-lerian Changelog

## Unreleased

- **Removals**
  - `LICENSE_ORGANIZATION_IDS` dropped from `values.yaml` and
    `values-template.yaml` (four components each). The name does not exist
    anywhere in the application — a repository-wide search of
    `plugin-br-pix-lerian` returns no hit — so the key configured nothing. The
    license organization list is bound to `ORGANIZATION_IDS` (`pkg/config`
    `BaseConfig.LicenseOrganizationIDs`), which is the name to use. No
    behaviour changes: removing a key nothing reads cannot alter what any
    component receives, and every rendered environment keeps its object count.
    If your own values carry the old spelling, rename it.

- **Breaking changes**
  - `global.externalPostgresDefinitions.pixswitchCredentials` renamed to
    `pixLerianCredentials`. There is no alias, and `values.schema.json` rejects
    the retired key so a stale override cannot silently stop taking effect.
    Rename the key in your values.
  - The bootstrap Jobs' environment variable `DB_PASSWORD_PIXSWITCH` renamed to
    `DB_PASSWORD_PIX_LERIAN`. An external Secret named by
    `pixLerianCredentials.useExistingSecret.name` must carry the new key.

- **Features**
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

- **Notes**
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

## [2.1.0-beta.13](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.1.0-beta.13)

- **Features**
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

- **Notes**
  - Selectors are a new identity: this chart is installed as a new release, not
    upgraded in place over an existing `plugin-br-pix-switch` release.
  - Database identifiers are deliberately unchanged (`pix-spi`, `pix-dict`,
    `pix-cob`, `pix-adapter-lerian`, `pix-pixauto`), as is the shared
    `pixswitch` Postgres role - renaming those would require migrating existing
    GRANTs.
  - Pix Automatico (`pixauto`, `pixautoSystemplane`) stays `enabled: false` by
    default, so this single chart serves both the 2.1.0-beta.7 and
    2.1.0-beta.12 deployment lines.
