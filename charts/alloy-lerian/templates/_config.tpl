{{/*
==============================================================================
COLLECTION PIPELINE — rendered, not configured
==============================================================================
The processing chain is NOT part of the values surface. Consumers declare
semantic intent (profile, origin, destination, interval) and this template
derives the wiring.

Why the chain is closed: in this agent components form a graph through
`output` references, not an ordered list. Swapping two stages produces no
error — it produces telemetry without enrichment, silently. Three ordering
constraints in this file were each verified by deliberately breaking them.

Verified empirically against the pinned agent version (see the sanitisation
evidence in the pre-dev artefacts):

  - backreference notation is $1, never $$1. The wrong form emits the literal
    text with no error and output that looks masked
  - replace_pattern is an EDITOR function: its own statement, never nested in
    set(). Nesting fails at load
  - the regex engine has no lookahead or lookbehind. Using either fails at load
*/}}

{{/*
Per-node role: receives application telemetry pushed over the standard
protocol, sanitises it, and forwards it.
*/}}
{{- define "alloy-lerian.config.node" -}}
{{- $origin := include "alloy-lerian.originId" . -}}
{{- $authenticated := eq (include "alloy-lerian.destinationAuthenticated" .) "true" -}}
// Managed by the alloy-lerian chart. Do not edit in place: the chart renders
// this file from semantic parameters, and manual edits are lost on upgrade.

logging {
  level  = {{ .Values.logging.level | default "info" | quote }}
  format = "logfmt"
}
{{ include "alloy-lerian.config.fleet" . }}
{{ if eq (include "alloy-lerian.livedebugEnabled" .) "true" -}}
// Enabled only in the own profile. Streams raw pipeline payloads.
livedebugging {
  enabled = true
}
{{ end -}}

otelcol.receiver.otlp "entrada" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  http {
    endpoint = "0.0.0.0:4318"
{{- if .Values.receiver.preserveLegacyTimeouts }}
    // Restores the pre-v1.18.0 behaviour of no timeout. Set only for an
    // application with long-lived connections that the new defaults cut.
    idle_timeout       = "0s"
    read_header_timeout = "0s"
    write_timeout       = "0s"
{{- end }}
  }

  output {
    metrics = [otelcol.processor.memory_limiter.admissao.input]
    logs    = [otelcol.processor.memory_limiter.admissao.input]
    traces  = [otelcol.processor.memory_limiter.admissao.input]
  }
}

// STAGE 1 — admission control. Must be first: it sheds load before anything
// downstream allocates for it.
otelcol.processor.memory_limiter "admissao" {
  check_interval         = "1s"
  limit_percentage       = 80
  spike_limit_percentage = 20

  output {
    metrics = [otelcol.processor.k8sattributes.contexto.input]
    logs    = [otelcol.processor.k8sattributes.contexto.input]
    traces  = [otelcol.processor.k8sattributes.contexto.input]
  }
}

// STAGE 2 — context enrichment. Must precede batching: the connection-based
// association path reads the peer address, which batching discards. Getting
// this wrong yields telemetry with no pod attribution and NO error.
//
// Two tiers, first match wins. The resource-attribute tier is preferred; the
// connection tier exists because not every application declares k8s.pod.ip.
otelcol.processor.k8sattributes "contexto" {
  pod_association {
    source {
      from = "resource_attribute"
      name = "k8s.pod.ip"
    }
  }
  pod_association {
    source {
      from = "connection"
    }
  }

  extract {
    metadata = [
      "k8s.namespace.name",
      "k8s.pod.name",
      "k8s.deployment.name",
      "k8s.container.name",
    ]
  }

  output {
    metrics = [otelcol.processor.transform.procedencia.input]
    logs    = [otelcol.processor.transform.procedencia.input]
    traces  = [otelcol.processor.transform.procedencia.input]
  }
}

