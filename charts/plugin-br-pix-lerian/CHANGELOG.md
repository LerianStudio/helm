# Plugin-br-pix-lerian Changelog

## [2.1.0-beta.13](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-lerian-v2.1.0-beta.13)

- **Features**
  - Initial release of the `plugin-br-pix-lerian` chart, forked from
    `plugin-br-pix-switch` at tag `plugin-br-pix-switch-v2.1.0-beta.12` as part
    of the Pix Switch to Pix Lerian product rename.
  - Chart identity renamed end to end: chart name (`plugin-br-pix-lerian-helm`),
    helper templates, resource names and selectors, the 15 component image
    repositories (`ghcr.io/lerianstudio/plugin-br-pix-lerian-*`), the 15
    `OTEL_LIBRARY_NAME` values (`github.com/LerianStudio/plugin-br-pix-lerian`)
    and the in-cluster `*_BASE_URL` defaults that resolve to this chart's own
    Services.
  - The three adapter-lerian components now carry component-scoped
    `APPLICATION_NAME` values (`pix-adapter-lerian`,
    `pix-adapter-lerian-consumer`, `pix-adapter-lerian-systemplane`), matching
    the other twelve components.
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
