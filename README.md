# Lerian Studio Helm Charts

![banner](image/README/midaz-banner.png)

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://github.com/LerianStudio/helm/blob/main/LICENSE)
[![Discord](https://img.shields.io/badge/Discord-Lerian%20Studio-%237289da.svg?logo=discord)](https://discord.gg/DnhqKwkGv3)

### Midaz Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/deploy-midaz-using-helm) for deployment guides.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/midaz).

#### Application Version Mapping

| Chart Version | Ledger Version | CRM Version | Onboarding Version | Transaction Version |
| :---: | :---: | :---: | :---: | :---: |
| `5.7.0` | 3.5.3 | 3.5.3 | 3.5.3 | 3.5.3 |
-----------------

### Plugin Access Manager Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/access-manager) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-access-manager).

#### Application Version Mapping

| Chart Version | Auth Version | Identity Version |
| :---: | :---: | :---: |
| `6.0.0` | 2.4.4 | 2.1.1 |

> **⚠️ Migration note for 6.0.0-beta.1:** The `auth.backend.migrations.image` and `auth.initUser.image` values changed from a single string to an object with `repository`, `tag`, and `pullPolicy` fields. Existing overrides using the old string format (e.g. `image: "ghcr.io/lerianstudio/casdoor-migrations:v1"`) will continue to work thanks to backward compatibility, but we recommend updating to the new format:
> ```yaml
> # Old format (still supported):
> auth:
>   backend:
>     migrations:
>       image: "ghcr.io/lerianstudio/casdoor-migrations:v1.0.0"
>
> # New format (recommended):
> auth:
>   backend:
>     migrations:
>       image:
>         repository: ghcr.io/lerianstudio/casdoor-migrations
>         tag: "v1.0.0"
>         pullPolicy: Always
> ```

-----------------

### Plugin CRM Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/crm/crm-overview) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-crm).

#### Application Version Mapping

| Chart Version | CRM Version | UI Version |
| :---: | :---: | :---: |
| `4.0.0` | 3.5.1 | `2.0.0` |
-----------------

### Plugin Fees Helm Chart

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/fees/fees-overview) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-fees).

#### Application Version Mapping

| Chart Version | Fees Version | UI Version |
| :---: | :---: | :---: |
| `4.1.2` | 3.0.8 | `3.0.0` |
-----------------

### Reporter

See the [official documentation](https://docs.lerian.studio/en/reporter) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/reporter).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version |
| :---: | :---: | :---: |
| `2.0.0` | 1.1.1 | 1.1.0 |
-----------------

### Plugin BR Bank Transfer JD

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/bank-transfer/bank-transfer-jd) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-bank-transfer-jd).

#### Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.1.0-beta.1` | 1.0.0-beta.1 |
-----------------

### Plugin BR Pix Direct JD

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/pix/direct-pix-jd) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-direct-jd).

#### Application Version Mapping

| Chart Version | Pix Version | Job Version |
| :---: | :---: | :---: |
| `1.2.6` | 1.2.1-beta.7 | 1.2.1-beta.7 |
-----------------

### Plugin BR Pix Indirect BTG

See the [official documentation](https://docs.lerian.studio/en/midaz/plugins/pix/indirect-pix-btg) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/plugin-br-pix-indirect-btg).

#### Application Version Mapping

| Chart Version | Pix Version | Inbound Version | Outbound Version | Reconciliation Version |
| :---: | :---: | :---: | :---: | :---: |
| `2.1.1` | 1.5.1 | 1.5.1 | 1.5.1 | 1.5.1 |
-----------------

### Fetcher

See the [official documentation](https://docs.lerian.studio/en/fetcher) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/fetcher).

#### Application Version Mapping

| Chart Version | Manager Version | Worker Version |
| :---: | :---: | :---: |
| `2.0.3` | 1.2.0 | 1.2.0 |
-----------------

### Underwriter

For more details, check out the [official documentation](https://docs.lerian.studio/en/underwriter).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/underwriter).

#### Application Version Mapping

| Chart Version | Underwriter Version |
| :---: | :---: |
| `1.0.1` | 1.0.0 |
-----------------

### Matcher

For more details, check out the [official documentation](https://docs.lerian.studio/en/matcher#matcher).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/matcher).

#### Application Version Mapping

| Chart Version | Matcher Version |
| :---: | :---: |
| `2.1.1` | 1.0.0 |

### Flowker

For more details, check out the [official documentation](https://docs.lerian.studio/en/flowker).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/flowker).

#### Application Version Mapping

| Chart Version | Flowker Version |
| :---: | :---: |
| `1.0.0` | 1.0.0-beta.22 |
-----------------

### Tracer

For more details, check out the [official documentation](https://docs.lerian.studio/en/tracer).

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/tracer).

#### Application Version Mapping

| Chart Version | Tracer Version |
| :---: | :---: |
| `1.0.0` | 1.0.0 |
-----------------

### Otel Collector Lerian

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/otel-collector-lerian).

#### Application Version Mapping

| Chart Version | Otel Version |
| :---: | :---: |
| `2.2.1` | 2.1.0 |
-----------------

### Product Console

See the [official documentation](https://docs.lerian.studio/en/console) for details.

For implementation and configuration details, see the [README](https://charts.lerian.studio/charts/product-console).

#### Application Version Mapping

| Chart Version | Console Version |
| :---: | :---: |
| `2.0.0-beta.3` | 1.5.0 |
-----------------