// STAGE 3 — origin marking. Assigned once, at the edge. Reassigning downstream
// would mask the real origin.
//
// Note: this marks provenance, not identity. The credential authenticates the
// sender; the marker is self-declared, so an authenticated origin could claim
// another's identifier. Out of scope by decision, recorded as a known limit.
otelcol.processor.transform "procedencia" {
  error_mode = "ignore"

  trace_statements {
    context    = "resource"
    statements = [`set(attributes["client.id"], {{ $origin | quote }})`]
  }
  metric_statements {
    context    = "resource"
    statements = [`set(attributes["client.id"], {{ $origin | quote }})`]
  }
  log_statements {
    context    = "resource"
    statements = [`set(attributes["client.id"], {{ $origin | quote }})`]
  }

  output {
    metrics = [otelcol.processor.filter.perimetro.input]
    logs    = [otelcol.processor.filter.perimetro.input]
    traces  = [otelcol.processor.filter.perimetro.input]
  }
}

// STAGE 4 — perimeter. Discards what is outside the observed scope, before
// sanitisation: no point sanitising what will be dropped.
otelcol.processor.filter "perimetro" {
  error_mode = "ignore"

{{- $nsInclude := include "alloy-lerian.namespaceInclude" . }}
{{- $nsExclude := include "alloy-lerian.namespaceExclude" . }}
{{- if $nsInclude }}
  metrics {
    datapoint = [
      `resource.attributes["k8s.namespace.name"] == nil or not IsMatch(resource.attributes["k8s.namespace.name"], {{ $nsInclude | quote }})`,
    ]
  }
  logs {
    log_record = [
      `resource.attributes["k8s.namespace.name"] == nil or not IsMatch(resource.attributes["k8s.namespace.name"], {{ $nsInclude | quote }})`,
    ]
  }
  traces {
    span = [
      `resource.attributes["k8s.namespace.name"] == nil or not IsMatch(resource.attributes["k8s.namespace.name"], {{ $nsInclude | quote }})`,
    ]
  }
{{- else if $nsExclude }}
  metrics {
    datapoint = [
      `IsMatch(resource.attributes["k8s.namespace.name"], {{ $nsExclude | quote }})`,
    ]
  }
  logs {
    log_record = [
      `IsMatch(resource.attributes["k8s.namespace.name"], {{ $nsExclude | quote }})`,
    ]
  }
  traces {
    span = [
      `IsMatch(resource.attributes["k8s.namespace.name"], {{ $nsExclude | quote }})`,
    ]
  }
{{- end }}

  output {
    metrics = [otelcol.processor.filter.ruido.input]
    logs    = [otelcol.processor.filter.ruido.input]
    traces  = [otelcol.processor.filter.ruido.input]
  }
}

// STAGE 5 — volume reduction at the edge. Health probe traffic carries no
// diagnostic value and its removal is also what the organisation's SRE
// standard requires of applications.
otelcol.processor.filter "ruido" {
  error_mode = "ignore"

  traces {
    span = [
      `IsMatch(attributes["http.route"], "^/(health|healthz|readyz|ready|livez|live|ping|metrics)$")`,
      `IsMatch(attributes["url.path"], "^/(health|healthz|readyz|ready|livez|live|ping|metrics)$")`,
    ]
  }
{{- if .Values.collection.dropDebugLogs }}
  logs {
    // Severity below INFO. Records with no severity are NOT dropped: absence
    // of the field is not evidence of low value.
    log_record = [
      `severity_number != SEVERITY_NUMBER_UNSPECIFIED and severity_number < SEVERITY_NUMBER_INFO`,
    ]
  }
{{- end }}

  output {
    metrics = [otelcol.processor.batch.agrupamento.input]
    logs    = [otelcol.processor.transform.sanitizacao.input]
{{- if .Values.spanMetrics.enabled }}
    // Traces fan out: the span itself continues to the destination unchanged,
    // AND feeds the RED derivation. The concentrator downstream sees no
    // difference in the trace stream.
    traces  = [
      otelcol.processor.batch.agrupamento.input,
      otelcol.connector.spanmetrics.red.input,
    ]
{{- else }}
    traces  = [otelcol.processor.batch.agrupamento.input]
{{- end }}
  }
}

