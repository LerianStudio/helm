# DR — restaurar a coleta quando o Fleet falha

Procedimento para quando a configuração vem do Fleet Management e essa via **para de
entregar**.

## O que está em jogo

Com `fleetManagement.enabled: true` (o padrão), a configuração de coleta **inteira**
vem do Fleet — receptor, sanitização, allowlists, perímetro e destino. O ConfigMap
local existe mas não é usado.

⚠️ **Isso significa que os três sinais dependem da mesma origem.** Se a configuração
sumir, não se perde só o log: param métricas e traces também.

## Quando acionar

| situação | ação |
|---|---|
| Fleet fora, agente **rodando** | nada — ele segue com a última configuração |
| Fleet fora **e um pod reinicia** | ⚠️ **acione o DR** — esse pod não sobe |
| configuração perdida ou corrompida no Fleet | republique; se não resolver, DR |

⚠️ A janela de risco não é o tempo de queda — é o **reinício de pod durante** a queda.
Medido: com o Fleet inalcançável ou respondendo 401, um agente que reinicia **não
sobe** (`could not perform the initial load successfully`). E pod reinicia por rollout
de nó, OOM, drain e upgrade de cluster.

## O procedimento

```yaml
fleetManagement:
  enabled: false
```

E `helm upgrade`. O chart passa a renderizar a configuração completa no ConfigMap
local, e o agente sobe sem depender do Fleet.

Quando o Fleet voltar: `true` e upgrade de novo.

⚠️ **O ConfigMap local só serve como DR se estiver atualizado.** Quem garante isso é
`sanitizacao/verificar-fleet.sh`, passo 5: ele compara a configuração publicada no
Fleet com o render do chart. Iguais, o DR está em dia. **Rode-o depois de cada
publicação** — o publicador já o chama automaticamente.

## ⚠️ Em BYOC, o DR depende do cliente

Se não tivermos acesso ao cluster, **alguém do lado do cliente precisa executar o
upgrade**. Não há saída técnica pelo nosso lado.

Isso deve ser comunicado antes, não durante o incidente: o cliente precisa saber que
existe um procedimento e quem executá-lo.

## O que faz a via do Fleet parar

Todos com o **mesmo sintoma**: a telemetria desaparece. Os pods seguem `Running`.

| causa | detalhe |
|---|---|
| pipeline **deletado** na console | agente sobe sem configuração |
| pipeline **desmarcado como ativo** | idem — e ⚠️ **pior**, ver abaixo |
| **cache preso a um módulo antigo** | ⚠️ o mais insidioso, ver abaixo |
| matcher errado ao publicar | a configuração não chega àquele coletor |
| token revogado | poll falha; se o pod reiniciar, não sobe |
| Fleet fora do ar | idem |

### Pipeline desmarcado como ativo é pior que deletado

Para o agente, inativo e inexistente são a **mesma coisa**. A diferença é para quem
investiga: deletado desaparece da lista; **inativo continua visível na console, com a
configuração correta**, e quem abrir para conferir conclui que está funcionando.

Por isso `verificar-fleet.sh` lista os desabilitados em vez de ignorá-los.

### ⚠️ Cache preso — a falha que exige reinício

MEDIDO em aws-devops (2026-08-31): um módulo publicado, depois **deletado** do Fleet,
permaneceu no cache do agente e **impediu qualquer configuração nova de carregar**:

    level=error msg="failed to parse and load configuration" service=remotecfg
    err="a loader exists already for remotecfg/<modulo>.default"

O agente seguia funcionando com a configuração anterior. **Nenhum erro visível fora do
log do agente** — a via do Fleet estava travada e nada apontava isso.

**Só o reinício do pod resolve**: o cache é em memória.

    kubectl rollout restart daemonset/alloy-lerian-node -n monitoring

⚠️ **Em BYOC isso também depende do cliente.** E é a razão mais provável de precisar
acionar alguém do outro lado.

### Sobre o token — correção de um erro comum

O token do Fleet é um Access Policy token da Grafana Cloud (`glc_`). **Não expira por
tempo** — os metadados que ele carrega são org, nome e região, sem campo de validade.

O modo de falha é **revogação**, manual ou por engano numa limpeza. Tratar como "vai
expirar sozinho" leva a diagnosticar a coisa errada.

## O que se perde durante a indisponibilidade

Depende de onde a coleta para:

| ponto de falha | efeito |
|---|---|
| agente rodando, Fleet fora | **nada** — segue com a última configuração |
| pod reinicia sem Fleet | tudo daquele nó, até o DR |
| configuração sem receptor | a ingestão é recusada; o SDK da aplicação retém conforme sua política |
| fila cheia | ⚠️ **descarte silencioso** — a aplicação recebe `200` |

⚠️ O último é o mais perigoso e é deliberado: `blockOnOverflow: false`, porque
contrapressão travaria a aplicação do cliente. O alerta `O11Y-FILA-001` existe para
que esse descarte não passe despercebido. Ver `docs/DIMENSIONAMENTO-FILA.md`.

## Detecção

Quatro alertas na Grafana Cloud, pasta `OBSERVABILITY`:

| alerta | detecta |
|---|---|
| `O11Y-LOG-001` | log de aplicação ausente |
| `O11Y-METRICA-001` | métrica ausente |
| `O11Y-TRACE-001` | trace ausente |
| `O11Y-FILA-001` | fila do exportador enchendo |

⚠️ **Todos PAUSADOS** até 100% de produção estar na versão nova. Enquanto isso, a
detecção é manual.

⚠️ E os três de ausência **disparam juntos** quando a configuração some — é o sinal de
que o problema não é de um sinal específico, e sim da via de configuração.

## Voltando para o Fleet, depois

1. confirme que a configuração está publicada: `sanitizacao/verificar-fleet.sh` com
   `CLIENT_ID` definido
2. `fleetManagement.enabled: true` e `helm upgrade`
3. confirme que a coleta voltou — os três sinais, não só o log

⚠️ Se o agente não pegar a configuração após alguns minutos, verifique o log por
`loader exists already`: pode ser o cache preso, e aí é reinício de pod.
