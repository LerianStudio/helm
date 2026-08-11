# Lerian Consul Changelog

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/lerian-consul-v1.0.0)

- **Features:**
  - Initial Lerian wrapper for the official `hashicorp/consul` chart, pinned exactly at `1.6.10` (Consul `1.20.6`).
  - Curated as a single-node (non-HA) service-discovery backend for `lib-service-discovery`.
  - Disabled unused Consul components by default: client DaemonSet, UI, catalog-sync, Connect/mesh injection, and all gateways.
  - ACL system managed by default (`global.acls.manageSystemACLs=true`) and gossip encryption auto-generated (`global.gossipEncryption.autoGenerate=true`).
  - TLS off by default with a documented enable path; ClusterIP-only services (no LoadBalancer/NodePort/Ingress).

-----------------
