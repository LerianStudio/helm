# Instalação do alloy-lerian — guia do cliente

Este guia é o passo a passo completo para instalar o agente de telemetria da
Lerian no seu cluster Kubernetes. Foi escrito para quem opera o cluster.

O agente coleta telemetria (logs, métricas e traces) dos produtos Lerian
instalados no seu ambiente e a envia para a plataforma de observabilidade da
Lerian, pela internet, por HTTPS de saída.

**Tempo estimado:** 15 minutos. São 4 passos.

---

## O que você vai precisar da Lerian

Dois tokens, entregues pelo time de operações da Lerian por canal seguro:

| Item | Para que serve |
|---|---|
| **Token de telemetria** | Autentica o envio dos dados ao destino. |
| **Token do Fleet** | Permite que a Lerian ajuste a configuração de coleta remotamente, sem pedir nada a você. |

Você não precisa de mais nada da Lerian: endereço de destino, perímetro de
coleta e regras de tratamento de dados já vêm no chart.

---

## Pré-requisitos no seu cluster

Confira antes de começar — o passo 4 valida tudo isso na prática.

### 1. Saída HTTPS para dois destinos

O agente só faz conexões **de saída**. Nada disca para dentro do seu cluster.

| Destino | Porta | Para quê |
|---|---|---|
| `telemetry.lerian.io` | 443 | Envio da telemetria |
| `fleet-management-prod-015.grafana.net` | 443 | Busca da configuração de coleta |

Se há proxy ou firewall de saída, estes dois domínios precisam estar liberados.

### 2. `hostNetwork` permitido para o DaemonSet

O agente que recebe a telemetria das aplicações roda com `hostNetwork: true`.

É necessário porque as aplicações enviam para o IP do nó em que elas mesmas
rodam, mantendo o tráfego local — sem isso, a telemetria atravessa a rede do
cluster e o agente perde a identificação de qual nó originou cada registro.

> ⚠️ **Se o seu cluster aplica Pod Security Admission no modo `restricted`**, o
> namespace de instalação precisa de exceção: o perfil `restricted` proíbe
> `hostNetwork`. É o ponto de atrito mais comum nesta instalação.
>
> ```console
> kubectl label namespace monitoring \
>   pod-security.kubernetes.io/enforce=privileged --overwrite
> ```
>
> O agente continua rodando **não-root** (uid 473), com sistema de arquivos raiz
> somente-leitura e sem privilégios elevados. A exceção é só para a rede.

### 3. Permissão para criar RBAC de escopo de cluster

O chart cria um `ClusterRole` e um `ClusterRoleBinding`. São permissões de
**leitura apenas**, necessárias para associar cada registro ao pod e namespace
de origem, e para ler métricas de consumo dos contêineres.

### 4. Capacidade

Por nó (DaemonSet): 100m de CPU e 128Mi de memória de requisição, com teto de
512Mi. Mais um pod único no cluster: 50m de CPU e 128Mi, teto de 256Mi.

---

## Passo 1 — Criar o namespace

```console
kubectl create namespace monitoring
```

Se preferir outro namespace, troque `monitoring` por ele em **todos** os
comandos deste guia.

---

## Passo 2 — Criar o Secret com os tokens

O chart **lê** este Secret e nunca o cria. Ele precisa existir antes da
instalação, com este nome exato e estas duas chaves.

```console
read -rs TELEMETRY_TOKEN   # cole o token de telemetria e tecle Enter (não aparece na tela)
read -rs FLEET_TOKEN       # cole o token do Fleet e tecle Enter

kubectl create secret generic alloy-lerian -n monitoring \
  --from-file=telemetry-token=<(printf '%s' "$TELEMETRY_TOKEN") \
  --from-file=fleet-token=<(printf '%s' "$FLEET_TOKEN")

unset TELEMETRY_TOKEN FLEET_TOKEN
```

> ⚠️ **Não use `--from-literal` para passar um token.** O valor fica visível em
> `ps -eo args` para qualquer usuário do host enquanto o comando roda, e é
> gravado no histórico do shell. O `read -rs` acima evita as duas coisas.

