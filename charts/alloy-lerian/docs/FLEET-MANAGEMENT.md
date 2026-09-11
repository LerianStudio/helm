# Fleet Management — gestão remota de configuração

O chart já nasce com suporte completo e **inativo**, não ausente. A distinção
importa: ligar é mudar uma flag e informar três valores — nenhuma edição de
configuração no cluster do cliente, nenhum upgrade de chart, nenhum passo que exija
o cliente entender o mecanismo.

Ligamos depois de validar a instalação nos nossos ambientes. O caminho de
habilitação é verificado desde já — ver a seção de verificação no fim — justamente
para que "ligar depois" não signifique "descobrir problemas depois".

## Como ligar

```yaml
fleetManagement:
  enabled: true
  url: "https://fleet-management-<stack>.grafana.net"   # copiar VERBATIM da interface
  username: "1563949"                                    # id numérico da stack
  attributes:
    plataforma: kubernetes
```

O cliente executa **um** comando antes do install, com os valores que entregamos
— um Secret, duas chaves:

```bash
# ⚠️ NÃO use `--from-literal` com token: DEMONSTRADO por execução — a credencial
# fica visível em `ps -eo args` enquanto o comando roda, e no histórico do shell
# depois. Qualquer usuário no host consegue ler.
#
# `read -rs` não ecoa e não vai para o histórico; `--from-file` lê de stdin.
read -rs TELEMETRY_TOKEN; echo
read -rs FLEET_TOKEN; echo

kubectl -n monitoring create secret generic alloy-lerian \
  --from-file=telemetry-token=<(printf '%s' "$TELEMETRY_TOKEN") \
  --from-file=fleet-token=<(printf '%s' "$FLEET_TOKEN")

unset TELEMETRY_TOKEN FLEET_TOKEN
```

Exige `bash` ou `zsh` — a substituição de processo `<(...)` não existe em `sh`. Para
uma chave só, `printf '%s' "$TOKEN" | kubectl ... --from-file=chave=/dev/stdin`
funciona em qualquer shell.

É o único passo manual. Todo o resto o chart resolve.

O chart valida quatro coisas ao habilitar, e cada uma recusa o render com mensagem
que nomeia a correção:

| Faltando | Por que é bloqueante |
|---|---|
| `url` vazia | o host varia por stack e região; construir à mão é erro documentado |
| `username` vazio | é o id numérico da stack, visível na interface |
| `ALLOY_FLEET_POD_NAME` ausente | o `remotecfg` lê a variável; sem ela o agente não inicia |
| `ALLOY_FLEET_TOKEN` com `optional: true` | **medido:** o render passava e o agente subia SEM o token — autentica, falha, e nunca recebe configuração, visível só no log do pod |

O último foi encontrado em revisão: declarar a variável não basta, ela precisa ser
obrigatória. Enquanto Fleet está inativo o token permanece opcional, para que
nenhum Secret seja exigido antes da hora.

Há uma quinta guarda, sobre a **outra** credencial: se o perfil autentica no destino,
`ALLOY_DESTINATION_CREDENTIAL` com `optional: true` também recusa o render. O motivo é
o mesmo modo de falha, com consequência pior — o pod subiria com o header vazio, o
ponto de entrada responderia `401`, que é falha **permanente**: o dado é descartado na
hora, sem reenvio, e nada reinicia nem alerta.

### ⚠️ Nos ambientes internos são duas chaves; em `aws-devops`, uma

Isto parece inconsistência e não é. Os ambientes internos `aws-*` entregam telemetria
ao **NLB interno**, sem passar pelo gateway — não há api-key a enviar, então
`destination.credential.enabled: false`, o Secret tem **só** `fleet-token`, e
`ALLOY_DESTINATION_CREDENTIAL` fica `optional: true` legitimamente.

A guarda acima não dispara ali justamente porque o perfil não autentica. Em BYOC, onde
autentica, ela dispara — que é o comportamento pretendido.

Ao comparar um cluster interno com um de cliente, conferir **primeiro** se o destino
autentica; sem isso a diferença de chaves parece um erro de provisionamento.

### Sobre o `username`

