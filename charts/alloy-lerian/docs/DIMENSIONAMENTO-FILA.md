# Dimensionamento da fila — guia de operação

Para escolher `destination.queue.size` e os limites de memória ao configurar um
cliente. Todos os números vêm de medição em produção, não de estimativa.

## Resumo executivo

**Na maioria dos casos, não mexa em nada.** O padrão (`size: 1000`, limite 512 Mi)
cobre folgadamente qualquer cliente até ~100 linhas/s por pod — o que inclui **todos os
clientes atuais**, o maior deles inclusive.

Este guia existe para o caso em que um cliente cresça além disso.

## Por que a fila importa

Quando o destino fica indisponível, a fila é o que segura o log até ele voltar. Cheia,
o comportamento é **descarte**, e a aplicação recebe `200` — ela considera entregue o
que foi jogado fora.

⚠️ Isso é deliberado: `blockOnOverflow: false`, porque contrapressão chegaria às
aplicações do cliente e telemetria não pode travar transação. O custo é a perda ser
silenciosa, e é por isso que o **alerta de saturação** é obrigatório, não opcional.

## Os três números que você precisa

    1. linhas de log por hora do cliente     (na Grafana Cloud, ver abaixo)
    2. número de nós                          (é DaemonSet: a fila é POR POD)
    3. quanto tempo de indisponibilidade quer absorver

⚠️ **O erro mais fácil aqui é esquecer o item 2.** O volume do cliente se reparte entre
os nós. Calcular como se fosse um pod só superdimensiona por um fator igual ao número
de nós — foi o erro cometido na primeira estimativa desta análise, que apontou 1,8 GB
onde o correto eram 182 MB.

### Como obter

```promql
# linhas/h — no datasource de LOGS (Loki)
sum(count_over_time({client_id="<cliente>"} [1h]))

# nós — no datasource de MÉTRICAS
max(k8s_daemonset_desired_scheduled_nodes{client_id="<cliente>"})
# vocabulário novo (pós-Alloy):
max(kube_daemonset_status_desired_number_scheduled{client_id="<cliente>"})
```

## A tabela

Entre pela coluna **linhas/s por pod** = (linhas por hora ÷ nós ÷ 3600).

| linhas/s/pod | fila p/ 30 min | RAM da fila | limite | request |
|---|---|---|---|---|
| até 10 | 18.000 | 16 MB | **512 Mi** (padrão) | 256 Mi |
| até 25 | 45.000 | 39 MB | **512 Mi** | 256 Mi |
| até 50 | 90.000 | 78 MB | **512 Mi** | 256 Mi |
| até 100 | 180.000 | 156 MB | **512 Mi** | 256 Mi |
| até 200 | 360.000 | 312 MB | **640 Mi** | 256 Mi |
| até 500 | 900.000 | 780 MB | **1152 Mi** | 256 Mi |

Para 60 min, dobre a fila e recalcule o limite pela fórmula abaixo.

### A fórmula, se precisar de um valor fora da tabela

    fila       = linhas/s/pod x segundos_de_retencao
    RAM        = fila x 909 bytes
    limite     = (RAM + 140 MB) / 0,8

Os três fatores são medidos:

| fator | valor | de onde |
|---|---|---|
| tamanho médio da linha | **909 bytes** | Voluti-prd: 1.909.008.384 bytes / 2.101.145 linhas |
| uso base do agente | **~140 MB** | aws-devops, pods estáveis |
| margem do `memory_limiter` | **80%** | o agente descarta a 80% do limite — a fila nunca usa tudo |

⚠️ O divisor de 0,8 não é folga arbitrária. Sem ele o `memory_limiter` começaria a
descartar **antes** de a fila encher, e o dimensionamento não entregaria a retenção
prometida.

## Os clientes hoje — medido em 2026-08-29/30

| cliente | linhas/h | nós | linhas/s/pod | faixa |
|---|---|---|---|---|
| **Voluti-prd** | 2.101.145 | 10 | **58,4** | até 100 → padrão serve |
| Cappta-Prd | 196.523 | ? | ? | nós não medidos |
| aws-production | 68.580 | 4 | 4,8 | padrão |
| aws-staging | 27.779 | 6 | 1,3 | padrão |
| Banqi-Prd | 5.523 | 4 | 0,4 | padrão |
| aws-devops | 3.601 | 3 | 0,3 | padrão |

⚠️ **O maior cliente cabe no padrão de memória.** Para 30 min de retenção o Voluti
precisa de `queue_size: 105000` — mas apenas 91 MB, dentro dos 512 Mi atuais. O que
muda é o `queue_size`, não o limite.

## Como aplicar

```yaml
destination:
  queue:
    size: 105000        # calculado pela tabela
node:
  resources:
    limits:
      memory: 512Mi     # só mude se a tabela pedir
```

⚠️ **É DaemonSet: o limite se multiplica por nó.** Subir de 512 Mi para 1 Gi num
cluster de 20 nós reserva 20 Gi a mais da capacidade do cliente. Não suba o limite sem
que a tabela peça.

## Ressalvas que o número não captura

| | |
|---|---|
| **é média, não pico** | 2,1 M/h é média de uma hora. Se o cliente tem pico de 3× em horário comercial, a fila de 30 min vira 10 min. Dimensione pela hora de maior volume, não pela média do dia |
| **a fila é volátil** | reinício de pod perde a fila inteira. Persistência está fora de escopo — exigiria baixar o piso de estabilidade do agente globalmente |
| **não protege contra queda longa** | `retry.maxElapsedTime` é 5 min por padrão; passando disso, descarta independentemente do tamanho da fila |

## O que torna isso verificável

O dimensionamento só é confiável se houver como saber que errou. O alerta de saturação
compara `otelcol_exporter_queue_size` com `otelcol_exporter_queue_capacity` e avisa
antes de encher.

⚠️ Sem esse alerta, um `queue_size` subdimensionado descarta em silêncio e ninguém
descobre. Foi assim que se perderam 256 eventos na benedita — ver o comentário de
`singletonSize` no `values.yaml`.

## Nota sobre o Fleet

`queue_size` **não** é ajustável pelo Fleet Management: é atributo de um exportador que
o chart declara, e o Fleet só acrescenta componentes novos — nunca edita os existentes.
Medido; ver `reference_fleet_adiciona_nunca_edita`.

Consequência prática: mudar a fila exige versão do chart e o cliente aplicar. Como é
configuração estável (nós e volume mudam devagar), na prática ela entra junto com a
migração do cliente.
