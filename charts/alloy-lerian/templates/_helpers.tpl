{{/*
Naming and labels.
*/}}
{{- define "alloy-lerian.name" -}}
{{- default "alloy-lerian" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "alloy-lerian.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "alloy-lerian.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "alloy-lerian.labels" -}}
app.kubernetes.io/name: {{ include "alloy-lerian.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: alloy-lerian
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}


{{/*
==============================================================================
PROFILE — validation and derivation
==============================================================================
The profile boundary is operational responsibility, not convenience:

  own     the node is ours, so host capacity and scheduling are our concern
  client  the node belongs to the client; collecting it asks for data we have
          no standing to act on, and adds traffic across the public network

Not inferable, no default. Inferring from a cluster property would silently
produce the wrong profile in the ambiguous case.
*/}}
{{- define "alloy-lerian.profile" -}}
{{- $p := .Values.profile | default "" -}}
{{- if not $p -}}
{{- fail "\n\nalloy-lerian: `profile` is required and has no default.\n\n  profile: own     # our own environment — collects node infrastructure\n  profile: client  # client cluster — does NOT collect node infrastructure\n\nThe distinction is operational responsibility, not preference.\n" -}}
{{- end -}}
{{- if not (has $p (list "own" "client")) -}}
{{- fail (printf "\n\nalloy-lerian: unknown profile %q. Valid values: own, client.\n" $p) -}}
{{- end -}}
{{- $p -}}
{{- end -}}

{{/*
Whether node infrastructure telemetry is collected. Derived from the profile,
never configurable on its own — that would let the boundary drift.
*/}}
{{- define "alloy-lerian.collectsNodeInfra" -}}
{{- eq (include "alloy-lerian.profile" .) "own" -}}
{{- end -}}


{{/*
==============================================================================
ORIGIN IDENTIFIER — required, canonical form
==============================================================================
Deliberately has NO default. The current collector chart ships a default that
violates its own schema, which is why it cannot render with its own values.

Canonical form accepts hyphenated composition: the earlier pattern rejected
legitimate identifiers already in use (`lazari-sandbox-prd`, `pix-switch-prd`).

Absence and malformation are DISTINCT errors. The current schema only detects
the second, so an omitted identifier passes silently — and telemetry arrives
at the destination with no owner.

The reserved list holds the three SaaS environments ONLY. They are exempt because
they predate the convention, and renaming them would orphan the metric history of
every series already carrying those names.

On-premise clusters are deliberately NOT reserved: their telemetry goes to a
separate Grafana, so they never share an identifier namespace with client data.
An identifier for them still follows the convention (benedita-prd, not benedita).

⚠️ NEITHER MESSAGE NAMES AN INTERNAL ENVIRONMENT. The reserved list is matched but
never printed. This chart is installed in third-party clusters, and an error
message is the one place a client is guaranteed to read: listing our own
environment names there discloses internal topology to every operator who
mistypes an identifier, for no benefit — a client cannot use a reserved name
anyway. Both messages state the required form and nothing else.
*/}}
{{- define "alloy-lerian.originId" -}}
{{- $id := .Values.origin.id | default "" -}}
{{- if not $id -}}
{{- fail "\n\nalloy-lerian: `origin.id` is required and has no default.\n\nIt marks every record with the environment it came from. Without it,\ntelemetry reaches the destination unattributable.\n\n  origin:\n    id: acme-prd\n\nRequired form: <name>-<stage>, lowercase, stage = stg | hml | prd.\n" -}}
{{- end -}}
{{- $reserved := list "aws-production" "aws-staging" "aws-devops" -}}
{{- if not (has $id $reserved) -}}
{{- if not (regexMatch "^[a-z0-9]+(-[a-z0-9]+)*-(stg|hml|prd)$" $id) -}}
{{- fail (printf "\n\nalloy-lerian: origin.id %q is malformed.\n\nRequired form: <name>-<stage>, lowercase, stage = stg | hml | prd.\nComposition is allowed: acme-prd, lazari-sandbox-prd.\n" $id) -}}
{{- end -}}
{{- end -}}
{{- $id -}}
{{- end -}}


{{/*
==============================================================================
COLLECTION INTERVAL — floor enforced, never silently adjusted
==============================================================================
Cost on the telemetry platform is a function of series x writes per minute.
Collecting faster than anyone queries wastes CPU in the client cluster,
bandwidth across the public network and processing at the destination.

A value below the floor is REJECTED, not clamped. Clamping would hide the
divergent intent of whoever configured it.
*/}}
{{- define "alloy-lerian.interval" -}}
{{- $i := .Values.collection.interval | default "60s" -}}
{{- $seconds := 0 -}}
{{- if regexMatch "^[0-9]+s$" $i -}}
{{-   $seconds = $i | trimSuffix "s" | int -}}
{{- else if regexMatch "^[0-9]+m$" $i -}}
{{-   $seconds = mul ($i | trimSuffix "m" | int) 60 -}}
{{- else -}}
{{-   fail (printf "\n\nalloy-lerian: collection.interval %q is malformed. Use a duration such as 60s or 5m.\n" $i) -}}
{{- end -}}
{{- if lt $seconds 60 -}}
{{- fail (printf "\n\nalloy-lerian: collection.interval %q is below the 60s floor.\n\nThe value is rejected rather than adjusted, so the divergent intent is\nvisible instead of silently corrected.\n" $i) -}}
{{- end -}}
{{- $i -}}
{{- end -}}


{{/*
==============================================================================
RED FLUSH INTERVAL — same 60s floor, same reason
==============================================================================
The write rate of the derived RED series. It is subject to the identical floor
as collection.interval because it is the identical cost mechanism: the
destination charges series x writes per minute, and these series are among the
most numerous the agent produces.

Returned quoted, so the caller emits a literal the config parser accepts.
*/}}
{{- define "alloy-lerian.spanMetricsFlushInterval" -}}
{{- $i := .Values.spanMetrics.flushInterval | default "60s" -}}
{{- $seconds := 0 -}}
{{- if regexMatch "^[0-9]+s$" $i -}}
{{-   $seconds = $i | trimSuffix "s" | int -}}
{{- else if regexMatch "^[0-9]+m$" $i -}}
{{-   $seconds = mul ($i | trimSuffix "m" | int) 60 -}}
{{- else -}}
{{-   fail (printf "\n\nalloy-lerian: spanMetrics.flushInterval %q is malformed. Use a duration such as 60s or 5m.\n" $i) -}}
{{- end -}}
{{- if lt $seconds 60 -}}
{{- fail (printf "\n\nalloy-lerian: spanMetrics.flushInterval %q is below the 60s floor.\n\nThese are the RED series, among the most numerous the agent emits, and the\ndestination charges series x writes per minute. Flushing faster multiplies\nthe cost of identical information.\n\nRejected rather than adjusted, so the divergent intent stays visible.\n" $i) -}}
{{- end -}}
{{- $i | quote -}}
{{- end -}}


{{/*
==============================================================================
DESTINATION — reference to a Secret, never a literal
==============================================================================
The credential lives in the origin cluster Secret, provisioned before install
by the onboarding process. The chart only reads it.

Registered in the repository's out-of-band secret allowlist, so the render
gate does not flag it as a dangling reference.
*/}}
{{- define "alloy-lerian.destinationEndpoint" -}}
{{- $e := .Values.destination.endpoint | default "" -}}
{{- if not $e -}}
{{- fail "\n\nalloy-lerian: `destination.endpoint` is required.\n\n  destination:\n    endpoint: https://telemetry.example.net/v1/logs\n" -}}
{{- end -}}
{{/*
Plaintext is refused only when a CREDENTIAL travels to this endpoint. Cleartext
transmission of the token is the risk; plain HTTP by itself is not, and an
internal Service inside our own cluster is a legitimate destination — benedita
uses exactly that, over http, with no credential.

Tying the rule to the credential rather than to the scheme keeps the internal
path working while making it impossible to send a token in the clear across a
client's network.
*/}}
{{- if and (eq (include "alloy-lerian.destinationAuthenticated" .) "true") (not (hasPrefix "https://" $e)) -}}
{{- fail (printf "\n\nalloy-lerian: `destination.endpoint` is %q, which is not https, but this profile\nSENDS A CREDENTIAL to it.\n\nThe token would cross the network in cleartext, readable by anything on the path.\n\nUse https, or — if the destination genuinely does not authenticate — set\n`destination.credential.enabled: false` so no credential is sent.\n" $e) -}}
{{- end -}}
{{- $e -}}
{{- end -}}

{{- define "alloy-lerian.credentialSecretName" -}}
{{- .Values.destination.credential.secretName | default "alloy-lerian" -}}
{{- end -}}

{{- define "alloy-lerian.credentialSecretKey" -}}
{{- .Values.destination.credential.secretKey | default "telemetry-token" -}}
{{- end -}}

{{/*
Whether the destination requires authentication. Internal platforms do not
validate the credential, so the header is omitted there rather than sent empty.
*/}}
{{- define "alloy-lerian.destinationAuthenticated" -}}
{{- if hasKey .Values.destination.credential "enabled" -}}
{{- .Values.destination.credential.enabled -}}
{{- else -}}
{{- eq (include "alloy-lerian.profile" .) "client" -}}
{{- end -}}
{{- end -}}


{{/*
==============================================================================
IN-TRANSIT DATA INSPECTION — absent from the client surface by construction
==============================================================================
The feature streams RAW pipeline payloads — that is its purpose. Here that
means log bodies and span attributes from a core banking ledger.

The upstream project's only stated mitigation is transport TLS, which protects
the channel and not the access; the agent UI carries no documented
authentication. TLS does not gate who opens the page.

In the client profile the parameter does not exist, so supplying it is a
configuration error rather than an override.
*/}}
{{- define "alloy-lerian.livedebugEnabled" -}}
{{- $profile := include "alloy-lerian.profile" . -}}
{{- $requested := false -}}
{{- if .Values.inspection -}}
{{- $requested = .Values.inspection.enabled | default false -}}
{{- end -}}
{{- if and $requested (eq $profile "client") -}}
{{- fail "\n\nalloy-lerian: `inspection.enabled` does not exist in the client profile.\n\nThe feature streams raw pipeline payloads — log bodies and span attributes\nfrom a core banking ledger — through a UI with no documented authentication.\n\nIt is available only in the own profile, where access control is ours.\n" -}}
{{- end -}}
{{- ternary "true" "false" (and $requested (eq $profile "own")) -}}
{{- end -}}


{{/*
==============================================================================
ROLE GUARDS
==============================================================================
The subchart values cannot reference the release name, so the ConfigMap name is
injected here and the single-replica constraint is enforced rather than merely
defaulted. A default can be overridden silently; this fails the render.
*/}}
{{- define "alloy-lerian.assertSingletonReplicas" -}}
{{- $s := .Values.singleton | default dict -}}
{{- $c := $s.controller | default dict -}}
{{- $r := $c.replicas -}}
{{- if and (ne ($r | toString) "<nil>") (ne ($r | int) 1) -}}
{{- fail (printf "\n\nalloy-lerian: singleton.controller.replicas is %v; it must be 1.\n\nThis role observes cluster-scope state. More than one replica writes the same\nseries from every instance, with no attribute distinguishing the writers —\nthe exact defect this chart exists to fix. Cost would grow with replica count\nwhile information does not.\n" $r) -}}
{{- end -}}
{{- end -}}

{{/*
ConfigMap names are FIXED, not release-derived. Subchart values are static YAML
and cannot reference the release name, so an aliased subchart could not point at
a release-prefixed ConfigMap. Fixed names keep the reference resolvable while
staying namespace-scoped, which is the actual isolation boundary.
*/}}
{{- define "alloy-lerian.nodeConfigMapName" -}}
alloy-lerian-node
{{- end -}}

{{- define "alloy-lerian.singletonConfigMapName" -}}
alloy-lerian-singleton
{{- end -}}


{{/*
==============================================================================
NAMESPACE PERIMETER — derived from the profile
==============================================================================
The client installs this chart, so it should fill in as little as possible.
The perimeter is one of the things that differs between profiles, and the
difference is not a preference:

  client  collect ONLY the namespaces we operate. Everything else in that
          cluster belongs to the client and is none of our business — and it
          would cross the public network for no return.
  own     collect everything except cluster plumbing. The whole cluster is ours.

Overridable, but the default is correct for each profile so the common case
needs no value at all.
*/}}
{{- define "alloy-lerian.namespaceInclude" -}}
{{- $ns := (.Values.collection).namespaces | default dict -}}
{{- if $ns.include -}}
{{- $ns.include -}}
{{- else if eq (include "alloy-lerian.profile" .) "client" -}}
^(midaz|midaz-plugins)$
{{- end -}}
{{- end -}}

{{- define "alloy-lerian.namespaceExclude" -}}
{{- $ns := (.Values.collection).namespaces | default dict -}}
{{- if $ns.exclude -}}
{{- $ns.exclude -}}
{{- else if eq (include "alloy-lerian.profile" .) "own" -}}
^(kube-system|kube-public|kube-node-lease)$
{{- end -}}
{{- end -}}


{{/*
==============================================================================
NODE INFRASTRUCTURE — own profile only, enforced
==============================================================================
Node CPU, memory and filesystem come from the kubelet, which is a different
source from the cluster-object producer. Not collected today in either profile.

The guard exists so that enabling it later cannot silently reach the client
profile: the node belongs to the client, and collecting it asks for data we have
no standing to act on.

Cluster-OBJECT metrics (pod phase, deployment state, autoscaler) are a different
thing and are collected in both profiles — those describe workloads we operate.
*/}}
{{/*
==============================================================================
NODE-EXPORTER TARGET — onde raspar metricas de no
==============================================================================
Mesma logica do clusterObjectTarget: instalar o exportador e raspa-lo sao
decisoes SEPARADAS. Um ambiente que ja rode node-exporter mantem
`node-exporter.enabled: false` e aponta aqui para o existente — foi o caso medido
na benedita, que roda `prometheus-prometheus-node-exporter` ha 40 dias.

Vazio + subchart habilitado => deriva o Service do subchart.
Vazio + subchart desabilitado => nao ha o que raspar, e o chart avisa.
*/}}
{{- define "alloy-lerian.nodeExporterTarget" -}}
{{- $explicito := (.Values.collection).nodeExporterTarget | default "" -}}
{{- if $explicito -}}
{{- $explicito -}}
{{- else -}}
{{- $ne := index .Values "node-exporter" | default dict -}}
{{- if $ne.enabled -}}
{{- printf "%s-prometheus-node-exporter.%s.svc.cluster.local:9100" .Release.Name .Release.Namespace -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Guarda: pedir metricas de no sem ter de onde raspar renderia um singleton que
coleta nada, em silencio.
*/}}
{{- define "alloy-lerian.assertNodeExporterTarget" -}}
{{- if (.Values.collection).nodeInfrastructure -}}
{{- if not (include "alloy-lerian.nodeExporterTarget" .) -}}
{{- fail "\n\nalloy-lerian: `collection.nodeInfrastructure` esta true, mas nao ha de onde raspar\nmetricas de no.\n\nEscolha um dos dois:\n\n  a) instalar o exportador junto com o chart\n\n     node-exporter:\n       enabled: true\n\n  b) apontar para um node-exporter que o ambiente JA roda\n\n     collection:\n       nodeExporterTarget: \"prometheus-prometheus-node-exporter.monitoring.svc.cluster.local:9100\"\n\nSem isto o papel singleton renderizaria sem coletar nada, em silencio.\n" -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "alloy-lerian.assertNodeInfra" -}}
{{- $requested := (.Values.collection).nodeInfrastructure | default false -}}
{{- if and $requested (eq (include "alloy-lerian.profile" .) "client") -}}
{{- fail "\n\nalloy-lerian: `collection.nodeInfrastructure` is not available in the client profile.\n\nNode CPU, memory and filesystem describe the host, which belongs to the client.\nWe have no standing to act on it, and it would cross the public network for no\nreturn.\n\nCluster-object metrics (pod phase, deployment state, autoscaler) are collected\nin both profiles — those describe workloads we operate.\n" -}}
{{- end -}}
{{/* Emits NOTHING. An assertion helper that returns a value gets that value
     written into the manifest by the call site — which produced
     "falseapiVersion: v1" and made every render invalid YAML. */}}
{{- end -}}


{{/*
==============================================================================
CLUSTER-OBJECT PRODUCER — where to scrape it
==============================================================================
Deploying the producer and scraping it are SEPARATE decisions. A cluster that
already runs one (a monitoring stack usually brings its own) should have ours
disabled — running two producers of the same metrics is the duplication this
migration exists to remove — but the scrape must still happen.

Tying the scrape to our subchart being enabled silently removed the collection
along with the workload. Verified.

Default: our own service, when enabled. Override to point at the existing one.
*/}}
{{- define "alloy-lerian.clusterObjectTarget" -}}
{{- $t := (.Values.collection).clusterObjectTarget | default "" -}}
{{- if $t -}}
{{- $t -}}
{{- else if index .Values "kube-state-metrics" "enabled" -}}
{{- printf "%s-kube-state-metrics.%s.svc.cluster.local:8080" .Release.Name .Release.Namespace -}}
{{- end -}}
{{- end -}}
