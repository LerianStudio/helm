{{- /* The literal, not .Chart.Name: the published chart is br-jd-courier-helm,
     and every resource (and the default Secret name) stays br-jd-courier. */ -}}
{{- define "br-jd-courier.name" -}}
{{- default "br-jd-courier" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-jd-courier.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "br-jd-courier" .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* The Secret every role loads. The chart never renders one: it must exist. */ -}}
{{- define "br-jd-courier.secretName" -}}
{{- .Values.secrets.existingSecret | default (include "br-jd-courier.fullname" .) -}}
{{- end -}}

{{- /* Every role's ServiceAccount: the namespace default unless serviceAccount says otherwise. */ -}}
{{- define "br-jd-courier.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "br-jd-courier.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "br-jd-courier.image" -}}
{{ printf "%s:%s" (index .Values "jd-courier" "image").repository ((index .Values "jd-courier" "image").tag | default .Chart.AppVersion) }}
{{- end -}}

{{- define "br-jd-courier.labels" -}}
app.kubernetes.io/name: {{ include "br-jd-courier.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
app.kubernetes.io/version: {{ (index .ctx.Values "jd-courier" "image").tag | default .ctx.Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .ctx.Chart.Name .ctx.Chart.Version }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "br-jd-courier.selector" -}}
app.kubernetes.io/name: {{ include "br-jd-courier.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- /*
The render-time guards. Every template includes this, so any render refuses.

The third layer of the single-writer defence. The chart CANNOT read the rail registry, so the list of
single-writer roles below duplicates a fact the rail descriptor owns. That is why
there are three layers and not one: the boot guard reads the registry and catches
what the chart cannot, and the chart catches what never reaches a boot.
*/ -}}
{{- define "br-jd-courier.guards" -}}
{{- /* Trimmed, as the service reads it. Empty would boot as
     "development": no production checks, and a wrong segment in every secret path. */ -}}
{{- $env := trim (toString (get $.Values.config "ENVIRONMENT_NAME" | default "")) -}}
{{- if not $env -}}
{{- fail "config.ENVIRONMENT_NAME is required: it turns the Courier's production checks on (production) and is the environment segment of every Pix engine credentialRef and multi-tenant JD bundle path (tenants/{env}/...). Unset, the service boots as development. config.ENV_NAME, the service's deprecated alias, does not satisfy this chart: rename it to ENVIRONMENT_NAME." -}}
{{- end -}}
{{- $singleWriterRoles := dict "spbConsumer" "spb-consumer" -}}
{{- range $key, $role := $singleWriterRoles -}}
{{- $values := index $.Values.roles $key -}}
{{- if and $values.enabled (gt (int $values.replicas) 1) -}}
{{- fail (printf "roles.%s.replicas=%v: %s is a SINGLE WRITER — it drains a destructive vendor queue, and a second replica loses messages. It runs exactly one replica." $key $values.replicas $role) -}}
{{- end -}}
{{- end -}}
{{- $soapTls := "roles.spbSender.soapTls and roles.spbSender.ingress" -}}
{{- $transit := "roles.admin.pixTransit" -}}
{{- range $key, $source := dict "SERVER_ADDRESS" "ports.*" "SOAP_SERVER_ADDRESS" "ports.*" "SOAP_TLS_CERT_FILE" $soapTls "SOAP_TLS_KEY_FILE" $soapTls "SOAP_TLS_TERMINATED_UPSTREAM" $soapTls "PIX_TRANSIT_SERVER_ADDRESS" $transit "PIX_TRANSIT_TLS_CERT_FILE" $transit "PIX_TRANSIT_TLS_KEY_FILE" $transit "PIX_TRANSIT_TLS_TERMINATED_UPSTREAM" $transit -}}
{{- if hasKey $.Values.config $key -}}
{{- fail (printf "config.%s is refused: the chart derives it from %s" $key $source) -}}
{{- end -}}
{{- end -}}
{{- with $.Values.roles.admin.pixTransit -}}
{{- if and .enabled (not (or .tls.existingSecret .tls.terminatedUpstream)) -}}
{{- fail "roles.admin.pixTransit.enabled needs roles.admin.pixTransit.tls.existingSecret or roles.admin.pixTransit.tls.terminatedUpstream=true: the Pix engines refuse plain HTTP" -}}
{{- end -}}
{{- end -}}
{{- if hasKey $.Values.config "OTEL_EXPORTER_OTLP_ENDPOINT" -}}
{{- fail "config.OTEL_EXPORTER_OTLP_ENDPOINT is refused: set telemetry.otlpEndpoint, which the pod env carries" -}}
{{- end -}}
{{- if hasKey $.Values.config "ALLOW_AUTH_DISABLED_LOCAL_ONLY" -}}
{{- fail "config.ALLOW_AUTH_DISABLED_LOCAL_ONLY is refused: authentication is off only on a developer's machine, never in a chart install" -}}
{{- end -}}
{{- $forbidden := list "COURIER_ROLES" "LICENSE_KEY" "DATABASE_URL" "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "REDIS_PASSWORD" "MULTI_TENANT_REDIS_PASSWORD" "MULTI_TENANT_SERVICE_API_KEY" "JD_PASSWORD" "JD_SPI_CLIENT_SECRET" "JD_PRIVATE_KEY_PEM" -}}
{{- range $key := $forbidden -}}
{{- if hasKey $.Values.config $key -}}
{{- if eq $key "COURIER_ROLES" -}}
{{- fail "config.COURIER_ROLES is refused: the chart sets each Deployment's role itself" -}}
{{- else -}}
{{- fail (printf "config.%s is refused: secrets arrive through secrets.existingSecret, never as rendered values" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- /* Any value, under any key, that carries a PEM private key: the Courier
     holds no signing key, and a key pasted under an unexpected name is still a
     key rendered into a ConfigMap or a pod spec. It matches a PEM private-key
     block header; whitespace inside it is allowed because toYaml may fold a
     long one-line value. A key in base64 or any other encoding is not seen. */ -}}
{{- $rendered := toYaml $.Values -}}
{{- if regexMatch "-----BEGIN[A-Z\\s]*PRIVATE\\s+KEY-----" $rendered -}}
{{- fail "a chart value carries a PEM private key (-----BEGIN ... PRIVATE KEY): the Courier holds no signing key, and no key is ever a rendered value" -}}
{{- end -}}
{{- end -}}

{{- /*
One role's Deployment. Called from deployment-<role>.yaml with
(dict "ctx" $ "key" "<values key>" "role" "<COURIER_ROLES value>" "ports" (list "http" ...)).
*/ -}}
{{- define "br-jd-courier.deployment" -}}
{{- $ctx := .ctx -}}
{{- $values := index $ctx.Values.roles .key -}}
{{- $singleWriter := eq .role "spb-consumer" -}}
{{- $soapCert := and (has "soap" .ports) $values.soapTls.existingSecret -}}
{{- $transit := has "pixTransit" .ports -}}
{{- $transitCert := and $transit $values.pixTransit.tls.existingSecret -}}
{{- /* TLS Secrets this role mounts, by volume name, at /etc/jd-courier/<name>. */ -}}
{{- $tls := dict -}}
{{- with $soapCert }}{{ $_ := set $tls "soap-tls" . }}{{ end -}}
{{- with $transitCert }}{{ $_ := set $tls "pix-transit-tls" . }}{{ end -}}
{{- if $values.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ printf "%s-%s" (include "br-jd-courier.fullname" $ctx) .role | trunc 63 | trimSuffix "-" }}
  labels:
    {{- include "br-jd-courier.labels" (dict "ctx" $ctx "component" .role) | nindent 4 }}
spec:
  replicas: {{ $values.replicas }}
  {{- if $singleWriter }}
  # A rolling update runs two consumers during the rollout — the exact
  # co-location the single-writer guard exists to prevent.
  strategy:
    type: Recreate
  {{- else }}
  strategy:
    type: RollingUpdate
  {{- end }}
  selector:
    matchLabels:
      {{- include "br-jd-courier.selector" (dict "ctx" $ctx "component" .role) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "br-jd-courier.selector" (dict "ctx" $ctx "component" .role) | nindent 8 }}
      annotations:
        checksum/config: {{ toJson $ctx.Values.config | sha256sum }}
        {{- with $ctx.Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "br-jd-courier.serviceAccountName" $ctx }}
      # No Kubernetes API token: the Courier never calls the API. IRSA and EKS Pod
      # Identity inject their own projected token regardless of this field.
      automountServiceAccountToken: false
      terminationGracePeriodSeconds: {{ $ctx.Values.terminationGracePeriodSeconds }}
      securityContext:
        # Numeric, because the image's USER is the name `nonroot` and the kubelet
        # cannot prove a named user is non-root: runAsNonRoot alone is refused.
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        seccompProfile:
          type: RuntimeDefault
      {{- with $ctx.Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: jd-courier
          image: {{ include "br-jd-courier.image" $ctx | quote }}
          imagePullPolicy: {{ (index $ctx.Values "jd-courier" "image").pullPolicy }}
          env:
            - name: COURIER_ROLES
              value: {{ .role | quote }}
            # The SPB drain's lease holder: a restarted container carries the
            # same name and re-claims the lease at once.
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            # OTLP leaves to telemetry.otlpEndpoint, the node's own collector by
            # default. Set here, not in the ConfigMap: Kubernetes expands
            # $(NODE_IP) only in an env value, and only below its definition.
            - name: NODE_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: {{ $ctx.Values.telemetry.otlpEndpoint | quote }}
            {{- if eq $ctx.Values.telemetry.otlpEndpoint "$(NODE_IP):4317" }}
            # The default hop never leaves the node, so production may send it
            # in plaintext. Any other endpoint meets lib-observability's gate.
            - name: ALLOW_INSECURE_OTEL
              value: "node-local collector on the pod's own node"
            {{- end }}
            # The listeners follow ports.*, so the probes and Services never
            # point at a port nothing listens on.
            - name: SERVER_ADDRESS
              value: {{ printf ":%v" $ctx.Values.ports.http | quote }}
            - name: SOAP_SERVER_ADDRESS
              value: {{ printf ":%v" $ctx.Values.ports.soap | quote }}
            # Named, not left to envFrom: a Secret without LICENSE_KEY stops the
            # container at creation (CreateContainerConfigError) instead of
            # booting a process that then refuses its own licence.
            - name: LICENSE_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "br-jd-courier.secretName" $ctx }}
                  key: LICENSE_KEY
            {{- if $soapCert }}
            # Read once at boot: a rotated certificate needs a rollout restart.
            - name: SOAP_TLS_CERT_FILE
              value: /etc/jd-courier/soap-tls/tls.crt
            - name: SOAP_TLS_KEY_FILE
              value: /etc/jd-courier/soap-tls/tls.key
            {{- end }}
            {{- if and (has "soap" .ports) (or $values.ingress.enabled $values.soapTls.terminatedUpstream) }}
            - name: SOAP_TLS_TERMINATED_UPSTREAM
              value: "true"
            {{- end }}
            {{- if $transit }}
            - name: PIX_TRANSIT_SERVER_ADDRESS
              value: {{ printf ":%v" $ctx.Values.ports.pixTransit | quote }}
            {{- if $transitCert }}
            - name: PIX_TRANSIT_TLS_CERT_FILE
              value: /etc/jd-courier/pix-transit-tls/tls.crt
            - name: PIX_TRANSIT_TLS_KEY_FILE
              value: /etc/jd-courier/pix-transit-tls/tls.key
            {{- end }}
            {{- if $values.pixTransit.tls.terminatedUpstream }}
            - name: PIX_TRANSIT_TLS_TERMINATED_UPSTREAM
              value: "true"
            {{- end }}
            {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "br-jd-courier.fullname" $ctx }}
            - secretRef:
                name: {{ include "br-jd-courier.secretName" $ctx }}
          ports:
            {{- range .ports }}
            - name: {{ kebabcase . }}
              containerPort: {{ index $ctx.Values.ports . }}
            {{- end }}
          # /health answers on every role, the consumer included. A revoked
          # licence never fails it: the pod stays up and says why. It
          # fails when a started single-writer rail worker has ended (the SPB
          # drain died or lost its lease): only a restart re-claims the lease,
          # and nothing is read from the vendor meanwhile. A channel halt, a
          # revoked licence and a capture being retried keep it green.
          livenessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          {{- with $values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $tls }}
          volumeMounts:
            {{- range $name, $secret := . }}
            - name: {{ $name }}
              mountPath: /etc/jd-courier/{{ $name }}
              readOnly: true
            {{- end }}
      volumes:
            {{- range $name, $secret := . }}
        - name: {{ $name }}
          secret:
            secretName: {{ $secret | quote }}
            {{- end }}
          {{- end }}
      {{- with $ctx.Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $ctx.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $ctx.Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end -}}

{{- /* The admin's ports: http, plus pixTransit while the transit is on. dig, because values
     reused from 2.0.0 (helm upgrade --reuse-values) carry no roles.admin.pixTransit. */ -}}
{{- define "br-jd-courier.adminPorts" -}}
http{{ if dig "pixTransit" "enabled" false .Values.roles.admin }} pixTransit{{ end }}
{{- end -}}

{{- define "br-jd-courier.service" -}}
{{- $ctx := .ctx -}}
{{- $values := index $ctx.Values.roles .key -}}
{{- if $values.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-%s" (include "br-jd-courier.fullname" $ctx) .role | trunc 63 | trimSuffix "-" }}
  labels:
    {{- include "br-jd-courier.labels" (dict "ctx" $ctx "component" .role) | nindent 4 }}
spec:
  type: {{ $values.service.type }}
  selector:
    {{- include "br-jd-courier.selector" (dict "ctx" $ctx "component" .role) | nindent 4 }}
  ports:
    {{- range .ports }}
    - name: {{ kebabcase . }}
      port: {{ index $ctx.Values.ports . }}
      targetPort: {{ kebabcase . }}
    {{- end }}
{{- end }}
{{- end -}}

{{- /* "true" when the service reads MULTI_TENANT_ENABLED as true (strconv.ParseBool spellings,
     trimmed), else empty. Refusing too much is safe here, refusing too little is not. */}}
{{- define "br-jd-courier.multiTenant" -}}
{{- if has (lower (trim (toString (get .Values.config "MULTI_TENANT_ENABLED" | default "false")))) (list "1" "t" "true") }}true{{ end }}
{{- end }}
