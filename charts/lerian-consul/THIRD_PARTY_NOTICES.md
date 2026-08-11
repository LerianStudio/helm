# Third-Party Notices — lerian-consul

This chart is a thin wrapper. Packaging it (`helm package`) embeds the upstream
HashiCorp Consul Helm chart as a dependency, and installing it deploys the
Consul container image. Both are third-party works with their own licenses.

## 1. HashiCorp Consul Helm chart (bundled in the package)

- Component: `consul` Helm chart, version `1.6.10` (from `hashicorp/consul-k8s`).
- License: **Mozilla Public License 2.0 (MPL-2.0)** — full text in
  [`licenses/MPL-2.0.txt`](licenses/MPL-2.0.txt).
- Copyright (c) HashiCorp, Inc.
- Source: https://github.com/hashicorp/consul-k8s
- Redistribution: the `helm package` output includes this chart's source under
  `charts/`. MPL-2.0 requires this notice and the license text to travel with it.

## 2. HashiCorp Consul (the deployed binary/image)

- Component: `hashicorp/consul` image, version `1.20.6`.
- License: **Business Source License 1.1 (BSL-1.1)** — Change License MPL-2.0,
  Change Date four years after each release.
- Full text: https://github.com/hashicorp/consul/blob/v1.20.6/LICENSE
- This chart does NOT redistribute the image; the cluster pulls it from
  HashiCorp at deploy time. See the "License" section of `README.md` for the
  Additional Use Grant and what it means for Lerian/BYOC use.