**Não é identidade — é o ID numérico da stack, igual para todos os clientes.** Não
serve para diferenciar origem. A credencial que varia é o **token**.

## Não exige o operator

`remotecfg` é bloco de configuração do runtime do agente, não recurso de um
operator. O chart standalone é caminho suportado, e assim o `bind`/`escalate` que
o operator pediria no RBAC **fica fora do cluster**.

Ver `COMPONENTES-EXCLUIDOS.md` para o detalhe do privilégio que evitamos.

## Transporte

**Pull, HTTPS 443 de saída.** O agente pergunta ao serviço se há configuração
nova, no intervalo configurado. **Nada disca para dentro do cluster do cliente** —
é o que torna isso aceitável em rede de terceiro, sem VPN nem link privado.

Versão mínima do agente: v1.7.2. Usamos 1.18.1.

## Sanitização não pode ser desligada remotamente

Configuração local e remota têm **controladores de componente separados**. Da
documentação:

> "Local and remote configurations each have their own component controller, which
> means components loaded by one configuration are isolated from the other."
>
> "Local and remote configurations **cannot be in conflict**."

As regras de sanitização vivem na configuração **local**. Não há caminho pelo qual
uma configuração remota as desative, substitua ou remova. O isolamento é
arquitetural, não convenção.

Corolário: erro na configuração remota **não afeta** a local. Se nunca houver
configuração remota válida, o agente segue operando só com a local.

## ⚠️ O risco real é o oposto do óbvio

Do **mesmo** isolamento decorre o inverso: uma configuração remota também **não
consegue encaminhar para** a nossa sanitização local. Os controladores não se
referenciam.

Consequência: uma pipeline remota que declare o **próprio exportador** teria um
caminho de saída paralelo que **nunca passa pelo mascaramento**.

O perigo não é *"a remota desliga minha regra"*. É *"a remota cria um caminho que
ignora minha regra"*.

**Mitigação é de política, não de configuração:**

| Usar Fleet Management para | Não usar para |
|---|---|
| Coleta e descoberta | Declarar exportadores |
| Ajuste de perímetro e de intervalo | Qualquer caminho de saída próprio |
| Habilitar e desabilitar receptores | Pipeline que envie telemetria direto |

Toda pipeline remota que exporte telemetria deve passar por revisão explícita. A
exportação deve permanecer local.

## Identidade do collector

O identificador é composto da marca de procedência mais o nome do pod, injetado
da metadata do objeto:

```
<origem>-<nome-do-pod>
```

**Por que não o padrão.** Se `id` é omitido, o agente gera um UUID e o persiste no
seu diretório de armazenamento. Em pod efêmero sem volume, isso é perdido a cada
reinício — produzindo identidade nova toda vez e churn no registro da frota.

`constants.hostname` também não serve: num DaemonSet resolveria para o nó, não
para o pod.

## ⚠️ Atributos: use os remotos para segmentação com significado de segurança

Existem três categorias:

| Categoria | Quem define | Pode ser falsificado |
|---|---|---|
| Reservados (`collector.os`, `collector.version`, `collector.ID`) | O serviço injeta | **Não** — a documentação afirma que não podem ser sobrescritos |
| Locais | O agente declara | **Sim** — auto-declarados, sem validação de conteúdo documentada |
| Remotos | Definidos na interface | Não, e **têm precedência** sobre os locais |

**Consequência para modelo multi-cliente:** se a segmentação de pipeline depender
de atributo **local**, um agente mal configurado poderia declarar o atributo de
outro cliente e receber configuração alheia. Para qualquer matching com
significado de segurança, use atributos **remotos**.

## 🔴 RISCO ACEITO: um cliente pode enumerar a frota inteira

**Decisão de 2026-08-10: aceito por ora, com a topologia de stack pendente para
antes do anel de clientes.** Não bloqueia os anéis internos.

### O que exatamente acontece

O token que o agente usa para buscar configuração serve para mais do que isso. As
mesmas credencial e URL respondem a `ListCollectors` e `ListPipelines` — chamadas
de enumeração da stack:

