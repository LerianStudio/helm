{{/*
==============================================================================
plugin-br-pix-jd — chart-local helpers.

`lerian-common` supplies env contracts and workload fragments but NOT naming or
labels (its only naming helper is `lerian-common.dependency.fullname`, for a
subchart Secret). So name/label derivation lives here, following the br-sfn
idiom for multi-component charts.
==============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "plugin-br-pix-jd.name" -}}
{{- default "plugin-br-pix-jd" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited by the DNS spec.
*/}}
{{- define "plugin-br-pix-jd.fullname" -}}
{{- default (include "plugin-br-pix-jd.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "plugin-br-pix-jd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "plugin-br-pix-jd.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Name of the service account to use (shared by api and worker).
*/}}
{{- define "plugin-br-pix-jd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "plugin-br-pix-jd.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
componentFullname — <chart fullname>-<component>, e.g. plugin-br-pix-jd-api.
Input dict: root, name.
*/}}
{{- define "plugin-br-pix-jd.componentFullname" -}}
{{- printf "%s-%s" (include "plugin-br-pix-jd.fullname" .root | trunc (int (sub 62 (len .name))) | trimSuffix "-") .name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Selector labels for one component (stable across image bumps).
Input dict: root, name.
*/}}
{{- define "plugin-br-pix-jd.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-jd.componentFullname" . }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/*
Common labels for one component. Input dict: root, name.
Honors global.commonLabels so a platform-wide label set lands on every object.
*/}}
{{- define "plugin-br-pix-jd.componentLabels" -}}
helm.sh/chart: {{ include "plugin-br-pix-jd.chart" .root }}
{{ include "plugin-br-pix-jd.componentSelectorLabels" . }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: plugin-br-pix-jd
app.kubernetes.io/component: {{ .name }}
{{- /* Label VALUES are coerced to strings. Kubernetes label maps are
   map[string]string, but `helm lint` does not type-check labels the way it does
   annotations — so `--set global.commonLabels.a.b=1` rendered a nested map, passed
   lint, and was rejected only by the API server at apply time. toString collapses a
   number or bool to a valid label; a nested map still fails, but now it fails at
   render with a message that names the key. */ -}}
{{- range $k, $v := ((.root.Values.global | default dict).commonLabels | default dict) }}
{{- if kindIs "map" $v }}
{{- fail (printf "\n\nERROR: global.commonLabels.%s is a map; Kubernetes labels must be scalar strings.\nFlatten it into a single value.\n" $k) }}
{{- end }}
{{ $k }}: {{ $v | toString | quote }}
{{- end }}
{{- end }}

{{/*
componentAnnotations — global.commonAnnotations, or "" when unset.
Input dict: root.
*/}}
{{- define "plugin-br-pix-jd.commonAnnotations" -}}
{{- with (.root.Values.global | default dict).commonAnnotations -}}
{{- toYaml . -}}
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
withCommonAnnotations — a component sub-map with global.commonAnnotations merged
under its own `annotations`.

values.yaml advertises commonAnnotations as landing on "every rendered object",
but the lerian-common workload helpers each read annotations only from the sub-map
they are handed (service.annotations, pdb.annotations, serviceAccount.annotations),
so passing the raw sub-map reached the ConfigMap/Secret/Deployment and silently
skipped the rest. This closes the gap without forking any helper: the component's
own annotations still win on a key collision.

`lerian-common.hpa` accepts no annotations at all — the HPA is therefore the one
object commonAnnotations cannot reach, and values.yaml says so rather than
repeating the "every object" claim.

Input dict: root, block (the component sub-map, e.g. .Values.api.service).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.withCommonAnnotations" -}}
{{- $common := ((.root.Values.global | default dict).commonAnnotations | default dict) -}}
{{- $block := deepCopy (.block | default dict) -}}
{{- $merged := mergeOverwrite (deepCopy $common) ($block.annotations | default dict) -}}
{{- $_ := set $block "annotations" $merged -}}
{{- toYaml $block -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
componentImage — the fully qualified image reference for one component.

`global.imageRegistry` prefixes the repository when set, so an air-gapped or
mirrored registry is a single top-level override instead of a per-component edit.
An empty tag falls back to .Chart.AppVersion.

Input dict: root, comp.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.componentImage" -}}
{{- $registry := ((.root.Values.global | default dict).imageRegistry | default "") -}}
{{- /* An empty repository printf'd to ":<tag>" — valid YAML, InvalidImageName at
   admission. Fail at render with the value to set. */ -}}
{{- $repository := required "\n\nERROR: image.repository is empty for one of the components.\nAn empty repository renders as \":<tag>\", which the API server rejects with\nInvalidImageName. Set api.image.repository (the worker inherits it).\n" (.comp.image.repository | default "") -}}
{{- if $registry -}}
{{- $repository = printf "%s/%s" (trimSuffix "/" $registry) $repository -}}
{{- end -}}
{{- printf "%s:%s" $repository (.comp.image.tag | default .root.Chart.AppVersion) -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
imageConsistent — CONSISTENCY GATE, not cosmetics.

`api` and `worker` are two processes of ONE build. The plugin's own topology says
why: Dockerfile.smoke ships both entry points into a single image so "the two
processes can never be built from different source"
(docker-compose.smoke.yml:303-304), and the worker runs that same image with
`entrypoint: ["/worker"]`. Two different tags here would deploy an api and a
worker compiled from different commits — the api answering one contract while
the worker reconciles money against another. That is a silent, and in the MED
settlement path a money-affecting, divergence.

So: when the worker is enabled, its image MUST match the api's. Fails the render
rather than emitting the mismatch, per the standard's fail-loud gate rules.

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.imageConsistent" -}}
{{- $api := .Values.api -}}
{{- $worker := .Values.worker | default dict -}}
{{- if $worker.enabled -}}
{{- $workerImage := $worker.image | default dict -}}
{{- $apiRepo := $api.image.repository -}}
{{- $apiTag := ($api.image.tag | default .Chart.AppVersion) -}}
{{- $workerRepo := ($workerImage.repository | default $apiRepo) -}}
{{- $workerTag := ($workerImage.tag | default $apiTag) -}}
{{- if or (ne $workerRepo $apiRepo) (ne $workerTag $apiTag) -}}
{{- fail (printf "\n\nERROR: api and worker must run the SAME image — they are two entry points of one build.\n  api:    %s:%s\n  worker: %s:%s\nSet worker.image.repository/tag to match api.image.repository/tag, or leave them\nunset so they inherit the api's values.\n" $apiRepo $apiTag $workerRepo $workerTag) -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
TWO SEPARATE QUESTIONS about the bundled Postgres, deliberately not one helper.

They were conflated in the first cut and it produced a dangling host: with
`postgresql.enabled=false` plus `postgresql.auth.existingSecret=<name>`, the
existingSecret disjunct flipped the "bundled" branch, so POSTGRES_HOST was derived
as the subchart Service name while NO subchart Service rendered. The required gate
that exists to prevent exactly that never fired. `postgresql.external=true` plus an
existingSecret had the mirror defect: the subchart rendered AND the app pointed at
it, against the operator's explicit declaration.

  postgresRenders        — does the subchart actually render in this release?
                           Governs the HOST. Ignores existingSecret entirely: an
                           operator-managed Secret says nothing about whether a
                           StatefulSet exists.
  postgresPasswordSourced — is the password readable from a Secret this chart does
                           not own (subchart-generated OR operator existingSecret)?
                           Governs whether POSTGRES_PASSWORD must appear in this
                           chart's Secret.

Both use `ne (toString ...) "false"` rather than sprig `default`: `default true false`
yields TRUE, so `--set postgresql.enabled=false` would otherwise still take the
bundled branch (the `enabled` coercion gotcha in docs/helm-chart-standard.md).

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{/*
------------------------------------------------------------------------------
consistencyGates — the render-time contradictions this chart refuses to emit.

Invoked once from the api ConfigMap (the first template Helm renders under api/),
so an operator sees the failure before a wall of unrelated output.
------------------------------------------------------------------------------
*/}}
{{/*
------------------------------------------------------------------------------
effectiveConfig — configmap + extraConfigmap, na mesma precedência do render.

IS_DEVELOPMENT é deliberadamente NÃO modelada: é um bypass de stack local, e dar a
ela um campo de primeira classe faria parecer knob suportado. Quem precisa dela usa
`api.extraConfigmap.IS_DEVELOPMENT`.

Mas os GATES têm de continuar enxergando-a, senão removê-la abriria um buraco: o
gate de produção deixaria de barrar o bypass e o gate de licença do worker deixaria
de saber que pode relaxar. Por isso todo gate resolve contra esta visão mesclada, e
não contra `.configmap` sozinho — a mesma precedência que o ConfigMap renderiza.

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.effectiveConfig" -}}
{{- toYaml (mergeOverwrite (deepCopy (.Values.api.configmap | default dict)) (.Values.api.extraConfigmap | default dict)) -}}
{{- end }}

{{- define "plugin-br-pix-jd.consistencyGates" -}}
{{- include "plugin-br-pix-jd.imageConsistent" . -}}
{{- $cfg := fromYaml (include "plugin-br-pix-jd.effectiveConfig" .) -}}
{{- /* ENVIRONMENT_NAME is REQUIRED, and this is the highest-leverage gate in the
   chart. The app resolves an empty value to "development", which does not merely
   change a log level: it makes validateProductionConfig, the security-bypass
   rejections and enforceProductionSecurityDefaults all no-ops, and it exposes panic
   stack traces. A chart that gates LICENSE_KEY but lets the entire production
   posture default to off has its priorities inverted. */ -}}
{{- if not (index $cfg "ENVIRONMENT_NAME" | default "") -}}
{{- fail "\n\nERROR: api.configmap.ENVIRONMENT_NAME is required.\nAn empty value resolves to \"development\" inside the app, which silently disables\nEVERY production security gate: the Postgres SSL and auth requirements stop being\nenforced, the ALLOW_* bypass rejections do not run, and panic stack traces are\nexposed. Set it deliberately:\n  --set api.configmap.ENVIRONMENT_NAME=production\n  --set api.configmap.ENVIRONMENT_NAME=staging\n  --set api.configmap.ENVIRONMENT_NAME=development   (explicitly, for a dev install)\n" -}}
{{- end -}}
{{- $isProduction := eq (index $cfg "ENVIRONMENT_NAME" | default "" | toString) "production" -}}
{{- /* The app keeps THREE vars in productionForbiddenBypassEnvVars
   (internal/bootstrap/config_validation.go) and refuses to boot when any is truthy
   under production: ALLOW_CORS_WILDCARD, ALLOW_RATELIMIT_FAIL_OPEN and IS_DEVELOPMENT.
   Each disables a safe default — a wildcard CORS origin, a fail-OPEN money-path rate
   limiter, and (IS_DEVELOPMENT) the worker per-tick license validation, which leaves
   the settlement-reconcile poller running unlicensed. Catching them at render beats a
   CrashLoop. ALLOW_INSECURE_TLS is deliberately NOT here: the app treats it as the one
   sovereign switch for internal-datastore TLS in any environment. */ -}}
{{- if $isProduction -}}
{{- $rl := .Values.api.rateLimit | default dict -}}
{{- $bypasses := dict
      "ALLOW_CORS_WILDCARD" (index $cfg "ALLOW_CORS_WILDCARD" | default "")
      "ALLOW_RATELIMIT_FAIL_OPEN" ($rl.allowFailOpen | default (index $cfg "ALLOW_RATELIMIT_FAIL_OPEN" | default ""))
      "IS_DEVELOPMENT" (index $cfg "IS_DEVELOPMENT" | default "") -}}
{{- range $name, $value := $bypasses -}}
{{- if and $value (ne ($value | toString) "false") -}}
{{- fail (printf "\n\nERROR: %s must not be set under ENVIRONMENT_NAME=production.\nThe app lists it in productionForbiddenBypassEnvVars and refuses to boot with it truthy,\nso this deploy would CrashLoop. It also disables a safe default: a wildcard CORS origin,\na fail-OPEN money-path rate limiter, or the worker per-tick license validation.\n" $name) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- /* global.imageRegistry cannot be honored while the Bitnami subchart is bundled:
   Bitnami reads the same Helm-global key, substitutes its own image, and then its
   image-verification guard hard-fails the render. Surfacing that here beats letting
   the operator hit an error that names only the subchart. */ -}}
{{- $registry := ((.Values.global | default dict).imageRegistry | default "") -}}
{{- if and $registry (include "plugin-br-pix-jd.postgresRenders" .) -}}
{{- $pgGlobal := ((.Values.postgresql | default dict).global | default dict) -}}
{{- if not (($pgGlobal.security | default dict).allowInsecureImages) -}}
{{- fail "\n\nERROR: global.imageRegistry cannot be combined with the bundled Postgres as-is.\nBitnami reads the same global key, substitutes its own image, and its verification\nguard then fails the render. Pick one:\n  - mirror only this chart's images: use api.image.repository with the full mirror path\n    and leave global.imageRegistry unset;\n  - mirror everything: also set postgresql.global.security.allowInsecureImages=true,\n    acknowledging the substituted Postgres image is unverified;\n  - use an external Postgres: postgresql.enabled=false.\n" -}}
{{- end -}}
{{- end -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- /* enabled + external is a contradiction that COSTS money: the subchart still
   renders its StatefulSet and an 8Gi PVC because its condition is postgresql.enabled,
   while the app is routed to the operator's datastore. The operator pays for a
   Postgres nothing connects to. */ -}}
{{- if and (ne (toString $pg.enabled) "false") $pg.external -}}
{{- fail "\n\nERROR: postgresql.enabled=true together with postgresql.external=true is contradictory.\nThe subchart's render condition is postgresql.enabled, so the bundled StatefulSet and\nits PersistentVolumeClaim would still be created while the app connects elsewhere.\nSet postgresql.enabled=false for an external datastore.\n" -}}
{{- end -}}
{{- /* A POSTGRES_PASSWORD the chart will silently ignore. On every sourced path the
   value comes from a Secret this chart does not own, so accepting the key here would
   let an operator "rotate" a password with no effect and no signal. */ -}}
{{- if include "plugin-br-pix-jd.postgresPasswordSourced" . -}}
{{- if (.Values.api.secrets | default dict).POSTGRES_PASSWORD -}}
{{- fail "\n\nERROR: api.secrets.POSTGRES_PASSWORD is set but would be IGNORED.\nThe password is read from the Secret that owns it — the bundled subchart's generated\nSecret, or postgresql.auth.existingSecret. Setting it here has no effect, so the chart\nrefuses rather than letting a password rotation appear to succeed.\nTo change the bundled password: --set postgresql.auth.password=<value>\nFor an external datastore: --set postgresql.enabled=false and set it here instead.\n" -}}
{{- end -}}
{{- end -}}
{{- /* namespaceOverride relocates THIS chart only; the subchart stays in
   .Release.Namespace. postgresHost qualifies the Service FQDN to survive that, but the
   subchart's NetworkPolicy is still scoped to its own namespace, so cross-namespace
   traffic can be denied. Warn loudly by failing: a silently unreachable database is
   worse than a refused install. */ -}}
{{- if and (.Values.namespaceOverride | default "") (include "plugin-br-pix-jd.postgresRenders" .) -}}
{{- fail "\n\nERROR: namespaceOverride cannot be combined with the bundled Postgres.\nnamespaceOverride moves this chart's objects, but the postgresql subchart stays in the\nrelease namespace, and its NetworkPolicy is scoped there — so the api may be unable to\nreach it. Either drop namespaceOverride, or set postgresql.enabled=false and point\napi.configmap.POSTGRES_HOST at a datastore reachable from the target namespace.\n" -}}
{{- end -}}
{{- end }}

{{- define "plugin-br-pix-jd.postgresRenders" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- if and (ne (toString $pg.enabled) "false") (not $pg.external) -}}
true
{{- end -}}
{{- end }}

{{- define "plugin-br-pix-jd.postgresPasswordSourced" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- $auth := $pg.auth | default dict -}}
{{- if or (include "plugin-br-pix-jd.postgresRenders" .) $auth.existingSecret -}}
true
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
dbPasswordEnv — POSTGRES_PASSWORD as a discrete env entry, single-sourced.

Bundled path: the Bitnami subchart generates the password into its OWN Secret, so
the container reads it via secretKeyRef and the key is absent from this chart's
Secret (Pattern A). Data key is `password` — the `auth.username` user the app
connects as — NOT `postgres-password`, which is the superuser.

External/disabled path: there is no subchart to source from, so the operator must
supply it. Required gate, naming both accepted routes.

The Secret NAME is derived through lerian-common.infraSecretRef (which wraps the
Bitnami `common.names.dependency.fullname`), never printf'd as
`<release>-postgresql`: the Bitnami common library collapses that to `postgresql`
when the release name already contains the subchart name, and the repository
render gate re-renders with exactly that release name to catch the dangling ref.

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.dbPasswordEnv" -}}
{{- if include "plugin-br-pix-jd.postgresPasswordSourced" . -}}
{{- include "lerian-common.infraSecretRef" (dict "context" . "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") -}}
{{- end -}}
{{- /* External path: NOTHING is emitted here on purpose. The password lives in this
   chart's own Secret (or the operator's existingSecret), which the container already
   loads wholesale through `envFrom: secretRef` — so a discrete secretKeyRef would
   define POSTGRES_PASSWORD twice for the same container. The standard forbids it
   explicitly: "Avoid double-definition (do not leave the key in both the envFrom
   Secret and the discrete env:)". */ -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
externalPostgresPasswordRequired — required gate for the external/disabled path.

Invoked from the api Secret template. Only fires on the path that actually needs
an operator-provided password: with the subchart bundled the value comes from its
Secret and no gate applies. Skipped when an existingSecret carries it.

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.externalPostgresPasswordRequired" -}}
{{- if not (include "plugin-br-pix-jd.postgresPasswordSourced" .) -}}
{{- $api := .Values.api -}}
{{- if not (($api.existingSecret | default dict).name | default "") -}}
{{- if not (($api.secrets | default dict).POSTGRES_PASSWORD | default "") -}}
{{- fail "\n\nERROR: POSTGRES_PASSWORD is not sourced.\nThe bundled postgresql subchart is disabled or marked external, so the chart has\nnowhere to read the password from. Pick one:\n  --set api.secrets.POSTGRES_PASSWORD=<value>\n  --set api.existingSecret.name=<secret carrying POSTGRES_PASSWORD>\n  --set postgresql.auth.existingSecret=<secret the subchart should use>\n" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
postgresHost — the Postgres authority the app connects to.

Bundled: the subchart's primary Service, whose name is the same collapse-aware
value as its Secret (verified against rendered output at postgresql 16.3.5 —
`Service/<dependency.fullname>`). Deriving it means the operator does not restate
a hostname the chart already knows.

External: operator-supplied. Required, because an empty POSTGRES_HOST makes the
app default to `localhost` and fail its readiness probe with a connection error
that reads like a Postgres outage rather than a missing value.

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.postgresHost" -}}
{{- $cm := .Values.api.configmap | default dict -}}
{{- $explicit := $cm.POSTGRES_HOST | default "" -}}
{{- if $explicit -}}
{{- $explicit -}}
{{- else if include "plugin-br-pix-jd.postgresRenders" . -}}
{{- /* postgresRenders, NOT postgresPasswordSourced: the host may only be derived
   when the subchart actually renders a Service in this release. An operator-managed
   existingSecret proves nothing about that, and treating it as proof is what
   produced a POSTGRES_HOST pointing at a Service that did not exist. */ -}}
{{- $ns := .Values.namespaceOverride | default "" -}}
{{- $svc := include "lerian-common.dependency.fullname" (dict "chartName" "postgresql" "chartValues" (.Values.postgresql | default dict) "context" .) -}}
{{- if $ns -}}
{{- /* namespaceOverride moves THIS chart's objects but not the subchart's, which
   stays in .Release.Namespace. A bare Service name does not resolve across
   namespaces, so qualify it. */ -}}
{{- printf "%s.%s.svc.cluster.local" $svc .Release.Namespace -}}
{{- else -}}
{{- $svc -}}
{{- end -}}
{{- else -}}
{{- fail "\n\nERROR: POSTGRES_HOST is not set and there is no bundled Postgres to derive it from.\nSet api.configmap.POSTGRES_HOST=<host> for the external datastore, or re-enable\nthe bundled subchart (postgresql.enabled=true, postgresql.external=false).\n" -}}
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
platformEnv — the env block BOTH components share.

api and worker are one binary pair over one datastore set, so their platform
configuration is identical by construction; only telemetry identity and the cron
knobs differ. Emitting the shared block from one place is what keeps the two
component ConfigMaps from drifting into "the api got the new Redis timeout and
the worker did not" — a divergence that in the worker's case silently degrades
the money-path reconcilers.

Most of the block comes from lerian-common: rateLimit (10 keys), otel (5),
auth (2). The rest has no shared contract and is emitted here.

Input dict: root, configmap (the COMPONENT's map — it is the override source, so
each component can still override any shared key), serviceName (OTel identity).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.cfg" -}}
{{- $cm := .configmap | default dict -}}
{{- if hasKey $cm .key -}}
{{- index $cm .key -}}
{{- else -}}
{{- .default -}}
{{- end -}}
{{- end }}

{{- define "plugin-br-pix-jd.platformEnv" -}}
{{- $root := .root -}}
{{- /* PRESENCE, not truthiness. The first cut resolved every key as
   `index api.configmap "K" | default "<literal>"`, which silently swallowed any
   explicit 0 / false / "" an operator set: `--set api.configmap.TLS_TERMINATED_UPSTREAM=false`
   rendered "true", and POSTGRES_CONN_MAX_LIFETIME_MINS=0 (which means "unlimited" to
   database/sql) rendered 30. It also broke the global contracts: a declared-but-empty
   key in values.yaml counts as PRESENT to lerian-common's hasKey resolvers, so it beat
   global.observability / global.auth every time and those blocks were dead on arrival.
   Both defects have one cause and one fix — resolve by hasKey, and keep the chart's
   defaults as literals HERE rather than as empty placeholders in values.yaml.

   The component map is merged OVER the api map so the worker still inherits every
   shared value (one datastore set, one auth, one telemetry backend) while keeping the
   ability to override any single key. For the api itself the merge is idempotent. */ -}}
{{- $cm := mergeOverwrite (deepCopy ($root.Values.api.configmap | default dict)) (.configmap | default dict) -}}
{{- $api := $root.Values.api -}}
{{- /* Runtime + server. ENVIRONMENT_NAME=production arms the app's security gates
   (auth forced on, Postgres password + SSL required, every ALLOW_* bypass and
   IS_DEVELOPMENT=true rejected at boot). */ -}}
ENVIRONMENT_NAME: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "ENVIRONMENT_NAME" "default" "") | quote }}
LOG_LEVEL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "LOG_LEVEL" "default" "info") | quote }}
INFRA_CONNECT_TIMEOUT_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "INFRA_CONNECT_TIMEOUT_SEC" "default" "30") | quote }}
DB_METRICS_INTERVAL_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "DB_METRICS_INTERVAL_SEC" "default" "15") | quote }}
SYSTEMPLANE_ENABLED: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "SYSTEMPLANE_ENABLED" "default" "false") | quote }}
ORGANIZATION_IDS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "ORGANIZATION_IDS" "default" "") | quote }}
{{- /* Postgres. Host is derived for the bundled subchart; the pool and timeout
   values are shared because both processes open their own pool to the same DB. */}}
