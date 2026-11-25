{{/*
Expand the name of the chart.
*/}}
{{- define "flowker.name" -}}
{{- default (default "flowker" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for flowker.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "flowker.fullname" -}}
{{- default (include "flowker.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flowker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create flowker app version
*/}}
{{- define "flowker.defaultTag" -}}
{{- default .Chart.AppVersion .Values.flowker.image.tag }}
{{- end -}}

{{/*
Return valid flowker version label
*/}}
{{- define "flowker.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "flowker.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "flowker.labels" -}}
helm.sh/chart: {{ include "flowker.chart" .context }}
{{ include "flowker.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "flowker.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flowker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flowker.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flowker.serviceAccountName" -}}
{{- if .Values.flowker.serviceAccount.create }}
{{- default (include "flowker.fullname" .) .Values.flowker.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.flowker.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
================================================================================
WORKER HELPERS
The scheduler worker is a SECOND Deployment running the SAME flowker image with
its command overridden to /worker. It reuses the api ConfigMap + Secret and
layers worker-only env on top. It gets its OWN app.kubernetes.io/name so its
(immutable) selector never overlaps the api Deployment's.
================================================================================
*/}}

{{/* Worker resource name: "<fullname>-worker". */}}
{{- define "flowker.worker.fullname" -}}
{{- printf "%s-worker" (include "flowker.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Worker app name (distinct from the api so selectors don't overlap). */}}
{{- define "flowker.worker.name" -}}
{{- printf "%s-worker" (include "flowker.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Worker selector labels — distinct name keeps the two Deployments apart. */}}
{{- define "flowker.worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flowker.worker.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/* Worker common labels. */}}
{{/* FIXME(nitpick): app.kubernetes.io/version tracks the api image tag, not
     worker.image.tag when overridden (ring-helm, 2026-07-10, Cosmetic). */}}
{{- define "flowker.worker.labels" -}}
helm.sh/chart: {{ include "flowker.chart" .context }}
{{ include "flowker.worker.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/version: {{ include "flowker.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/component: worker
{{- end }}

{{/* Worker ServiceAccount name (own SA, or reuse the api's when not creating). */}}
{{- define "flowker.worker.serviceAccountName" -}}
{{- $w := .Values.worker | default dict -}}
{{- $sa := $w.serviceAccount | default dict -}}
{{- if $sa.create }}
{{- default (include "flowker.worker.fullname" .) $sa.name }}
{{- else }}
{{- default (include "flowker.serviceAccountName" .) $sa.name }}
{{- end }}
{{- end }}

{{/* Worker enabled — gated by flowker.enabled; nil-aware on worker.enabled
     (unset/true enables, explicit false disables). */}}
{{- define "flowker.worker.enabled" -}}
{{- $w := .Values.worker | default dict -}}
{{- if and .Values.flowker.enabled (ne (toString $w.enabled) "false") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
flowker.mongoInternal — true when the bundled Bitnami mongodb subchart provides the DB.
*/}}
{{- define "flowker.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
flowker.mongoHost — the MongoDB host used by the readiness init container and the assembled URI,
kept consistent across both. When the bundled Bitnami mongodb subchart is enabled, resolve the
in-cluster Service FQDN via Bitnami's own helper (honoring collapse/nameOverride/fullnameOverride).
On the EXTERNAL path (mongodb.enabled=false) there is no in-cluster Service — return the real
external host from flowker.configmap.MONGO_HOST so the init container actually probes the external
MongoDB instead of a non-existent <release>-mongodb Service.
*/}}
{{- define "flowker.mongoHost" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if eq (include "flowker.mongoInternal" .) "true" -}}
{{- $mongoFullname := include "common.names.dependency.fullname" (dict "chartName" "mongodb" "chartValues" $mongo "context" .) -}}
{{- printf "%s.%s.svc.cluster.local" $mongoFullname (include "global.namespace" .) -}}
{{- else -}}
{{- required "flowker.configmap.MONGO_HOST is required when mongodb is external (mongodb.enabled=false)" .Values.flowker.configmap.MONGO_HOST -}}
{{- end -}}
{{- end }}

{{/*
flowker.mongoEnv — single-source the MongoDB connection (the app is URI-only).
Emits MONGO_PASSWORD (secretKeyRef) then MONGO_URI referencing it via $(MONGO_PASSWORD)
expansion (MONGO_PASSWORD MUST precede MONGO_URI in the env list). flowker authenticates as the
mongodb ROOT user (mongodb.auth.rootUser), so the Bitnami key is mongodb-root-password.
- Bundled subchart: MONGO_PASSWORD <- <release>-mongodb / mongodb-root-password.
- existingSecret override: MONGO_PASSWORD <- <existingSecret> / mongodb-root-password.
- External inline: MONGO_PASSWORD <- app Secret / MONGO_PASSWORD.
An explicit flowker.secrets.MONGO_URI wins (no assembly); it is referenced from the Secret.
Input (dict): context (root .), secretName (app Secret name for the external-inline fallback).
*/}}
{{- define "flowker.mongoEnv" -}}
{{- $ctx := .context -}}
{{- $mongo := default dict $ctx.Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- $internal := eq (include "flowker.mongoInternal" $ctx) "true" -}}
{{- if $ctx.Values.flowker.secrets.MONGO_URI }}
{{- /* The supplied URI carries the password: reference it from the Secret
   (chart Secret, or the existing Secret), never as a literal PodSpec value. */}}
- name: MONGO_URI
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: MONGO_URI
{{- else if not $ctx.Values.flowker.useExistingSecret }}
{{- if or $internal $mongoAuth.existingSecret }}
{{- /* Single-source MONGO_PASSWORD from the mongodb subchart Secret (or its
   existingSecret override) via the shared lerian-common helper. */}}
{{- include "lerian-common.infraSecretRef" (dict "context" $ctx "subchart" "mongodb" "key" "mongodb-root-password" "envName" "MONGO_PASSWORD") }}
{{- else if $ctx.Values.flowker.secrets.MONGO_PASSWORD }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: MONGO_PASSWORD
{{- else }}
{{- fail "flowker.secrets.MONGO_PASSWORD is required when mongodb is external and mongodb.auth.existingSecret is not set" }}
{{- end }}
- name: MONGO_URI
  value: {{ printf "mongodb://%s:$(MONGO_PASSWORD)@%s:27017/?authSource=admin" $mongo.auth.rootUser (include "flowker.mongoHost" $ctx) | quote }}
{{- end }}
{{- end }}

{{/*
flowker.waitForMongoInit — the shared wait-for-mongodb init container, used by
both the api and worker Deployments so they never drift. Input (dict): context (root .).
*/}}
{{- define "flowker.waitForMongoInit" -}}
{{- $ctx := .context -}}
- name: wait-for-mongodb
  image: busybox:1.37
  command:
    - /bin/sh
    - -c
    - >
      TIMEOUT=300;
      ELAPSED=0;
      {{- $mongoHost := include "flowker.mongoHost" $ctx }}
      echo "Checking {{ $mongoHost }}:27017...";
      while ! nc -z "{{ $mongoHost }}" 27017; do
        if [ $ELAPSED -ge $TIMEOUT ]; then
          echo "Timeout waiting for MongoDB after ${TIMEOUT}s";
          exit 1;
        fi;
        echo "MongoDB is not ready yet, waiting... (${ELAPSED}s/${TIMEOUT}s)";
        sleep 5;
        ELAPSED=$((ELAPSED + 5));
      done;
      echo "MongoDB is ready!";
{{- end }}

{{/*
flowker.valkey.enabled — true only for an explicit enable (default off). Backs the
scheduler queue Redis; an external Redis is used by overriding REDIS_HOST instead.
*/}}
{{- define "flowker.valkey.enabled" -}}
{{- eq (toString (.Values.valkey | default dict).enabled) "true" -}}
{{- end -}}

{{/*
flowker.awsRolesAnywhere.enabled — true only when aws.rolesAnywhere.enabled is set
(default off). Used to gate the IAM Roles Anywhere signing sidecar on non-EKS clusters.
*/}}
{{- define "flowker.awsRolesAnywhere.enabled" -}}
{{- $ra := (.Values.aws | default dict).rolesAnywhere | default dict -}}
{{- eq (toString $ra.enabled) "true" -}}
{{- end -}}

{{/*
flowker.xsdValidator.enabled — nil-aware: unset/true enables, explicit false disables.
*/}}
{{- define "flowker.xsdValidator.enabled" -}}
{{- $x := .Values.flowker.xsdValidator | default dict -}}
{{- if and .Values.flowker.enabled (ne (toString $x.enabled) "false") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
flowker.xsdValidatorContainer — the in-pod XSD validator sidecar container, shared
by the api and worker pods. Flowker reaches it over loopback (XSD_VALIDATOR_URL).
Its own /v1 authorization delegates to the Access Manager (PLUGIN_AUTH_*), defaulting
to the app's PLUGIN_AUTH_* config; AUTH_M2M_* come from the app ConfigMap itself.
Input (dict): context (root .).
*/}}
{{- define "flowker.xsdValidatorContainer" -}}
{{- $ctx := .context -}}
{{- $x := $ctx.Values.flowker.xsdValidator | default dict -}}
{{- $img := $x.image | default dict -}}
{{- $repo := $img.repository | default "ghcr.io/lerianstudio/flowker-xsd-validator" -}}
{{- $tag := $img.tag | default (include "flowker.defaultTag" $ctx) -}}
{{- $pullPolicy := $img.pullPolicy | default $ctx.Values.flowker.image.pullPolicy -}}
{{- $port := (($x.port) | default 8081) -}}
{{- $pa := $x.pluginAuth | default dict -}}
{{- $paEnabled := (ne (toString $pa.enabled) "") | ternary (toString $pa.enabled) ($ctx.Values.flowker.configmap.PLUGIN_AUTH_ENABLED | default "false" | toString) -}}
{{- $paAddress := $pa.address | default $ctx.Values.flowker.configmap.PLUGIN_AUTH_ADDRESS | default "" -}}
{{- if and (eq $paEnabled "true") (hasPrefix "http://" $paAddress) (ne (toString $pa.allowInsecureHttp) "true") -}}
{{- fail (printf "flowker.xsdValidator: PLUGIN_AUTH_ADDRESS %q is cleartext http:// and the sidecar exits on it unless you acknowledge it. Set flowker.xsdValidator.pluginAuth.allowInsecureHttp=\"true\", use an https:// address, or disable the sidecar (flowker.xsdValidator.enabled=false)" $paAddress) -}}
{{- end -}}
{{- $lp := $x.livenessProbe | default dict -}}
{{- $rp := $x.readinessProbe | default dict -}}
- name: xsd-validator
  image: "{{ $repo }}:{{ $tag }}"
  imagePullPolicy: {{ $pullPolicy }}
  securityContext:
    {{- toYaml $x.securityContext | nindent 4 }}
  env:
    - name: PORT
      value: {{ $port | quote }}
    - name: ENV_NAME
      value: {{ $x.envName | default $ctx.Values.flowker.configmap.ENV_NAME | default "development" | quote }}
    - name: MAX_BODY_BYTES
      value: {{ $x.maxBodyBytes | default "5242880" | quote }}
    - name: READ_TIMEOUT
      value: {{ $x.readTimeout | default "10s" | quote }}
    - name: WRITE_TIMEOUT
      value: {{ $x.writeTimeout | default "10s" | quote }}
    - name: PLUGIN_AUTH_ENABLED
      {{- /* toString distinguishes set-vs-unset so a typed bool false is honored (not swallowed by default) */}}
      value: {{ (ne (toString $pa.enabled) "") | ternary (toString $pa.enabled) ($ctx.Values.flowker.configmap.PLUGIN_AUTH_ENABLED | default "false") | quote }}
    - name: PLUGIN_AUTH_ADDRESS
      value: {{ $pa.address | default $ctx.Values.flowker.configmap.PLUGIN_AUTH_ADDRESS | default "" | quote }}
    - name: PLUGIN_AUTH_ALLOW_INSECURE_HTTP
      value: {{ $pa.allowInsecureHttp | default "false" | quote }}
    {{- /* lib-auth M2M switches: same ConfigMap key flowker loads, so the sidecar never diverges; absent key stays unset */}}
    {{- range list "AUTH_M2M_INVERSION_ENABLED" "AUTH_M2M_PRODUCT_FORWARD_ENABLED" }}
    - name: {{ . }}
      valueFrom:
        configMapKeyRef:
          name: {{ include "flowker.fullname" $ctx }}
          key: {{ . }}
          optional: true
    {{- end }}
  ports:
    - name: xsd
      containerPort: {{ $port }}
      protocol: TCP
  livenessProbe:
    httpGet:
      path: /health
      port: xsd
    initialDelaySeconds: {{ $lp.initialDelaySeconds | default 10 }}
    periodSeconds: {{ $lp.periodSeconds | default 20 }}
    timeoutSeconds: {{ $lp.timeoutSeconds | default 5 }}
    successThreshold: {{ $lp.successThreshold | default 1 }}
    failureThreshold: {{ $lp.failureThreshold | default 3 }}
  readinessProbe:
    httpGet:
      path: /health
      port: xsd
    initialDelaySeconds: {{ $rp.initialDelaySeconds | default 5 }}
    periodSeconds: {{ $rp.periodSeconds | default 10 }}
    timeoutSeconds: {{ $rp.timeoutSeconds | default 5 }}
    successThreshold: {{ $rp.successThreshold | default 1 }}
    failureThreshold: {{ $rp.failureThreshold | default 3 }}
  resources:
    {{- toYaml $x.resources | nindent 4 }}
{{- end }}

{{/*
Collapse-aware "<release>-<name>" subchart resource name. Thin alias to the
shared lerian-common helper so infra Secret/Service names render even when all
bundled subcharts are disabled (external-infra path). Kept as a 1-line alias so
existing callers (mongoEnv, mongoHost, configmap valkey host) keep working.
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- include "lerian-common.dependency.fullname" . -}}
{{- end -}}

{{/*
Licence-file Secret name from .Values.flowker (api and worker share it); nil-safe for
`helm upgrade --reuse-values` over older releases. Mounted whole as a directory, never a subPath.
*/}}
{{- define "flowker.licenseFileSecret" -}}
{{- ((. | default dict).licenseFile | default dict).existingSecret | default "" -}}
{{- end }}

{{- define "flowker.licenseFileEnv" -}}
- name: LICENSE_FILE_PATH
  value: /etc/lerian/license/license.lic
{{- end }}

{{- define "flowker.licenseFileMount" -}}
volumeMounts:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true
{{- end }}

{{- define "flowker.licenseFileVolume" -}}
- name: license-file
  secret:
    secretName: {{ . | quote }}
    defaultMode: 0444
    items:
      - key: license.lic
        path: license.lic
{{- end }}

{{/*
flowker.health / flowker.worker.health: the lerian-common health preset for the api and
the worker. minImage is the first Flowker image that serves HEALTH_PORT. The retired
rollout values are refused here, as the preset refuses probes, grace and its env.
*/}}
{{- define "flowker.health" -}}
{{- range $key := list "enabled" "minAvailable" "maxUnavailable" -}}
{{- if hasKey ($.Values.flowker.pdb | default dict) $key -}}
{{- fail (printf "flowker.pdb.%s is owned by the health preset" $key) -}}
{{- end -}}
{{- end -}}
{{- if hasKey .Values.flowker "deploymentUpdate" -}}
{{- fail "flowker.deploymentUpdate is owned by the health preset" -}}
{{- end -}}
{{- $f := .Values.flowker -}}
{{- include "lerian-common.health" (dict
      "name" (include "flowker.fullname" .)
      "component" (dict "image" (dict "tag" (include "flowker.defaultTag" .)) "configmap" $f.configmap "livenessProbe" $f.livenessProbe "readinessProbe" $f.readinessProbe)
      "health" $f.health "port" $f.service.port "minImage" "1.7.0-beta.50"
      "replicas" $f.replicaCount "autoscaling" $f.autoscaling) -}}
{{- end -}}

{{- define "flowker.worker.health" -}}
{{- $w := .Values.worker | default dict -}}
{{- if hasKey $w "deploymentStrategy" -}}
{{- fail "worker.deploymentStrategy is owned by the health preset" -}}
{{- end -}}
{{- include "lerian-common.health" (dict
      "name" (include "flowker.worker.fullname" .)
      "component" (dict "image" (dict "tag" ((($w.image | default dict).tag) | default (include "flowker.defaultTag" .))) "configmap" $w.configmap "livenessProbe" $w.livenessProbe "readinessProbe" $w.readinessProbe "terminationGracePeriodSeconds" $w.terminationGracePeriodSeconds)
      "health" (mergeOverwrite (deepCopy ($w.health | default dict)) (dict "stack" "go-worker" "singleton" true))
      "port" (($w.service).port | default 4022) "minImage" "1.7.0-beta.50") -}}
{{- end -}}