```bash
# ⚠️ O header Content-Type é OBRIGATÓRIO: a API é Connect RPC e responde 415 sem
# ele, porque `curl -d` sozinho envia application/x-www-form-urlencoded.
curl -X POST -H 'Content-Type: application/json' -d '{}' -u "<stack-id>:<token>" \
  https://fleet-management-<stack>.grafana.net/collector.v1.CollectorService/ListCollectors
```

Pipelines ficam em outro serviço, e trocar o par serviço/método dá 404:

```bash
curl -X POST -H 'Content-Type: application/json' -d '{}' -u "<stack-id>:<token>" \
  https://fleet-management-<stack>.grafana.net/pipeline.v1.PipelineService/ListPipelines
```

Para comparar o que está publicado com o repositório, use
`sanitizacao/verificar-fleet.sh` em vez de ler a saída à mão — ele confere as
regras **na ordem** e acusa pipeline com exportador próprio.

E o escopo mínimo de uma access policy é a **stack inteira**: seletores de rótulo,
que seriam o mecanismo de sub-escopo, valem só para métricas e logs — não para
Fleet Management.

**Consequência:** um cliente que leia o Secret do próprio cluster — e ele pode, é
o cluster dele — enumera collectors, atributos e pipelines de **todos os outros
clientes** da mesma stack.

### O que NÃO resolve

| Tentativa | Por que não basta |
|---|---|
| Token por cliente | Melhora revogação e rastreabilidade, mas o alcance de cada token continua sendo a stack |
| `username` distinto | Não é identidade — é o ID da stack, igual para todos |
| Esconder a credencial do cliente | Estruturalmente impossível: o agente precisa lê-la em runtime, e quem tem o namespace lê o Secret |
| RBAC do Fleet Management | Governa a interface, não o token de API. Planos distintos |
| `id` e `attributes` | Auto-declarados e não autenticados. Não são fronteira de tenant |

### O que resolve

**Uma stack por cliente.** É o padrão que a documentação recomenda nomeando o
cenário — revendedores e prestadores de serviço gerenciado com clientes que não
devem acessar dados uns dos outros. Bônus: cada stack tem contabilização própria,
o que dá atribuição de custo por cliente de graça.

Particionamento **dentro** de uma stack não está documentado, e a evidência aponta
para inexistente.

### Por que aceitar por agora

Fleet Management é fase posterior e começa pelos **nossos** ambientes (benedita,
depois AWS), onde não há cliente na stack e o problema não existe.

⚠️ **A decisão de topologia de stack precisa ser tomada ANTES de habilitar Fleet
Management em cluster de cliente.** Não depois.

## O que fica obrigatoriamente local

Configuração remota é **módulo**, não configuração de topo. Estes blocos
permanecem locais:

- `logging`, `tracing`
- `remotecfg` (o próprio bloco)
- parâmetros do servidor HTTP

Somado à política de exportação local, isso define a fronteira do que a gestão
remota alcança.

## Rotação do token

**Decisão: manter variável de ambiente.** É o caminho que a documentação de
onboarding mostra, e mais legível na configuração.

**Custo aceito:** variável de ambiente **não recarrega**. Trocar o token exige
reiniciar os pods — em cluster de cliente, isso é janela negociada.

A alternativa existe e fica registrada: com `password_file` e o Secret montado
como volume, o agente relê o arquivo a cada requisição, permitindo rotação sem
reinício. Se a frequência de rotação passar a doer, é a mudança a fazer.

## Verificação executada

Validado contra o binário v1.18.1, não apenas renderizado:

| Cenário | Resultado |
|---|---|
| Desligado | zero blocos `remotecfg`; config idêntica à anterior |
| Ligado, token falso | `unauthenticated: invalid token` — **o bloco foi parseado e executado** |
| Ligado, endpoint inexistente | falha de DNS, não de parse — confirma que a sintaxe é válida |
| `enabled: true` sem `url` | render falha com mensagem explicando |
| `enabled: true` sem `username` | render falha com mensagem explicando |

O erro de autenticação é a prova positiva: o agente chegou a tentar autenticar,
o que só ocorre se o bloco for sintaticamente válido.
