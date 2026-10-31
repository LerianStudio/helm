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

### Midaz Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/deploy-midaz-using-helm) for deployment guides.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/midaz).

#### Application Version Mapping

| Chart Version | Ledger Version | CRM Version |
| :---: | :---: | :---: |
| `10.0.4` | 4.4.0 | 3.8.4 |
-----------------

### Plugin Access Manager Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/access-manager) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-access-manager).

#### Application Version Mapping

| Chart Version | Auth Version | Identity Version | Caradhras Version |
| :---: | :---: | :---: | :---: |
| `10.1.3` | 3.14.0 | 3.14.0 | 1.8.6 |
-----------------

### Plugin Fees Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/fees/fees-overview) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-fees).

#### Application Version Mapping

| Chart Version | Fees Version | UI Version |
| :---: | :---: | :---: |
| `9.0.0` | 3.4.0 | `3.0.0` |

-----------------

### Reporter

See the [official documentation](https://docs.lerian.studio/en/reporter) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/reporter).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version |
| :---: | :---: | :---: |
| `5.1.0` | 4.6.0 | 4.6.0 |
-----------------

### Plugin BR Bank Transfer 

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/bank-transfer/bank-transfer) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-bank-transfer).

#### Application Version Mapping

| Chart Version | bankTransfer Version |
| :---: | :---: |
| `3.0.3` | 3.4.0 |
-----------------



### Plugin BR Pix JD

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-jd).

Multi-component chart (`api` + `worker`) for the Go PIX Direct plugin.
The app publishes one image per entry point — `plugin-br-pix-jd` (`cmd/app`) and
`plugin-br-pix-jd-worker` (`cmd/worker`) — and the release pipeline builds only the
component that changed, so their tags may legitimately differ.

#### Application Version Mapping

| Chart Version | API Version | Worker Version |
| :---: | :---: | :---: |
| `0.5.8` | 1.5.0 | 1.5.0 |
-----------------

### BR JD Courier

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/br-jd-courier).

Multi-component chart for the JD Courier: four role Deployments (`spb-consumer`,
`spb-sender`, `pix-ingress`, `admin`) off one image, `ghcr.io/lerianstudio/br-jd-courier`.
The release bumps `jd-courier.image.tag`, which is the column below.

#### Application Version Mapping

| Chart Version | Br-Jd-Courier Version |
| :---: | :---: |
| `2.1.2` | 1.2.1 |
-----------------

### Plugin BR Pix Lerian

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-lerian).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `2.0.1` | 1.1.0 |
-----------------

### Plugin BR Pix Indirect BTG

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/pix/indirect-pix-btg) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-indirect-btg).

#### Application Version Mapping

| Chart Version | Pix Version | Inbound Version | Outbound Version | Reconciliation Version | Schedule Version |
| :---: | :---: | :---: | :---: | :---: | :---: |
| `5.2.0` | 1.12.0 | 1.12.0 | 1.12.0 | 1.12.0 | 1.12.0 |

-----------------

### Plugin BR Payments

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-payments).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.1.2` | 1.0.0-beta.9 |
-----------------

### Fetcher

See the [official documentation](https://docs.lerian.studio/en/fetcher) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/fetcher).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version |
| :---: | :---: | :---: |
| `4.0.0` | 3.1.1 | 3.1.1 |
-----------------

### Tracer

For more details, check out the [official documentation](https://docs.lerian.studio/en/tracer).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/tracer).

#### Application Version Mapping

| Chart Version | Tracer Version |
| :---: | :---: |
| `3.0.0` | 1.0.0 |
-----------------

### Alloy Lerian

Telemetry collection agent for client clusters (BYOC). Replaces Otel Collector Lerian in the client-side collection role.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/alloy-lerian).

#### Application Version Mapping

| Chart Version | Alloy Version |
| :---: | :---: |
| `2.0.3` | 1.18.1 |
-----------------

### Otel Collector Lerian

> [!WARNING]
> **Deprecated.** Superseded by [Alloy Lerian](#alloy-lerian) for client-side
> collection. New installations should use Alloy Lerian; existing ones remain
> supported while they migrate.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/otel-collector-lerian).

#### Application Version Mapping

| Chart Version | Otel Version |
| :---: | :---: |
| `4.3.0` | 0.142.0 |
-----------------

### Product Console

See the [official documentation](https://docs.lerian.studio/en/console) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/product-console).

#### Application Version Mapping

| Chart Version | Console Version |
| :---: | :---: |
| `4.4.7` | 3.0.0 |
-----------------

### Plugin BC Correios

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-bc-correios).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `3.0.0` | 1.2.0 |

-----------------

### Notifications

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/notifications).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.0.0-beta.4` | 0.1.0 |
-----------------

### BR SISBAJUD

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/br-sisbajud).

#### Application Version Mapping

| Chart Version | App Version | Migrations Version |
| :---: | :---: | :---: |
| `1.4.1` | 1.1.0 | 1.1.0 |
| `1.1.0` | `1.0.0-beta.109` | `1.0.0-beta.109` |
-----------------

### Plugin BR SISBAJUD

SISBAJUD executor: pulls judicial orders from the Sisbajud Mensageria over TLS (optional mTLS), executes them on Midaz and posts the results back. Complements `br-sisbajud`, which deploys the Mensageria the executor calls; run both.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-sisbajud).

#### Application Version Mapping

| Chart Version | Sisbajud Version | Migrations Version |
| :---: | :---: | :---: |
| `1.1.0` | 1.1.0 | 1.1.0 |
-----------------

### Plugin BR TED Lerian

TED transfers plugin for Midaz.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-ted-lerian).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.0.0` | 1.0.0-beta.33 |
-----------------

### BR Consignado GW

API gateway and same-origin operator console for the Dataprev consignado rail.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/br-consignado-gw).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.1.0` | `1.3.0-beta.36` |
-----------------

### BR STA

BACEN STA (Sistema de Transferência de Arquivos): file transfers to and from BACEN, operator credentials and the audit trail.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/br-sta).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version | Migrations Version |
| :---: | :---: | :---: | :---: |
| `1.0.2` | 1.0.0 | 1.0.0 | 1.0.0 |
-----------------

### Agent

Lerian BYOC agent: runs in your Kubernetes cluster, polls the Lerian control plane over an outbound-only connection and executes the Helm operations it is assigned.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/agent).

#### Application Version Mapping

| Chart Version | Agent Version |
| :---: | :---: |
| `1.0.3` | 1.0.2 |
-----------------

### Streaming Hub

Event delivery edge: consumes lib-streaming CloudEvents from Redpanda and fans them out per tenant to webhooks and queues.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/streaming-hub).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `2.0.0` | 3.0.0 |
-----------------

### Lerian Common (Library)

Library chart consumed by other Lerian charts — renders nothing on its own.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/lerian-common).

#### Application Version Mapping

| Chart Version |
| :---: |
| `2.4.2` |
-----------------

### System Facts

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/system-facts).

#### Application Version Mapping

| Chart Version | System-Facts Version |
| :---: | :---: |
| `1.1.0` | 1.1.0 |
-----------------

## License

Copyright 2024 Lerian Studio Ltd. Licensed under the Elastic License 2.0. See
[LICENSE](LICENSE).