POSTGRES_HOST: {{ include "plugin-br-pix-jd.postgresHost" $root | quote }}
POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "plugin-br-pix-jd") | quote }}
POSTGRES_NAME: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "POSTGRES_NAME" "default" "plugin-br-pix-jd") | quote }}
POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" "disable") | quote }}
POSTGRES_MAX_OPEN_CONNS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "POSTGRES_MAX_OPEN_CONNS" "default" "25") | quote }}
POSTGRES_MAX_IDLE_CONNS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "POSTGRES_MAX_IDLE_CONNS" "default" "5") | quote }}
POSTGRES_CONN_MAX_LIFETIME_MINS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "POSTGRES_CONN_MAX_LIFETIME_MINS" "default" "30") | quote }}
POSTGRES_CONN_MAX_IDLE_TIME_MINS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "POSTGRES_CONN_MAX_IDLE_TIME_MINS" "default" "5") | quote }}
POSTGRES_CONNECT_TIMEOUT_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "POSTGRES_CONNECT_TIMEOUT_SEC" "default" "10") | quote }}
MIGRATIONS_PATH: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIGRATIONS_PATH" "default" "/migrations") | quote }}
{{- /* ALLOW_INSECURE_TLS — modeled as a first-class key, not left to the escape hatch,
   because the benedita test environments run Postgres, Valkey and RabbitMQ WITHOUT TLS
   and lib-commons refuses a plaintext connection to any of them unless this is set.
   Reaching a required knob through extraConfigmap would be the chart admitting it does
   not model its own deployment target.

   It is emitted ONLY when explicitly set: absent means the app's own safe default
   (false). The chart never ships it enabled.

   Deliberately NOT in the production-bypass gate, unlike the other three ALLOW_*: the
   app treats this one as the single sovereign switch for internal-datastore TLS in ANY
   environment (config_validation.go says so explicitly, and both the production guard
   and the SaaS TLS enforcement defer to it). Gating it here would be the chart
   overruling the app. The separate production check that DOES still apply is
   POSTGRES_SSLMODE != disable — those are independent, so setting this does not buy a
   plaintext Postgres under ENVIRONMENT_NAME=production. */ -}}
{{- with (include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "ALLOW_INSECURE_TLS" "default" "")) }}
ALLOW_INSECURE_TLS: {{ . | quote }}
{{- end }}

