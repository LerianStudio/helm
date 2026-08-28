{{/*
==============================================================================
FLEET MANAGEMENT — remote configuration, off by default
==============================================================================
Renders the `remotecfg` block so enabling remote management is a flag, not a
config edit in the client cluster.

Facts this implementation is built on, each verified in the upstream docs:

  - it does NOT require the agent operator. `remotecfg` is a config block of the
    agent runtime, so the standalone chart is a supported path and we keep the
    operator's `bind`/`escalate` RBAC out of the cluster

  - transport is PULL, outbound HTTPS 443 only. Nothing dials into the client
    cluster, which is what makes it acceptable in a third-party network

  - local and remote configurations have SEPARATE component controllers:
    "Local and remote configurations cannot be in conflict." A remote pipeline
    cannot disable, replace or reference anything in the local config

  - therefore the sanitisation rules, which live in the local config, cannot be
    turned off remotely. That isolation is architectural, not a convention

⚠️ THE REAL RISK IS THE OPPOSITE OF THE OBVIOUS ONE.
Because the controllers are isolated, a remote pipeline cannot forward INTO our
local sanitisation either. A remote pipeline that declares its own exporter
would have a parallel egress path that never passes through masking.

So the hazard is not "remote turns my rule off" — it is "remote creates a path
that bypasses my rule". Mitigated by policy, not by config: use Fleet Management
for collection and discovery, and keep EXPORT local. See docs/FLEET-MANAGEMENT.md.

⚠️ Global blocks (logging, tracing, remotecfg itself, HTTP server) must stay
local — remote content is a module, not top-level config.
*/}}

{{- define "alloy-lerian.fleetEnabled" -}}
{{- $f := .Values.fleetManagement | default dict -}}
{{- ternary "true" "false" ($f.enabled | default false) -}}
{{- end -}}

{{/*
Renders the remotecfg block. Emits nothing when disabled, so the rendered config
is byte-identical to today's until someone opts in.
*/}}
{{- define "alloy-lerian.config.fleet" -}}
{{- $ctx := .ctx | default . -}}
{{- $papel := .papel | default "node" -}}
{{- if eq (include "alloy-lerian.fleetEnabled" $ctx) "true" -}}
{{- $f := $ctx.Values.fleetManagement -}}
{{- if not $f.url -}}
{{- fail "\n\nalloy-lerian: fleetManagement.enabled is true but `fleetManagement.url` is empty.\n\nCopy the endpoint verbatim from the Fleet Management UI — the host format varies\nby stack and region, and building it by hand is a documented mistake.\n" -}}
{{- end -}}
{{/*
The token travels to this URL in basic_auth, so plaintext here is the same defect
the destination guard covers — and the same reasoning applies: it is the CREDENTIAL
crossing the network in the clear that matters. Unlike the destination, there is no
legitimate plain-http case: Fleet Management is a hosted service reached over the
public internet, and its URL is copied verbatim from the UI, which gives https.
*/}}
{{- if not (hasPrefix "https://" $f.url) -}}
{{- fail (printf "\n\nalloy-lerian: `fleetManagement.url` e %q, que nao e https.\n\nO token de configuracao remota viaja para esta URL em basic_auth — em texto claro,\nlegivel por qualquer coisa no caminho.\n\nCopie o endpoint VERBATIM da interface do Fleet Management: ela entrega https, e\nconstruir o host a mao e erro documentado (o formato varia por stack e regiao).\n" $f.url) -}}
{{- end -}}
{{- if not $f.username -}}
{{- fail "\n\nalloy-lerian: fleetManagement.enabled is true but `fleetManagement.username` is empty.\n\nIt is the numeric stack id shown in the Fleet Management UI.\n" -}}
{{- end -}}