{{- if .Values.spanMetrics.enabled }}

// RED DERIVATION — request rate, error rate and latency, counted from spans.
//
// POSITION IS A CORRECTNESS PROPERTY, not a preference. This reads the output
// of stage 5, so it counts exactly the spans that survive the perimeter and
// the noise filter. Placed before them it would count spans that the trace
// stream discards, and the metrics would report requests no trace can show —
// a divergence with no error to reveal it.
//
// ⚠️ THAT REASONING INVERTS IF TAIL SAMPLING IS EVER ADDED. Upstream is
// explicit that the connector must run BEFORE a sampling decision, because
// sampled-away spans still happened and the rate must count them. The two
// positions are not in conflict today: our stage 4 and 5 are deliberate
// exclusion (health probes, namespaces outside the perimeter), where the metric
// SHOULD exclude too — not sampling, where it must not. Adding a tail sampler
// downstream means moving this connector ahead of it.
//
// Feeds the batch stage rather than the exporter directly, so the derived
// metrics get the same batching as everything else.
otelcol.connector.spanmetrics "red" {
  histogram {
    explicit {
      buckets = [{{ range $i, $b := .Values.spanMetrics.buckets }}{{ if $i }}, {{ end }}{{ $b | quote }}{{ end }}]
    }
  }

{{- range .Values.spanMetrics.dimensions }}
  dimension {
    name = {{ . | quote }}
  }
{{- end }}

  namespace = {{ .Values.spanMetrics.namespace | quote }}

  // CUMULATIVE is what the destination chain expects. Delta would silently
  // change the meaning of every rate() in the existing dashboards.
  aggregation_temporality = "CUMULATIVE"

  metrics_expiration = {{ .Values.spanMetrics.expiration | quote }}

  // Explicit, because it is the write rate of these series and therefore a
  // cost parameter. The component default is not ours to inherit silently.
  metrics_flush_interval = {{ include "alloy-lerian.spanMetricsFlushInterval" . }}
{{- if gt (int .Values.spanMetrics.cardinalityLimit) 0 }}

  // Runaway guard. Past this many distinct dimension combinations, further ones
  // fold into a single entry labelled otel.metric.overflow="true" — visible at
  // the destination, not discarded in silence. It exists mainly because
  // span_name is an unavoidable dimension and a badly named span in one service
  // is enough to blow up cardinality.
  aggregation_cardinality_limit = {{ int .Values.spanMetrics.cardinalityLimit }}
{{- end }}

  output {
    metrics = [otelcol.processor.batch.agrupamento.input]
  }
}
{{- end }}

// STAGE 6 — SANITISATION. Regulated data never leaves the origin cluster
// unmasked. Logs only: this is where free-text bodies carry it.
//
// error_mode is "ignore" so a malformed rule cannot halt the pipeline — which
// is exactly why correctness cannot depend on this mechanism reporting failure.
// The delivery gate asserts each rule against a known input and expected
// output, and blocks release on mismatch.
{{ include "alloy-lerian.config.sanitizacao" (dict "nome" "sanitizacao" "saida" "otelcol.processor.batch.agrupamento.input") }}

// STAGE 7 — batching. Must be last: enrichment operates on individual records,
// and batching destroys the connection context stage 2 depends on.
otelcol.processor.batch "agrupamento" {
  timeout             = "200ms"
  send_batch_size     = 512
  send_batch_max_size = 1024

  output {
    metrics = [otelcol.exporter.otlphttp.destino.input]
    logs    = [otelcol.exporter.otlphttp.destino.input]
    traces  = [otelcol.exporter.otlphttp.destino.input]
  }
}

