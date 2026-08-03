{{/*
==============================================================================
lerian-common — in-cluster host derivation primitives.

The `name` and `namespace` are ALWAYS computed by the caller (via
`common.names.dependency.fullname`, `.Release.Name`-prefixing, `global.namespace`,
`.Release.Namespace`, or a literal) and passed in as strings. The library only
assembles the FQDN suffix, so the rendered output stays byte-identical to the
hand-written printf it replaces.

The four axes of variation observed across the charts are explicit flags:
  dot    (bool)   -> trailing "." after svc.cluster.local  (the ad-hoc-est knob)
  port   (number) -> ":<port>" suffix
  scheme (string) -> "<scheme>://" prefix (internalURL only)
  path   (string) -> trailing path (internalURL only)
==============================================================================
*/}}

{{/*
lerian-common.internalHost -> <name>.<namespace>.svc.cluster.local[.][:port]
Inputs: name (req), namespace (req), dot (opt bool), port (opt).
*/}}
{{- define "lerian-common.internalHost" -}}
{{- $h := printf "%s.%s.svc.cluster.local" .name .namespace -}}
{{- if .dot }}{{- $h = printf "%s." $h -}}{{- end -}}
{{- if .port }}{{- $h = printf "%s:%v" $h .port -}}{{- end -}}
{{- $h -}}
{{- end -}}

{{/*
lerian-common.internalURL -> <scheme>://<internalHost><path>
Inputs: scheme (req), name (req), namespace (req), dot/port (opt), path (opt).
*/}}
{{- define "lerian-common.internalURL" -}}
{{- printf "%s://%s%s" .scheme (include "lerian-common.internalHost" .) (default "" .path) -}}
{{- end -}}
