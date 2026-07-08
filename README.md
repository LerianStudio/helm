# Lerian Studio Helm Charts

![banner](image/README/midaz-banner.png)

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://github.com/LerianStudio/helm/blob/main/LICENSE)
[![Discord](https://img.shields.io/badge/Discord-Lerian%20Studio-%237289da.svg?logo=discord)](https://discord.gg/DnhqKwkGv3)

## Chart Maintenance

- Chart contract: [`docs/helm-chart-standard.md`](docs/helm-chart-standard.md)
- Render inventory (on demand): `cd .github/scripts && go run ./validate-helm-charts --root ../.. --render-inventory --output /tmp/helm-render-inventory.md`
- Static validation: `cd .github/scripts && go run ./validate-helm-charts --root ../.. --strict`
- Render validation: `cd .github/scripts && go run ./validate-helm-charts --root ../.. --render-gate --all`

CI enforces the static contract and render gate. Required production secrets are represented by dummy sample values under `.github/configs/helm-render-values/` only so charts can render in CI without publishing credentials.

### Midaz Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/deploy-midaz-using-helm) for deployment guides.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/midaz).

#### Application Version Mapping

| Chart Version | Ledger Version | CRM Version |
| :---: | :---: | :---: |
| `8.5.0-beta.1` | 3.7.7 | 3.7.6 |
-----------------

### Plugin Access Manager Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/access-manager) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-access-manager).

#### Application Version Mapping

| Chart Version | Auth Version | Identity Version |
| :---: | :---: | :---: |
| `8.3.0` | 2.6.7 | 2.4.5 |
-----------------

### Plugin Fees Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/fees/fees-overview) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-fees).

#### Application Version Mapping

| Chart Version | Fees Version | UI Version |
| :---: | :---: | :---: |
| `7.0.0` | 3.2.1 | `3.0.0` |

-----------------

### BR SPI Helm Chart

Brazilian SFN — SPI / Pix rail (components: core, spi, brcode, dict, plus a dedicated schema-migration Job).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/br-spi).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `0.1.0-beta.1` | `0.1.0` |
-----------------

### Reporter

See the [official documentation](https://docs.lerian.studio/en/reporter) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/reporter).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version |
| :---: | :---: | :---: |
| `3.1.1` | 2.1.2 | 2.1.2 |
-----------------

### Plugin BR Bank Transfer 

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/bank-transfer/bank-transfer) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-bank-transfer).

#### Application Version Mapping

| Chart Version | bankTransfer Version |
| :---: | :---: |
| `1.3.0-beta.1` | 1.0.0 |
-----------------



### Plugin BR Pix Direct JD

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/pix/direct-pix-jd) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-direct-jd).

#### Application Version Mapping

| Chart Version | Pix Version | Job Version |
| :---: | :---: | :---: |
| `3.0.0` | 1.2.1-beta.11 | 1.2.1-beta.12 |
-----------------

### Plugin BR Pix Switch

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-switch).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `2.1.0-beta.2` | 1.0.0-beta.1 |
-----------------

### Plugin BR Pix Indirect BTG

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/pix/indirect-pix-btg) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-indirect-btg).

#### Application Version Mapping

| Chart Version | Pix Version | Inbound Version | Outbound Version | Reconciliation Version |
| :---: | :---: | :---: | :---: | :---: |
| `3.4.0-beta.1` | 1.7.5 | 1.7.5 | 1.7.5 | 1.7.5 |

-----------------

### Plugin BR Payments

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-payments).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.1.0-beta.5` | 1.0.0-beta.9 |
-----------------

### Fetcher

See the [official documentation](https://docs.lerian.studio/en/fetcher) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/fetcher).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version |
| :---: | :---: | :---: |
| `3.0.0` | 1.4.2 | 1.4.2 |
-----------------

### Underwriter

For more details, check out the [official documentation](https://docs.lerian.studio/en/underwriter).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/underwriter).

#### Application Version Mapping

| Chart Version | Underwriter Version |
| :---: | :---: |
| `3.1.0-beta.1` | 1.0.0 |
-----------------

### Matcher

For more details, check out the [official documentation](https://docs.lerian.studio/en/matcher#matcher).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/matcher).

#### Application Version Mapping

| Chart Version | Matcher Version |
| :---: | :---: |
| `3.1.0-beta.2` | 1.0.0 |

### Flowker

For more details, check out the [official documentation](https://docs.lerian.studio/en/flowker).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/flowker).

#### Application Version Mapping

| Chart Version | Flowker Version |
| :---: | :---: |
| `3.0.0` | 1.0.0-beta.22 |
-----------------

### Tracer

For more details, check out the [official documentation](https://docs.lerian.studio/en/tracer).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/tracer).

#### Application Version Mapping

| Chart Version | Tracer Version |
| :---: | :---: |
| `2.2.0-beta.1` | 1.0.0 |
-----------------

### Otel Collector Lerian

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/otel-collector-lerian).

#### Application Version Mapping

| Chart Version | Otel Version |
| :---: | :---: |
| `4.1.0` | 0.142.0 |
-----------------

### Product Console

See the [official documentation](https://docs.lerian.studio/en/console) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/product-console).

#### Application Version Mapping

| Chart Version | Console Version |
| :---: | :---: |
| `3.1.0` | 1.6.0 |
-----------------

### Plugin BC Correios

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-bc-correios).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `2.2.0` | 1.0.0 |


### Go Boilerplate DDD

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/go-boilerplate-ddd).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `2.2.0-beta.2` | 1.0.0 |
-----------------

### Notifications

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/notifications).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.0.0-beta.4` | 0.1.0 |
-----------------

### Streaming Hub

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/streaming-hub).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.0.0-beta.3` | 1.0.0 |
-----------------

### BR STA

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/br-sta).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version |
| :---: | :---: | :---: |
| `1.0.0-beta.2` | 1.0.0-beta.32 | 1.0.0-beta.32 |
-----------------