{{- /* Redis (Valkey). Required in practice: the rate limiter is fail-closed by
   default, so an unreachable Redis rejects traffic rather than degrading. */}}
REDIS_HOST: {{ required "\n\nERROR: api.configmap.REDIS_HOST is required.\nThe rate limiter is fail-closed by default, so an unset Redis authority makes\nevery request 4xx instead of degrading. Set it to host:port.\n" (include "lerian-common.datastore.value" (dict "context" $root "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" "")) | quote }}
REDIS_DB: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_DB" "default" "0") | quote }}
REDIS_PROTOCOL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_PROTOCOL" "default" "3") | quote }}
REDIS_POOL_SIZE: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_POOL_SIZE" "default" "10") | quote }}
REDIS_MIN_IDLE_CONNS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_MIN_IDLE_CONNS" "default" "2") | quote }}
REDIS_READ_TIMEOUT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_READ_TIMEOUT" "default" "3") | quote }}
REDIS_WRITE_TIMEOUT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_WRITE_TIMEOUT" "default" "3") | quote }}
REDIS_DIAL_TIMEOUT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_DIAL_TIMEOUT" "default" "5") | quote }}
REDIS_POOL_TIMEOUT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_POOL_TIMEOUT" "default" "2") | quote }}
REDIS_MAX_RETRIES: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_MAX_RETRIES" "default" "3") | quote }}
{{- /* Retry backoff: the app declares envDefault 8 (ms) and 1 (s), but lib-commons'
   SetConfigFromEnvVars ignores envDefault, so an unset key arrives as 0. Emitting
   them explicitly is what makes the documented values real. */}}
