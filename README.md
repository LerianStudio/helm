# Lerian Studio Helm Charts

![banner](image/README/midaz-banner.png)

[![License: Elastic-2.0](https://img.shields.io/badge/License-Elastic_2.0-blue.svg)](https://github.com/LerianStudio/helm/blob/main/LICENSE)
[![Discord](https://img.shields.io/badge/Discord-Lerian%20Studio-%237289da.svg?logo=discord)](https://discord.gg/DnhqKwkGv3)

## Chart Maintenance

- Chart contract: [`docs/helm-chart-standard.md`](docs/helm-chart-standard.md)
- Render inventory (on demand): `cd .github/scripts && go run ./validate-helm-charts --root ../.. --render-inventory --output /tmp/helm-render-inventory.md`
- Static validation: `cd .github/scripts && go run ./validate-helm-charts --root ../.. --strict`
- Render validation: `cd .github/scripts && go run ./validate-helm-charts --root ../.. --render-gate --all`

CI enforces the static contract and render gate. Required production secrets are represented by dummy sample values under `.github/configs/helm-render-values/` only so charts can render in CI without publishing credentials.

> **Maintenance line.** This branch is the `5.2.x` chart line of `plugin-br-pix-indirect-btg`,
> serving the app's `1.12.x` maintenance line — the chart and app numbers do not
> match, and the binding lives in the chart's `appVersion`. Only this chart is released from here;
> the other charts in the tree are a frozen snapshot. Mainline charts live on the default branch.

### Plugin BR Pix Indirect BTG

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/pix/indirect-pix-btg) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-indirect-btg).

#### Application Version Mapping

| Chart Version | Pix Version | Inbound Version | Outbound Version | Reconciliation Version | Schedule Version |
| :---: | :---: | :---: | :---: | :---: | :---: |
| `5.2.2` | 1.12.0 | 1.12.0 | 1.12.0 | 1.12.0 | 1.12.0 |

-----------------