// EXIT — to the central concentrator. Queue and retry are mandatory: without
// them any blip in the destination is definitive, unrecorded loss.
//
// Retry classification is by status code and is NOT symmetric: 429/502/503/504
// are retryable, everything else is permanent and discarded immediately. So a
// rejected credential (401/403) causes continuous silent loss, not a growing
// queue — which is why permanent discard is alerted separately.
otelcol.exporter.otlphttp "destino" {
  client {
    endpoint = {{ include "alloy-lerian.destinationEndpoint" . | quote }}
{{- if $authenticated }}
    headers = {
      "x-api-key" = sys.env("ALLOY_DESTINATION_CREDENTIAL"),
    }
{{- end }}
  }

  sending_queue {
    enabled       = true
    queue_size    = {{ .Values.destination.queue.size | default 1000 }}
    num_consumers = {{ .Values.destination.queue.consumers | default 10 }}
    // Not blocking on overflow: back-pressure would propagate to the client's
    // applications, which is not ours to impose.
    block_on_overflow = false
  }

  retry_on_failure {
    enabled          = true
    initial_interval = "5s"
    max_interval     = "30s"
    max_elapsed_time = {{ .Values.destination.retry.maxElapsedTime | default "5m" | quote }}
  }
}
{{- if (.Values.collection).containerUsage }}

// ===========================================================================
// CONTAINER USAGE — observed consumption, from the kubelet's own cAdvisor
// ===========================================================================
// This is REPLACEMENT of collection that already exists, not a new capability.
// The retiring agent reads it through `kubeletstats`, and the `container_*`
// families in the destination today come from there (MEASURED: 68 series in
// aws-devops, 72 in aws-production, 44 in aws-staging). kube-state-metrics does
// NOT cover it: KSM describes an object's DECLARED state — the limit, the desired
// replica count — never the consumption observed against it.
//
// Belongs to the node role, not the singleton: each agent scrapes the kubelet of
// its OWN node. That is why replication is safe here and duplication is not a
// concern — a node's cAdvisor is only ever read by the agent on that node.
//
// RBAC needs nothing added: the upstream chart's ClusterRole already grants
// `nodes/metrics`, verified in the rendered output.
discovery.kubernetes "nos_para_cadvisor" {
  role = "node"
}

// Rewrites each node target into the API-server proxy path. Going through the
// API server rather than the kubelet port directly is deliberate: the kubelet
// port is frequently unreachable from a pod (firewall, read-only port disabled),
// and the proxy path works wherever the API server does.
discovery.relabel "alvo_cadvisor" {
  targets = discovery.kubernetes.nos_para_cadvisor.targets

  rule {
    action = "replace"
    target_label = "__address__"
    replacement  = "kubernetes.default.svc:443"
  }

  rule {
    source_labels = ["__meta_kubernetes_node_name"]
    regex         = "(.+)"
    action        = "replace"
    target_label  = "__metrics_path__"
    replacement   = "/api/v1/nodes/${1}/proxy/metrics/cadvisor"
  }
}

prometheus.scrape "consumo_container" {
{{- if (.Values.collection).containerUsageTarget }}
  // Explicit target: an environment that exposes cAdvisor by another route.
  targets = [{
    __address__ = {{ (.Values.collection).containerUsageTarget | quote }},
  }]
{{- else }}
  targets = discovery.relabel.alvo_cadvisor.output
  scheme  = "https"

  bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"

  tls_config {
    ca_file             = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    insecure_skip_verify = false
  }
{{- end }}

  // Same 60s floor as everything else: cost at the destination is series x
  // writes per minute, and the retiring agent's 10s interval is precisely what
  // this migration exists to correct.
  scrape_interval = {{ include "alloy-lerian.interval" . | quote }}
  forward_to      = [prometheus.relabel.allowlist_consumo.receiver]
}

