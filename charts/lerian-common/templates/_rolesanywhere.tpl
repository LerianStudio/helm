{{/*
==============================================================================
lerian-common — AWS IAM Roles Anywhere pod-spec fragments.

The `aws-signing-helper` sidecar + IMDS env + iam-certs volume + fsGroup pod
securityContext are BYTE-IDENTICAL across the inline implementations in
fetcher (manager/worker), matcher and plugin-fees. These helpers reproduce
those blocks exactly so callers can drop the copy-paste.

Indentation contract (same convention as _deployment.tpl): each helper emits
its keys at base indent 0; the caller supplies the real indent via `nindent`.
Nested `toYaml … | nindent N` values use the SMALL N that, once the caller's
outer nindent is added, lands on the original column.

  sidecar             -> caller nindent 8 (container list item)
  volume              -> caller nindent 6 (spec.volumes)
  imdsEnv             -> caller nindent 10 or 12 (container env list)
  podSecurityContext  -> caller nindent 6 (spec.securityContext); self-contained
                         if/else, always call it (do NOT wrap in an if)

The sidecar / volume / imdsEnv helpers are PURE (no guard): wrap the include in
the caller with the standard guard so they render only when enabled:

  {{- if and .Values.aws .Values.aws.rolesAnywhere .Values.aws.rolesAnywhere.enabled }}
      {{- include "lerian-common.rolesAnywhere.sidecar" (dict "aws" .Values.aws) | nindent 8 }}
  {{- end }}

NOTE: excludes reporter, whose inline block intentionally differs (no `required`
wrappers, extra runAsGroup, `$.`-prefixed context). Align reporter before reuse.
*/}}

{{/*
lerian-common.rolesAnywhere.sidecar — the aws-signing-helper sidecar container.
Input: (dict "aws" .Values.aws). Caller: nindent 8.
*/}}
{{- define "lerian-common.rolesAnywhere.sidecar" -}}
{{- $ra := .aws.rolesAnywhere -}}
- name: aws-signing-helper
  image: "{{ $ra.sidecar.image.repository }}:{{ $ra.sidecar.image.tag }}"
  imagePullPolicy: {{ $ra.sidecar.image.pullPolicy | default "IfNotPresent" }}
  args:
    - serve
    - --certificate
    - /certs/tls.crt
    - --private-key
    - /certs/tls.key
    - --trust-anchor-arn
    - "{{ required "aws.rolesAnywhere.trustAnchorArn is required when rolesAnywhere is enabled" $ra.trustAnchorArn }}"
    - --profile-arn
    - "{{ required "aws.rolesAnywhere.profileArn is required when rolesAnywhere is enabled" $ra.profileArn }}"
    - --role-arn
    - "{{ required "aws.rolesAnywhere.roleArn is required when rolesAnywhere is enabled" $ra.roleArn }}"
    - --region
    - "{{ $ra.region | default "us-east-2" }}"
    - --session-duration
    - "{{ $ra.sessionDuration | default 3600 }}"
    - --port
    - "{{ $ra.sidecar.port | default 9911 }}"
  ports:
    - name: imds
      containerPort: {{ $ra.sidecar.port | default 9911 }}
      protocol: TCP
  volumeMounts:
    - name: iam-certs
      mountPath: /certs
      readOnly: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
  resources:
    {{- toYaml $ra.sidecar.resources | nindent 4 }}
{{- end -}}

{{/*
lerian-common.rolesAnywhere.volume — the iam-certs secret volume.
Input: (dict "aws" .Values.aws "iamTlsDefault" "<chart>-iam-tls"). Caller: nindent 6.
*/}}
{{- define "lerian-common.rolesAnywhere.volume" -}}
{{- $ra := .aws.rolesAnywhere -}}
volumes:
  - name: iam-certs
    secret:
      secretName: {{ $ra.certificateSecretName | default .iamTlsDefault }}
      defaultMode: 0440
      items:
        - key: tls.crt
          path: tls.crt
        - key: tls.key
          path: tls.key
{{- end -}}

{{/*
lerian-common.rolesAnywhere.imdsEnv — env vars pointing the app at the sidecar IMDS.
Input: (dict "aws" .Values.aws). Caller: nindent 10 or 12 (match the chart's env indent).
*/}}
{{- define "lerian-common.rolesAnywhere.imdsEnv" -}}
{{- $ra := .aws.rolesAnywhere -}}
- name: AWS_EC2_METADATA_SERVICE_ENDPOINT
  value: "http://127.0.0.1:{{ $ra.sidecar.port | default 9911 }}"
- name: AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE
  value: "IPv4"
{{- end -}}

{{/*
lerian-common.rolesAnywhere.podSecurityContext — pod securityContext: fsGroup when
rolesAnywhere is on, else the chart's podSecurityContext. Self-contained if/else,
always call it (do NOT wrap in an if).
Input: (dict "aws" .Values.aws "podSecurityContext" .Values.<comp>.podSecurityContext).
Caller: nindent 6.
*/}}
{{- define "lerian-common.rolesAnywhere.podSecurityContext" -}}
{{- if and .aws .aws.rolesAnywhere .aws.rolesAnywhere.enabled -}}
securityContext:
  fsGroup: 65532
{{- else -}}
securityContext:
  {{- toYaml .podSecurityContext | nindent 2 }}
{{- end -}}
{{- end -}}