REDIS_MIN_RETRY_BACKOFF: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_MIN_RETRY_BACKOFF" "default" "8") | quote }}
REDIS_MAX_RETRY_BACKOFF: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_MAX_RETRY_BACKOFF" "default" "1") | quote }}
{{- /* Transport security for Redis/Valkey. REDIS_CA_CERT is only consulted by the app
   when REDIS_TLS is true, so both are emitted together — otherwise a TLS Valkey was
   reachable only through the extraConfigmap escape hatch. */}}
REDIS_TLS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_TLS" "default" "false") | quote }}
REDIS_CA_CERT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_CA_CERT" "default" "") | quote }}
{{- /* Sentinel topology. Empty selects the plain client, which is the common case. */}}
REDIS_MASTER_NAME: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "REDIS_MASTER_NAME" "default" "") | quote }}
{{- /* Auth. hostKey is PLUGIN_AUTH_HOST — the key this app actually reads. The
   retired TypeScript-era chart emitted PLUGIN_AUTH_ADDRESS, which this app
   ignores, so auth silently stayed unconfigured. */}}
{{ include "lerian-common.auth.env" (dict "context" $root "configmap" $cm "hostKey" "PLUGIN_AUTH_HOST") }}
{{- /* Telemetry. ENABLE_TELEMETRY stays out of otel.envFlat by that helper's own
   split, so it is emitted here as the knob. OTEL_EXPORTER_OTLP_ENDPOINT_PORT is
   dropped from the key list: the app has no such variable (it belonged to the
   TypeScript chart), and emitting it would be inert noise. */ -}}
{{- $telemetryEnabled := include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" "false") -}}
{{- $otlpEndpoint := include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" "") -}}
{{- $deployEnv := include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "deploymentEnvironment" "nativeKey" "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" "default" "") -}}
{{- $otelKeys := list "OTEL_RESOURCE_SERVICE_NAME" "OTEL_LIBRARY_NAME" "OTEL_RESOURCE_SERVICE_VERSION" "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" "OTEL_EXPORTER_OTLP_ENDPOINT" -}}
{{- /* The closing `}}` here deliberately keeps its newline: every preceding
   assignment trims both sides, so this is what terminates the last emitted key
   line above. */ -}}
{{- $otelDefaults := dict "OTEL_RESOURCE_SERVICE_NAME" .serviceName "OTEL_LIBRARY_NAME" (include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OTEL_LIBRARY_NAME" "default" "plugin-br-pix-jd")) "OTEL_RESOURCE_SERVICE_VERSION" ($api.image.tag | default $root.Chart.AppVersion) "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" $deployEnv "OTEL_EXPORTER_OTLP_ENDPOINT" $otlpEndpoint }}
ENABLE_TELEMETRY: {{ $telemetryEnabled | quote }}
{{ include "lerian-common.otel.envFlat" (dict "configmap" $cm "keys" $otelKeys "defaults" $otelDefaults) }}
{{- end }}

{{/*
------------------------------------------------------------------------------
migrationPostgresPassword — the operator-provided password for the migration-only
hook Secret, with its required gate.

The gate lives HERE rather than inline in the Secret template on purpose. The
repository's static validator flags `required` next to POSTGRES_PASSWORD inside a
Secret template whenever a bundled Bitnami postgresql dependency is declared — its
dual-secret rule — and it cannot see that this Secret renders ONLY on the external
path, where there is no subchart Secret to single-source from. Keeping the gate in a
named helper is the same shape plugin-br-bank-transfer uses
(`bank-transfer.migrationPostgresPassword`), and the semantics are unchanged: the
value is still mandatory exactly where it is consumed.

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.migrationPostgresPassword" -}}
{{- $pw := (.Values.api.secrets | default dict).POSTGRES_PASSWORD | default "" -}}
{{- if not $pw -}}
{{- fail "\n\nERROR: api.secrets.POSTGRES_PASSWORD is required to migrate an external Postgres.\nThe migration Job runs as a pre-install hook, before this chart's normal Secret exists,\nso it reads a minimal migration-only Secret that needs the value. Alternatively point\nthe chart at an existing Secret with api.existingSecret.name.\n" -}}
{{- end -}}
{{- $pw -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
migrationPasswordEnv — POSTGRES_PASSWORD for the migration Job.

Three sources, matching the Job's own hook phase:
  bundled Postgres  -> the subchart's generated Secret. The Job is a POST hook there,
                       so that Secret already exists; reuse the same single-source
                       helper the app containers use.
  operator Secret   -> api.existingSecret.name, read directly.
  external Postgres -> the minimal migration-only hook Secret (weight -5), which is
                       the only thing guaranteed to exist before a PRE hook.

Input: root context ($).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.migrationPasswordEnv" -}}
{{- if include "plugin-br-pix-jd.postgresPasswordSourced" . -}}
{{- include "plugin-br-pix-jd.dbPasswordEnv" . -}}
{{- else -}}
{{- $existing := (.Values.api.existingSecret | default dict).name | default "" -}}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ if $existing }}{{ $existing }}{{ else }}{{ printf "%s-migrations" (include "plugin-br-pix-jd.fullname" .) | trunc 63 | trimSuffix "-" }}{{ end }}
      key: POSTGRES_PASSWORD
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
domainEnv — the PIX domain configuration, shared by api and worker.

Both processes talk to the same JD, the same Midaz ledger and the same CRM, so this
block is resolved once and merged into both ConfigMaps. Same presence-aware
resolution as platformEnv: the component map is merged over the api map, and an
explicit "" / 0 / false from the operator survives.

NOT MODELED, deliberately:
  MIDAZ_AUTH_ADDRESS — removed from the app on purpose ("a second address knob for
  one Access Manager drifts", internal/bootstrap/config_pix.go). It survives only in
  the app's .env.example and .env.aws-* files, which are a false contract. Modeling
  it here would make the chart a third place that documents a variable no process
  reads.

Input dict: root, configmap (the component's map).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.domainEnv" -}}
{{- $root := .root -}}
{{- $cm := mergeOverwrite (deepCopy ($root.Values.api.configmap | default dict)) (.configmap | default dict) -}}
{{- $c := dict "configmap" $cm -}}
{{- /* JD / JDPI. JD_BANK_ID is the plugin's own ISPB and is load-bearing far beyond
   an identifier: the worker gates EVERY MED poller on it being exactly 8 characters,
   and a missing or malformed value skips them all with a single WARN — including the
   settlement reconciler, which is the job that commits or cancels reserved money.
   Silent partial function on a money path is worth a render-time gate. */ -}}
{{- $bankId := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_BANK_ID" "default" "") -}}
{{- if and $bankId (ne (len $bankId) 8) -}}
{{- fail (printf "\n\nERROR: JD_BANK_ID must be exactly 8 characters (an ISPB); got %d.\nThe worker gates every MED poller on this length and skips them ALL with one WARN\nwhen it does not match — including med_settlement_reconcile, which commits or cancels\nreserved money. A wrong length degrades the money path silently.\n" (len $bankId)) -}}
{{- end }}
JD_BASE_URL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_BASE_URL" "default" "") | quote }}
JD_BANK_ID: {{ $bankId | quote }}
JD_GRANT_TYPE: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_GRANT_TYPE" "default" "client_credentials") | quote }}
{{- /* DNS+Service+Path gateway mode: true inserts the fixed JDPI service segment for an
   APISIX-fronted JDPI; false keeps the direct-JDPI/mock scheme. */}}
JD_USE_SERVICE_SEGMENTS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_USE_SERVICE_SEGMENTS" "default" "false") | quote }}
{{- /* Idempotency-aware transport retry. A bare money POST that JDPI may already have
   processed is never re-fired; only GETs and idempotency-keyed POSTs retry. */}}
JDPI_MAX_RETRIES: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JDPI_MAX_RETRIES" "default" "2") | quote }}
JDPI_RETRY_BASE_DELAY_MS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JDPI_RETRY_BASE_DELAY_MS" "default" "100") | quote }}
{{- /* Midaz ledger. MIDAZ_ASSET_ID has NO safe default: the app silently backfills "1"
   when it is empty, which posts against a fabricated asset instead of failing. The
   chart refuses instead — same defect class the app's own smoke report flagged. */ -}}
{{- /* O `}}` abaixo NÃO right-trima de propósito: o comentário acima e este
   assignment trimam ambos os lados, então esta é a newline que termina a última
   chave emitida antes do bloco Midaz. Sem ela as duas se juntam numa linha só. */ -}}
{{- $assetId := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIDAZ_ASSET_ID" "default" "") }}
MIDAZ_ORGANIZATION_ID: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIDAZ_ORGANIZATION_ID" "default" "") | quote }}
MIDAZ_LEDGER_ID: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIDAZ_LEDGER_ID" "default" "") | quote }}
MIDAZ_ASSET_ID: {{ required "\n\nERROR: api.configmap.MIDAZ_ASSET_ID is required.\nAn empty value is NOT inert: the app backfills \"1\" and posts against a fabricated\nasset instead of failing closed. Set the real asset code (for example BRL).\n" $assetId | quote }}
MIDAZ_EXTERNAL_ID: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIDAZ_EXTERNAL_ID" "default" "") | quote }}
MIDAZ_TIMEOUT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIDAZ_TIMEOUT" "default" "30000") | quote }}
MIDAZ_URL_ONBOARDING: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIDAZ_URL_ONBOARDING" "default" "") | quote }}
MIDAZ_URL_TRANSACTION: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MIDAZ_URL_TRANSACTION" "default" "") | quote }}
{{- /* CRM — alias resolution. */}}
CRM_URL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "CRM_URL" "default" "") | quote }}
{{- /* Transaction limits: the clock bounds separating the daily and nightly buckets. */}}
TRANSACTION_LIMIT_DAILY_PERIOD_INIT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "TRANSACTION_LIMIT_DAILY_PERIOD_INIT" "default" "06:00") | quote }}
TRANSACTION_LIMIT_DAILY_PERIOD_END: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "TRANSACTION_LIMIT_DAILY_PERIOD_END" "default" "20:00") | quote }}
{{- /* Notification providers. SENDGRID_BASE_URL / TWILIO_BASE_URL MUST default to
   empty: empty means "the real provider", and they exist only so a test rig can point
   the adapter at a local counterparty. A non-empty default here would silently divert
   production OTP mail and SMS. */}}
SENDGRID_FROM_EMAIL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "SENDGRID_FROM_EMAIL" "default" "") | quote }}
SENDGRID_FROM_TEMPLATE: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "SENDGRID_FROM_TEMPLATE" "default" "") | quote }}
SENDGRID_BASE_URL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "SENDGRID_BASE_URL" "default" "") | quote }}
TWILIO_PHONE_NUMBER: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "TWILIO_PHONE_NUMBER" "default" "") | quote }}
TWILIO_BASE_URL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "TWILIO_BASE_URL" "default" "") | quote }}
{{- end }}