Confira que as duas chaves existem:

```console
kubectl get secret alloy-lerian -n monitoring \
  -o jsonpath='{.data}' | tr ',' '\n' | cut -d'"' -f2
```

Deve listar `fleet-token` e `telemetry-token`.

---

## Passo 3 — Criar o `values.yaml` e instalar

### O arquivo

Troque **`acme-prd`** pelo identificador que a Lerian informou para o seu
ambiente. Ele aparece em um lugar só, e tem a forma `<cliente>-<ambiente>`, em
minúsculas, com ambiente `stg` ou `prd`.

```yaml
profile: client

origin:
  id: acme-prd

node:
  alloy:
    extraEnv:
      - name: ALLOY_DESTINATION_CREDENTIAL
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: telemetry-token
            optional: false
      - name: ALLOY_FLEET_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: ALLOY_FLEET_TOKEN
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: fleet-token
            optional: false

singleton:
  alloy:
    extraEnv:
      - name: ALLOY_DESTINATION_CREDENTIAL
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: telemetry-token
            optional: false
      - name: ALLOY_FLEET_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: ALLOY_FLEET_TOKEN
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: fleet-token
            optional: false
```

Os blocos repetidos declaram que o Secret é **obrigatório**: com eles, um pod
sem credencial não sobe. Sem eles, o pod subiria e descartaria telemetria em
silêncio. Copie como está.

### Instalar

```console
helm install alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm \
  --version <versão informada pela Lerian> \
  -n monitoring -f values.yaml
```

Se algo estiver faltando no values, a instalação **falha na hora**, com uma
mensagem dizendo o que falta e como corrigir. Ela não sobe pela metade.

---

## Passo 4 — Verificar

### Os pods estão de pé?

```console
kubectl get pods -n monitoring
```

Esperado — um `node` por nó do cluster, um `singleton` e um
`kube-state-metrics`:

```
alloy-lerian-node-xxxxx               2/2     Running
alloy-lerian-singleton-xxxxxxx-xxxxx  2/2     Running
alloy-lerian-kube-state-metrics-...   1/1     Running
```

### A configuração remota chegou?

```console
kubectl logs -n monitoring \
  -l 'app.kubernetes.io/instance=alloy-lerian,app.kubernetes.io/name in (node,singleton)' \
  -c alloy --tail=-1 | grep "successfully loaded remote configuration"
```

Uma linha por pod do agente significa que o Fleet autenticou e entregou a
configuração de coleta. **Este é o sinal de que a instalação está completa.**

> O `--tail=-1` não é detalhe: sem ele o `kubectl` mostra só as últimas linhas
> de cada pod, e esta mensagem acontece na **partida**. Em um agente que já roda
> há algum tempo ela fica fora da janela, e o resultado vazio pareceria falha.

### Há erro de entrega?

```console
kubectl logs -n monitoring \
  -l 'app.kubernetes.io/instance=alloy-lerian,app.kubernetes.io/name in (node,singleton)' \
  -c alloy --tail=-1 | grep -i "exporting failed"
```

O esperado é **nenhuma saída**. Se aparecer algo, veja a tabela de problemas
abaixo.

> O seletor acima limita os dois papéis do agente de propósito. O
> `kube-state-metrics` compartilha o rótulo de instância mas não tem o contêiner
> `alloy`, e incluí-lo faria o comando falhar.

---

## Apontar suas aplicações para o agente

As aplicações Lerian já vêm configuradas. Esta seção é para aplicações suas que
você queira enviar ao mesmo agente.

O agente recebe OTLP nas portas **4317** (gRPC) e **4318** (HTTP) no IP do nó.
Cada pod descobre o IP do próprio nó pela API do Kubernetes:

```yaml
env:
  - name: HOST_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(HOST_IP):4318"
```

> ⚠️ **Use o IP do nó, não o nome do Service.** Os dois funcionam, mas o Service
> balanceia entre todos os nós e o tráfego acaba atravessando a rede do
> cluster. O IP do nó mantém cada envio no agente local — menos latência, e a
> origem de cada registro fica corretamente identificada.

