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
