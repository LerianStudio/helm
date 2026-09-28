{{/*
Validate the chart-visible v3.9 startup contract, not network reachability.
Existing Secrets and discovery results are deliberately not read with lookup:
GitOps/offline rendering must remain deterministic. Runtime validates them.
*/}}
{{- define "plugin-access-manager.validateStartup" -}}
{{- range $component := list "auth" "identity" -}}
{{- $values := index $.Values $component -}}
{{- $cm := $values.configmap | default dict -}}
{{- $extra := $values.extraEnvVars | default dict -}}
{{- /* These keys always render in data, so extraEnvVars would duplicate them. */ -}}
{{- range $key := list "ENV_NAME" "AUTHORIZER_ADDRESS" -}}
{{- if hasKey $extra $key -}}
{{- fail (printf "%s.extraEnvVars.%s duplicates a chart-owned ConfigMap key; use %s.configmap.%s instead" $component $key $component $key) -}}
{{- end -}}
{{- end -}}
{{- if and (eq $component "identity") (hasKey $extra "PLUGIN_AUTH_ENABLED") -}}
{{- fail "identity.extraEnvVars.PLUGIN_AUTH_ENABLED duplicates a chart-owned ConfigMap key; use identity.configmap.AUTH_ENABLED instead" -}}
{{- end -}}
{{- $env := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "env" "field" "name" "nativeKey" "ENV_NAME" "default" "development") | trim | lower -}}
{{- $address := $cm.AUTHORIZER_ADDRESS | default (printf "http://%s:%v" (include "plugin-caradhras.fullname" $) (include "caradhras.servicePort" $)) | toString -}}
{{- $url := $address -}}
{{- $enabled := true -}}
{{- if eq $component "identity" -}}
{{- /* Match the ConfigMap's default semantics, including boolean false. */ -}}
{{- $enabled = has (toString ($cm.AUTH_ENABLED | default "true")) (list "true" "TRUE" "True" "1" "t" "T") -}}
{{- if and $cm.AUTH_M2M_JWKS_URL (hasKey $extra "AUTH_M2M_JWKS_URL") -}}
{{- fail "AUTH_M2M_JWKS_URL is set in both identity.configmap and identity.extraEnvVars; keep only one" -}}
{{- end -}}
{{- $explicit := $cm.AUTH_M2M_JWKS_URL | default (get $extra "AUTH_M2M_JWKS_URL") | default "" | toString | trim -}}
{{- $url = $explicit | default (printf "%s/.well-known/jwks" (regexReplaceAll `/+$` $address "")) -}}
{{- end -}}
{{- if and $enabled (not (has $env (list "development" "staging" "local"))) -}}
{{- /* Parse like the Go runtime (including scheme normalization and invalid ports).
Helm has no net.ParseIP equivalent. Do not reject IPv6 identity endpoints using
an incomplete regex: defer their loopback classification to lib-auth, which
still enforces TLS. Auth has no loopback exception. */ -}}
{{- $parsed := urlParse $url -}}
{{- $host := $parsed.hostname | default "" -}}
{{- $scheme := $parsed.scheme | default "" -}}
{{- $ipv4Loopback := regexMatch `^127(\.(0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}$` $host -}}
{{- $identityLocalOrIPv6 := and (eq $component "identity") (eq $scheme "http") (or (eq $host "localhost") $ipv4Loopback (contains ":" $host)) -}}
{{- if not (or $identityLocalOrIPv6 (and (eq $scheme "https") (ne $host ""))) -}}
{{- fail (printf "%s requires an HTTPS JWKS upstream outside development/staging/local. Set %s.configmap.AUTHORIZER_ADDRESS to a reachable HTTPS Caradhras endpoint with trusted TLS (identity may override AUTH_M2M_JWKS_URL). Do not relabel production or disable authentication to bypass this requirement. Service-discovery endpoints must also satisfy it." $component $component) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $cm := .Values.auth.configmap | default dict -}}
{{- $extra := .Values.auth.extraEnvVars | default dict -}}
{{- if and (hasKey $extra "MFA_ENABLED") (not (kindIs "string" (get $extra "MFA_ENABLED"))) -}}
{{- fail "auth.extraEnvVars.MFA_ENABLED must be a quoted string because it renders in ConfigMap.data; alternatively use auth.configmap.MFA_ENABLED" -}}
{{- end -}}
{{- $mfa := get $extra "MFA_ENABLED" | default "false" | toString -}}
{{- if and (not (kindIs "invalid" $cm.MFA_ENABLED)) (ne (toString $cm.MFA_ENABLED) "") -}}
{{- $mfa = toString $cm.MFA_ENABLED -}}
{{- end -}}
{{- if hasKey $extra "MFA_SECRET" -}}
{{- fail "MFA_SECRET is sensitive: use auth.secrets.MFA_SECRET or auth.useExistingSecret, not auth.extraEnvVars (a ConfigMap)" -}}
{{- end -}}
{{- if has $mfa (list "true" "TRUE" "True" "1" "t" "T") -}}
{{- if .Values.auth.useExistingSecret -}}
{{- if not (.Values.auth.existingSecretName | default "" | trim) -}}
{{- fail "MFA_ENABLED requires auth.existingSecretName when auth.useExistingSecret=true; that Secret must contain a non-empty MFA_SECRET" -}}
{{- end -}}
{{- else if not .Values.auth.secrets.MFA_SECRET -}}
{{- fail "MFA_ENABLED requires a non-empty auth.secrets.MFA_SECRET (or auth.useExistingSecret with an existing Secret containing MFA_SECRET)" -}}
{{- end -}}
{{- end -}}
{{- end -}}
