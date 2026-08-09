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
*/}}
{{- define "alloy-lerian.originId" -}}
{{- $id := .Values.origin.id | default "" -}}
{{- if not $id -}}
{{- fail "\n\nalloy-lerian: `origin.id` is required and has no default.\n\nIt marks every record with the environment it came from. Without it,\ntelemetry reaches the destination unattributable.\n\n  origin:\n    id: acme-prd\n\nForm: lowercase segments separated by hyphens, ending in a stage segment\n      (stg | hml | prd), or one of the reserved own-environment names.\n" -}}
{{- end -}}
{{- $reserved := list "aws-production" "aws-staging" "aws-devops" "benedita" "anacleto" -}}
{{- if not (has $id $reserved) -}}
{{- if not (regexMatch "^[a-z0-9]+(-[a-z0-9]+)*-(stg|hml|prd)$" $id) -}}
{{- fail (printf "\n\nalloy-lerian: origin.id %q is malformed.\n\nExpected lowercase segments separated by hyphens, ending in stg, hml or prd\n(for example: acme-prd, lazari-sandbox-prd), or a reserved own-environment\nname: %s\n" $id (join ", " $reserved)) -}}
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
{{- $e -}}
{{- end -}}

{{- define "alloy-lerian.credentialSecretName" -}}
{{- .Values.destination.credential.secretName | default "alloy-api-key" -}}
{{- end -}}

{{- define "alloy-lerian.credentialSecretKey" -}}
{{- .Values.destination.credential.secretKey | default "api-key" -}}
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