{{/*
------------------------------------------------------------------------------
qrcodeEnv — dynamic-QR JWS hosting. API-ONLY: the worker serves no QR payloads.

QRCODE_PUBLIC_BASE_URL has no safe default and two constraints that are easy to
violate and expensive to discover, so both are gates rather than comments:
  - SCHEMA-LESS. JDPI rejects a value carrying http:// or https://.
  - urlPayloadJson is capped at 77 characters by JDPI, and that URL is
    "<base>/<payloadPath>/<id>" — so the base plus path must leave room for the id.
A wrong value advertises a payload nothing can serve, and the failure surfaces at a
payer's PSP rather than at deploy.

Input dict: root, configmap.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.qrcodeEnv" -}}
{{- $root := .root -}}
{{- $cm := mergeOverwrite (deepCopy ($root.Values.api.configmap | default dict)) (.configmap | default dict) -}}
{{- $base := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "QRCODE_PUBLIC_BASE_URL" "default" "") -}}
{{- $payloadPath := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "QRCODE_PAYLOAD_PATH" "default" "v1/qrcodes/payload") -}}
{{- if $base -}}
{{- if or (hasPrefix "http://" $base) (hasPrefix "https://" $base) -}}
{{- fail (printf "\n\nERROR: QRCODE_PUBLIC_BASE_URL must be schema-less; got %q.\nJDPI rejects a value carrying http:// or https://. Use just the FQDN, e.g. pix.example.com\n" $base) -}}
{{- end -}}
{{- $advertised := printf "%s/%s/" $base $payloadPath -}}
{{- if gt (len $advertised) 45 -}}
{{- fail (printf "\n\nERROR: QRCODE_PUBLIC_BASE_URL + QRCODE_PAYLOAD_PATH is too long.\nJDPI caps urlPayloadJson at 77 characters and the advertised URL is\n  <base>/<payloadPath>/<id>\nThe prefix alone is already %d characters (%q), leaving too little room for the id.\nShorten the host or the path.\n" (len $advertised) $advertised) -}}
{{- end -}}
{{- end }}
QRCODE_PUBLIC_BASE_URL: {{ $base | quote }}
QRCODE_PAYLOAD_PATH: {{ $payloadPath | quote }}
QRCODE_JWK_PATH: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "QRCODE_JWK_PATH" "default" "v1/qrcodes/jwks") | quote }}
{{- /* PRE-LAUNCH GATE per the app's own config: the served JWS content-type is deferred
   by the JDPI spec to the Bacen "Manual de Padrões para Iniciação do PIX". Confirm
   before go-live rather than assuming this default. */}}
