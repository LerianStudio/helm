{{/*
Expand the name of the chart.
*/}}
{{- define "streaming-hub.name" -}}
{{- default "streaming-hub" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec). When fullnameOverride is set it wins verbatim.
*/}}
{{- define "streaming-hub.fullname" -}}
{{- default (include "streaming-hub.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "streaming-hub.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the image tag, falling back to the chart appVersion when image.tag is "".
*/}}
{{- define "streaming-hub.defaultTag" -}}
{{- default .Chart.AppVersion .Values.streamingHub.image.tag }}
{{- end -}}

{{/*
Return a valid version label value (k8s label charset).
*/}}
{{- define "streaming-hub.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "streaming-hub.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Component fully-qualified name: <fullname>-<component>.
Input: dict { context, component }. Truncated to 63 chars.
Used by every per-role Deployment/Service/HPA/PDB so the three role variants
never collide on a name.
*/}}
{{- define "streaming-hub.componentFullname" -}}
{{- $fullname := include "streaming-hub.fullname" .context -}}
{{- printf "%s-%s" $fullname .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Base selector labels (no component).
Input: dict { context }.
*/}}
{{- define "streaming-hub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "streaming-hub.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Component-aware selector labels: base labels + app.kubernetes.io/component.
Input: dict { context, component }. The component label is the load-bearing
discriminator that keeps split-mode (ingest/delivery) Deployments from sharing
one ReplicaSet selector.
*/}}
{{- define "streaming-hub.componentSelectorLabels" -}}
{{ include "streaming-hub.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Component-aware common labels (selector labels + chart/version/managed-by/part-of).
Input: dict { context, component }.
*/}}
{{- define "streaming-hub.labels" -}}
helm.sh/chart: {{ include "streaming-hub.chart" .context }}
{{ include "streaming-hub.componentSelectorLabels" (dict "context" .context "component" .component) }}
app.kubernetes.io/version: {{ include "streaming-hub.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: streaming-hub
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "streaming-hub.serviceAccountName" -}}
{{- if .Values.streamingHub.serviceAccount.create }}
{{- default (include "streaming-hub.fullname" .) .Values.streamingHub.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.streamingHub.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Resolve the shared Secret name a Deployment should reference:
existingSecretName when useExistingSecret, otherwise the shared chart Secret.
Input: root context (.).
The existing-Secret path carries a KEY contract, not just a name: the
Deployments pin STREAMING_HUB_POSTGRES_DSN,
STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY and LICENSE_KEY via secretKeyRef
(_deployment.tpl),
so the `required` message below states the full contract the external Secret
must satisfy.
*/}}
{{- define "streaming-hub.secretName" -}}
{{- if .Values.streamingHub.useExistingSecret -}}
{{- required "\n\nERROR: streamingHub.existingSecretName is required when streamingHub.useExistingSecret=true. The referenced Secret MUST carry the keys STREAMING_HUB_POSTGRES_DSN, STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY and LICENSE_KEY — the Deployments consume all three via explicit secretKeyRefs, and a Secret missing any of them fails container creation (CreateContainerConfigError) instead of starting the app." .Values.streamingHub.existingSecretName -}}
{{- else -}}
{{- include "streaming-hub.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
streaming-hub.migrationDSN — STREAMING_HUB_POSTGRES_DSN for the migration-only
Secret hook. migration-secret.yaml renders only on the chart-managed credential
path (NOT migrations.useExistingSecret), and runs as a PreSync hook BEFORE the
normal app Secret exists, so the operator MUST supply the DSN here. Kept as a
named gate helper (not an inline `required`) to mirror the bank-transfer pattern.
Input: root context (.).
*/}}
{{- define "streaming-hub.migrationDSN" -}}
{{- $secrets := get (.Values.streamingHub | default dict) "secrets" | default dict -}}
{{- required "streamingHub.secrets.STREAMING_HUB_POSTGRES_DSN is required when migrations run with a chart-managed Secret (migrations.useExistingSecret=false)" (get $secrets "STREAMING_HUB_POSTGRES_DSN") -}}
{{- end -}}

{{/*
=============================================================================
postgres.caBundle — the Postgres/RDS server CA the app and the migration
toolchain verify the database certificate against.

The hardened 2.x boot REFUSES a DSN whose sslmode is verify-full (or
verify-ca/require) unless sslrootcert names a READABLE bundle, so the file has
to be in the container before the DSN is ever dialed. This chart guarantees only
the FILE, at one fixed path:

    /etc/streaming-hub/postgres-ca/bundle.pem

The DSN itself keeps coming from the Secret (gitops/Vault); it is what points
sslrootcert at that path.

Two mutually-exclusive sources:
  - caBundle.pem               -> the chart renders its own ConfigMap
  - caBundle.existingConfigMap -> an operator-managed one, which MUST carry the
                                  key `bundle.pem` (the volume pins that single
                                  key, so a ConfigMap keyed otherwise blocks pod
                                  creation with a clear kubelet event instead of
                                  booting the app with no CA at the path).
Neither set while enabled=true is a hard render failure: mounting a ConfigMap
that does not exist hangs every pod in ContainerCreating with no useful message.
=============================================================================
*/}}

{{/*
streaming-hub.postgresCaConfigMapName — resolve which ConfigMap to mount.
Input: dict { context (root "."), hook (bool) }.

hook=true asks for the PreSync COPY the migrations Job mounts. The Job is a
pre-install/pre-upgrade hook at weight -1, so a NORMAL (main-sync) ConfigMap
does not exist yet when it runs — the same ordering gap migration-secret.yaml
exists to close for the DSN. With existingConfigMap the operator owns the object
and it already exists, so both paths resolve to that one name.
*/}}
{{- define "streaming-hub.postgresCaConfigMapName" -}}
{{- $ := .context -}}
{{- $ca := get ($.Values.postgres | default dict) "caBundle" | default dict -}}
{{- $existing := get $ca "existingConfigMap" | default "" -}}
{{- if and $existing (get $ca "pem") -}}
{{- fail "\n\nERROR: postgres.caBundle.pem and postgres.caBundle.existingConfigMap are mutually exclusive — set exactly one. With both, the chart would render a ConfigMap from `pem` that nothing ever mounts, while every workload silently verified against the OTHER bundle." -}}
{{- end -}}
{{- if $existing -}}
{{- $existing -}}
{{- else -}}
{{- if not (get $ca "pem") -}}
{{- fail "\n\nERROR: postgres.caBundle.enabled=true requires EITHER postgres.caBundle.pem (the chart renders the ConfigMap) OR postgres.caBundle.existingConfigMap (an operator-managed ConfigMap carrying the key bundle.pem). Neither is set, and mounting a ConfigMap that does not exist leaves every pod stuck in ContainerCreating." -}}
{{- end -}}
{{- $suffix := ternary "migrations-postgres-ca" "postgres-ca" (.hook | default false) -}}
{{/*
The BASE is truncated to 63 minus the separator and the suffix, so the suffix
always survives. Truncating the joined string instead (what componentFullname
does, where every suffix is short) collapses both names onto the bare fullname
once it approaches 63 chars — the normal ConfigMap and the PreSync copy would
then share one name and overwrite each other.
*/}}
{{- $base := include "streaming-hub.fullname" $ | trunc (int (sub 62 (len $suffix))) | trimSuffix "-" -}}
{{- printf "%s-%s" $base $suffix -}}
{{- end -}}
{{- end -}}

{{/*
streaming-hub.postgresCaVolume — the pod volume entry.
Input: dict { context, hook }. Caller: nindent 6 or 8 (see _deployment.tpl).
*/}}
{{- define "streaming-hub.postgresCaVolume" -}}
- name: postgres-ca
  configMap:
    name: {{ include "streaming-hub.postgresCaConfigMapName" . }}
    defaultMode: 0444
    items:
      - key: bundle.pem
        path: bundle.pem
{{- end -}}

{{/*
streaming-hub.postgresCaVolumeMount — the container mount entry. The mountPath
is the DIRECTORY; the pinned `bundle.pem` item lands inside it, so the file the
DSN's sslrootcert names is /etc/streaming-hub/postgres-ca/bundle.pem.
Input: none. Caller: nindent 12.
*/}}
{{- define "streaming-hub.postgresCaVolumeMount" -}}
- name: postgres-ca
  mountPath: /etc/streaming-hub/postgres-ca
  readOnly: true
{{- end -}}

{{/*
streaming-hub.licenseGuard — render-time mirror of the app's license config
gate (lib-license-go, GLOBAL mode). Fails the render for the combination the
license-gated app refuses at boot, so the operator reads the fix in the `helm`
output instead of a CrashLoopBackOff:
  - ORGANIZATION_IDS not EXACTLY "global" (trimmed, case-sensitive: the app
    compares the literal, so "GLOBAL" or a comma list is refused).
The EFFECTIVE value is judged: streamingHub.extraEnvVars is explicit env and
WINS over the ConfigMap (envFrom), so it is read first.
LICENSE_KEY is deliberately NOT `required` here: like the DSN and the cursor
HMAC key it is always emitted (even empty) so a bare `helm template` (CI lint,
kubescape) still renders; an empty key refuses the boot by name.
It also refuses LICENSE_KEY in extraEnvVars, which would put the license in
plaintext on the Deployment spec. (configmap.LICENSE_KEY is already rejected by
the values.schema.json allowlist and skipped by the ConfigMap's leak guard.)
Input: root context (.).
*/}}
{{- define "streaming-hub.licenseGuard" -}}
{{- $sh := .Values.streamingHub -}}
{{- $cm := $sh.configmap | default dict -}}
{{- $x := $sh.extraEnvVars | default dict -}}
{{- if hasKey $x "LICENSE_KEY" -}}
{{- fail "\n\nERROR: streamingHub.extraEnvVars.LICENSE_KEY is refused: extraEnvVars renders plaintext env on the Deployment. Set streamingHub.secrets.LICENSE_KEY, or carry LICENSE_KEY in the Secret named by streamingHub.existingSecretName (useExistingSecret=true)." -}}
{{- end -}}
{{- $org := trim (toString (ternary (get $x "ORGANIZATION_IDS") (get $cm "ORGANIZATION_IDS" | default "global") (hasKey $x "ORGANIZATION_IDS"))) -}}
{{- if ne $org "global" -}}
{{- fail (printf "\n\nERROR: ORGANIZATION_IDS must be exactly \"global\" (got %q): streaming-hub supports GLOBAL license mode only, and the app refuses any other value at boot (ErrLicenseOrganizationIDsInvalid). Leave streamingHub.configmap.ORGANIZATION_IDS unset (the chart default is \"global\")." $org) -}}
{{- end -}}
{{- end -}}
