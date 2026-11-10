<!-- {% raw %} -->
# Helm Upgrade from v2.0.0 to v2.0.1

This guide covers the upgrade from `alloy-lerian` chart version **2.0.0** to **2.0.1**. This patch release clarifies documentation for unimplemented configuration fields and fixes the node-exporter Service name derivation logic.

---

## Topics

- **[Fixes](#fixes)**
  - [1. Documentation Clarification for Unimplemented Fields](#1-documentation-clarification-for-unimplemented-fields)
  - [2. Node-Exporter Service Name Derivation](#2-node-exporter-service-name-derivation)
  - [3. Sanitization Rule Count Update](#3-sanitization-rule-count-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Documentation Clarification for Unimplemented Fields

The chart documents two configuration fields that **have no effect** in the current implementation. These fields exist in `values.yaml` but are not referenced by any template.

#### Destination Credential Secret Reference

| Setting | v2.0.0 | v2.0.1 |
|---------|--------|--------|
| `destination.credential.secretName` | Documented as configurable | **Documented as not implemented** |
| `destination.credential.secretKey` | Documented as configurable | **Documented as not implemented** |

**What changed:**

The `values.yaml` file now includes a warning block above these fields:

```yaml
destination:
  credential:
    # ⚠️ NAO IMPLEMENTADO: `secretName` e `secretKey` NAO tem efeito. Os templates
    # definem os helpers `credentialSecretName` e `credentialSecretKey`, mas
    # nenhum os chama (verificado: `--set destination.credential.secretName=other`
    # gera render identico). O Secret e a chave efetivos sao os do `secretKeyRef`
    # em `node.alloy.extraEnv` e `singleton.alloy.extraEnv`; para usar outro nome
    # ou chave, altere la, nos dois papeis. Os valores abaixo ficam apenas como
    # registro do padrao.
    #
    # Referência apenas. O chart LÊ este Secret e nunca o cria.
    secretName: "alloy-lerian"
    secretKey: "telemetry-token"
```

**What this means:**

- Setting `destination.credential.secretName` or `destination.credential.secretKey` has **no effect** on the rendered manifests
- The actual Secret name and key are defined in the `secretKeyRef` of `ALLOY_DESTINATION_CREDENTIAL` in `node.alloy.extraEnv` and `singleton.alloy.extraEnv`
- The values in `destination.credential` serve only as documentation of the default

**Migration Steps:**

No action required. If you have overridden these fields in your `values.yaml`, they are being ignored. To use a different Secret name or key:

1. Override the `extraEnv` entries in both roles:

```yaml
node:
  alloy:
    extraEnv:
      - name: ALLOY_DESTINATION_CREDENTIAL
        valueFrom:
          secretKeyRef:
            name: my-custom-secret
            key: my-custom-key
            optional: false
      # ... other extraEnv entries

singleton:
  alloy:
    extraEnv:
      - name: ALLOY_DESTINATION_CREDENTIAL
        valueFrom:
          secretKeyRef:
            name: my-custom-secret
            key: my-custom-key
            optional: false
      # ... other extraEnv entries
```

> **Important:** `extraEnv` is a list, so declaring it replaces the chart default entirely. You must repeat all default entries (Fleet token, pod name) when overriding.

#### Fleet Management Token Secret Reference

| Setting | v2.0.0 | v2.0.1 |
|---------|--------|--------|
| `fleetManagement.tokenSecret.name` | Documented as configurable | **Documented as not implemented** |
| `fleetManagement.tokenSecret.key` | Documented as configurable | **Documented as not implemented** |

**What changed:**

The `values.yaml` file now includes a warning block above these fields:

```yaml
fleetManagement:
  # ⚠️ NAO IMPLEMENTADO: `tokenSecret.name` e `tokenSecret.key` NAO tem efeito
  # (verificado: `--set fleetManagement.tokenSecret.name=zzz` gera render
  # identico). O token chega pelo `secretKeyRef` de `ALLOY_FLEET_TOKEN` em
  # `node.alloy.extraEnv` e `singleton.alloy.extraEnv`; para separar as
  # credenciais em outro Secret, altere la, nos dois papeis.
  tokenSecret:
    name: "alloy-lerian"
    key: "fleet-token"
```

**What this means:**

- Setting `fleetManagement.tokenSecret.name` or `fleetManagement.tokenSecret.key` has **no effect** on the rendered manifests
- The actual Secret name and key are defined in the `secretKeyRef` of `ALLOY_FLEET_TOKEN` in `node.alloy.extraEnv` and `singleton.alloy.extraEnv`
- The values in `fleetManagement.tokenSecret` serve only as documentation of the default

**Migration Steps:**

No action required. If you have overridden these fields in your `values.yaml`, they are being ignored. To use a different Secret name or key, follow the same procedure as for the destination credential above.

#### Profile and Fleet Management Relationship

| Setting | v2.0.0 | v2.0.1 |
|---------|--------|--------|
| `profile: own` disables Fleet | Implied by documentation | **Explicitly documented as false** |

**What changed:**

The `values.yaml` file now clarifies that `profile: own` does **not** disable Fleet Management:

```yaml
node:
  alloy:
    extraEnv:
      - name: ALLOY_FLEET_TOKEN
        valueFrom:
          secretKeyRef:
            # ATENCAO: o perfil `own` NAO desliga o Fleet. `fleetManagement.enabled`
            # nasce `true` nos dois perfis, e `profile: own` sozinho continua
            # renderizando o bloco `remotecfg` (verificado com `helm template
            # --set profile=own`). Para rodar sem Fleet e preciso desligar de forma
            # explicita: `fleetManagement.enabled: false`. Mesmo desligado, esta
            # entrada continua `optional: false` no render: desligar o Fleet nao a
            # torna opcional.
            optional: false

fleetManagement:
  # Nasce `true` nos DOIS perfis. `profile: own` NAO o desliga: sem
  # `enabled: false` explicito o bloco `remotecfg` continua sendo renderizado.
  enabled: true
```

**What this means:**

- `fleetManagement.enabled` defaults to `true` in **both** `profile: own` and `profile: client`
- Setting `profile: own` alone does **not** disable Fleet Management
- To run without Fleet, you must explicitly set `fleetManagement.enabled: false`

**Migration Steps:**

If you are running `profile: own` and expect Fleet Management to be disabled, verify your configuration:

```bash
helm get values alloy-lerian -n alloy-lerian
```

If `fleetManagement.enabled` is not explicitly set to `false`, the agent is fetching configuration from Fleet. To disable Fleet:

```yaml
profile: "own"
fleetManagement:
  enabled: false
```

> **Warning:** Even with Fleet disabled, the `ALLOY_FLEET_TOKEN` environment variable entry remains with `optional: false`. If the Secret does not contain a `fleet-token` key, the pods will fail with `CreateContainerConfigError`. Either create a placeholder key or override `extraEnv` to remove the entry.

### 2. Node-Exporter Service Name Derivation

The helper template that derives the node-exporter Service name now correctly handles `nameOverride`, `fullnameOverride`, and `namespaceOverride` from the subchart.

**Before (v2.0.0):**

```yaml
{{- define "alloy-lerian.nodeExporterTarget" -}}
{{- if .Values.collection.nodeExporterTarget -}}
{{- .Values.collection.nodeExporterTarget -}}
{{- else -}}
{{- $ne := index .Values "node-exporter" | default dict -}}
{{- if $ne.enabled -}}
{{- printf "%s-prometheus-node-exporter.%s.svc.cluster.local:9100" .Release.Name .Release.Namespace -}}
{{- end -}}
{{- end -}}
{{- end -}}
```

**After (v2.0.1):**

```yaml
{{- define "alloy-lerian.nodeExporterTarget" -}}
{{- if .Values.collection.nodeExporterTarget -}}
{{- .Values.collection.nodeExporterTarget -}}
{{- else -}}
{{- $ne := index .Values "node-exporter" | default dict -}}
{{- if $ne.enabled -}}
{{- /* Nome do Service como o subchart o renderiza: o ALIAS `node-exporter` vira
       `.Chart.Name` la dentro, entao nao ha `prometheus-` no nome. Espelha o
       helper `prometheus-node-exporter.fullname` (fullnameOverride, nameOverride
       e "release ja contem o nome") e `namespaceOverride`. */ -}}
{{- $nome := default "node-exporter" $ne.nameOverride -}}
{{- $svc := "" -}}
{{- if $ne.fullnameOverride -}}
{{- $svc = $ne.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains $nome .Release.Name -}}
{{- $svc = .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $svc = printf "%s-%s" .Release.Name $nome | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- $ns := default .Release.Namespace $ne.namespaceOverride -}}
{{- printf "%s.%s.svc.cluster.local:9100" $svc $ns -}}
{{- end -}}
{{- end -}}
{{- end -}}
```

**What changed:**

1. The hardcoded Service name `<release>-prometheus-node-exporter` is replaced with logic that mirrors the `prometheus-node-exporter.fullname` helper
2. The subchart runs under the alias `node-exporter`, so the Service name is `<release>-node-exporter` (no `prometheus-` prefix)
3. The helper now respects `node-exporter.fullnameOverride`, `node-exporter.nameOverride`, and `node-exporter.namespaceOverride`

**What this means:**

- If you have overridden the node-exporter subchart name, the chart will now correctly derive the Service name
- The default Service name changes from `<release>-prometheus-node-exporter` to `<release>-node-exporter`

**Migration Steps:**

#### Option 1: Accept the corrected Service name (recommended)

No action required. The chart will use the correct Service name on upgrade.

**Verify the Service name after upgrade:**

```bash
kubectl get svc -n alloy-lerian -l app.kubernetes.io/name=node-exporter
```

#### Option 2: Preserve the old Service name

If you have external references to the old Service name (e.g., in dashboards or alerts), override the subchart to use the old name:

```yaml
node-exporter:
  enabled: true
  fullnameOverride: "alloy-lerian-prometheus-node-exporter"
```

> **Note:** This is only necessary if you have hardcoded the Service name outside the chart. The Alloy configuration is generated by the chart and will use the correct name automatically.

### 3. Sanitization Rule Count Update

The `NOTES.txt` template now reflects the current sanitization rule count and provides more detail on which rules are form-based versus field-name-based.

**Before (v2.0.0):**

```
Sanitização de dado regulado: SEMPRE ativa, não configurável.
  8 classes cobertas, verificadas contra o agente real na porta de entrega.
  7 reconhecem por FORMA (robustas a nome de campo novo); 4 regras dependem de
  NOME DE CAMPO — ver a seção de limites no README antes de tratar como garantia.
```

**After (v2.0.1):**

```
Sanitização de dado regulado: SEMPRE ativa, não configurável.
  7 classes cobertas (10 regras), verificadas contra o agente real na porta de entrega.
  Telefone, e-mail e os esquemas `Bearer`, `Basic` e `Digest` são reconhecidos pelo
  formato (robustos a nome de campo novo); nome, conta e agência, chave Pix, endereço e as formas de chave e
  atribuição de credencial dependem de NOME DE CAMPO — ver a seção de limites no
  README antes de tratar como garantia.
```

**What changed:**

- The class count is updated from 8 to 7 (reflecting the removal of CPF and CNPJ rules in v2.0.0)
- The rule count is now explicit: 10 rules across 7 classes
- The form-based rules are listed by name: phone, email, Bearer, Basic, Digest
- The field-name-based rules are listed by name: name, account/branch, Pix key, address, credential key/assignment

**What this means:**

No operational impact. This is a documentation correction to match the actual sanitization rules deployed in v2.0.0.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.1 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.1 -n alloy-lerian
```
<!-- {% endraw %} -->
