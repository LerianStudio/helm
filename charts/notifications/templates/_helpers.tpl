{{/*
================================================================================
NOTIFICATIONS - HELM TEMPLATE HELPERS
================================================================================
Topology:
  - api             (HTTP service + ingress)
  - worker-email    (consumer, health probe only)
  - worker-sms      (consumer, health probe only)
  - worker-webhook  (consumer, health probe only)
External deps: Postgres, Redis, RabbitMQ. Subchart: lerian-common-helm (health preset only).
================================================================================
*/}}

{{/*
================================================================================
NAME HELPERS
================================================================================
*/}}

{{- define "notifications.name" -}}
{{- default .Values.api.name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerEmail.name" -}}
{{- default "notifications-worker-email" .Values.workerEmail.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerSms.name" -}}
{{- default "notifications-worker-sms" .Values.workerSms.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerWebhook.name" -}}
{{- default "notifications-worker-webhook" .Values.workerWebhook.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
FULLNAME HELPERS
================================================================================
*/}}

{{- define "notifications.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default "notifications" .Values.api.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "workerEmail.fullname" -}}
{{- default "notifications-worker-email" .Values.workerEmail.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerSms.fullname" -}}
{{- default "notifications-worker-sms" .Values.workerSms.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerWebhook.fullname" -}}
{{- default "notifications-worker-webhook" .Values.workerWebhook.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
CHART / VERSION HELPERS
================================================================================
*/}}

{{- define "notifications.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "notifications.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
LABEL HELPERS (parametric: pass dict with "context" and "name")
================================================================================
*/}}

{{- define "notifications.labels" -}}
helm.sh/chart: {{ include "notifications.chart" .context }}
{{ include "notifications.podLabels" . }}
{{- end }}

{{/*
Labels without helm.sh/chart, for the pod template: the chart version changes on
every release and would restart every pod each time.
*/}}
{{- define "notifications.podLabels" -}}
{{ include "notifications.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "notifications.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: notifications
{{- end }}

{{- define "notifications.selectorLabels" -}}
{{- if .name }}
app.kubernetes.io/name: {{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .name }}
app.kubernetes.io/component: {{ .name }}
{{- end }}
{{- end }}

{{/*
================================================================================
SERVICE ACCOUNT HELPER
================================================================================
*/}}

{{- define "notifications.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "notifications.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
================================================================================
SHARED CONFIGMAP / SECRET REFS
================================================================================
All components consume the same env contract, so we point envFrom at a single
ConfigMap and Secret (overridable via .Values.secretRef.name for AVP / external
secrets integration).
*/}}

{{- define "notifications.configMapName" -}}
{{- default (include "notifications.fullname" .) .Values.configMapNameOverride }}
{{- end }}

{{- define "notifications.secretName" -}}
{{- if .Values.secretRef.name }}
{{- .Values.secretRef.name }}
{{- else }}
{{- include "notifications.fullname" . }}
{{- end }}
{{- end }}

{{/*
================================================================================
NAMESPACE HELPER
================================================================================
*/}}

{{- define "notifications.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
LICENCE FILE (optional). licenseFile.existingSecret is mounted as a directory (never
subPath, so rotations propagate) at /etc/lerian/license; LICENSE_FILE_PATH points at its key.
*/}}
{{- define "notifications.licenseFileSecret" -}}
{{- (.Values.licenseFile | default dict).existingSecret | default "" -}}
{{- end }}

{{- define "notifications.licenseFileEnv" -}}
{{- if include "notifications.licenseFileSecret" . }}
- name: LICENSE_FILE_PATH
  value: /etc/lerian/license/license
{{- end }}
{{- end }}

{{- define "notifications.licenseFileVolumeMount" -}}
{{- if include "notifications.licenseFileSecret" . }}
volumeMounts:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true
{{- end }}
{{- end }}

{{- define "notifications.licenseFileVolume" -}}
{{- with include "notifications.licenseFileSecret" . }}
volumes:
  - name: license-file
    secret:
      secretName: {{ . | quote }}
      items:
        - key: license
          path: license
{{- end }}
{{- end }}

{{/*
================================================================================
HEALTH PRESET (lerian-common.health)
================================================================================
Probes, ports, HEALTH_PORT / SHUTDOWN_* env, grace, rollout strategy, PDB and the
API's internal `health` Service port belong to the preset; they are not values.
Call: include "notifications.health" (dict "context" $ "key" "api" "name" "notifications") | fromYaml

minImage is the first image that serves HEALTH_PORT: 1.2.0-beta.6, the beta cut by
the app change. The guard compares one semver and a prerelease sorts by identifier:
beta < rc < stable. It refuses beta.5 and older; v1.2.0-rc.1 sorts above the floor
but predates the cut, so staging pairs this chart only with an rc cut after it.
*/}}
{{- define "notifications.minImage" -}}1.2.0-beta.6{{- end -}}

{{- define "notifications.health" -}}
{{- $v := .context.Values -}}
{{- $c := index $v .key -}}
{{- if hasKey $v "terminationGracePeriodSeconds" -}}{{- fail "notifications: terminationGracePeriodSeconds is owned by the health preset; remove it (tune <component>.health.drainSeconds / shutdownSeconds)" -}}{{- end -}}
{{- range $k := list "probes" "deploymentStrategy" -}}
{{- if hasKey $c $k -}}{{- fail (printf "notifications: %s.%s is owned by the health preset; remove it" $.key $k) -}}{{- end -}}
{{- end -}}
{{- if and (ne $c.health.stack "go") (hasKey $c "containerPort") -}}{{- fail (printf "notifications: %s.containerPort is gone: the worker's only listener is the health port 8099; remove it" .key) -}}{{- end -}}
{{- range $k := list "maxUnavailable" "minAvailable" -}}
{{- if and (eq $.key "api") $c.pdb (hasKey $c.pdb $k) -}}{{- fail (printf "notifications: %s.pdb.%s is owned by the health preset; remove it" $.key $k) -}}{{- end -}}
{{- end -}}
{{- include "lerian-common.health" (dict
      "name" .name
      "component" (dict "image" (dict "tag" ($c.image.tag | default .context.Chart.AppVersion)) "configmap" (merge (dict) ($v.config | default dict) ($v.extraConfig | default dict) ($c.extraEnvVars | default dict)))
      "health" $c.health "port" $c.containerPort "minImage" (include "notifications.minImage" .context)
      "replicas" $c.replicaCount "autoscaling" $c.autoscaling) -}}
{{- end -}}

{{- define "notifications.api.health" -}}
{{- include "notifications.health" (dict "context" . "key" "api" "name" "notifications") -}}
{{- end -}}
