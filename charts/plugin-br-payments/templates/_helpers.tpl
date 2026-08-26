{{/*
================================================================================
PLUGIN BR PAYMENTS - HELM TEMPLATE HELPERS
================================================================================
The plugin runs API + worker logic in a SINGLE process (SERVICE_TYPE=both).
One Deployment, one pod. No separate worker Deployment.
================================================================================
*/}}

{{/*
================================================================================
NAME HELPERS
================================================================================
*/}}

{{/*
Top-level chart name.
*/}}
{{- define "plugin-br-payments.name" -}}
{{- default "plugin-br-payments" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Application name (single deployment).
*/}}
{{- define "plugin-br-payments.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default "plugin-br-payments" .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
================================================================================
CHART HELPERS
================================================================================
*/}}

{{- define "plugin-br-payments.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the application image tag (Chart.appVersion if app.image.tag is empty).
*/}}
{{- define "plugin-br-payments.defaultTag" -}}
{{- default .Chart.AppVersion .Values.app.image.tag }}
{{- end -}}

{{/*
Sanitize tag for use in app.kubernetes.io/version label.
*/}}
{{- define "plugin-br-payments.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "plugin-br-payments.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
================================================================================
LABEL HELPERS
================================================================================
*/}}

{{/*
Common labels.
Usage: {{ include "plugin-br-payments.labels" (dict "context" .) }}
*/}}
{{- define "plugin-br-payments.labels" -}}
helm.sh/chart: {{ include "plugin-br-payments.chart" .context }}
{{ include "plugin-br-payments.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/version: {{ include "plugin-br-payments.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: plugin-br-payments
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "plugin-br-payments.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-br-payments.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
================================================================================
SERVICE ACCOUNT HELPER
================================================================================
*/}}

{{- define "plugin-br-payments.serviceAccountName" -}}
{{- if .Values.app.serviceAccount.create }}
{{- default (include "plugin-br-payments.fullname" .) .Values.app.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.app.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
================================================================================
NAMESPACE HELPER
================================================================================
*/}}

