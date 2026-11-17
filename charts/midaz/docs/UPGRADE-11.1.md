# Helm Upgrade from v11.0.0 to v11.1.0

## Release scope and runtime limitation

Chart `midaz-helm` 11.1.0 adds `OTEL_TRUST_INBOUND_TRACE_CONTEXT` to the
ledger and tracer ConfigMaps, with a rendered default of `"false"`. Both
chart releases retain application version 4.4.2; this is chart wiring, not
an application upgrade.

**The default 4.4.2 ledger and tracer images do not read this environment
variable.** Their telemetry bootstrap leaves the library's
`TrustInboundTraceContext` field at its default false value. This was also
true with chart 11.0.0. Absence of the ConfigMap key in the previous chart
therefore does not mean those images trusted inbound context.

Setting the new key to `"true"` renders that value but does not enable the
advertised inbound trace-continuity opt-in with the default images. Do not
use ConfigMap presence as proof of runtime behavior or weaken gateway trust
boundaries on that assumption. No replacement application image is prescribed
here. An existing image override needs separate source and runtime validation;
this guide does not certify its behavior or downstream propagation.

| Value path | Chart 11.0.0 | Chart 11.1.0 |
|------------|--------------|--------------|
| `ledger.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT` | Not provided | `"false"` |
| `tracer.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT` | Not provided | `"false"` |

The following is an **incomplete overlay**, not a replacement for your release
configuration. Keep the default; setting it does not change runtime support.

```yaml
ledger:
  configmap:
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "false"
tracer:
  configmap:
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "false"
```

## Prepare and preserve the release

1. Confirm the installed chart is 11.0.0. Review your effective image pins,
   enabled components, authentication, external stores, storage, ingress and
   Secret references. Tracer is disabled by default; do not enable it merely
   to apply this chart setting.
2. Save the installed release values, manifests and history privately. They can
   contain credentials; restrict access, never commit them or paste rendered
   Secrets into tickets. Record the prior chart package and image revisions.
3. Create a reviewed **complete intended configuration** in
   `values-11.1.0.private.yaml`. Reconcile existing overrides with target
   defaults; preserve unrelated settings, image pins and Secret references.
   Do not use the small overlay above as that file. The explicit reset below
   removes stored overrides omitted from it.
4. Take consistent, private backups of the deployed datastores and required
   persistent data; verify the restore procedure and recovery window before
   proceeding. This release adds no image, dependency-lock or datastore topology
   change, but existing bootstrap and migration hooks can still execute on
   upgrade, including RabbitMQ bootstrap, ledger migrations and enabled tracer
   migrations. Review their effective configuration and image overrides.

## Preview and upgrade

These commands assume the release and namespace are both `midaz`; substitute
both consistently for your installation. Keep all render/diff output private.
The [helm-diff plugin](https://github.com/databus23/helm-diff) is needed only
for the diff step; inspect and install it through your normal tooling process.

```bash
umask 077
helm template midaz oci://ghcr.io/lerianstudio/midaz-helm \
  --version 11.1.0 --namespace midaz --is-upgrade \
  -f values-11.1.0.private.yaml > preview-11.1.0.private.yaml
helm diff upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm \
  --version 11.1.0 --namespace midaz --reset-values \
  -f values-11.1.0.private.yaml > diff-11.1.0.private.txt
```

Review hooks, resource identities, PVC mounts, selectors, images, Secret
references and pod-template changes. Upgrade-mode validation may require
preserving the current bundled datastore credentials in the complete private
configuration; do not retrieve or print them merely to demonstrate this guide.
The new ConfigMap keys change enabled workloads' pod-template checksums in
source renders. Actual rollout and availability depend on the installed values,
replicas, strategy, readiness and capacity; no zero-downtime or data-safety
promise follows from a static render.

After review and during the approved change window:

```bash
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm \
  --version 11.1.0 --namespace midaz --reset-values \
  -f values-11.1.0.private.yaml
```

## Verify and recover

Inspect the release's actual workload names, hook Job outcomes, readiness and
health. Confirm intended images, retained data/configuration and representative
ledger operations using your established smoke checks. Inspect only the two
non-secret ConfigMap keys when checking chart wiring; neither those keys nor
a successful Helm command prove a working trace-context opt-in. Validate actual
traces separately if running custom images.

If verification fails, stop further changes and follow the prepared recovery
plan. Roll back only after assessing migration/bootstrap effects and compatibility
with the previous chart and images. Helm rollback restores release resources,
not database contents or persistent data; it can also run hooks. Data recovery
requires the tested backup/restore and cutover procedure, not just a Helm rollback.

Static checks for this guide covered exact 11.0.0/11.1.0 chart sources, published
packages and matching default application source revisions, plus synthetic
lint/renders. No live upgrade, migration execution, restore drill or runtime
trace-continuity test was performed.
