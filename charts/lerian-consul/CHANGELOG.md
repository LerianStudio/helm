# Lerian-consul Changelog

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/lerian-consul-v1.1.1)

Features:
- State the `lerian-consul` `1.0.0` move as the chart's own path. (@fredcamaral)

Fixes:
- Disable Consul DNS in `lerian-consul`. (@fredcamaral)
- Add gossip encryption to `lerian-consul` HA hint. (@fredcamaral)

Improvements:
- Apply review fixes to chart documentation and upgrade guides. (@gandalf-at-lerian)
- Add verified upgrade guides for `1.1.0`. (@fredcamaral)
- Correct chart documentation against templates and app code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-consul-v1.1.0...lerian-consul-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/lerian-consul-v1.1.1)

Features:
- State the `lerian-consul` `1.0.0` move as the chart's own path. (@fredcamaral)

Fixes:
- Disable Consul DNS in `lerian-consul`. (@fredcamaral)
- Add gossip encryption to `lerian-consul` HA hint. (@fredcamaral)

Improvements:
- Apply review fixes to chart documentation and upgrade guides. (@gandalf-at-lerian)
- Add verified upgrade guides for `1.1.0`. (@fredcamaral)
- Correct chart documentation against templates and app code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-consul-v1.1.0...lerian-consul-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/lerian-consul-v1.1.1)

Features:
- State the `lerian-consul` `1.0.0` move as the chart's own path. (@fredcamaral)

Fixes:
- Disable Consul DNS in `lerian-consul`. (@fredcamaral)
- Add gossip encryption to `lerian-consul` HA hint. (@fredcamaral)

Improvements:
- Apply review fixes to chart documentation and upgrade guides. (@gandalf-at-lerian)
- Add verified upgrade guides for `1.1.0`. (@fredcamaral)
- Correct chart documentation against templates and app code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-consul-v1.1.0...lerian-consul-v1.1.1)

---

## [1.1.1](https://github.com/LerianStudio/helm/releases/tag/lerian-consul-v1.1.1)

Features:
- State the `lerian-consul` `1.0.0` move as the chart's own path. (@fredcamaral)

Fixes:
- Disable Consul DNS in `lerian-consul`. (@fredcamaral)
- Add gossip encryption to `lerian-consul` HA hint. (@fredcamaral)

Improvements:
- Apply review fixes to chart documentation and upgrade guides. (@gandalf-at-lerian)
- Add verified upgrade guides for `1.1.0`. (@fredcamaral)
- Correct chart documentation against templates and app code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-consul-v1.1.0...lerian-consul-v1.1.1)

---

## [1.1.0](https://github.com/LerianStudio/helm/releases/tag/lerian-consul-v1.1.0)

Features:
- Deploy lerian-consul using Consul `2.1.0`. (@fredcamaral)

Improvements:
- Remove the bootstrap secret during a fresh installation of lerian-consul. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/lerian-consul-v1.0.0...lerian-consul-v1.1.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/lerian-consul-v1.0.0)

- **Features:**
  - Initial Lerian wrapper for the official `hashicorp/consul` chart, pinned exactly at `1.6.10` (Consul `1.20.6`).
  - Curated as a single-node (non-HA) service-discovery backend for `lib-service-discovery`.
  - Disabled unused Consul components by default: client DaemonSet, UI, catalog-sync, Connect/mesh injection, and all gateways.
  - ACL system managed by default (`global.acls.manageSystemACLs=true`). Gossip encryption is OFF at the single-node default (no server-to-server gossip to encrypt); a render-time check requires it before scaling past one server.
  - TLS off by default with a documented enable path; ClusterIP-only services (no LoadBalancer/NodePort/Ingress).

-----------------