**Só os namespaces onde os produtos Lerian estão instalados são coletados**
(`midaz` e `midaz-plugins`, por padrão). Telemetria vinda de outros namespaces é
descartada no agente. Se os seus produtos Lerian estão em outro lugar, avise a
Lerian — o ajuste é feito remotamente, sem mexer na sua instalação.

---

## Problemas comuns

| Sintoma | Causa | O que fazer |
|---|---|---|
| Pod em `CreateContainerConfigError` | O Secret não existe, ou falta uma das duas chaves | Refaça o passo 2. A mensagem do pod nomeia a chave que falta: `kubectl describe pod -n monitoring <pod>` |
| Pod em `Pending` ou rejeitado na criação | Pod Security Admission bloqueando `hostNetwork` | Veja o pré-requisito 2 |
| `Exporting failed... 401` | Token de telemetria inválido | Peça a reemissão à Lerian. 401 é permanente: o dado é descartado na hora, sem nova tentativa |
| `Exporting failed... 403` | Chamada chegando por caminho inesperado | Acione a Lerian com a linha de log completa |
| `Exporting failed... connection refused` ou timeout | Saída HTTPS bloqueada | Veja o pré-requisito 1 |
| Nenhum `successfully loaded remote configuration` | Token do Fleet inválido ou destino do Fleet bloqueado | Confira a chave `fleet-token` e o pré-requisito 1 |
| Pod que reiniciou não volta, e os outros seguem rodando | O Fleet está indisponível no momento do reinício | Veja a nota abaixo |

### Sobre a dependência do Fleet

O agente busca a configuração de coleta no Fleet **ao iniciar**. Uma
indisponibilidade do Fleet não derruba os pods que já estão rodando — mas um pod
que reiniciar durante ela (por OOM, drenagem de nó ou autoscaler) **não sobe**
até o Fleet voltar.

É um comportamento conhecido e medido. Se acontecer, acione a Lerian: o
diagnóstico e a retomada são do nosso lado.

---

## Operação

### Aumentar o detalhe do log do agente

O agente registra apenas erros, por padrão, para não consumir o disco do seu
cluster com operação normal. Para investigar um problema:

```console
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm \
  --version <mesma versão> -n monitoring -f values.yaml \
  --set logging.level=debug
```

Valores aceitos: `error` (padrão), `warn`, `info`, `debug`. Reproduza o
problema, colete o log e **volte para `error`** — `debug` gera volume alto.

### Atualizar

```console
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm \
  --version <nova versão> -n monitoring -f values.yaml
```

O `values.yaml` continua o mesmo. Ajustes na coleta normalmente **não** exigem
atualização: a Lerian os aplica remotamente pelo Fleet.

### Desinstalar

```console
helm uninstall alloy-lerian -n monitoring
kubectl delete secret alloy-lerian -n monitoring
```

A coleta para imediatamente. Nada do seu ambiente é alterado.

---

## Sobre os dados coletados

- **O que é coletado:** telemetria dos namespaces dos produtos Lerian — logs de
  aplicação, métricas de uso e traces de requisição.
- **Dados sensíveis são mascarados no seu cluster**, antes de qualquer envio.
  CPF, CNPJ, e-mail, telefone, nome de pessoa, dados de conta e credenciais são
  tratados na origem. O mascaramento não é configurável e não pode ser
  desligado — nem localmente, nem remotamente pelo Fleet.
- **Sentido do tráfego:** somente saída, HTTPS na porta 443. Nenhuma porta é
  aberta para fora do cluster e nada disca para dentro dele.
- **Os tokens ficam no seu cluster**, no Secret que você criou. O Fleet nunca
  recebe o valor deles.

---

## Suporte

Acione o time de operações da Lerian com:

1. `kubectl get pods -n monitoring`
2. `kubectl logs -n monitoring -l 'app.kubernetes.io/instance=alloy-lerian,app.kubernetes.io/name in (node,singleton)' -c alloy --tail=100`
3. O identificador do seu ambiente (`origin.id`)