QRCODE_JWS_CONTENT_TYPE: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "QRCODE_JWS_CONTENT_TYPE" "default" "application/jose") | quote }}
{{- /* RFC 7517 §8.5 media type, so a payer PSP's JOSE library content-negotiates on it;
   a generic application/json risks rejection. */}}
QRCODE_JWKS_CONTENT_TYPE: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "QRCODE_JWKS_CONTENT_TYPE" "default" "application/jwk-set+json") | quote }}
{{- end }}

{{/*
------------------------------------------------------------------------------
workerCronEnv — the worker's own surface: cron cadence and the stuck-order threshold.
Input dict: root, configmap.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.workerCronEnv" -}}
{{- $cm := mergeOverwrite (deepCopy (.root.Values.api.configmap | default dict)) (.configmap | default dict) -}}
JOBS_CRON: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JOBS_CRON" "default" "*/10 * * * * *") | quote }}
JOBS_CRON_TRANSACTIONS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JOBS_CRON_TRANSACTIONS" "default" "*/10 * * * * *") | quote }}
{{- /* 80s is the JDPI manual §8.4.2 CPM number (2x the 40s BACEN Manual de Tempos
   SPI-max-processing window). A PENDING external CASH_OUT past this age emits a STUCK
   signal — it NEVER auto-settles, because the manual forbids any terminal state
   without an unequivocal SPI/JDPI confirmation. */}}
JOBS_RECONCILE_STUCK_THRESHOLD_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JOBS_RECONCILE_STUCK_THRESHOLD_SEC" "default" "80") | quote }}
{{- end }}

{{/*
------------------------------------------------------------------------------
domainSecrets — the PIX credentials, shared by api and worker.

Emits `KEY: <b64>` lines with no leading indent; the caller nindents under `data:`.
A key is emitted only when it has a value: an unset JD credential should surface as
the app own boot error naming the integration, not as an empty string to trace.

Worker values fall back to the api values so the two components cannot drift onto
different credentials for the same downstream.

MULTI-TENANT: every credential here is IGNORED when MULTI_TENANT_ENABLED=true — they
are resolved per tenant from AWS Secrets Manager.

Input dict: root, comp (the component values block).
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.domainSecrets" -}}
{{- $api := .root.Values.api.secrets | default dict -}}
{{- $own := (.comp.secrets | default dict) -}}
{{- $s := mergeOverwrite (deepCopy $api) $own -}}
{{- $mt := eq (index (.root.Values.api.configmap | default dict) "MULTI_TENANT_ENABLED" | default "false" | toString) "true" -}}
{{- $lines := list -}}
{{- range $k := (list "JD_CLIENT_ID" "JD_SECRET" "MIDAZ_CLIENT_ID" "MIDAZ_CLIENT_SECRET" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "SENDGRID_API_KEY" "TWILIO_ACCOUNT_SID" "TWILIO_AUTH_TOKEN") -}}
{{- with (index $s $k) -}}
{{- $lines = append $lines (printf "%s: %s" $k (. | b64enc | quote)) -}}
{{- end -}}
{{- end -}}
{{- /* INDIRECTS_DELIVERY_ENCRYPTION_KEY encrypts an indirect HMAC delivery secret at
   rest. Hex-encoded AES-256 = EXACTLY 64 hex characters. The app fails the encryption
   closed on a malformed value, so a secret-bearing registration errors instead of
   persisting plaintext — correct, but discovered at runtime. Validating the shape here
   moves it to render time. In multi-tenant the key is resolved per tenant. */ -}}
{{- $delivery := index $s "INDIRECTS_DELIVERY_ENCRYPTION_KEY" | default "" -}}
{{- if and $delivery (not $mt) -}}
{{- /* SKIP the format check for an argocd-vault-plugin placeholder. AVP substitutes
   `<path:...>` in the RENDERED manifest, AFTER helm has run — so at template time the
   value is always the literal placeholder, never the secret. A shape check here would
   therefore reject every AVP-managed install, which is exactly what happened: the
   GitOps sync rendered only the first helmfile release and ArgoCD still reported
   Synced/Healthy because avp-helmfile swallowed the error.
   The guard stays for direct `helm install`, where the real value IS present. */ -}}
{{- if and (not (hasPrefix "<path:" $delivery)) (not (regexMatch "^[0-9a-fA-F]{64}$" $delivery)) -}}
{{- fail (printf "\n\nERROR: INDIRECTS_DELIVERY_ENCRYPTION_KEY must be 64 hex characters (a hex-encoded\nAES-256 key); got %d. Generate one with: openssl rand -hex 32\nA malformed key makes the app fail delivery-secret encryption closed at runtime.\n" (len $delivery)) -}}
{{- end -}}
{{- $lines = append $lines (printf "INDIRECTS_DELIVERY_ENCRYPTION_KEY: %s" ($delivery | b64enc | quote)) -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
multiTenantEnv — the MT block, from lerian-common's canonical contract.

`lerian-common.multiTenant.envFlat` owns the 14 standard keys, their names and their
defaults, so this chart inherits exactly what the other 13 MT charts in the repo
emit instead of inventing a 14th dialect. Two things it does NOT cover and this
chart adds:

  READYZ_ISPB_SCAN_INTERVAL_SEC — not in the library's key set. It paces the
    background cross-tenant ISPB-uniqueness scan, and it MUST stay above
    MULTI_TENANT_IDLE_TIMEOUT_SEC: while a scan holds tenant connections, the pools
    never become eviction-eligible and MULTI_TENANT_MAX_TENANT_POOLS silently stops
    bounding anything. That is a consistency gate, not a comment.

  M2M / AWS — the per-tenant credential path. Both target services are REQUIRED in
    MT (the app fails the boot naming the missing one) and the Secrets Manager path
    segments are NOT derivable from the service name, so there is no sensible
    default to guess.

Input dict: root, configmap.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.multiTenantEnv" -}}
{{- $root := .root -}}
{{- $cm := mergeOverwrite (deepCopy ($root.Values.api.configmap | default dict)) (.configmap | default dict) -}}
{{- $enabled := eq (index $cm "MULTI_TENANT_ENABLED" | default "false" | toString) "true" -}}
{{- if $enabled -}}
{{- $idle := index $cm "MULTI_TENANT_IDLE_TIMEOUT_SEC" | default "300" | toString | atoi -}}
{{- $scan := index $cm "READYZ_ISPB_SCAN_INTERVAL_SEC" | default "600" | toString | atoi -}}
{{- if le $scan $idle -}}
{{- fail (printf "\n\nERROR: READYZ_ISPB_SCAN_INTERVAL_SEC (%d) must be GREATER than MULTI_TENANT_IDLE_TIMEOUT_SEC (%d).\nThe background ISPB-uniqueness scan holds tenant connections while it runs; scanning at\nor below the idle timeout means those pools never become eviction-eligible, so\nMULTI_TENANT_MAX_TENANT_POOLS stops bounding anything and the process leaks pools.\n" $scan $idle) -}}
{{- end -}}
{{- $ledgerTarget := index $cm "M2M_LEDGER_TARGET_SERVICE" | default "" -}}
{{- $crmTarget := index $cm "M2M_CRM_TARGET_SERVICE" | default "" -}}
{{- if or (not $ledgerTarget) (not $crmTarget) -}}
{{- fail "\n\nERROR: M2M_LEDGER_TARGET_SERVICE and M2M_CRM_TARGET_SERVICE are both required when\nMULTI_TENANT_ENABLED=true. One value per downstream: the Secrets Manager path is\n  tenants/{env}/{tenantOrgID}/{app}/m2m/{targetService}/credentials\nso a single value could only ever authenticate one of them. The segments are NOT\nderivable from the service name — copy them from the provisioned secret paths\n(staging uses \"ledger\" bare and \"plugin-crm\" prefixed). The app fails its boot naming\nwhichever is missing.\n" -}}
{{- end -}}
{{- end }}
{{ include "lerian-common.multiTenant.envFlat" (dict
      "configmap" $cm
      "keys" (list "MULTI_TENANT_URL" "MULTI_TENANT_ALLOW_INSECURE_HTTP"
                   "MULTI_TENANT_MAX_TENANT_POOLS" "MULTI_TENANT_IDLE_TIMEOUT_SEC"
                   "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC"
                   "MULTI_TENANT_REDIS_HOST" "MULTI_TENANT_REDIS_PORT" "MULTI_TENANT_REDIS_TLS"
                   "MULTI_TENANT_TIMEOUT" "MULTI_TENANT_CACHE_TTL_SEC"
                   "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC")
      "defaults" (dict "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" "20")
      "required" (dict
        "MULTI_TENANT_URL" "api.configmap.MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true"
        "MULTI_TENANT_REDIS_HOST" "api.configmap.MULTI_TENANT_REDIS_HOST is required when MULTI_TENANT_ENABLED=true")) }}
{{- if $enabled }}
READYZ_ISPB_SCAN_INTERVAL_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "READYZ_ISPB_SCAN_INTERVAL_SEC" "default" "600") | quote }}
M2M_LEDGER_TARGET_SERVICE: {{ index $cm "M2M_LEDGER_TARGET_SERVICE" | quote }}
M2M_CRM_TARGET_SERVICE: {{ index $cm "M2M_CRM_TARGET_SERVICE" | quote }}
M2M_CREDENTIAL_CACHE_TTL_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "M2M_CREDENTIAL_CACHE_TTL_SEC" "default" "300") | quote }}
{{- /* The app's own smoke campaign traced four 503s to a wrong AWS_REGION, and the
   default moved from us-east-1 to us-east-2 on the integration branch. Emitting it
   explicitly beats inheriting whatever the node's metadata suggests. */}}
