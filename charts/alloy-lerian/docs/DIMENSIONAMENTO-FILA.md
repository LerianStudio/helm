# Dimensionamento da fila — guia de operação

Para escolher `destination.queue.size` e os limites de memória ao configurar um
cliente. Todos os números vêm de medição em produção, não de estimativa.

## Resumo executivo

**Na maioria dos casos, não mexa no limite de memória.** O limite padrão (512 Mi) comporta a fila de 30 min de qualquer cliente até ~100 linhas/s por pod.

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

# ⚠️ Se as duas acima não retornarem nada — acontece: nem todo cliente envia
# métrica de DaemonSet — conte os nós distintos vistos nos contêineres:
count(count by (k8s_node_name) (k8s_container_ready{client_id="<cliente>"}))
```

## A tabela

Entre pela coluna **linhas/s por pod** = (linhas por hora ÷ nós ÷ 3600).

| linhas/s/pod | linhas em 30 min | RAM da fila | limite | request |
|---|---|---|---|---|
| até 10 | 18.000 | 16 MB | **512 Mi** (padrão) | 256 Mi |
| até 25 | 45.000 | 39 MB | **512 Mi** | 256 Mi |
| até 50 | 90.000 | 78 MB | **512 Mi** | 256 Mi |
| até 100 | 180.000 | 156 MB | **512 Mi** | 256 Mi |
| até 200 | 360.000 | 312 MB | **640 Mi** | 256 Mi |
| até 500 | 900.000 | 780 MB | **1152 Mi** | 256 Mi |

Para 60 min, dobre as linhas e recalcule o limite pela fórmula abaixo.

### A fórmula, se precisar de um valor fora da tabela

    linhas     = linhas/s/pod x segundos_de_retencao
    RAM        = linhas x 909 bytes
    limite     = (RAM + 140 MB) / 0,8

`queue_size` conta lotes, não linhas: o papel `node` agrupa as linhas em lotes antes da fila. Cada lote tem ao menos uma linha, então usar o número de linhas como `queue_size` basta.

Os três fatores são medidos:

| fator | valor | de onde |
|---|---|---|
| tamanho médio da linha | **909 bytes** | média medida em produção |
| uso base do agente | **~140 MB** | pods estáveis |
| margem do `memory_limiter` | **80%** | o agente descarta a 80% do limite — a fila nunca usa tudo |

⚠️ O divisor de 0,8 não é folga arbitrária. Sem ele o `memory_limiter` começaria a
descartar **antes** de a fila encher, e o dimensionamento não entregaria a retenção
prometida.

## Como aplicar

```yaml
destination:
  queue:
    size: 105000        # calculado pela tabela
node:
  alloy:
    resources:
      limits:
        memory: 512Mi   # só mude se a tabela pedir
```

⚠️ **É DaemonSet: o limite se multiplica por nó.** Subir de 512 Mi para 1 Gi num
cluster de 20 nós reserva 20 Gi a mais da capacidade do cliente. Não suba o limite sem
que a tabela peça.

## Ressalvas que o número não captura

| | |
|---|---|
| **é média, não pico** | O volume por hora é média de uma hora. Se o cliente tem pico de 3× em horário comercial, a fila de 30 min vira 10 min. Dimensione pela hora de maior volume, não pela média do dia |
| **a fila é volátil** | reinício de pod perde a fila inteira. Persistência está fora de escopo — exigiria baixar o piso de estabilidade do agente globalmente |
| **não protege contra queda longa** | `retry.maxElapsedTime` é 5 min por padrão; passando disso, descarta independentemente do tamanho da fila |

## O que torna isso verificável

O dimensionamento só é confiável se houver como saber que errou: um alerta de saturação
que compare `otelcol_exporter_queue_size` com `otelcol_exporter_queue_capacity` e avise
antes de a fila encher.

⚠️ Sem esse alerta, um `queue_size` subdimensionado descarta em silêncio e ninguém
descobre. Ver o comentário de `singletonSize` no `values.yaml`.

## Nota sobre o Fleet

Com `fleetManagement.enabled: true` (o padrão), o exportador do papel `node`, com o `queue_size`, vem da configuração publicada no Fleet. Essa configuração é uma só para todos os clientes e é renderizada de `examples/values-cliente.yaml`. Um `destination.queue.size` no `values.yaml` do cliente só vale com o Fleet desligado.