// ⚠️ ALLOWLIST, not full collection. MEASURED on benedita: the endpoint exposes
// 78 families and 90,948 series; the {{ len ((.Values.collection).containerUsageAllowlist | default list) }} kept here are 4,893 — a 94.6% cut.
//
// The cut is by diagnostic value, not by volume. The expensive families answer
// nothing: container_tasks_state (5,255 series),
// container_blkio_device_usage_total (5,048), container_memory_failures_total
// (4,204). What matters is cheap.
//
// ⚠️ NO `container!=""` FILTER HERE, and that is a measured decision: cAdvisor
// reports filesystem and network at POD level, so container_fs_* and
// container_network_* carry no container name at all. Filtering on a container
// name would silently drop four of the sixteen families.
prometheus.relabel "allowlist_consumo" {
  rule {
    source_labels = ["__name__"]
    regex         = {{ join "|" ((.Values.collection).containerUsageAllowlist | default list) | quote }}
    action        = "keep"
  }

  rule {
    target_label = "client_id"
    replacement  = {{ $origin | quote }}
  }

  forward_to = [otelcol.receiver.prometheus.ponte_consumo.receiver]
}

// Bridge to OTLP: the destination speaks OTLP only, same as every other signal
// on this chain.
otelcol.receiver.prometheus "ponte_consumo" {
  output {
    metrics = [otelcol.exporter.otlphttp.destino.input]
  }
}
{{- end }}
{{- end -}}


{{/*
Single-replica role: observes cluster-scope state.

Exactly one replica. More than one duplicates: the same events are written by
each instance with no attribute distinguishing the writers. The upstream
project's own reference chart keeps a dedicated singleton role for this reason.
*/}}
{{- define "alloy-lerian.config.singleton" -}}
{{- $origin := include "alloy-lerian.originId" . -}}
{{- $authenticated := eq (include "alloy-lerian.destinationAuthenticated" .) "true" -}}
{{- $interval := include "alloy-lerian.interval" . -}}
// Managed by the alloy-lerian chart. Single-replica role: cluster-scope state.

logging {
  level  = {{ .Values.logging.level | default "info" | quote }}
  format = "logfmt"
}
{{ include "alloy-lerian.config.fleet" . }}

{{- $alvoNo := include "alloy-lerian.nodeExporterTarget" . }}
{{ if and (.Values.collection).nodeInfrastructure $alvoNo -}}
// Metricas de NO, raspadas de um node-exporter — o agente nao monta /proc nem
// /sys e nao ganha privilegio nenhum. Mesmo padrao do chart guarda-chuva da
// Grafana, que separa instalar o exportador de coleta-lo.
//
// ALLOWLIST, nao coleta integral. MEDIDO na benedita: 3 nos produzem 612
// familias e 46.575 series — 11% de todas as series daquele cluster, e escala
// com o numero de nos. As 20 familias mais caras somam 25.482 series e a maioria
// nao responde pergunta nenhuma: node_cpu_scaling_governor sao 4.608 series de
// uma CONSTANTE, e node_cooling_device_*, node_softnet_* e node_cpu_frequency_*
// seguem o mesmo padrao.
//
// O criterio das 35 familias mantidas: responder saturacao e falha iminente —
// CPU, memoria, swap, filesystem (bytes E inodes E readonly), disco, rede com
// erros e descartes, carga, pressure stall, e estado de unidade systemd.
//
// Resultado medido: 46.575 -> 7.620 series (-83,6%).
prometheus.scrape "metricas_de_no" {
  targets = [{
    __address__ = {{ $alvoNo | quote }},
  }]
  scrape_interval = {{ $interval | quote }}
  forward_to      = [prometheus.relabel.allowlist_no.receiver]
}

