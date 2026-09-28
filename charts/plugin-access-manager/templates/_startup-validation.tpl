{{/*
Validate the values that can be checked offline against application 3.9.0's
startup contract. Keep transport enforcement in the application; a successful
render cannot prove DNS, certificate trust, discovery results or Secret contents.
*/}}
{{- define "plugin-access-manager.identityAuthEnabled" -}}
{{- $value := .Values.identity.configmap.AUTH_ENABLED -}}
{{- if or (kindIs "invalid" $value) (eq (toString $value) "") -}}
true
{{- else -}}
{{- toString $value -}}
{{- end -}}
{{- end -}}

{{- define "plugin-access-manager.validateStartup" -}}
{{- range $component := list "auth" "identity" -}}
{{- $values := index $.Values $component -}}
{{- $cm := $values.configmap | default dict -}}
{{- $extra := $values.extraEnvVars | default dict -}}
{{- /* These keys are already emitted by the chart. A duplicate YAML key must
not make validation inspect a different value than Kubernetes receives. */ -}}
{{- $ownedKeys := list "ENV_NAME" "AUTHORIZER_ADDRESS" "SD_ENABLED" -}}
{{- if eq $component "identity" -}}{{- $ownedKeys = append $ownedKeys "PLUGIN_AUTH_ENABLED" -}}{{- end -}}
{{- range $key := $ownedKeys -}}
{{- if hasKey $extra $key -}}
{{- fail (printf "%s.extraEnvVars.%s duplicates a chart-owned ConfigMap key; configure %s.configmap instead (use AUTH_ENABLED for PLUGIN_AUTH_ENABLED)." $component $key $component) -}}
{{- end -}}
{{- end -}}
{{- if and (eq $component "identity") (hasKey $extra "AUTH_M2M_JWKS_URL") ($cm.AUTH_M2M_JWKS_URL | default "") -}}
{{- fail "AUTH_M2M_JWKS_URL is set in both identity.configmap and identity.extraEnvVars; keep only one source." -}}
{{- end -}}
{{- $env := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "env" "field" "name" "nativeKey" "ENV_NAME" "default" "development") | trim | lower -}}
{{- $authEnabled := true -}}
{{- if eq $component "identity" -}}
{{- $flag := include "plugin-access-manager.identityAuthEnabled" $ -}}
{{- if not (has $flag (list "1" "t" "T" "TRUE" "true" "True" "0" "f" "F" "FALSE" "false" "False")) -}}
{{- fail "identity.configmap.AUTH_ENABLED must be a boolean accepted by the application." -}}
{{- end -}}
{{- $authEnabled = has $flag (list "1" "t" "T" "TRUE" "true" "True") -}}
{{- end -}}
{{- /* Match the emitted SD_ENABLED and lib-service-discovery v2.0.0's
ConfigFromEnv/anyEnvTrue: only the exact string "true" enables discovery (not
strconv.ParseBool); its legacy alias can also enable it. Auth validates the
resolved endpoint or fallback at runtime. Identity's JWKS URL stays static. */ -}}
{{- $discovery := and (eq $component "auth") (or (eq (toString ($cm.SD_ENABLED | default "false")) "true") (eq (toString ($extra.SERVICE_DISCOVERY_ENABLED | default "false")) "true")) -}}
{{- if and $authEnabled (not $discovery) (not (has $env (list "development" "staging" "local"))) -}}
{{- $address := $cm.AUTHORIZER_ADDRESS | default (printf "http://%s:%v" (include "plugin-caradhras.fullname" $) (include "caradhras.servicePort" $)) -}}
{{- $url := printf "%s/.well-known/jwks" (trimSuffix "/" $address) -}}
{{- if eq $component "identity" -}}
{{- $explicit := $cm.AUTH_M2M_JWKS_URL | default $extra.AUTH_M2M_JWKS_URL | default "" | toString | trim -}}
{{- if $explicit -}}{{- $url = $explicit -}}{{- end -}}
{{- end -}}
{{- $parsed := urlParse $url -}}
{{- /* Additional chart policy: require HTTPS even for Identity loopback URLs.
Do not approximate net.ParseIP.IsLoopback with a Helm regex. This only checks
that the parsed authority contains a host (including bracketed IPv6), not DNS
or IP validity; the runtime remains responsible for validating the endpoint. */ -}}
{{- $hasHost := regexMatch `^(\[[^\[\]]+\]|[^\[\]:]+)(:[0-9]*)?$` ($parsed.host | default "") -}}
{{- if or (not $hasHost) (ne $parsed.scheme "https") -}}
{{- fail (printf "%s: ENV_NAME outside development/staging/local requires an HTTPS JWKS upstream with a non-empty hostname. The chart requires HTTPS even for loopback URLs. Set %s.configmap.AUTHORIZER_ADDRESS to a reachable HTTPS endpoint with trusted TLS%s. Helm cannot verify endpoint reachability, certificate trust, or service-discovery results; the application still validates at startup." $component $component (ternary " (or identity.configmap.AUTH_M2M_JWKS_URL)" "" (eq $component "identity"))) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $cm := .Values.auth.configmap | default dict -}}
{{- $extra := .Values.auth.extraEnvVars | default dict -}}
{{- if hasKey $extra "MFA_SECRET" -}}
{{- fail "MFA_SECRET must not be stored in auth.extraEnvVars (a ConfigMap); use auth.secrets.MFA_SECRET or an existing Secret." -}}
{{- end -}}
{{- $mfa := "false" -}}
{{- if and (not (kindIs "invalid" $cm.MFA_ENABLED)) (ne (toString $cm.MFA_ENABLED) "") -}}
{{- $mfa = toString $cm.MFA_ENABLED -}}
{{- else if hasKey $extra "MFA_ENABLED" -}}
{{- $mfa = toString $extra.MFA_ENABLED -}}
{{- end -}}
{{- if not (has $mfa (list "1" "t" "T" "TRUE" "true" "True" "0" "f" "F" "FALSE" "false" "False")) -}}
{{- fail "auth MFA_ENABLED must be a boolean accepted by the application." -}}
{{- end -}}
{{- if has $mfa (list "1" "t" "T" "TRUE" "true" "True") -}}
{{- if .Values.auth.useExistingSecret -}}
{{- if empty (.Values.auth.existingSecretName | default "" | trim) -}}
{{- fail "MFA_ENABLED requires auth.existingSecretName when auth.useExistingSecret=true; that Secret must contain a non-empty MFA_SECRET (verified at application startup)." -}}
{{- end -}}
{{- else if empty (.Values.auth.secrets.MFA_SECRET | default "" | toString | trim) -}}
{{- fail "MFA_ENABLED requires a non-empty auth.secrets.MFA_SECRET; provision it securely before enabling MFA." -}}
{{- end -}}
{{- end -}}
{{- end -}}
