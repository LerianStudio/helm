{{- define "mongodb.customPasswords" -}}
{{- $passwords := list -}}
{{- if .Values.auth.password -}}
{{- $passwords = append $passwords .Values.auth.password -}}
{{- end -}}
{{- range .Values.auth.passwords -}}
{{- $passwords = append $passwords . -}}
{{- end -}}
{{- $configured := join "," $passwords -}}
{{- if or $configured .Values.auth.existingSecret .Values.passwordUpdateJob.enabled -}}
{{- $configured -}}
{{- else -}}
{{- include "common.secrets.lookup" (dict "secret" (include "mongodb.secretName" .) "key" "mongodb-passwords" "context" .) | b64dec -}}
{{- end -}}
{{- end -}}
