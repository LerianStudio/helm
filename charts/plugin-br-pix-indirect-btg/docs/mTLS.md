# Outbound BTG client mTLS

This chart can present a **client certificate (mutual TLS)** on the plugin's
outbound calls to the BTG API. It is **off by default** and fully
backward-compatible — nothing below is rendered unless `mtls.enabled: true`.

The certificate is applied to the two components that call BTG directly:
**`pix`** (the API) and **`reconciliation`** (the worker). It is independent of
the inbound webhook `MTLS_ENABLED` toggle (that one is a different, server-side
feature).

> **App requirement:** the application image must be built on **lib-commons
> ≥ v6.1.1** (e.g. app `1.9.0-rc.2`+). That is the version whose certificate
> loader accepts a **group-readable** key (mode `0440`) — see
> [Security model](#security-model). An older image will reject the key.

---

## Quick start

Minimal — reference a Secret you already have in the namespace:

```yaml
mtls:
  enabled: true
  secretName: "mtls"   # a Secret with keys tls.crt / tls.key (+ optional ca.crt)
```

Or let the chart create the Secret from inline material (see
[Providing the certificate](#providing-the-certificate)):

```yaml
mtls:
  enabled: true
  secretName: "mtls"
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    ...
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    ...
```

When enabled, each of `pix` and `reconciliation` gets:

| Env var (in the ConfigMap) | Value |
|---|---|
| `BTG_OUTBOUND_MTLS_ENABLED` | `"true"` |
| `CLIENT_TLS_CERT_FILE` | `<mountPath>/<certFileName>` (default `/etc/btg/mtls/tls.crt`) |
| `CLIENT_TLS_KEY_FILE` | `<mountPath>/<keyFileName>` (default `/etc/btg/mtls/tls.key`) |
| `CLIENT_TLS_CA_FILE` | `<mountPath>/<caFileName>` — **only if a CA is provided**; empty → system trust store |

The referenced Secret is mounted read-only at `mountPath` (`defaultMode: 0440`)
with the pod's `fsGroup` set.

---

## Providing the certificate

There is **one decision**: is `mtls.tls.crt` set or not?

### Mode A — chart-managed (`mtls.tls.crt` set)

The chart renders a `Secret` named `mtls.secretName` from `tls.crt` / `tls.key`
/ `ca.crt`. Use this for:

- **Quick tests** — paste literal PEM into the values.
- **GitOps with a render-time secret injector** — put a placeholder your tool
  resolves. Example with argocd-vault-plugin (AVP), keeping the cert in Vault and
  nothing sensitive in git:

  ```yaml
  mtls:
    enabled: true
    secretName: "mtls"
    tls.crt: "<path:secret/data/<env>/plugin-br-pix-indirect-btg/mtls#tls.crt>"
    tls.key: "<path:secret/data/<env>/plugin-br-pix-indirect-btg/mtls#tls.key>"
  ```

  The values are written into the Secret's `stringData`, so a literal PEM is
  base64-ed by Kubernetes and a placeholder is substituted to plaintext by the
  injector before apply. (Store **plaintext PEM** in Vault for this path.)

> ⚠️ **Never commit a real private key as literal PEM.** Literal `tls.key` in
> `values.yaml` lands in git, `helm get values`, and CI logs. Use it only for
> throwaway test material; for anything real use a placeholder (above) or Mode B.

When the chart manages the Secret, a `checksum/mtls` pod annotation is added, so
a `helm upgrade` that changes the cert **rolls the pods automatically** (needed
because the app snapshots the cert at startup — see [Rotation](#rotation)).

### Mode B — externally managed (`mtls.tls.crt` empty, the default)

Leave `tls.crt` empty and point `secretName` at a Secret provisioned by whatever
your cluster uses. The chart does **not** render any backend-specific object
(keeping it portable across clusters):

- **External Secrets Operator** — author an `ExternalSecret` that writes a Secret
  named `mtls`; the chart consumes it.
- **cert-manager** — a `Certificate` whose `secretName` is `mtls`.
- **Vault CSI / sealed-secrets / manual `kubectl create secret`** — same idea.

The Secret must carry the keys named by `certFileName` / `keyFileName`
(default `tls.crt` / `tls.key`) and, if used, `caFileName`.

---

## Configuration reference

| Key | Default | Description |
|---|---|---|
| `mtls.enabled` | `false` | Master switch. Off → nothing rendered. |
| `mtls.secretName` | `""` | Secret name. **Created** by the chart if `tls.crt` is set; otherwise **referenced** (must pre-exist). Required when enabled. |
| `mtls.tls.crt` | `""` | Client cert PEM (or a resolver placeholder). Setting it switches on Mode A. |
| `mtls.tls.key` | `""` | Private key PEM. Required when `tls.crt` is set. |
| `mtls.ca.crt` | `""` | Optional CA (verifies BTG's **server** cert). When set, `CLIENT_TLS_CA_FILE` is emitted. Empty → system trust store. |
| `mtls.mountPath` | `/etc/btg/mtls` | Where the cert dir is mounted. **Do not** use `/etc/ssl/certs` (it shadows the OS trust store). |
| `mtls.certFileName` | `tls.crt` | Secret key / file name for the cert → `CLIENT_TLS_CERT_FILE`. |
| `mtls.keyFileName` | `tls.key` | Secret key / file name for the key → `CLIENT_TLS_KEY_FILE`. |
| `mtls.caFileName` | `""` | Secret key / file name for the CA → `CLIENT_TLS_CA_FILE`. Auto-set to `ca.crt` when `mtls.ca.crt` is provided. |
| `mtls.fsGroup` | `1000` | Pod `fsGroup` so the non-root app can group-read the key. Match `runAsGroup`. |

---

## Security model

The plugin runs **non-root** (`runAsUser: 1000`). Kubernetes Secret volumes are
owned by `root`, so:

- An owner-only mode (`0400`) would be **unreadable** by uid 1000.
- Making it readable requires a **group** (or other) permission bit.

So the Secret is mounted at **`0440`** with the pod's **`fsGroup`**, which makes
the files `root:<fsGroup>` and group-readable — the app (in that group) can read
them. lib-commons v6's certificate loader accepts this (`0440`/`0640`) while
still rejecting group-**write** and **any** other/world bit. This is the same
shape cert-manager and Istio use to ship private keys to non-root pods.

There is **no init container** and **no third-party image**, and **no
PersistentVolume** — just the Secret volume.

---

## Rotation

The application **loads the certificate once at startup** into a static TLS
config (there is no hot-reload wired). Consequences:

- A Secret mounted as a volume has its files refreshed in place by the kubelet
  when the Secret changes — **but the app does not re-read them**.
- Therefore **rotating the cert requires a pod restart**
  (`kubectl rollout restart deploy/...`), regardless of how the Secret is
  provisioned.
- In **Mode A** (chart-managed), changing the cert and running `helm upgrade`
  triggers that restart automatically via the `checksum/mtls` annotation.

---

## Troubleshooting

- **`open /etc/btg/mtls/tls.crt: no such file or directory` at startup**, then
  the next pod is healthy → the pod started **before** the Secret was present
  (bootstrap race). The app fail-fasts and CrashLoops until the Secret exists,
  then recovers. Ensure the Secret is applied before the workload (sync-wave /
  `needs` in GitOps) to avoid the first crashed pod.
- **`key file ... has overly permissive mode`** → the app image predates
  lib-commons v6.1.1 (old loader wanted owner-only `0400`). Upgrade the app image.
- **`permission denied` reading the key** → `fsGroup` is not set (or does not
  match the runtime group). Keep `mtls.fsGroup` aligned with the component's
  `runAsGroup` (1000).
- **Verify inside a pod:** `stat -c '%a' /etc/btg/mtls/tls.key` should be `440`,
  and the startup log should show `[MTLS] outbound BTG mTLS ENABLED | cert_file=...`.
