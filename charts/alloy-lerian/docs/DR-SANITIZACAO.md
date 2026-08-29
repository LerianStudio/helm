# DR — restaurar a sanitização local

Procedimento para quando a sanitização de log de aplicação foi cedida a uma pipeline
do Fleet Management e essa via **para de entregar**.

## Quando acionar

| duração da indisponibilidade | ação |
|---|---|
| até ~30 min | nada. O agente que já está rodando sobrevive com a última config; o poll falha sem derrubar |
| acima de ~2h | **acione este procedimento** |

⚠️ A janela de exposição real não é o tempo de queda — é o **reinício de pod** durante
a queda. Medido: com o Fleet inalcançável ou respondendo 401, um agente que reinicia
**não sobe** (`could not perform the initial load successfully`). E pod reinicia por
rollout de nó, OOM, drain e upgrade de cluster.

## O que faz a via do Fleet parar

Todos estes têm o **mesmo sintoma**: o log de aplicação desaparece. Os pods seguem
`Running`, métricas e traces continuam chegando. Log ausente parece com "cliente sem
movimento", e é por isso que a detecção não pode depender de alguém notar.

| causa | como se manifesta |
|---|---|
| pipeline deletado na console | agente sobe sem pipeline, sem erro |
| **matcher deixa de casar** | idem — ver abaixo |
| token revogado | poll falha; se o pod reiniciar, o agente não sobe |
| Fleet fora do ar | idem |
| pod reinicia com o Fleet fora | ⚠️ **o agente inteiro não sobe** — ver abaixo |

### Matcher deixa de casar

O chart declara **três** atributos, derivados (ver `_fleet.tpl`):

    client_id = <cliente>
    platform  = kubernetes
    role      = node | singleton

Um pipeline publicado com seletor `role=node` só é entregue aos DaemonSets. Mudar o
valor no values, renomear o atributo ou publicar com seletor errado faz o coletor
deixar de casar — e o pipeline **não chega**, sem erro.

⚠️ Erro real desta classe, cometido nesta frente: um teste de conflito de porta usou
matcher `role="singleton"`, e o singleton **não tem** receptor OTLP. O matcher não
casava o que se supunha, o teste não exercia nada, e quase se concluiu "não há
conflito" a partir dele.

### Reinício de pod com o Fleet fora

A assimetria aqui é o que importa, e foi medida com o agente v1.18.1:

| situação | resultado |
|---|---|
| Fleet inalcançável, agente **já rodando** | segue com a última config; o poll falha sem derrubar |
| Fleet inalcançável, agente **iniciando** | **não sobe**: `could not perform the initial load successfully` |
| Fleet responde 401, agente **iniciando** | idem |

Não é "o log para" — é o agente **inteiro** que não inicia: métricas, traces, tudo. E
pod reinicia por rollout de nó, OOM, drain e upgrade de cluster.

⚠️ Isso vale enquanto `fleetManagement.enabled: true`, **independente** de
`sanitizacao.local.enabled`. Risco aceito conscientemente, com o raciocínio de que a
janela de exposição é o reinício, não a queda.

### Sobre o token — correção de um erro comum

O token do Fleet é um Access Policy token da Grafana Cloud (`glc_`). **Não expira por
tempo.** Os metadados que ele carrega são org, nome e região; não há campo de validade,
e este foi criado sem expiração opcional.

O modo de falha é **revogação** — manual, ou por engano numa limpeza de tokens. Tratar
como "vai expirar sozinho" leva a diagnosticar a coisa errada quando parar.

## O procedimento

```yaml
sanitizacao:
  local:
    enabled: true
```

Aplique e sincronize. É isso.

## Por que é só isso — e por que era para ser mais

O desenho original previa um "values de emergência" contendo a corrente de log
inteira, porque supunha que o chart deixaria de tê-la. **Não é o caso.** As 14 regras
vivem sempre em `templates/_sanitizacao.tpl`; a flag decide apenas para onde os logs
são encaminhados.

Isso elimina três custos que estavam previstos:

| custo previsto | situação real |
|---|---|
| regra de PII existindo em dois lugares, podendo divergir | fonte única, não há segunda cópia |
| o DR não pode copiar `regras.alloy` (usa `error_mode = "propagate"`) | não há cópia; o chart renderiza com `"ignore"` |
| o gate teria de comparar **3** alvos | segue comparando **2** |

**Verificado, não suposto:** o render com `enabled: true` explícito é byte a byte
idêntico ao padrão do chart. As 28 regras (14 × 2 cadeias) aparecem com
`error_mode = "ignore"` nos 7 processadores.

## O que volta e o que não volta

| | |
|---|---|
| log de aplicação | volta a ser aceito e mascarado localmente |
| métricas e traces | **nunca pararam** — a flag não os toca (verificado por diff) |
| eventos de cluster | **nunca pararam de ser mascarados** — não obedecem a flag |

## O que se perde durante a indisponibilidade

O log de aplicação daquele período. Medido contra o agente real: a ingestão é
**recusada na borda**, não descartada em silêncio —

    POST /v1/logs     ->  503 {"code":14,"message":"telemetry type is not supported"}
    POST /v1/metrics  ->  200

A aplicação vê o erro, e o SDK OTLP retém em buffer conforme sua própria política.
Parte do log pode ser recuperada quando a via volta; o que exceder o buffer, não.

⚠️ Isso é melhor que a alternativa: encaminhar log sem máscara enviaria PII de titular
em claro. Medido em produção que esse log carrega CPF, CNPJ, nome completo e chave Pix
— ver `pre-dev/regras-pii-falso-positivo/ACHADO-pii-em-claro-byoc.md`.

## Voltando para a via do Fleet, depois

Não faça na pressa. Antes de desligar a flag de novo:

1. confirme que a pipeline está publicada e o coletor a recebeu (`poll_frequency` é 1 min)
2. confirme que o log está chegando mascarado, com dado real
3. só então `enabled: false`

⚠️ **A porta 4318 não coexiste.** Medido: `bind: address already in use`. Não é
possível subir a via nova em paralelo e desligar a antiga depois — há uma janela cega
entre os dois passos, e é por isso que o passo 2 vem antes.

## Detecção

Este procedimento depende de alguém perceber que o log parou. O alerta de log ausente
por `client_id` é o que torna isso detectável em vez de silencioso — enquanto ele não
existir, a detecção é manual.
