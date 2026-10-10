# Instalação do alloy-lerian — guia do cliente

Este guia é o passo a passo completo para instalar o agente de telemetria da
Lerian no cluster Kubernetes.

O agente coleta telemetria (logs, métricas e traces) dos produtos Lerian
instalados no ambiente e a envia para a plataforma de observabilidade da
Lerian, pela internet, por HTTPS de saída.

**Tempo estimado:** 15 minutos. São 3 passos.

---

## O que você vai precisar?

Dois tokens, entregues pelo time de operações da Lerian por canal seguro:

| Item | Para que serve |
|---|---|
| **Token de telemetria** | Autentica o envio dos dados ao destino. |
| **Token do Fleet** | Ajuste a configuração de coleta remotamente no Grafana. |

Não precisa de mais nada da Lerian: endereço de destino, perímetro de
coleta e regras de tratamento de dados já vêm no chart.

---

## Passo 1 — Criar o Secret com os tokens

O chart **lê** este Secret e nunca o cria. Ele precisa existir antes da instalação, com este nome exato e estas duas chaves — por isso o namespace também é criado aqui. O comando abaixo não falha se ele já existir.

```console
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

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

## Passo 2 — Criar o `values.yaml` e instalar

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
  -n monitoring --create-namespace -f values.yaml
```

Se algo estiver faltando no values, a instalação **falha na hora**, com uma
mensagem dizendo o que falta e como corrigir. Ela não sobe pela metade.

---

## Passo 3 — Verificar

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

## Problemas comuns