{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` env entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart ("postgresql"|"valkey"),
key (data key), envName (container env var name).
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "plugin-br-payments.infraSecretRef" -}}
{{- $ctx := .context -}}
{{- $sub := .subchart -}}
{{- $auth := default dict (index $ctx.Values $sub "auth") -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{- $secretName = $auth.existingSecret -}}
{{- else -}}
{{- $secretName = include "common.names.dependency.fullname" (dict "chartName" $sub "chartValues" (index $ctx.Values $sub) "context" $ctx) -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ .key }}
{{- end }}

{{/*
================================================================================
DEPENDENCY ENABLED HELPER
================================================================================
*/}}

{{- define "postgresql.enabled" -}}
{{- if and (default true .Values.postgresql.enabled) (not .Values.postgresql.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
================================================================================
VALIDATION HELPERS
================================================================================
ERRORS (fail) block deployment for truly required fields.
Mirrors the OUTBOX_ENABLED + provider/Midaz requirements documented in the
plugin-br-payments README.
================================================================================
*/}}

{{- define "plugin-br-payments.validateRequired" -}}

{{/* OUTBOX must be enabled for HTTP routes to register */}}
{{- if ne (.Values.app.configmap.OUTBOX_ENABLED | toString) "true" }}
{{- fail "\n\nERROR: app.configmap.OUTBOX_ENABLED must be \"true\".\n   plugin-br-payments only registers its routes when the outbox pattern is enabled.\n   See README -> 'Local Development Config'.\n" }}
{{- end }}

{{/* BTG provider integration — required for any write operation */}}
{{- if not .Values.app.configmap.BTG_API_BASE_URL }}
{{- fail "\n\nERROR: app.configmap.BTG_API_BASE_URL is REQUIRED.\n   Set the BTG API base URL (e.g., https://api.btgpactual.com).\n" }}
{{- end }}

{{- if not .Values.app.configmap.BTG_AUTH_URL }}
{{- fail "\n\nERROR: app.configmap.BTG_AUTH_URL is REQUIRED.\n   Set the BTG OAuth2 token endpoint URL.\n" }}
{{- end }}

{{/* ONE tenancy toggle, and this refuses the other one rather than guessing.

     MULTI_TENANCY_ENABLED is the app's DEPRECATED spelling of MULTI_TENANT_ENABLED.
     This chart no longer ships or reads it, so an overlay that still sets it would
     read as single-tenant to every guard below — and a multi-tenant environment
     would then be refused with "PROVIDER_CLIENT_ID is REQUIRED in single-tenant
     mode", which points at the wrong problem. Failing here instead names the actual
     fix in the message.

     A hard fail rather than a warning, because the quiet outcome is worse than a
     blocked render: the app resolves the canonical name through bare os.LookupEnv,
     so once anything sets MULTI_TENANT_ENABLED the deprecated value stops being
     adopted, and a deployment that reads as multi-tenant in its own values file
     runs SINGLE-TENANT. There is no version of that which is safe to let through
     silently. */}}
{{- if hasKey .Values.app.configmap "MULTI_TENANCY_ENABLED" }}
{{- fail "\n\nERROR: app.configmap.MULTI_TENANCY_ENABLED was RENAMED to app.configmap.MULTI_TENANT_ENABLED.\n   The application deprecated the MULTI_TENANCY_ prefix; this chart now reads MULTI_TENANT_ENABLED only.\n   Rename the key in your values overlay — the value itself does not change.\n   Leaving both set is not supported: the app resolves the canonical name first, so the deprecated one would be ignored and a multi-tenant overlay would run single-tenant.\n" }}
{{- end }}

{{/* The OAuth2 credential pair — named for the ROLE, not the vendor, and required
     only in SINGLE-TENANT mode.

     RENAMED from BTG_CLIENT_ID / BTG_CLIENT_SECRET. plugin-br-payments is
     provider-agnostic by design and BTG is its first adapter, not its only one; a
     client id and a client secret are what any OAuth2 provider issues, unlike the
     URLs and the webhook keys above, which point at something vendor-specific and
     keep their BTG_ prefix. The app reads PROVIDER_CLIENT_ID /
     PROVIDER_CLIENT_SECRET (internal/bootstrap/config.go). Note this reverses part
     of the 1.0.0 rename — the deployment repositories' Vault field names were
     PROVIDER_CLIENT_ID all along and never followed it.

     ⛔ CONDITIONAL, AND THE UNCONDITIONAL VERSION WAS A DEFECT. In multi-tenant the
     pair is resolved PER TENANT from the credential row, nothing reads these two,
     and the app logs a WARN at boot naming each one left set. Demanding them
     anyway made a legitimate multi-tenant deployment fail to render — verified
     against this chart: `helm template` with the tenancy toggle on refused
     with "app.secrets.BTG_CLIENT_ID is REQUIRED" before this change.

     ONE toggle, and it is MULTI_TENANT_ENABLED — the name the app actually prefers.
     MULTI_TENANCY_ENABLED is the app's DEPRECATED alias
     (reconcileDeprecatedMultiTenantEnv) and this chart no longer ships or reads it.

     ⛔ AND THE CHART MUST NOT SHIP A VALUE FOR MULTI_TENANT_ENABLED EITHER, which is
     why values.yaml leaves it commented out. The app's reconciliation asks bare
     os.LookupEnv for the canonical name, so a PRESENT BUT BLANK MULTI_TENANT_ENABLED
     makes the canonical "set" and the deprecated alias is then NOT adopted. An
     overlay that still says MULTI_TENANCY_ENABLED=true would silently run
     SINGLE-TENANT. The ConfigMap template renders every key in app.configmap,
     empty strings included, so a chart default here is not a harmless placeholder —
     it is that silent mode flip. Overlays on the deprecated name keep working
     precisely because the chart declares nothing.

     An overlay still on the deprecated name therefore reads as single-tenant HERE
     and keeps being asked for the pair. That is deliberate and safe: it is the
     behaviour those overlays already have, the app still runs multi-tenant because
     it adopts the alias, and the way out is to rename the toggle in the overlay —
     not to make this guard guess. */}}
{{- if ne (.Values.app.configmap.MULTI_TENANT_ENABLED | default "" | toString) "true" }}
{{- if not .Values.app.secrets.PROVIDER_CLIENT_ID }}
{{- fail "\n\nERROR: app.secrets.PROVIDER_CLIENT_ID is REQUIRED in single-tenant mode.\n   Set the provider OAuth2 client ID in the secrets section.\n   (In multi-tenant it is resolved per tenant and must be left unset.)\n" }}
{{- end }}

{{- if not .Values.app.secrets.PROVIDER_CLIENT_SECRET }}
{{- fail "\n\nERROR: app.secrets.PROVIDER_CLIENT_SECRET is REQUIRED in single-tenant mode.\n   Set the provider OAuth2 client secret in the secrets section.\n   (In multi-tenant it is resolved per tenant and must be left unset.)\n" }}
{{- end }}
{{- end }}

{{- if not .Values.app.secrets.BTG_WEBHOOK_SECRET }}
{{- fail "\n\nERROR: app.secrets.BTG_WEBHOOK_SECRET is REQUIRED.\n   Set the BTG webhook bearer token in the secrets section.\n" }}
{{- end }}

{{/* Midaz Ledger URL — required for production.
     Preferred: app.configmap.MIDAZ_LEDGER_URL (single Ledger plane URL; the
     app now serves onboarding + transaction from one plane).
     DEPRECATED fallback: MIDAZ_ONBOARDING_URL + MIDAZ_TRANSACTION_URL (the
     former split pair). Still accepted for backward compatibility with
     environments that have not migrated yet; remove once all overlays use
     MIDAZ_LEDGER_URL. */}}
{{- if not .Values.app.configmap.MIDAZ_LEDGER_URL }}
{{- if not (and .Values.app.configmap.MIDAZ_ONBOARDING_URL .Values.app.configmap.MIDAZ_TRANSACTION_URL) }}
{{- fail "\n\nERROR: app.configmap.MIDAZ_LEDGER_URL is REQUIRED.\n   Set the Midaz Ledger service URL.\n   (Deprecated: the former MIDAZ_ONBOARDING_URL + MIDAZ_TRANSACTION_URL pair is still accepted as a fallback.)\n" }}
{{- end }}
{{- end }}

{{/* PostgreSQL password is single-sourced from the postgresql subchart Secret
     (<release>-postgresql, key "password") via secretKeyRef; see
     docs/helm-chart-standard.md "Single-Source Infra Secrets". No gate here:
     for the bundled subchart the value is generated; for external Postgres the
     operator supplies postgresql.auth.existingSecret or app.secrets.POSTGRES_PASSWORD. */}}

{{/* Multi-tenant required fields when enabled. Same single toggle as above, and
     the same reason: the canonical name only. An overlay still on the deprecated
     MULTI_TENANCY_ENABLED skips this block, and the app is the backstop — it
     asserts MULTI_TENANT_URL is present when tenancy is on
     (internal/bootstrap/config_multitenant.go), so the failure is a precise boot
     error rather than a missing check. */}}
{{- if eq (.Values.app.configmap.MULTI_TENANT_ENABLED | default "" | toString) "true" }}
{{- if not .Values.app.configmap.MULTI_TENANT_MANAGER_URL }}
{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_MANAGER_URL is REQUIRED when MULTI_TENANT_ENABLED=true.\n" }}
{{- end }}
{{- if not .Values.app.secrets.MULTI_TENANT_SERVICE_API_KEY }}
{{- fail "\n\nERROR: app.secrets.MULTI_TENANT_SERVICE_API_KEY is REQUIRED when MULTI_TENANT_ENABLED=true.\n" }}
{{- end }}
{{- end }}

{{/* Internal API key + credential encryption — required when worker runs in-process or as worker pod */}}
{{- $svcType := .Values.app.configmap.SERVICE_TYPE | default "both" | toString }}
{{- if or (eq $svcType "both") (eq $svcType "worker") }}
{{- if not .Values.app.secrets.INTERNAL_API_KEY }}
{{- fail "\n\nERROR: app.secrets.INTERNAL_API_KEY is REQUIRED when SERVICE_TYPE includes worker (\"both\" or \"worker\").\n   The plugin uses this key for cross-pod token retrieval.\n   Must be at least 32 characters. Generate with: openssl rand -hex 32\n" }}
{{- end }}
{{- if lt (len (.Values.app.secrets.INTERNAL_API_KEY | toString)) 32 }}
{{- fail "\n\nERROR: app.secrets.INTERNAL_API_KEY must be at least 32 characters.\n   Generate with: openssl rand -hex 32\n" }}
{{- end }}
{{- if not .Values.app.secrets.CREDENTIAL_ENCRYPTION_KEY }}
{{- fail "\n\nERROR: app.secrets.CREDENTIAL_ENCRYPTION_KEY is REQUIRED when SERVICE_TYPE includes worker (\"both\" or \"worker\").\n   The plugin uses this key to encrypt provider OAuth credentials at rest.\n   Must be a base64-encoded AES-256 key (32 random bytes).\n   Generate with: openssl rand -base64 32\n" }}
{{- end }}
{{- end }}

{{/* Split-deployment API mode requires INTERNAL_WORKER_URL */}}
{{- if eq $svcType "api" }}
{{- if not .Values.app.configmap.INTERNAL_WORKER_URL }}
{{- fail "\n\nERROR: app.configmap.INTERNAL_WORKER_URL is REQUIRED when SERVICE_TYPE=\"api\".\n   API pods need to reach the worker pod's internal token endpoint.\n" }}
{{- end }}
{{- if not .Values.app.secrets.INTERNAL_API_KEY }}
{{- fail "\n\nERROR: app.secrets.INTERNAL_API_KEY is REQUIRED when SERVICE_TYPE=\"api\".\n" }}
{{- end }}
{{- end }}

{{- end }}

{{/*
Generate annotation listing default-value warnings (non-blocking).
*/}}
{{- define "plugin-br-payments.secretWarnings" -}}
{{- $warnings := list -}}
{{- if .Values.postgresql.enabled -}}
{{- if eq (.Values.postgresql.auth.password | toString) "lerian" -}}
{{- $warnings = append $warnings "postgresql.auth.password is using default value 'lerian'" -}}
{{- end -}}
{{- end -}}
{{- if not .Values.app.secrets.LICENSE_KEY -}}
{{- $warnings = append $warnings "LICENSE_KEY is empty - required for production" -}}
{{- end -}}
{{- if gt (len $warnings) 0 -}}
lerian.studio/security-warnings: {{ $warnings | join "; " | quote }}
{{- end -}}
{{- end -}}

{{/*
Vendored from Bitnami common (charts/common/templates/_names.tpl) so infra
Secret/Service names render even when all bundled subcharts are disabled
(external-infra path). Self-contained: no other common.* helpers required.
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- if .chartValues.fullnameOverride -}}
{{- .chartValues.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .chartName .chartValues.nameOverride -}}
{{- if contains $name .context.Release.Name -}}
{{- .context.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .context.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