// Remote configuration. Pull-based: this agent asks the service whether there is
// new configuration, on the interval below. Nothing connects inbound.
remotecfg {
  url = {{ $f.url | quote }}

  // Origin plus pod name: stable for the pod's lifetime and unique across the
  // DaemonSet. Composed here rather than read from one variable, because the
  // origin is known at render time and only the pod name needs the environment.
  //
  // NOT constants.hostname (resolves to the node in a DaemonSet) and NOT the
  // auto-generated seed: the seed is persisted to the agent's storage path,
  // which an ephemeral pod loses on every restart — producing a new collector
  // identity each time and churn in the fleet registry.
  id = {{ printf "%s-" (include "alloy-lerian.originId" $ctx) | quote }} + sys.env("ALLOY_FLEET_POD_NAME")

  // ⚠️ ATRIBUTOS SÃO O QUE FAZ O FLEET FUNCIONAR. Os pipelines são entregues por
  // MATCHER sobre eles, e um conjunto VAZIO não casa com matcher nenhum: o coletor
  // registra e nunca recebe configuração.
  //
  // O modo de falha é silencioso — pod Running, log mostrando registro bem-sucedido,
  // e nada chegando. Por isso os TRÊS abaixo são DERIVADOS, não digitados no
  // values de cada ambiente.
  //
  // `platform`: os 5 pipelines que a Grafana gera por padrão casam por
  // `platform="kubernetes"` — VERIFICADO na Pipeline API desta stack. É invariante
  // deste chart (só roda em Kubernetes), então não há o que configurar.
  //
  // ⚠️ `collector.os` NÃO PODE SER DECLARADO AQUI, e a lição custou um
  // CrashLoopBackOff em devops (2026-08-27).
  //
  // ⚠️ E NENHUMA VALIDAÇÃO ESTÁTICA PEGA ISSO. Medido com a versão exata do agente
  // (v1.18.1), na config que quebrou: `alloy fmt` exit 0, `alloy validate` exit 0 —
  // no pod E em Docker, inclusive num trecho isolado só com o remotecfg. O erro é de
  // decodificação de SERVIÇO, e só aparece quando o agente carrega no `run`.
  //
  // Consequência para quem editar este bloco: mudança em `remotecfg` exige subir num
  // anel de menor risco e olhar o pod. Não há atalho por ferramenta.
  //
  // O agente recusa a config inteira:
  //
  //   Failed to evaluate service: decoding configuration:
  //   "collector" is a reserved namespace for remotecfg attribute keys
  //
  // O prefixo `collector.` é reservado e preenchido pelo PRÓPRIO agente — é dele
  // que vêm `collector.os` e `collector.ID`. Os matchers dos pipelines usam
  // `collector.os="linux"`, o que me levou a supor que era nossa responsabilidade
  // declarar. Não é: quem casa o matcher é o valor que o agente injeta.
  attributes = {
    "platform"     = "kubernetes",
    // Permite pipeline POR CLIENTE: um matcher `client_id="acme-prd"` entrega
    // configuração só àquele cluster. Mesmo valor que marca as séries, então o
    // que se vê no painel é o que se endereça no Fleet.
    "client_id"    = {{ include "alloy-lerian.originId" $ctx | quote }},
    // Permite pipeline POR PAPEL. O papel node e o singleton coletam coisas
    // diferentes; sem isto um pipeline cairia nos dois, e o de escopo de cluster
    // replicado no DaemonSet é exatamente a duplicação que esta migração corrigiu.
    "role"         = {{ $papel | quote }},
{{- range $k, $v := ($f.attributes | default dict) }}
    {{ $k | quote }} = {{ $v | quote }},
{{- end }}
  }

  poll_frequency = {{ $f.pollFrequency | default "1m" | quote }}

  basic_auth {
    username = {{ $f.username | quote }}
    password = sys.env("ALLOY_FLEET_TOKEN")
  }
}
{{- end -}}
{{- end -}}