AWS_REGION: {{ required "\n\nERROR: api.configmap.AWS_REGION is required when MULTI_TENANT_ENABLED=true.\nPer-tenant credentials are resolved from AWS Secrets Manager, and a wrong or unset\nregion surfaces as opaque 503s rather than a credential error.\n" (index $cm "AWS_REGION" | default "") | quote }}
{{- end }}
{{- end }}

{{/*
------------------------------------------------------------------------------
streamingEnv — the outbox relay and its Kafka producer. API + worker both publish.

Three consistency gates, all encoding couplings the app documents but does not
enforce at config-load time:
  - STREAMING_ENABLED requires OUTBOX_ENABLED: use cases write an envelope to the
    outbox table and the dispatcher is the SOLE publish path, so streaming without
    the outbox produces a producer that never receives anything.
  - STREAMING_ENABLED requires STREAMING_BROKERS.
  - STREAMING_CLOSE_TIMEOUT_S must stay BELOW terminationGracePeriodSeconds, or the
    pod is killed mid-flush and buffered CloudEvents are lost.
  - OUTBOX_DELIVERY_TABLE_NAME must differ from OUTBOX_TABLE_NAME: the delivery
    outbox is drained by the per-tenant delivery drainer, and pointing both at one
    table makes two drainers race the same rows.

Input dict: root, configmap, graceSeconds.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.streamingEnv" -}}
{{- $root := .root -}}
{{- $cm := mergeOverwrite (deepCopy ($root.Values.api.configmap | default dict)) (.configmap | default dict) -}}
{{- $streaming := eq (index $cm "STREAMING_ENABLED" | default "false" | toString) "true" -}}
{{- $outbox := eq (index $cm "OUTBOX_ENABLED" | default "false" | toString) "true" -}}
{{- $outboxTable := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_TABLE_NAME" "default" "outbox_events") -}}
{{- $deliveryTable := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_DELIVERY_TABLE_NAME" "default" "indirect_delivery_outbox") -}}
{{- if eq $outboxTable $deliveryTable -}}
{{- fail (printf "\n\nERROR: OUTBOX_DELIVERY_TABLE_NAME must differ from OUTBOX_TABLE_NAME (both are %q).\nThe delivery outbox is drained by the per-tenant delivery drainer and the main outbox by\nthe streaming dispatcher; pointing both at one table makes the two race the same rows.\n" $outboxTable) -}}
{{- end -}}
{{- if $streaming -}}
{{- if not $outbox -}}
{{- fail "\n\nERROR: STREAMING_ENABLED=true requires OUTBOX_ENABLED=true.\nUse cases write a streaming envelope to the outbox table and the outbox dispatcher is\nthe SOLE publish path, so streaming without the outbox starts a producer nothing ever\nfeeds — events are silently never published.\n" -}}
{{- end -}}
{{- if not (index $cm "STREAMING_BROKERS" | default "") -}}
{{- fail "\n\nERROR: STREAMING_BROKERS is required when STREAMING_ENABLED=true.\nComma-separated Kafka broker list, e.g. redpanda.dev-st.lerian.net:9092\n" -}}
{{- end -}}
{{- $closeTimeout := index $cm "STREAMING_CLOSE_TIMEOUT_S" | default "30" | toString | atoi -}}
{{- if ge $closeTimeout (int .graceSeconds) -}}
{{- fail (printf "\n\nERROR: STREAMING_CLOSE_TIMEOUT_S (%d) must be BELOW terminationGracePeriodSeconds (%d).\nOtherwise the pod is killed while the producer is still flushing and buffered\nCloudEvents are lost. Lower the close timeout or raise the grace period.\n" $closeTimeout (int .graceSeconds)) -}}
{{- end -}}
{{- end }}
OUTBOX_ENABLED: {{ index $cm "OUTBOX_ENABLED" | default "false" | quote }}
{{- if $outbox }}
OUTBOX_TABLE_NAME: {{ $outboxTable | quote }}
OUTBOX_DELIVERY_TABLE_NAME: {{ $deliveryTable | quote }}
OUTBOX_DISPATCH_INTERVAL_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_DISPATCH_INTERVAL_SEC" "default" "2") | quote }}
OUTBOX_BATCH_SIZE: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_BATCH_SIZE" "default" "50") | quote }}
OUTBOX_PUBLISH_MAX_ATTEMPTS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_PUBLISH_MAX_ATTEMPTS" "default" "3") | quote }}
OUTBOX_PUBLISH_BACKOFF_MS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_PUBLISH_BACKOFF_MS" "default" "200") | quote }}
OUTBOX_RETRY_WINDOW_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_RETRY_WINDOW_SEC" "default" "300") | quote }}
OUTBOX_MAX_DISPATCH_ATTEMPTS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_MAX_DISPATCH_ATTEMPTS" "default" "10") | quote }}
OUTBOX_PROCESSING_TIMEOUT_SEC: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_PROCESSING_TIMEOUT_SEC" "default" "600") | quote }}
OUTBOX_MAX_FAILED_PER_BATCH: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_MAX_FAILED_PER_BATCH" "default" "25") | quote }}
OUTBOX_INCLUDE_TENANT_METRICS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_INCLUDE_TENANT_METRICS" "default" "false") | quote }}
OUTBOX_ALLOW_EMPTY_TENANT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "OUTBOX_ALLOW_EMPTY_TENANT" "default" "true") | quote }}
CIRCUIT_BREAKER_ENABLED: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "CIRCUIT_BREAKER_ENABLED" "default" "false") | quote }}
{{- end }}
STREAMING_ENABLED: {{ index $cm "STREAMING_ENABLED" | default "false" | quote }}
{{- if $streaming }}
STREAMING_HEALTH_CHECK_TIMEOUT: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "STREAMING_HEALTH_CHECK_TIMEOUT" "default" "2s") | quote }}
STREAMING_CLOSE_TIMEOUT_S: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "STREAMING_CLOSE_TIMEOUT_S" "default" "30") | quote }}
{{ include "lerian-common.streaming.env" (dict
      "context" $root "enabled" true "configmap" $cm
      "clientId" (include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "STREAMING_CLIENT_ID" "default" "plugin-br-pix-jd"))
      "cloudeventsSource" (include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "STREAMING_CLOUDEVENTS_SOURCE" "default" "//lerian.midaz/plugin-br-pix-jd"))) }}
{{- end }}
{{- end }}

{{/*
------------------------------------------------------------------------------
platformSecrets — MT, streaming and M2M credentials, shared by api and worker.

Emits `KEY: <b64>` lines; the caller nindents under `data:`. Gated on the feature
being ON, because requiring a tenant-manager API key from a single-tenant install
would be nonsense.

M2M_L2_ENCRYPTION_KEY guards the L2 credential cache, which holds EVERY tenant
clientId/clientSecret and has no plaintext mode. Empty disables L2 (L1 only, one boot
WARN); set-but-malformed fails the boot. Validating the 64-hex shape here turns that
boot failure into a render failure.

Input dict: root, comp.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.platformSecrets" -}}
{{- $api := .root.Values.api.secrets | default dict -}}
{{- $s := mergeOverwrite (deepCopy $api) (.comp.secrets | default dict) -}}
{{- $cm := .root.Values.api.configmap | default dict -}}
{{- $mt := eq (index $cm "MULTI_TENANT_ENABLED" | default "false" | toString) "true" -}}
{{- $streaming := eq (index $cm "STREAMING_ENABLED" | default "false" | toString) "true" -}}
{{- $lines := list -}}
{{- if $mt -}}
{{- $apiKey := index $s "MULTI_TENANT_SERVICE_API_KEY" | default "" -}}
{{- if not $apiKey -}}
{{- fail "\n\nERROR: api.secrets.MULTI_TENANT_SERVICE_API_KEY is required when MULTI_TENANT_ENABLED=true.\nWithout it the app cannot authenticate to the Tenant Manager and no tenant resolves.\n" -}}
{{- end -}}
{{- $lines = append $lines (printf "MULTI_TENANT_SERVICE_API_KEY: %s" ($apiKey | b64enc | quote)) -}}
{{- with (index $s "MULTI_TENANT_REDIS_PASSWORD") -}}
{{- $lines = append $lines (printf "MULTI_TENANT_REDIS_PASSWORD: %s" (. | b64enc | quote)) -}}
{{- end -}}
{{- $l2 := index $s "M2M_L2_ENCRYPTION_KEY" | default "" -}}
{{- if $l2 -}}
{{- /* SKIP the format check for an argocd-vault-plugin placeholder. AVP substitutes
   `<path:...>` in the RENDERED manifest, AFTER helm has run — so at template time the
   value is always the literal placeholder, never the secret. A shape check here would
   therefore reject every AVP-managed install, which is exactly what happened: the
   GitOps sync rendered only the first helmfile release and ArgoCD still reported
   Synced/Healthy because avp-helmfile swallowed the error.
   The guard stays for direct `helm install`, where the real value IS present. */ -}}
{{- if and (not (hasPrefix "<path:" $l2)) (not (regexMatch "^[0-9a-fA-F]{64}$" $l2)) -}}
{{- fail (printf "\n\nERROR: M2M_L2_ENCRYPTION_KEY must be 64 hex characters (hex-encoded AES-256); got %d.\nGenerate one with: openssl rand -hex 32\nIt encrypts the L2 cache holding every tenant clientId/clientSecret; a malformed value\nfails the boot. Leave it EMPTY to disable L2 deliberately (L1 only, one boot WARN).\n" (len $l2)) -}}
{{- end -}}
{{- $lines = append $lines (printf "M2M_L2_ENCRYPTION_KEY: %s" ($l2 | b64enc | quote)) -}}
{{- end -}}
{{- end -}}
{{- if $streaming -}}
{{- with (index $s "STREAMING_SASL_PASSWORD") -}}
{{- $lines = append $lines (printf "STREAMING_SASL_PASSWORD: %s" (. | b64enc | quote)) -}}
{{- end -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
componentSecretName — the Secret a component's `envFrom` points at.
Input dict: root, name, comp.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.componentSecretName" -}}
{{- $existing := (.comp.existingSecret | default dict).name | default "" -}}
{{- if $existing -}}
{{- $existing -}}
{{- else -}}
{{- include "plugin-br-pix-jd.componentFullname" (dict "root" .root "name" .name) -}}
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
rendersOwnSecret — does this component render its own Secret?
False when the operator supplied an existingSecret: the values live outside the
chart then, so requiring them inline would be wrong.
Input dict: comp.
------------------------------------------------------------------------------
*/}}
{{- define "plugin-br-pix-jd.rendersOwnSecret" -}}
{{- if not ((.comp.existingSecret | default dict).name | default "") -}}
true
{{- end -}}
{{- end }}