// A allowlist. `keep` sobre __name__ descarta tudo que nao esta na lista, ANTES
// de sair do cluster — o corte na borda economiza CPU aqui, banda na rede e
// processamento no destino.
prometheus.relabel "allowlist_no" {
  rule {
    source_labels = ["__name__"]
    regex = "node_(cpu_seconds_total|memory_(MemTotal|MemAvailable|Cached|Buffers|SwapTotal|SwapFree)_bytes|filesystem_(size|avail)_bytes|filesystem_files(_free)?|filesystem_readonly|disk_(read|written)_bytes_total|disk_io_time(_weighted)?_seconds_total|network_(receive|transmit)_(bytes|errs|drop)_total|load(1|5|15)|uname_info|boot_time_seconds|time_seconds|context_switches_total|intr_total|vmstat_pgmajfault|pressure_(cpu|memory|io)_waiting_seconds_total|systemd_unit_state)"
    action = "keep"
  }

  // Dos 8 modos de CPU, 5 respondem alguma pergunta: idle (para calcular uso),
  // iowait (espera de disco), system e user (onde o tempo vai), steal
  // (contencao do hipervisor). irq, softirq e nice sao 2.304 series medidas que
  // ninguem consulta.
  rule {
    source_labels = ["__name__", "mode"]
    separator     = ";"
    regex         = "node_cpu_seconds_total;(irq|softirq|nice)"
    action        = "drop"
  }

  rule {
    target_label = "client_id"
    replacement  = {{ $origin | quote }}
  }

  forward_to = [otelcol.receiver.prometheus.ponte_metricas.receiver]
}
{{ end -}}

{{- $alvoObjetos := include "alloy-lerian.clusterObjectTarget" . }}
{{ if $alvoObjetos -}}
// Cluster-object metrics, scraped from the dedicated producer. Single writer by
// construction: the producer runs one replica, so this scrape cannot duplicate
// regardless of how many agents exist.
//
// Interval is enforced at or above the 60s floor. Collecting faster than anyone
// queries wastes CPU here, bandwidth on the wire and processing at the
// destination — and the cost at the destination is series x writes per minute.
prometheus.scrape "objetos_de_cluster" {
  targets = [{
    __address__ = {{ $alvoObjetos | quote }},
  }]
  scrape_interval = {{ $interval | quote }}
  forward_to      = [prometheus.relabel.procedencia.receiver]
}

// Origin marking for the scraped series.
prometheus.relabel "procedencia" {
  rule {
    target_label = "client_id"
    replacement  = {{ $origin | quote }}
  }
  forward_to = [otelcol.receiver.prometheus.ponte_metricas.receiver]
}

// Bridge into OTLP. See the note on the exporter below for why this role does
// not speak the native protocols.
otelcol.receiver.prometheus "ponte_metricas" {
  output {
    metrics = [otelcol.exporter.otlphttp.destino.input]
  }
}
{{ end -}}

// Cluster lifecycle events. Watching all namespaces, so clustering would
// degrade to a single collecting node anyway — the singleton deployment is the
// explicit form of the same guarantee.
loki.source.kubernetes_events "eventos" {
  log_format = "logfmt"
  forward_to = [otelcol.receiver.loki.ponte_eventos.receiver]
}

otelcol.receiver.loki "ponte_eventos" {
  output {
    logs = [otelcol.processor.memory_limiter.admissao_eventos.input]
  }
}

// ADMISSION CONTROL — first in the event chain, for the same reason it is first
// in the node chain: it sheds load before anything downstream allocates for it.
//
// This role needed it MORE than the node role, not less. Measured on benedita:
// loki.source.kubernetes_events replays the cluster's whole event history the
// moment it starts, and that burst already overran the exporter queue once. A
// deeper `queue_size` bounds the EXPORTER, not the process — a large enough
// history is absorbed in memory until the OOM killer decides for us.
otelcol.processor.memory_limiter "admissao_eventos" {
  check_interval         = "1s"
  limit_percentage       = 80
  spike_limit_percentage = 20

  output {
    logs = [otelcol.processor.transform.procedencia_eventos.input]
  }
}

