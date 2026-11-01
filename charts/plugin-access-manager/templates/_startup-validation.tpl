{{/*
Validate the chart-visible v3.9 startup contract that is not about the JWKS
transport (validateJwksTls owns that): chart-owned keys duplicated through
extraEnvVars, and the MFA secret. Existing Secrets are deliberately not read
with lookup: GitOps/offline rendering must remain deterministic. Runtime
validates their contents.
*/}}
{{- define "plugin-access-manager.validateStartup" -}}
{{- /* The init-user Job was post-install only, so an upgrade never ran it; only a fresh install would be left with no Console admin. */ -}}
{{- if and .Release.IsInstall (.Values.auth.initUser | default dict).enabled -}}
{{- fail "auth.initUser was removed: the chart no longer creates the first Console user. Remove auth.initUser from your values. Instead, sign in to Caradhras as built-in/admin, rotate its seed password, create the first lerian user and add it to lerian/admin-group (see the chart README, 'Initial admin')" -}}
{{- end -}}
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
{{- include "plugin-access-manager.validateGoogleDirectory" . -}}
{{- end -}}

{{/*
Google Workspace directory (identity 3.12.0+). Identity refuses to boot with
GOOGLE_DIRECTORY_ENABLED=true unless all four GOOGLE_DIRECTORY_* values are
set and GOOGLE_DIRECTORY_ENCRYPTION_KEY is at least 32 bytes, so the chart
refuses the same release at render time. The two secret keys are refused in
identity.configmap (the chart would drop them) and in identity.extraEnvVars
(it writes a ConfigMap). The plain keys must be quoted strings in
extraEnvVars, which is written to ConfigMap.data as is. With
identity.useExistingSecret only the Secret name is checked: offline rendering
cannot read its contents.
*/}}
{{- define "plugin-access-manager.validateGoogleDirectory" -}}
{{- $cm := .Values.identity.configmap | default dict -}}
{{- $extra := .Values.identity.extraEnvVars | default dict -}}
{{- $secrets := .Values.identity.secrets | default dict -}}
{{- range $key := list "GOOGLE_DIRECTORY_ENABLED" "GOOGLE_DIRECTORY_CLIENT_ID" "GOOGLE_DIRECTORY_REDIRECT_URL" -}}
{{- /* "Set" includes an explicit false: false + extraEnvVars "true" would enable it. */ -}}
{{- $named := get $cm $key -}}
{{- if and (not (kindIs "invalid" $named)) (ne (toString $named) "") (hasKey $extra $key) -}}
{{- fail (printf "%s is set in both identity.configmap and identity.extraEnvVars; keep only identity.configmap.%s" $key $key) -}}
{{- end -}}
{{- if and (hasKey $extra $key) (not (kindIs "string" (get $extra $key))) -}}
{{- fail (printf "identity.extraEnvVars.%s must be a quoted string because it renders in ConfigMap.data; alternatively use identity.configmap.%s" $key $key) -}}
{{- end -}}
{{- end -}}
{{- range $key := list "GOOGLE_DIRECTORY_CLIENT_SECRET" "GOOGLE_DIRECTORY_ENCRYPTION_KEY" -}}
{{- if or (hasKey $extra $key) (get $cm $key) -}}
{{- fail (printf "%s is sensitive: use identity.secrets.%s or identity.useExistingSecret, not identity.configmap or identity.extraEnvVars" $key $key) -}}
{{- end -}}
{{- end -}}
{{- $enabled := get $cm "GOOGLE_DIRECTORY_ENABLED" | default (get $extra "GOOGLE_DIRECTORY_ENABLED") | default "false" | toString -}}
{{- if has $enabled (list "true" "TRUE" "True" "1" "t" "T") -}}
{{- $missing := list -}}
{{- range $key := list "GOOGLE_DIRECTORY_CLIENT_ID" "GOOGLE_DIRECTORY_REDIRECT_URL" -}}
{{- if not (get $cm $key | default (get $extra $key) | toString | trim) -}}
{{- $missing = append $missing (printf "identity.configmap.%s" $key) -}}
{{- end -}}
{{- end -}}
{{- if $.Values.identity.useExistingSecret -}}
{{- if not ($.Values.identity.existingSecretName | default "" | trim) -}}
{{- $missing = append $missing "identity.existingSecretName (a Secret holding GOOGLE_DIRECTORY_CLIENT_SECRET and GOOGLE_DIRECTORY_ENCRYPTION_KEY)" -}}
{{- end -}}
{{- else -}}
{{- range $key := list "GOOGLE_DIRECTORY_CLIENT_SECRET" "GOOGLE_DIRECTORY_ENCRYPTION_KEY" -}}
{{- if not (get $secrets $key | toString | trim) -}}
{{- $missing = append $missing (printf "identity.secrets.%s" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $missing -}}
{{- fail (printf "GOOGLE_DIRECTORY_ENABLED=true needs a non-empty %s; identity refuses to boot without them" (join ", " $missing)) -}}
{{- end -}}
{{- /* Same check as identity: whitespace trimmed, length in bytes. */ -}}
{{- if and (not $.Values.identity.useExistingSecret) (lt (len (get $secrets "GOOGLE_DIRECTORY_ENCRYPTION_KEY" | toString | trim)) 32) -}}
{{- fail "GOOGLE_DIRECTORY_ENABLED=true needs identity.secrets.GOOGLE_DIRECTORY_ENCRYPTION_KEY of at least 32 bytes; identity refuses to boot with a shorter key" -}}
{{- end -}}
{{- end -}}
{{- end -}}
