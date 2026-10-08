# Helm Upgrade from v0.4.8 to v0.4.9

## Version alignment

- Chart: `0.4.8` → `0.4.9`.
- App fallback (`Chart.appVersion`): `1.1.0` → `1.1.1`.
- Migration image default: `1.1.0` → `1.1.1`.

This is a patch release of the app. It is not breaking: an upgrade with unchanged
values renders and behaves as before. Payment-order signing is new and optional (see
[Payment-order signing (optional)](#payment-order-signing-optional)). The GHCR API,
worker and migrations images all exist at `1.1.1`.

## What the application fixes

- **JDPI payment orders can be signed with the participant's hash.** Since JDPI
  manual 5.5.2, a JD running with `JDPI_IF__HashAtivo=true` refuses a payment order
  that carries no `hash` group (`JDPISPI017`), and repeated refusals open JD's
  signature circuit breaker (`JDPISPI018`), which blocks every debit of the
  participant until JD's recovery window closes. With the signing key and
  certificate set, the app signs each order with the paying participant's key; with
  neither, it sends unsigned orders as before
  ([plugin-br-pix-jd#378](https://github.com/LerianStudio/plugin-br-pix-jd/issues/378)).
- **`JDPISPI017` and `JDPISPI018` are final refusals.** Whatever HTTP status carries
  them, including `429`, the order is never re-sent and the hold is released.
  `JDPISPI018` has its own message.
- **Signing settings that are set but unusable refuse the order before JD is called.**
  Only one of the key and the certificate set, an unknown algorithm, a key that does not fit it, or a certificate
  that is not the key's own answers `409 PIX-0136`, naming the setting. No funds move
  and nothing reaches JD unsigned.
- **Access Manager and Midaz outages are named instead of answered `500` or `400`.**
  An Access Manager token call that times out answers `504 PIX-3007`, one that is
  refused or returns a 5xx answers `503 PIX-3008` (previously `500 PIX-0109 "internal
  error"`). A Midaz account read that times out, is refused or returns 5xx answers
  `503 PIX-4002` instead of "account not found", and a Midaz `401`/`403` on the
  plugin's own credential is a dependency fault (`503 PIX-4002` on reads, `500
  PIX-4011` on postings) instead of `400 PIX-4005`.
- **The inbound cash-in webhook keeps JD's response contract.** JDPI §9.3.2 declares
  no `503` or `504` for `POST /v1/webhooks/cash-ins`, so a CRM, Access Manager or
  Midaz outage there answers `500`, keeping the dependency code and a detail naming
  the dependency. Every other route keeps `503`/`504`.

## Database migration

None. No file under the app's `migrations/` changed between `1.1.0` and `1.1.1`;
`000042` is still the latest.

## Payment-order signing (optional)

Needed only when the client's JD enforces signed payment orders
(`JDPI_IF__HashAtivo=true`). Without the values nothing changes: the chart renders no
signing key and the api sends unsigned orders, which a JD that does not enforce the
signature accepts.

New values, consumed by the app's API only:

| Value | Where it lands | Required |
|---|---|---|
| `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY` | api Secret, only when set | no — both or neither |
| `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` | api Secret, only when set | no — both or neither |
| `api.configmap.JD_PAYMENT_SIGNING_ALGORITHM` | api ConfigMap, only when set | no — empty means `ECDSA_P256_SHA256`; also `ECDSA_P384_SHA384`, `RSA_PKCS1_SHA256` (RSA 3072 or larger) |

`helm template` and `helm upgrade` fail, naming the value, when only one of the two
PEMs is set (the app would refuse every order with `409 PIX-0136`), when a set value
has no `-----BEGIN` PEM header, and when the algorithm is not one of the three above.
With `api.existingSecret.name` the chart renders no Secret and does not check: to
sign, that Secret must carry both keys. An argocd-vault-plugin `<path:...>`
placeholder is accepted.

To enable it:

1. Generate the signing key and a certificate for it (ECDSA P-256; self-signed is
   accepted):

   ```bash
   openssl ecparam -name prime256v1 -genkey -noout | openssl pkcs8 -topk8 -nocrypt -out payment-signing.key
   openssl req -new -x509 -key payment-signing.key -out payment-signing.crt -days 730 -subj "/CN=<institution> Pix payments"
   ```

2. Register the certificate in JDPI Cabine: "Gestão de Certificados" → Incluir,
   "Tipo Certificado" = "Certificados Hash – Assinatura Payload", with
   `payment-signing.crt`. Cabine receives **only the public certificate** (PEM). The
   private key `payment-signing.key` never leaves your environment: it goes only
   into `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY`.

   `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` must be **the same certificate**
   registered in Cabine. The plugin derives from it the thumbprint each payment order
   carries; with a different certificate JD refuses every order with `JDPISPI017`.
   Compare its SHA-1 fingerprint with the one Cabine shows:

   ```bash
   openssl x509 -in payment-signing.crt -outform DER | shasum -a 1 | tr a-f A-F
   ```
3. Set both values, merged into your existing values (not a complete install
   configuration):

   ```yaml
   api:
     secrets:
       JD_PAYMENT_SIGNING_PRIVATE_KEY: |
         -----BEGIN PRIVATE KEY-----
         ...
         -----END PRIVATE KEY-----
       JD_PAYMENT_SIGNING_CERTIFICATE: |
         -----BEGIN CERTIFICATE-----
         ...
         -----END CERTIFICATE-----
   ```

   Or pass the files: `--set-file api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=payment-signing.key --set-file api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=payment-signing.crt`.

## Operator configuration

1. Update the image tags, merged into your existing values:

   ```yaml
   api:
     image:
       tag: "1.1.1"
   worker:
     # Keep the existing enabled flag; when enabled, use the dedicated worker image.
     image:
       repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
       tag: "1.1.1"
   migrations:
     image:
       tag: "1.1.1"
   ```

2. To sign payment orders, follow [Payment-order signing (optional)](#payment-order-signing-optional).
3. Upgrade the chart.

Explicit image tags in an existing values file win over chart defaults; update
them to `1.1.1`.

## Verification and rollback

Render with the target environment's values before upgrading. Verify the API image
is `1.1.1`, the enabled worker uses `plugin-br-pix-jd-worker:1.1.1`, any rendered
migration Job uses `plugin-br-pix-jd-migrations:1.1.1`, and, when signing is enabled,
the api Secret carries `JD_PAYMENT_SIGNING_PRIVATE_KEY` and `JD_PAYMENT_SIGNING_CERTIFICATE`.
After the upgrade, send one Pix to another institution and confirm it reaches
`EXECUTED`. With signing enabled, a `JDPISPI017` means the certificate in Cabine is
not the one in `JD_PAYMENT_SIGNING_CERTIFICATE`; without it, a `JDPISPI017` means the
JD enforces signed orders and signing has to be enabled. A certificate that is not the key's own never reaches
JD: the order is refused `409 PIX-0136`.

Rolling back to chart `0.4.8` and app `1.1.0` needs no database step. App `1.1.0`
always sends unsigned orders, which a JD with `HashAtivo=true` refuses. No environment
deployment is performed by this PR.
