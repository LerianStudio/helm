{{/*
Validate the chart-visible v3.9 startup contract that is not about the JWKS
transport (validateJwksTls owns that): chart-owned keys duplicated through
extraEnvVars, and the MFA secret. Existing Secrets are deliberately not read
with lookup: GitOps/offline rendering must remain deterministic. Runtime
validates their contents.
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
{{- if and (eq $component "identity") $cm.AUTH_M2M_JWKS_URL (hasKey $extra "AUTH_M2M_JWKS_URL") -}}
{{- fail "AUTH_M2M_JWKS_URL is set in both identity.configmap and identity.extraEnvVars; keep only one" -}}
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
