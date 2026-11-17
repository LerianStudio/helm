# Helm Upgrade from v1.6.0 to v1.6.1

## Release scope

This guide covers `plugin-br-sisbajud` chart **1.6.0 → 1.6.1**. The default application changes from **1.3.0 to 1.5.0**, while the default migrations image changes from **1.3.0 to 1.4.0**. Chart version, application version and migrator version are distinct.

| Setting | Chart 1.6.0 | Chart 1.6.1 |
|---|---|---|
| `appVersion` | `1.3.0` | `1.5.0` |
| `sisbajud.image.tag` | `""`, selecting appVersion | `""`, selecting appVersion |
| `migrations.image.tag` | `""`, selecting appVersion | `"1.4.0"` |

Existing explicit image overrides remain operator choices. Record the effective installed executor and migrator images before selecting a compatible target set. A pod restart does not prove adoption of the new application: a retained executor pin can keep 1.3.0 even when a changed pod-template version label recreates the pod.

The 1.5.0 migrations image was unavailable during release review; the target chart pins the published 1.4.0 migrator. **Set `migrations.image.tag: "1.4.0"` explicitly in your complete intended values.** Setting it to an empty string selects appVersion **1.5.0**, not the nonempty 1.4.0 default. Do not use that empty-string configuration. Publication of a future image alone does not establish its upgrade compatibility.

## Application and migration prerequisites

This patch chart crosses application releases 1.3.0 → 1.4.0 → 1.5.0. It is not merely a cosmetic tag change. The Mensageria permanent-block switch, ignored by 1.3.0, is consumed by 1.4.0/1.5.0. Inspect retained `sisbajud.mensageria.permanentBlockEnabled`, native ConfigMap overrides and extra environment before rollout: a previously inert true value can now activate business behavior. Keep the switch false unless the complete cross-service rollout has been separately validated. Application 1.5.0 also adds manual permanent-stop operations.

Preserve the Direct/active-order maintenance prerequisites, explicit streaming configuration and emitter requirements. Enabling permanent-block behavior requires separate validation of the actual Midaz/CRM, institution product catalog, Mensageria execution contract and STA return-file compatibility, including homologation capture and result delivery. This guide does not establish compatible companion versions or live end-to-end behavior; it does not authorize unconditional enablement or replacing Direct with an unvalidated switch.

The OCI-linked application sources for 1.4.0 and 1.5.0 have identical SQL migrations, migration Dockerfile, runner and local imported packages, `go.mod` and `go.sum`. SQL migrations are also unchanged from 1.3.0 to 1.4.0. This is source-parity evidence—not an exercised migration, mixed-version compatibility certification or restore test. Do not infer that a pinned 1.3.0 executor plus a 1.4.0 migrator is certified. Verify effective migration configuration, database ownership and licensing before proceeding.

## Preserve configuration and recovery options

1. Schedule a maintenance window appropriate to the installed workloads and active judicial orders. Record private Helm history, effective images, configuration and migration state.
2. Take consistent private PostgreSQL and other necessary persistent-state backups. Establish a tested coordinated restore/cutover plan before changing the release. Protect license, credential and encryption material through the normal secret-management process; never print decoded Secrets or publish saved values/manifests.
3. Prepare `values-1.6.1.private.yaml` with the **complete intended configuration**, including all unrelated overrides and Secret references. Preserve authentication, tenant identity, license settings, Direct policy, streaming brokers/TLS/SASL, Mensageria endpoints/CA, Midaz/CRM, external stores, storage and deliberate image pins. The commands use `--reset-values`: stored overrides omitted from this file are discarded.
4. Explicitly select the reviewed migrator in the existing mapping, without duplicate YAML keys:

   ```yaml
   migrations:
     image:
       tag: "1.4.0"
   ```

   This fragment is not a complete values file. Review `sisbajud.image.tag` separately: an empty executor tag selects application 1.5.0, while a deliberate retained pin selects that version.
5. Verify the actual migration mode. With migrations enabled and single-tenant external PostgreSQL, the chart renders a pre-install/pre-upgrade hook (weight -5). Successful hooks are deleted. With bundled development PostgreSQL, migrations run in the executor Deployment's `migrations` initContainer instead. Multi-tenant mode and `migrations.enabled: false` suppress chart migration execution; arrange and verify the supported separate procedure. Do not assume enabling the value creates a Job in every mode or enable development infrastructure to bypass production safeguards.

## Preview and upgrade

The examples use release `plugin-br-sisbajud` and namespace `sisbajud`; substitute the actual names consistently. Use the same complete intended values for preview and upgrade. Preview output can expose credentials, including through ConfigMaps: retain it privately with restricted permissions. Helm rendering does not exercise application startup, licensing, database migrations or judicial-order processing.

```bash
umask 077
helm template plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  --version 1.6.1 --namespace sisbajud --is-upgrade \
  -f values-1.6.1.private.yaml > preview-1.6.1.private.yaml
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  --version 1.6.1 --namespace sisbajud --reset-values \
  -f values-1.6.1.private.yaml --suppress-secrets > diff-1.6.1.private.txt
```

Preview requires an approved pinned installation of the [helm-diff plugin](https://github.com/databus23/helm-diff). Review effective images, external Secret references, database/tenant configuration, migration mode, storage, active-order handling and expected pod-template changes. Do not replace the complete file with an isolated `--set` or assume editing a local pin changes the release without passing that file.

After reviewing the preview and meeting all prerequisites:

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  --version 1.6.1 --namespace sisbajud --reset-values \
  -f values-1.6.1.private.yaml --wait --timeout 15m
```

Choose an environment-appropriate timeout. A timeout is not a rollback and does not undo database or judicial-order side effects.

## Verify and recover

Observe applicable migration execution and retain completion evidence privately. A successful hook normally disappears (`before-hook-creation,hook-succeeded`); an absent Job does not establish success. Inspect rendered names, Helm outcome and the approved migration completion evidence. If a failed Job remains, scope inspection to both the actual release instance and `app.kubernetes.io/component=migrations`; do not index the last Job across an entire namespace. In bundled mode inspect the `migrations` initContainer's actual image and termination status instead.

```bash
kubectl get deployments -n sisbajud \
  -l app.kubernetes.io/instance=plugin-br-sisbajud \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image,READY:.status.readyReplicas'
```

Use actual rendered resource names if naming overrides are configured. Verify executor rollout, `/readyz` readiness and effective images, then representative supported business operations and active-order result delivery under the approved maintenance plan. Image strings alone do not prove compatibility or successful processing.

If verification fails, stop and assess committed schema and business effects before reverting. Helm rollback restores release manifests, not database contents or financial/judicial side effects. Use the tested coordinated restore and compatible-image plan where needed; prevent conflicting writes during recovery. No live upgrade, migration, restore or business transaction is claimed by this guide.
