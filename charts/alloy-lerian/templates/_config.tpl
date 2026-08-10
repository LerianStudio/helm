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
    traces  = [otelcol.processor.batch.agrupamento.input]
  }
}

// STAGE 6 — SANITISATION. Regulated data never leaves the origin cluster
// unmasked. Logs only: this is where free-text bodies carry it.
//
// error_mode is "ignore" so a malformed rule cannot halt the pipeline — which
// is exactly why correctness cannot depend on this mechanism reporting failure.
// The delivery gate asserts each rule against a known input and expected
// output, and blocks release on mismatch.
{{ include "alloy-lerian.config.sanitizacao" . }}

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
  forward_to = [prometheus.remote_write.destino.receiver]
}

prometheus.remote_write "destino" {
  endpoint {
    url = {{ printf "%s/api/v1/push" (trimSuffix "/" (include "alloy-lerian.destinationEndpoint" .)) | quote }}
{{- if $authenticated }}
    headers = {
      "x-api-key" = sys.env("ALLOY_DESTINATION_CREDENTIAL"),
    }
{{- end }}
  }
}
{{ end -}}

// Cluster lifecycle events. Watching all namespaces, so clustering would
// degrade to a single collecting node anyway — the singleton deployment is the
// explicit form of the same guarantee.
loki.source.kubernetes_events "eventos" {
  log_format = "logfmt"
  forward_to = [loki.write.destino.receiver]
}

loki.write "destino" {
  endpoint {
    url = {{ printf "%s/loki/api/v1/push" (trimSuffix "/" (include "alloy-lerian.destinationEndpoint" .)) | quote }}
{{- if $authenticated }}
    headers = {
      "x-api-key" = sys.env("ALLOY_DESTINATION_CREDENTIAL"),
    }
{{- end }}
  }

  external_labels = {
    client_id = {{ $origin | quote }},
  }
}
{{- end -}}
