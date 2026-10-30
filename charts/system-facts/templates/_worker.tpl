{{/*
==============================================================================
internal-facts-worker — helpers for the optional `worker` workload.

The worker is a separate binary (image system-facts-worker) that consumes
product events from RedPanda and delivers facts to the System Facts API. It is
NOT an HTTP service: its admin port (/health, /readyz, /version) is for the
kubelet only, so this chart renders no Service, Ingress, HPA or PDB for it, and
no database, Redis or migrations contract.

SELECTOR ISOLATION. The API's selector is app.kubernetes.io/name +
app.kubernetes.io/instance (system-facts.selectorLabels is called without a
component there), and the API Service and HPA match on it. A worker pod that
carried name=system-facts would be selected by the API Service and receive API
traffic on its admin port. The worker therefore has its OWN name label
(<name>-worker); the component label alone would not separate them.
==============================================================================
*/}}

{{- define "system-facts.worker.fullname" -}}
{{- printf "%s-worker" (include "system-facts.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "system-facts.worker.selectorLabels" -}}
app.kubernetes.io/name: {{ printf "%s-worker" (include "system-facts.name" .) | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "system-facts.worker.tag" -}}
{{- default .Chart.AppVersion (dig "image" "tag" "" .Values.worker) -}}
{{- end -}}

{{- define "system-facts.worker.labels" -}}
helm.sh/chart: {{ include "system-facts.chart" . }}
{{ include "system-facts.worker.selectorLabels" . }}
app.kubernetes.io/component: worker
app.kubernetes.io/version: {{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "system-facts.worker.tag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "system-facts.extraCommonLabels" . }}
{{- end -}}

{{- define "system-facts.worker.serviceAccountName" -}}
{{- $sa := .Values.worker.serviceAccount | default dict -}}
{{- if $sa.create | default false -}}
{{- default (include "system-facts.worker.fullname" .) $sa.name -}}
{{- else -}}
{{- default "default" $sa.name -}}
{{- end -}}
{{- end -}}

{{- define "system-facts.worker.secretName" -}}
{{- if .Values.worker.useExistingSecret -}}
{{- .Values.worker.existingSecretName -}}
{{- else -}}
{{- include "system-facts.worker.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
system-facts.worker.configData — the worker ConfigMap as a dict (JSON), so the
ConfigMap and the checksum annotation render from one source.

Precedence, lowest to highest: productized params, raw `worker.configmap.<KEY>`,
`worker.extraEnvVars`. Keys with an empty value are not emitted, so an unset
optional key falls through to the binary's own default instead of overriding it
with a blank. SYSTEM_FACTS_ALLOW_INSECURE_HTTP is always emitted, like REQUIRE_BROKER_SECURITY.
*/}}
{{- define "system-facts.worker.configData" -}}
{{- $w := .Values.worker -}}
{{- $sf := $w.systemFacts | default dict -}}
{{- $mt := $w.multiTenant | default dict -}}
{{- $st := $w.streaming | default dict -}}
{{- $ot := $w.otel | default dict -}}
{{- $tm := $w.timing | default dict -}}
{{- $cand := dict
      "SYSTEM_FACTS_URL" ($sf.url | default "")
      "SYSTEM_FACTS_AUTH_URL" ($sf.authUrl | default "")
      "SYSTEM_FACTS_ALLOW_INSECURE_HTTP" (toString ($sf.allowInsecureHttp | default false))
      "WORKER_PRODUCTS" (join "," ($w.products | default list))
      "MULTI_TENANT_ENABLED" (toString ($mt.enabled | default "false"))
      "ENV_NAME" ($mt.env | default "")
      "M2M_APPLICATION_NAME" ($mt.m2mApplicationName | default "")
      "M2M_TARGET_SERVICE" ($mt.m2mTargetService | default "")
      "STREAMING_CONSUMER_ENABLED" "true"
      "STREAMING_CONSUMER_BROKERS" ($st.brokers | default "")
      "STREAMING_CLOUDEVENTS_SOURCE" ($st.cloudeventsSource | default "")
      "STREAMING_TLS_ENABLED" (toString (ternary "true" $st.tlsEnabled (kindIs "invalid" $st.tlsEnabled)))
      "STREAMING_SASL_MECHANISM" ($st.saslMechanism | default "")
      "STREAMING_SASL_USERNAME" ($st.saslUsername | default "")
      "STREAMING_TOPIC_AUTO_PROVISION" (toString (ternary "" $st.topicAutoProvision (kindIs "invalid" $st.topicAutoProvision)))
      "REQUIRE_BROKER_SECURITY" (toString (ternary "true" $st.requireSecurity (kindIs "invalid" $st.requireSecurity)))
      "SERVER_ADDRESS" (printf ":%v" ($w.port | default 8080))
      "ENVIRONMENT_NAME" ($w.environmentName | default "")
      "ENABLE_TELEMETRY" (toString ($ot.enabled | default "false"))
      "OTEL_RESOURCE_SERVICE_NAME" ($ot.serviceName | default "")
      "OTEL_LIBRARY_NAME" ($ot.libraryName | default "")
      "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" ($ot.deploymentEnvironment | default "")
      "OTEL_EXPORTER_OTLP_ENDPOINT" ($ot.endpoint | default "")
      "WORKER_LAG_POLL_INTERVAL" ($tm.lagPollInterval | default "")
      "TENANT_CREDENTIAL_CACHE_TTL" ($tm.credentialCacheTtl | default "")
      "TENANT_CREDENTIAL_NEGATIVE_TTL" ($tm.credentialNegativeTtl | default "")
-}}
{{- $data := dict -}}
{{- range $k, $v := $cand -}}
{{- if ne (toString $v) "" -}}{{- $_ := set $data $k (toString $v) -}}{{- end -}}
{{- end -}}
{{- range $k, $v := ($w.configmap | default dict) -}}
{{- $_ := set $data $k (toString $v) -}}
{{- end -}}
{{- range ($w.extraEnvVars | default list) -}}
{{- $_ := set $data .name (toString .value) -}}
{{- end -}}
{{- toJson $data -}}
{{- end -}}

{{/*
system-facts.worker.secretData — the worker Secret as a dict (JSON). Only the
four keys the worker reads from a secret; empty ones are not emitted.
*/}}
{{- define "system-facts.worker.secretData" -}}
{{- $s := .Values.worker.secrets | default dict -}}
{{- $data := dict -}}
{{- range $k, $v := $s -}}
{{- if ne (toString $v) "" -}}{{- $_ := set $data $k (toString $v) -}}{{- end -}}
{{- end -}}
{{- toJson $data -}}
{{- end -}}

{{/*
system-facts.worker.validate — render-time refusals. Each one is a boot refusal
or a silent no-op in the binary; failing the render names the value instead of
leaving an operator to read a CrashLoopBackOff.
*/}}
{{- define "system-facts.worker.validate" -}}
{{- $w := .Values.worker -}}
{{- $cfg := include "system-facts.worker.configData" . | fromJson -}}
{{- $sec := include "system-facts.worker.secretData" . | fromJson -}}
{{- /* 1. Settings the products fix. The binary refuses to boot on them. */ -}}
{{- range $k := list "STREAMING_CONSUMER_TOPICS" "STREAMING_CONSUMER_COMMANDS" "STREAMING_CONSUMER_APPS" "STREAMING_CONSUMER_GROUP" -}}
{{- if hasKey $cfg $k -}}
{{- fail (printf "system-facts: worker sets %s. The products fix the consumer topics, commands, apps and group; the worker refuses to boot when they are set. Remove it from worker.configmap / worker.extraEnvVars." $k) -}}
{{- end -}}
{{- end -}}
{{- /* 2. The consumer switch. Off, the binary boots, reports ready and reads nothing. */ -}}
{{- if ne (get $cfg "STREAMING_CONSUMER_ENABLED") "true" -}}
{{- fail "system-facts: worker STREAMING_CONSUMER_ENABLED must be true: with it off the worker boots, stays ready and consumes nothing." -}}
{{- end -}}
{{- /* 3. Required wiring. */ -}}
{{- range $k := list "SYSTEM_FACTS_URL" "SYSTEM_FACTS_AUTH_URL" "STREAMING_CONSUMER_BROKERS" -}}
{{- if not (hasKey $cfg $k) -}}
{{- fail (printf "system-facts: worker.enabled=true needs %s (worker.systemFacts.url / authUrl, worker.streaming.brokers)." $k) -}}
{{- end -}}
{{- end -}}
{{- if and (eq (get $cfg "MULTI_TENANT_ENABLED") "true") (not (hasKey $cfg "ENV_NAME")) -}}
{{- fail "system-facts: worker multi-tenant mode needs worker.multiTenant.env (ENV_NAME): it names the Secrets Manager path of the per-tenant credentials." -}}
{{- end -}}
{{- /* 4. Credentials. A missing one is a refusal at boot, not at render, unless we check here. */ -}}
{{- if not $w.useExistingSecret -}}
{{- range $k := list "SYSTEM_FACTS_CLIENT_ID" "SYSTEM_FACTS_CLIENT_SECRET" -}}
{{- if not (hasKey $sec $k) -}}
{{- fail (printf "system-facts: worker.secrets.%s is required (the bootstrap credential that registers the manifests; also delivers in single-tenant mode)." $k) -}}
{{- end -}}
{{- end -}}
{{- if and (hasKey $cfg "STREAMING_SASL_MECHANISM") (not (hasKey $sec "STREAMING_SASL_PASSWORD")) -}}
{{- fail "system-facts: worker.secrets.STREAMING_SASL_PASSWORD is required when worker.streaming.saslMechanism is set." -}}
{{- end -}}
{{- end -}}
{{- if and (hasKey $cfg "STREAMING_SASL_MECHANISM") (not (hasKey $cfg "STREAMING_SASL_USERNAME")) -}}
{{- fail "system-facts: worker.streaming.saslUsername is required when worker.streaming.saslMechanism is set." -}}
{{- end -}}
{{- if and $w.useExistingSecret (not $w.existingSecretName) -}}
{{- fail "system-facts: worker.useExistingSecret=true needs worker.existingSecretName." -}}
{{- end -}}
{{- /* 5. Topology. Parallelism is bounded by distinct tenants, not by replicas. */ -}}
{{- $ceiling := int ($w.partitionCeiling | default 1) -}}
{{- if gt (int ($w.replicaCount | default 1)) $ceiling -}}
{{- fail (printf "system-facts: worker.replicaCount=%v exceeds worker.partitionCeiling=%v. Replicas past the ceiling own no partition and sit idle with a green probe. Raise the ceiling only after reading the partition count (rpk topic describe <topic> -p) and the number of distinct tenants." $w.replicaCount $ceiling) -}}
{{- end -}}
{{- /* 6. Shutdown budget: consumer close 30s + admin drain 10s + telemetry 10s. */ -}}
{{- if lt (int ($w.terminationGracePeriodSeconds | default 60)) 60 -}}
{{- fail "system-facts: worker.terminationGracePeriodSeconds must be >= 60 (consumer close 30s + admin drain 10s + telemetry flush); below it the kubelet SIGKILLs mid-drain." -}}
{{- end -}}
{{- /* 7. Product selection (system-facts #71). The binary refuses each of these at boot. */ -}}
{{- $raw := trim (get $cfg "WORKER_PRODUCTS") -}}
{{- if ne $raw "" -}}
{{- $known := list "midaz" "plugin-br-pix-jd" -}}
{{- $seen := dict -}}
{{- range (splitList "," $raw) -}}
{{- $e := trim . -}}
{{- if eq $e "" -}}
{{- fail (printf "system-facts: worker WORKER_PRODUCTS has an empty entry in %q. List the products separated by single commas, with no blank entry (worker.products: [midaz, plugin-br-pix-jd])." $raw) -}}
{{- end -}}
{{- if not (has $e $known) -}}
{{- fail (printf "system-facts: worker WORKER_PRODUCTS names unknown product %q. Known products: midaz, plugin-br-pix-jd (System Facts producer names, not broker app names such as ledger). Fix worker.products." $e) -}}
{{- end -}}
{{- if hasKey $seen $e -}}
{{- fail (printf "system-facts: worker WORKER_PRODUCTS lists %q more than once. Name each product once in worker.products." $e) -}}
{{- end -}}
{{- $_ := set $seen $e true -}}
{{- end -}}
{{- if and (hasKey $seen "plugin-br-pix-jd") (not (hasKey $seen "midaz")) -}}
{{- fail "system-facts: worker WORKER_PRODUCTS selects plugin-br-pix-jd without midaz. plugin-br-pix-jd requires midaz: its manifest mirrors lerian.midaz.transaction_id. Add midaz to worker.products." -}}
{{- end -}}
{{- end -}}
{{- /* 8. Plain http (system-facts #65). Without the opt-in the binary refuses a non-loopback http URL at boot; the chart refuses every http URL, loopback included (a pod never reaches the API on its own loopback). */ -}}
{{- /* The opt-in mirrors Go strconv.ParseBool after TrimSpace, case-sensitive like the binary's parseBool. */ -}}
{{- $v := trim (get $cfg "SYSTEM_FACTS_ALLOW_INSECURE_HTTP") -}}
{{- $trueSet := list "1" "t" "T" "TRUE" "true" "True" -}}
{{- $falseSet := list "0" "f" "F" "FALSE" "false" "False" -}}
{{- if and $v (not (has $v $trueSet)) (not (has $v $falseSet)) -}}
{{- fail (printf "system-facts: worker SYSTEM_FACTS_ALLOW_INSECURE_HTTP is %q: not a boolean (use true/false/1/0). Set worker.systemFacts.allowInsecureHttp to true or false." $v) -}}
{{- end -}}
{{- $insecure := has $v $trueSet -}}
{{- range $k := list "SYSTEM_FACTS_URL" "SYSTEM_FACTS_AUTH_URL" -}}
{{- $v := get $cfg $k -}}
{{- if and (not $insecure) (hasPrefix "http://" (lower (trim $v))) -}}
{{- /* Mask userinfo so a password never reaches helm, ArgoCD or CI output. */ -}}
{{- /* Print the origin only: userinfo masked, path/query/fragment dropped, so no token in a URL reaches helm, ArgoCD or CI output. */ -}}
{{- /* Mask first, on the full value: a malformed password holding "/", "?" or "#" would
       otherwise end the origin inside the userinfo and print part of it. */ -}}
{{- $masked := regexReplaceAll "^([A-Za-z][A-Za-z0-9+.-]*://).*@" (trim $v) "${1}<redacted>@" -}}
{{- $shown := regexReplaceAll "^([A-Za-z][A-Za-z0-9+.-]*://[^/?#]*).*$" $masked "${1}" -}}
{{- fail (printf "system-facts: worker %s is %q: plain http is not allowed (this chart has no loopback exception: a pod never reaches the API on its own loopback). Use https, or set worker.systemFacts.allowInsecureHttp=true only inside a namespace whose pod-to-pod traffic is already encrypted (e.g. istio.io/dataplane-mode: ambient)." $k $shown) -}}
{{- end -}}
{{- end -}}
{{- end -}}