// PERIMETER for events. Cluster events come from EVERY namespace, including the
// ones the client profile is meant to exclude — the source watches the whole
// cluster and takes no namespace argument. Without this, the perimeter that the
// node role enforces would simply not apply to this signal.
//
// Reads the same k8s.namespace.name the node role filters on. The Loki bridge
// promotes the source's labels to attributes, so the attribute is present on the
// LOG RECORD here rather than on the resource.
otelcol.processor.filter "perimetro_eventos" {
  error_mode = "ignore"

{{- $nsIncludeEv := include "alloy-lerian.namespaceInclude" . }}
{{- $nsExcludeEv := include "alloy-lerian.namespaceExclude" . }}
{{- if $nsIncludeEv }}
  logs {
    log_record = [
      `attributes["namespace"] == nil or not IsMatch(attributes["namespace"], {{ $nsIncludeEv | quote }})`,
    ]
  }
{{- else if $nsExcludeEv }}
  logs {
    log_record = [
      `IsMatch(attributes["namespace"], {{ $nsExcludeEv | quote }})`,
    ]
  }
{{- end }}

  output {
    logs = [otelcol.processor.transform.sanitizacao_eventos.input]
  }
}

// SANITISATION for events. Event messages are free text written by controllers,
// and they quote application payloads — a failed job's message can carry whatever
// the application put in it. The SAME rule set as the node role, rendered from
// one source: duplicating the rules would create two sets that can drift, and a
// drifted copy is worse than no copy because it still looks protected.
{{ include "alloy-lerian.config.sanitizacao" (dict "nome" "sanitizacao_eventos" "saida" "otelcol.exporter.otlphttp.destino.input") }}

// Events do not pass through the node role, so they need their own origin mark.
otelcol.processor.transform "procedencia_eventos" {
  error_mode = "ignore"
  log_statements {
    context = "resource"
    statements = [
      `set(attributes["client.id"], {{ $origin | quote }})`,
    ]
  }
  output {
    logs = [otelcol.processor.filter.perimetro_eventos.input]
  }
}

// ⚠️ OTLP, NOT prometheus.remote_write and loki.write.
//
// The destination in this architecture is an OTLP COLLECTOR, not a storage
// backend. Measured on the real destination: its receivers are otlp, jaeger and
// a self-scrape — there is no prometheusremotewrite receiver and no Loki push
// endpoint. Exporting natively would POST to /api/v1/push and /loki/api/v1/push
// on a collector that serves neither path.
//
// The failure mode is what makes this worth a comment: cluster-object metrics
// and Kubernetes events would simply never arrive, while the agent stayed
// healthy and the node role kept delivering normally. Nothing would look broken.
//
// OTLP is also the contract every other hop already speaks, so the concentrator
// treats this role exactly like any other producer.
otelcol.exporter.otlphttp "destino" {
  client {
    endpoint = {{ include "alloy-lerian.destinationEndpoint" . | quote }}
{{- if $authenticated }}
    headers = {
      "x-api-key" = sys.env("ALLOY_DESTINATION_CREDENTIAL"),
    }
{{- end }}
  }

  // MEASURED on benedita: without this block the exporter used its implicit
  // default and lost 256 event records at startup —
  // `enqueue_failed_log_records_total = 256`, "sending queue is full", zero HTTP
  // errors at any point. The destination never refused; the local queue filled.
  //
  // The cause is specific to this role: loki.source.kubernetes_events replays the
  // cluster's existing event history the moment it starts, so the first seconds
  // carry a burst that steady-state sizing does not cover. The node role never
  // sees this — applications push at their own pace.
  //
  // Deeper queue than the node role for that reason. Still bounded: a burst that
  // outlasts the queue should drop rather than grow without limit.
  sending_queue {
    enabled       = true
    queue_size    = {{ .Values.destination.queue.singletonSize | default 5000 }}
    num_consumers = {{ .Values.destination.queue.consumers | default 10 }}
    // Same reasoning as the node role: back-pressure is not ours to impose.
    block_on_overflow = false
  }

  // The node role had retry and this one did not — an inconsistency, not a
  // decision. A transient failure at the destination would discard cluster-object
  // metrics outright while application telemetry survived the same outage.
  retry_on_failure {
    enabled          = true
    initial_interval = "5s"
    max_interval     = "30s"
    max_elapsed_time = {{ .Values.destination.retry.maxElapsedTime | default "5m" | quote }}
  }
}
{{- end -}}
