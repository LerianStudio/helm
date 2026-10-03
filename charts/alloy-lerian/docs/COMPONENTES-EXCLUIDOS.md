# Componentes deliberadamente fora deste chart

O chart instala **três** componentes: o agente em dois papéis (por nó e instância
única) e um produtor de estado de objetos de cluster.

Medido no cluster: **zero CRDs, nenhum pod privilegiado, nenhum `hostPID`, nenhum
`hostPath`, e o agente roda como uid 473 com raiz somente-leitura.** O único
privilégio é `hostNetwork` no papel por nó, necessário para o caminho secundário
de atribuição de contexto.

> **Correção (2026-08-10).** Esta seção afirmava a mesma postura quando o agente
> ainda rodava como **root** — o chart oficial entrega `securityContext: {}` e o
> usuário default da imagem é uid 0, de modo que o sidecar `config-reloader`
> injetado pelo próprio chart era mais restrito que o agente. Encontrado ao
> comparar com o chart oficial, e corrigido: `runAsUser: 473`,
> `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`.
> Verificado no cluster (`uid=473(alloy)`), sem perda de função.
> Comparação completa contra o chart oficial: o agente rodava como root porque
> o upstream entrega `securityContext: {}` e a imagem tem uid 0 por padrão.

Este documento registra por que cada componente do chart guarda-chuva ficou fora,
para que a decisão não se perca e ninguém religue por conveniência.

---

## Alloy Operator

**O que faz:** gerencia o ciclo de vida de instâncias do agente através de um
recurso customizado. Internamente usa o próprio chart do agente para renderizar
os workloads.

**Não é requisito.** Deploy direto pelo chart é caminho suportado e documentado
de primeira classe.

**Por que o guarda-chuva o adotou** — razões sobre *aquele chart*, não sobre o
agente: cada instância exigia um subchart e todo override tinha de ser declarado
no values do pai, que chegou a quase 3.000 linhas; e o deploy por Helm hook
quebrava com ArgoCD em upgrade.

**Por que está fora — motivo de segurança, não de simplicidade:** o ClusterRole
dele pede **`bind` e `escalate`** em `rbac.authorization.k8s.io`, que são
equivalentes a admin, mais CRUD completo em secrets e configmaps, por padrão em
todos os namespaces. Há issue aberta upstream pedindo a remoção desses verbos
justamente porque times de segurança rejeitam a configuração.

Temos **dois papéis fixos**. O problema que o operator resolve é gestão de frota
multi-instância. Excluí-lo **reduz** a nossa superfície de privilégio.

---

## Pyroscope / perfilamento por eBPF

⚠️ **O item mais perigoso da lista, e o único que não é chart separado.**

É uma flag **dentro do nosso agente**. Habilitá-la exige rodar o agente como root
no namespace de PID do host — na prática, `privileged: true` no DaemonSet que hoje
está limpo. E passa a ler stack traces de **todos** os processos do nó, expondo
símbolos de qualquer workload, não apenas dos nossos.

Ligar "só para testar" reverte a postura de privilégio inteira.

---

## Beyla — auto-instrumentação por eBPF

**O que faz:** instrumenta aplicações sem alterar código, produzindo métricas e
rastros de HTTP, gRPC e SQL.

**Por que está fora:** exige `privileged` + `hostPID`, ou seis capabilities
incluindo `CAP_BPF` e `CAP_PERFMON`. E **lê paths HTTP e statements SQL no
kernel** — numa plataforma com PII cifrada em campo no ledger, isso é vetor de
exfiltração que contorna os controles da aplicação.

Além disso é desnecessário: as aplicações já emitem telemetria nativa pela
biblioteca compartilhada. Beyla existe para código que não se controla.

---

## Kepler — consumo energético

`privileged: true` + `hostPID: true` + acesso a `/sys/class/powercap/intel-rapl`,
para produzir uma métrica (watts) sem uso regulatório nem de SLO.

Agravante: depende de leitura RAPL do processador, que tipicamente **não é
exposta em ambiente virtualizado**. Em nós gerenciados de nuvem provavelmente nem
funcionaria.

---

## OpenCost — atribuição de custo

Exige um Prometheus próprio para scrape e armazenamento, e credencial de
faturamento da conta de nuvem para obter custo real em vez de preço de tabela.

É FinOps, ortogonal ao objetivo deste chart. E pedir credencial de billing num
cluster de cliente não faz sentido.

---

## node-exporter — métricas de host

**Ressalva honesta: este é o menos privilegiado dos DaemonSets desta lista.**
Roda não-root, sem eBPF, sem `privileged`, com filesystem somente leitura. Pede
`hostPID` e monta o rootfs do nó em leitura.

**Está fora por ESCOPO, não por risco proibitivo:** métricas de host descrevem o
nó, e no perfil de cliente o nó pertence ao cliente. Não temos competência para
agir sobre ele.

Se algum dia precisarmos de saturação de nó nos **nossos** ambientes, este é o
candidato defensável — e o perfil `own` permite habilitar. Justificar sua exclusão
com o mesmo peso de Beyla ou Kepler seria vender demais a decisão.

---

## windows-exporter

Exige nós Windows. O stack é Go em Linux, então o DaemonSet ficaria com zero pods
agendados. Excluir é o único comportamento correto.

---

## CRDs — nota de correção

O subchart `crds` do chart do agente instala **uma única** definição:
`podlogs.monitoring.grafana.com`. As do Prometheus Operator
(`servicemonitors`, `podmonitors`, `probes`) **nunca** foram entregues por ele —
o pedido foi fechado upstream como não planejado.

Portanto **não há risco de conflito** com um `kube-prometheus-stack` existente: os
grupos de API são disjuntos (`monitoring.grafana.com` vs `monitoring.coreos.com`).

Desligamos (`crds.create: false` nos dois papéis) por outro motivo: evitar
depositar uma definição de escopo global que **o Helm nunca remove no
uninstall**, por um recurso que não consumimos. O modo de falha real não é disputa
de propriedade — é definição antiga congelada, porque o Helm não atualiza CRD em
upgrade.

Pegadinha registrada: o diretório `crds/` só é aplicado quando o chart é o
primário, **não quando é dependência**. Como aqui ele é subchart sob alias,
`crds.create: true` poderia silenciosamente não instalar nada — mais uma razão
para a decisão ser explícita em vez de herdada.

---

## Resumo da postura

| Aspecto | Este chart |
|---|---|
| CRDs instaladas | zero |
| Usuário do agente | **uid 473, não-root** (medido: `uid=473(alloy)`) |
| Raiz somente-leitura | **sim** |
| Escalonamento de privilégio | negado |
| Capabilities | todas descartadas |
| Pods privilegiados | nenhum |
| `hostPID` / `hostIPC` | nenhum |
| `hostPath` | nenhum |
| eBPF | não |
| `hostNetwork` | apenas o papel por nó, com justificativa |
| Credencial de nuvem exigida | nenhuma |

Cada exclusão acima preserva pelo menos uma linha desta tabela.
