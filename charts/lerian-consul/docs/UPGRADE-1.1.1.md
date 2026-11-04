# Helm upgrade from v1.1.0 to v1.1.1

## Topics

- [Consul DNS off in the subchart](#consul-dns-off-in-the-subchart)
- [Gossip encryption in the HA example](#gossip-encryption-in-the-ha-example)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)

---

## Consul DNS off in the subchart

The chart already turned off the DNS listener of the Consul agent (`ports.dns: -1`), because lib-service-discovery uses only the HTTP API. v1.1.1 also sets `consul.dns.enabled: false`, so the upstream subchart no longer renders two DNS objects:

- the `<consul-fullname>-dns` Service on port 53
- the `-allow-dns` flag on the ACL init Job, which lets the anonymous token read DNS

| Setting | v1.1.0 | v1.1.1 |
|---------|--------|--------|
| `consul.dns.enabled` | not set (the subchart renders DNS) | `false` |

**What you need to do:**

- Nothing, unless a workload in your cluster calls the `<consul-fullname>-dns` Service. The upgrade deletes that Service, so move those callers to the HTTP API on port 8500.
- If your values set `consul.dns.enabled: true`, your value still applies and the DNS objects stay.

---

## Gossip encryption in the HA example

The post-install notes of a single-server install now add `--set consul.global.gossipEncryption.autoGenerate=true` to the example that scales to three servers. The default values do not change.

**What you need to do:**

- Single server (the default): nothing.
- When you scale to several servers, set the flag as the notes show:

```bash
helm upgrade lerian-consul oci://ghcr.io/lerianstudio/lerian-consul --version 1.1.1 -n lerian-consul \
  --set consul.server.replicas=3 \
  --set consul.server.bootstrapExpect=3 \
  --set consul.global.gossipEncryption.autoGenerate=true
```

- If you already run several servers without gossip encryption, do not turn it on with a plain `helm upgrade`. Follow HashiCorp's procedure to [enable gossip encryption on an existing datacenter](https://developer.hashicorp.com/consul/docs/secure/encryption/gossip/enable).

---

## Preview changes before upgrading

```bash
helm diff upgrade lerian-consul oci://ghcr.io/lerianstudio/lerian-consul --version 1.1.1 -n lerian-consul
```

> **Note:** This command needs the [helm-diff plugin](https://github.com/databus23/helm-diff): `helm plugin install https://github.com/databus23/helm-diff`.

---

## Command to upgrade

```bash
helm upgrade lerian-consul oci://ghcr.io/lerianstudio/lerian-consul --version 1.1.1 -n lerian-consul
```
