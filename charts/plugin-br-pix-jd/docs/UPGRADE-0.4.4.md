# Helm Upgrade from v0.4.3 to v0.4.4

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. QRCODE_PAYLOAD_PATH Default Changed from `v1/qrcodes/payload` to `qr`](#1-qrcode_payload_path-default-changed-from-v1qrcodespayload-to-qr)
  - [2. Tenant-Aware QR URL Budget Validation](#2-tenant-aware-qr-url-budget-validation)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This patch release fixes the default dynamic-QR payload path and the render-time
validation of the QR URL budget. Both changes only affect deployments that set
`api.configmap.QRCODE_PUBLIC_BASE_URL`; with the base unset the rendered output is
byte-identical except for the `QRCODE_PAYLOAD_PATH` value itself.

| Setting | v0.4.3 | v0.4.4 |
|---------|--------|--------|
| Chart Version | 0.4.3 | 0.4.4 |
| `QRCODE_PAYLOAD_PATH` default | `v1/qrcodes/payload` | `qr` |
| `<base>/<payloadPath>/` cap | 45 (always) | 42 (`MULTI_TENANT_ENABLED=true`) / 51 (otherwise) |

## Fixes

### 1. QRCODE_PAYLOAD_PATH Default Changed from `v1/qrcodes/payload` to `qr`

JDPI caps the advertised `urlPayloadJson` at 77 characters, and the app composes it as:

- multi-tenant: `<base>/<payloadPath>/<ispb:8>/cob/<id: up to 22>`
- single-tenant: `<base>/<payloadPath>/cob/<id: up to 22>`

The chart's previous default, `v1/qrcodes/payload` (18 characters), spent the budget
on the path: with the decided hosts (`pix-jd.sa-east-1.lerian.io`, 26 characters, and
`pix-jd.sa-east-1.stg.lerian.io`, 30 characters) every multi-tenant emission produced
URLs of 81 and 85 characters — past the cap, so JDPI rejected every QR at runtime.
The app's own default is `qr` (`internal/shared/qrlocation`: `DefaultPayloadPath`);
the chart now matches it.

**Why the default can change in a patch release:** no environment pins
`QRCODE_PAYLOAD_PATH` in its values (measured across both gitops repositories) and no
QR code has been issued or printed against the old route. There are no consumers of
the old path yet — this is exactly the window in which the default can move safely.

**Operational impact:** on upgrade, the served and advertised payload route changes
from `<base>/v1/qrcodes/payload/...` to `<base>/qr/...`. If you need the old route,
pin it explicitly:

```yaml
api:
  configmap:
    QRCODE_PAYLOAD_PATH: "v1/qrcodes/payload"
```

Note that the old default does not fit the multi-tenant budget on the decided hosts;
pinning it is only viable for single-tenant deployments with a short base host.

### 2. Tenant-Aware QR URL Budget Validation

The render-time gate on `QRCODE_PUBLIC_BASE_URL` + `QRCODE_PAYLOAD_PATH` capped the
`<base>/<payloadPath>/` prefix at 45 characters regardless of tenancy. The real
budget depends on what the app appends before the id (up to 22 characters):

- multi-tenant adds `<ispb:8>/cob/` (13 characters), so the prefix cap is
  77 − 22 − 13 = **42**
- single-tenant adds `cob/` (4 characters), so the prefix cap is
  77 − 22 − 4 = **51**

The single cap of 45 was wrong on both sides: multi-tenant prefixes of 43–45
characters rendered fine and then failed at every emission, while valid single-tenant
prefixes of 46–51 characters were refused at render time for no reason.

The gate now reads `MULTI_TENANT_ENABLED` (default `false`) and applies 42 or 51
accordingly, and the failure message shows the real URL composition and the applied
cap. As before, the gate only runs when `QRCODE_PUBLIC_BASE_URL` is set — an empty
base means the knob is not in use and never fails the render.

**Before (v0.4.3):**

```yaml
{{- $advertised := printf "%s/%s/" $base $payloadPath -}}
{{- if gt (len $advertised) 45 -}}
{{- fail (printf "...The prefix alone is already %d characters (%q)..." (len $advertised) $advertised) -}}
{{- end -}}
```

**After (v0.4.4):**

```yaml
{{- $advertised := printf "%s/%s/" $base $payloadPath -}}
{{- $mt := eq (index $cm "MULTI_TENANT_ENABLED" | default "false" | toString) "true" -}}
{{- $prefixCap := ternary 42 51 $mt -}}
{{- if gt (len $advertised) $prefixCap -}}
{{- fail (printf "...may be at most %d characters (MULTI_TENANT_ENABLED=%v)..." $prefixCap $mt) -}}
{{- end -}}
```

**Operational impact:** none for renders that were both valid and working. A
multi-tenant render with a 43–45 character prefix now fails at `helm template` /
`helm upgrade` instead of at runtime — that render was already broken, the failure
just moves to where it can be fixed. A single-tenant render with a 46–51 character
prefix, previously refused, now renders.

## Preview changes before upgrading

To see exactly what will change in your deployment, run:

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.4 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.4 -n plugin-br-pix-jd
```