| Sintoma | Causa | O que fazer |
|---|---|---|
| Pod em `CreateContainerConfigError` | O Secret não existe, ou falta uma das duas chaves | Refaça o passo 1. A mensagem do pod nomeia a chave que falta: `kubectl describe pod -n monitoring <pod>` |
| Pod em `Pending` ou rejeitado na criação | Pod Security Admission bloqueando `hostNetwork` | Veja [Por que o agente usa `hostNetwork`?](#por-que-o-agente-usa-hostnetwork) no FAQ |
| `Exporting failed... 401` | Token de telemetria inválido | Peça a reemissão à Lerian. 401 é permanente: o dado é descartado na hora, sem nova tentativa |
| `Exporting failed... 403` | Chamada chegando por caminho inesperado | Acione a Lerian com a linha de log completa |
| `Exporting failed... connection refused` ou timeout | Saída HTTPS bloqueada | Veja [Quais acessos de saída o agente precisa?](#quais-acessos-de-saída-o-agente-precisa) no FAQ |
| Nenhum `successfully loaded remote configuration` | Token do Fleet inválido ou destino do Fleet bloqueado | Confira a chave `fleet-token` e os acessos de saída, no FAQ |
| Pod que reiniciou não volta, e os outros seguem rodando | O Fleet está indisponível no momento do reinício | Acione a Lerian: o diagnóstico e a retomada são do nosso lado |

---

## Atualizar

```console
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm \
  --version <nova versão> -n monitoring -f values.yaml
```

O `values.yaml` continua o mesmo. Ajustes na coleta normalmente **não** exigem
atualização: a Lerian os aplica remotamente pelo Fleet.

## Desinstalar

```console
helm uninstall alloy-lerian -n monitoring
kubectl delete secret alloy-lerian -n monitoring
```

A coleta para imediatamente. Nada do seu ambiente é alterado.

---

## FAQ

### Já rodamos kube-state-metrics no cluster. Vai haver conflito?

Não, mas vale ajustar. Por padrão o chart instala a própria instância, e duas
rodando ao mesmo tempo é desperdício — ambas produzem a mesma informação.

Para reusar a que já existe, acrescente ao `values.yaml`:

```yaml
kube-state-metrics:
  enabled: false

collection:
  # host:porta do Service existente, em qualquer namespace
  clusterObjectTarget: kube-state-metrics.kube-system.svc.cluster.local:8080
```

O agente passa a ler a instância de vocês e nenhuma nova é criada. O namespace
não importa — basta o Service ser alcançável de dentro do cluster.

### Quais acessos de saída o agente precisa?

Somente saída, HTTPS na porta 443. Nada disca para dentro do cluster.

| Destino | Para quê |
|---|---|
| `telemetry.lerian.io` | Envio da telemetria |
| `fleet-management-prod-015.grafana.net` | Busca da configuração de coleta |

Se houver proxy ou firewall de saída, os dois domínios precisam estar liberados.

### Por que o agente usa `hostNetwork`?

As aplicações enviam telemetria para o IP do nó em que elas mesmas rodam, o que
mantém o tráfego local. Sem `hostNetwork`, cada envio atravessaria a rede do
cluster e o agente deixaria de identificar corretamente o nó de origem de cada
registro.

O agente continua rodando **não-root** (uid 473), com sistema de arquivos raiz
somente-leitura e sem privilégios elevados. A exceção é só para a rede.

> Se o cluster aplica Pod Security Admission no modo `restricted`, o namespace
> precisa de exceção — esse perfil proíbe `hostNetwork`:
>
> ```console
> kubectl label namespace monitoring \
>   pod-security.kubernetes.io/enforce=privileged --overwrite
> ```

### Quais permissões o chart cria no cluster?

`ClusterRole` e `ClusterRoleBinding` de **leitura apenas** — um par por
componente, três no total. Os verbos são `get`, `list` e `watch`, e servem para
associar cada registro ao pod e namespace de origem, e para ler as métricas de
consumo dos contêineres. O agente não cria, altera nem remove nada no cluster.

### Quanto consome?

| Componente | CPU (requisição) | Memória (requisição / limite) |
|---|---|---|
| Agente por nó | 100m | 128Mi / 512Mi |
| Agente único do cluster | 50m | 128Mi / 256Mi |

### Posso instalar em outro namespace?

Pode. Troque `monitoring` por ele em todos os comandos. O Secret precisa ser
criado no mesmo namespace da instalação.

### A telemetria de outras aplicações nossas também é coletada?

Só os namespaces onde os produtos Lerian estão instalados são coletados
(`midaz` e `midaz-plugins`, por padrão). Telemetria de outros namespaces é
descartada no agente, antes de qualquer envio.

Se os produtos Lerian estão em outro lugar no cluster de vocês, avise a Lerian:
o ajuste é remoto, sem mexer na instalação.

### O que exatamente é coletado?

Logs de aplicação, métricas de uso e traces de requisição, dos namespaces onde
os produtos Lerian estão instalados.

Os tokens ficam no cluster de vocês, no Secret criado no passo 1 — a Lerian
nunca recebe o valor deles.

### Dados sensíveis saem do nosso cluster?

Nome de pessoa, e-mail, telefone, endereço, dados de conta, chave Pix e
credenciais não: são mascarados **dentro do cluster de vocês**, antes de qualquer
envio. Identificadores (CPF, CNPJ, matrícula, número de contrato) seguem em claro
no texto do log, para que um chamado possa ser rastreado.

O mascaramento não é configurável e não pode ser desligado — nem na instalação,
nem remotamente pela Lerian.

### O que a Lerian consegue mudar remotamente?

A configuração de coleta: quais sinais são coletados, de quais namespaces, com
qual frequência e qual tratamento recebem. É o que evita pedir um upgrade de
chart ou uma janela de manutenção a cada ajuste.

O que a gestão remota **não** faz: não executa comandos no cluster, não acessa
outros recursos e não desliga o mascaramento de dados sensíveis.

### Precisamos atualizar o chart com frequência?

Não. A maior parte dos ajustes é aplicada remotamente. Atualizações de chart
acontecem quando há mudança no próprio agente, e a Lerian avisa quando for o
caso.

### Como aumentar o detalhe do log do agente

O agente registra apenas erros, por padrão, para não consumir o disco do seu
cluster com operação normal. Para investigar um problema:

```console
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm \
  --version <mesma versão> -n monitoring -f values.yaml \
  --set logging.level=debug
```

Valores aceitos: `error` (padrão), `warn`, `info`, `debug`. Reproduza o
problema, colete o log e **volte para `error`** — `debug` gera volume alto.

---

## Suporte

Acione o time de operações da Lerian com:

1. `kubectl get pods -n monitoring`
2. `kubectl logs -n monitoring -l 'app.kubernetes.io/instance=alloy-lerian,app.kubernetes.io/name in (node,singleton)' -c alloy --tail=100`