{{/*
==============================================================================
GUARD — the fleet block needs environment the subchart values must carry
==============================================================================
The `remotecfg` block reads ALLOY_FLEET_POD_NAME and ALLOY_FLEET_TOKEN from
the environment. Those entries live in the subchart's `extraEnv`, which is static
YAML — a parent template cannot inject a fieldRef into it.

So the chart cannot wire them automatically. It CAN refuse to render a
configuration that would fail at startup, which is what this guard does: without
it, enabling fleet management would produce an agent that cannot authenticate and
never receives configuration, and the failure would only appear in the pod log.

Verified: the helper that used to render these entries was never invoked, so the
environment never reached the container. This guard is what makes that class of
mistake impossible rather than merely unlikely.
*/}}
{{- define "alloy-lerian.assertFleetEnv" -}}
{{- if eq (include "alloy-lerian.fleetEnabled" .) "true" -}}
{{- range $papel := list "node" "singleton" -}}
{{- $cfg := index $.Values $papel -}}
{{- if $cfg -}}
{{- if $cfg.enabled -}}
{{- $env := ($cfg.alloy).extraEnv | default list -}}
{{- $nomes := list -}}
{{- range $e := $env -}}{{- $nomes = append $nomes $e.name -}}{{- end -}}
{{- if not (has "ALLOY_FLEET_POD_NAME" $nomes) -}}
{{- fail (printf "\n\nalloy-lerian: fleetManagement está habilitado, mas `%s.alloy.extraEnv` não\ndeclara ALLOY_FLEET_POD_NAME.\n\nO bloco remotecfg lê essa variável. Sem ela o agente não inicia, e a falha só\napareceria no log do pod.\n\nAcrescente ao values do papel %s:\n\n  %s:\n    alloy:\n      extraEnv:\n        - name: ALLOY_FLEET_POD_NAME\n          valueFrom:\n            fieldRef:\n              fieldPath: metadata.name\n        - name: ALLOY_FLEET_TOKEN\n          valueFrom:\n            secretKeyRef:\n              name: alloy-lerian\n              key: fleet-token\n" $papel $papel $papel (include "alloy-lerian.originId" $)) -}}
{{- end -}}
{{/*
Declaring the token is not enough: it must be REQUIRED.
MEASURED — with fleet enabled and the entry `optional: true`, the render passes and
`remotecfg.basic_auth.password` resolves from a variable that may not exist. The
agent then starts, authenticates, fails, and never receives configuration — visible
only in the pod log. Same class of defect as the destination credential, in the
opposite direction.
*/}}
{{- range $e2 := $env -}}
{{- if eq $e2.name "ALLOY_FLEET_TOKEN" -}}
{{- $ref2 := ($e2.valueFrom).secretKeyRef -}}
{{- if $ref2 -}}
{{- if $ref2.optional -}}
{{- fail (printf "\n\nalloy-lerian: fleetManagement esta habilitado, mas `%s.alloy.extraEnv` marca\nALLOY_FLEET_TOKEN como `optional: true`.\n\nO agente subiria SEM o token: remotecfg autentica, falha, e nunca recebe\nconfiguracao — e isso aparece SO no log do pod. Nenhum pod reinicia, nenhum\nalerta dispara, a gestao remota simplesmente nao funciona.\n\nCorrija no values deste ambiente:\n\n  %s:\n    alloy:\n      extraEnv:\n        - name: ALLOY_FLEET_TOKEN\n          valueFrom:\n            secretKeyRef:\n              name: %s\n              key: fleet-token\n              optional: false\n\nE garanta que a chave `fleet-token` exista no Secret %q ANTES de habilitar.\n" $papel $papel $ref2.name $ref2.name) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not (has "ALLOY_FLEET_TOKEN" $nomes) -}}
{{- fail (printf "\n\nalloy-lerian: fleetManagement está habilitado, mas `%s.alloy.extraEnv` não\ndeclara ALLOY_FLEET_TOKEN.\n\nSem o token o agente autentica e falha, e nunca recebe configuração.\n" $papel) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
==============================================================================
GUARD — in the client profile the credential must be REQUIRED
==============================================================================
The subchart values ship `optional: true`, and the requirement lives HERE rather
than there, because the decision belongs to the PROFILE and static YAML cannot
ask which profile is active.

Why this direction and not the other. The first version defaulted to
`optional: false` and made this guard reject own environments. MEASURED on
benedita: every own environment then failed with CreateContainerConfigError,
"secret alloy-lerian not found", over a variable the rendered config never even
references — and the only fix was to repeat ~20 lines of extraEnv to undo the
default. A default the simplest case has to override is the wrong default.

Inverted, both cases are served: own environments install with no Secret and no
overrides, and the client profile — where 401 is a PERMANENT failure and a pod
that starts without a credential loses data silently and continuously — is held
to the strict requirement by this guard.
*/}}
{{- define "alloy-lerian.assertCredentialEnv" -}}
{{- if eq (include "alloy-lerian.destinationAuthenticated" .) "true" -}}
{{- range $papel := list "node" "singleton" -}}
{{- $cfg := index $.Values $papel -}}
{{- if $cfg -}}
{{- if $cfg.enabled -}}
{{- range $e := (($cfg.alloy).extraEnv | default list) -}}
{{- if eq $e.name "ALLOY_DESTINATION_CREDENTIAL" -}}
{{- $ref := ($e.valueFrom).secretKeyRef -}}
{{- if $ref -}}
{{- if $ref.optional -}}
{{- fail (printf "\n\nalloy-lerian: este destino AUTENTICA (perfil %q), mas `%s.alloy.extraEnv`\nmarca ALLOY_DESTINATION_CREDENTIAL como `optional: true`.\n\nO pod subiria SEM a credencial. O ponto de entrada responderia 401, que e falha\nPERMANENTE: o dado e descartado na hora, sem reenvio. A perda seria silenciosa e\ncontinua — nenhum pod reiniciando, nenhum alerta, so telemetria que nunca chega.\n\nFalhar a criacao do pod e ruidoso e recuperavel. E o modo de falha que queremos.\n\nCorrija no values deste ambiente:\n\n  %s:\n    alloy:\n      extraEnv:\n        - name: ALLOY_DESTINATION_CREDENTIAL\n          valueFrom:\n            secretKeyRef:\n              name: %s\n              key: telemetry-token\n              optional: false\n\nE garanta que o Secret %q exista no namespace ANTES do install.\n" (include "alloy-lerian.profile" $) $papel $papel $ref.name $ref.name) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
