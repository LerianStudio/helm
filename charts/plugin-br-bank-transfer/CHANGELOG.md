# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2024-03-24

### Changed
- Renamed chart from `plugin-br-bank-transfer-jd` to `plugin-br-bank-transfer`
- Fixed auth env var names to match source code:
  - `AUTH_ENABLED` → `PLUGIN_AUTH_ENABLED`
  - `AUTH_SERVICE_ADDRESS` → `PLUGIN_AUTH_ADDRESS`
  - `ORGANIZATION_IDS` → `TENANT_IDS`
- Updated image repository to `ghcr.io/lerianstudio/plugin-br-bank-transfer`
- Updated MongoDB database default to `plugin_br_bank_transfer`
- Updated OTEL service name to `plugin-br-bank-transfer`

### Added
- `PLUGIN_AUTH_CLIENT_ID` - Auth client identifier
- `PLUGIN_AUTH_CLIENT_SECRET` - Auth client secret (in secrets)
- `CRM_AUTH_ENABLED`, `CRM_CLIENT_ID`, `CRM_CLIENT_SECRET` - CRM outbound M2M auth
- `FEES_AUTH_ENABLED`, `FEES_CLIENT_ID`, `FEES_CLIENT_SECRET` - Fees outbound M2M auth
- `SYSTEMPLANE_BACKEND`, `SYSTEMPLANE_POSTGRES_SCHEMA` - Systemplane config
- `SYSTEMPLANE_SECRET_MASTER_KEY`, `SYSTEMPLANE_POSTGRES_DSN` - Systemplane secrets
