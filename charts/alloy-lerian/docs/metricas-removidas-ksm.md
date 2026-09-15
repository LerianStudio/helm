# Métricas de objeto de cluster que NÃO coletamos — e como ver a informação

**Coletamos o mínimo.** Este documento existe para que a decisão seja reversível: cada
família removida está listada com o motivo, o custo em séries e onde ver aquela
informação por outro caminho. Se alguma passar a fazer falta, **habilitar é
acrescentar o nome em `collection.clusterObjectAllowlist`** — e aqui está o que isso
custa.

Medição de referência: **aws-devops, 2026-08-25**, 3 nós, ~57 pods. O
kube-state-metrics 2.19.1 entrega por padrão **184 famílias / 5.272 séries**. A
allowlist mantém **46 famílias / 1.254 séries** — corte de **76%**.

Números escalam com o tamanho do cluster: são por pod, por deployment, por secret.

## O critério

Duas perguntas decidem cada família:

1. **Responde uma pergunta operacional?** Por que caiu, por que reiniciou, está perto
   do limite, saturou, vai saturar.
2. **É estado ou inventário?** Estado muda ao longo do tempo, e por isso pode alertar.
   Inventário só descreve o que existe — e `kubectl` responde melhor, na hora, de graça.

Métrica de série temporal é caro no destino (custo = séries × escritas/minuto). Vale
para o que muda e precisa de histórico. Não vale para o que é descrição estática.

---

## 1. Estado redundante — a mesma resposta já vem de outra família

| Removida | Séries | Onde ver | Por quê |
|---|---:|---|---|
| `kube_pod_status_reason` | 456 | `kube_pod_container_status_terminated_reason` (mantida) | 456 séries e quase todas valendo 0. Mesmo padrão do `k8s_container_status_reason`, onde medimos 747 séries e só **5 com valor 1**. O motivo do encerramento vem por contêiner, que é onde a ação acontece |
| `kube_pod_status_scheduled` | 171 | `kube_pod_status_phase{phase="Pending"}` (mantida) | pod não agendado é `Pending`. A família dedicada não acrescenta |
| `kube_pod_status_ready` | 171 | `kube_pod_container_status_ready` (mantida) | prontidão de pod é derivável da de contêiner, e a de contêiner diz *qual* não está pronto |
| `kube_deployment_status_condition` | 186 | `kube_deployment_status_replicas_available` (mantida) | a condição `Available` é exatamente `available >= desired`. A condição `Progressing` só importa durante rollout, janela curta |
| `kube_pod_status_ready_time`, `kube_pod_status_container_ready_time`, `kube_pod_status_initialized_time`, `kube_pod_status_scheduled_time`, `kube_pod_start_time`, `kube_pod_created`, `kube_pod_completion_time` | ~330 | `kubectl get pod -o wide`; `kube_pod_container_state_started` se precisar de idade em query | 7 famílias de carimbo de tempo. Idade de pod raramente é alvo de alerta, e quando é, uma basta |

**Subtotal: ~1.314 séries.**

## 2. Inventário — descreve o que existe, não como está

Tudo aqui responde melhor com `kubectl`, e na hora.

| Removida | Séries | Onde ver |
|---|---:|---|
| `kube_pod_tolerations` | 202 | `kubectl get pod <p> -o jsonpath='{.spec.tolerations}'` |
| `kube_pod_status_qos_class` | 171 | `kubectl get pod <p> -o jsonpath='{.status.qosClass}'` — é consequência de requests/limits, que mantemos |
| `kube_pod_info`, `_ips`, `_scheduler`, `_service_account`, `_restart_policy` | ~285 | `kubectl get pod <p> -o wide` / `describe` |
| `kube_secret_*` (5 famílias: created, info, metadata_resource_version, owner, type) | 195 | `kubectl get secret -A`. **E num cluster financeiro, inventário de Secret em série temporal é superfície que não precisa existir** |
| `kube_configmap_*` (3 famílias) | 126 | `kubectl get cm -A` |
| `kube_service_*` (3) + `kube_endpointslice_*` (4) | 216 | `kubectl get svc,endpointslice -A`. Topologia de rede: útil em depuração pontual, não vale série contínua |
| `kube_ingress_*` (4 famílias) | 47 | `kubectl get ingress -A` |
| `kube_lease_owner`, `kube_lease_renew_time` | 36 | `kubectl get lease -A` — eleição de líder de componentes de controle |
| `kube_namespace_created` | 14 | `kubectl get ns` |
| `kube_*_metadata_generation`, `kube_*_status_observed_generation` (em deployment, replicaset, statefulset, daemonset, hpa) | ~180 | contadores internos de reconciliação do Kubernetes. Não descrevem saúde de aplicação |
| `kube_deployment_owner`, `kube_deployment_created`, `kube_deployment_spec_paused`, 2× `spec_strategy_rollingupdate_*` | ~150 | `kubectl describe deploy` |
| webhooks (`kube_mutatingwebhookconfiguration_*`, `kube_validatingwebhookconfiguration_*`, 6 famílias) | ~32 | `kubectl get mutatingwebhookconfiguration` |
| `kube_volumeattachment_*` (6) + `kube_storageclass_*` (2) | ~10 | `kubectl get volumeattachment,storageclass` |
| `kube_persistentvolume_created`, `_info`, `_claim_ref`, `_volume_mode` | 8 | `kubectl get pv` |

**Subtotal: ~1.672 séries.**

## 3. `kube_replicaset_*` — o maior bloco único

| Removidas | Séries |
|---|---:|
| `kube_replicaset_owner`, `_spec_replicas`, `_status_replicas`, `_status_ready_replicas`, `_status_fully_labeled_replicas`, `_status_observed_generation`, `_metadata_generation`, `_created` | **648** |

**Por quê:** ReplicaSet é objeto intermediário. Você opera **Deployment**; o
Deployment cria ReplicaSets, e um Deployment com histórico de 10 revisões carrega 10
ReplicaSets — quase todos com 0 réplicas, cada um gerando 8 séries que nunca mudam.

**Onde ver:** `kube_deployment_spec_replicas` e
`kube_deployment_status_replicas_available` (ambas mantidas) respondem a mesma
pergunta no nível em que se age. Para inspecionar rollout: `kubectl rollout status` /
`kubectl get rs`.

**Quando reabilitar:** se um dia houver ReplicaSet gerido sem Deployment acima, ou
investigação recorrente de rollout preso. Custo: ~81 séries por família.

## 4. Cauda longa

~100 famílias com 1 a 10 séries cada, **~415 séries no total**: `kube_job_*`
metadados (owner, info, created, spec_*), `kube_cronjob_*` de configuração (suspend,
history_limit, starting_deadline), `kube_node_created`/`_info`/`_status_addresses`,
`kube_networkpolicy_*`, `kube_poddisruptionbudget_created`,
`kube_statefulset_*` de revisão, `kube_pod_spec_volumes_*`, `kube_pod_init_container_*`
restantes.

Todas inventário ou configuração declarada. `kubectl describe` do objeto responde.

---

## Total

| | Séries |
|---|---:|
| KSM sem allowlist | 5.272 |
| Estado redundante | −1.314 |
| Inventário | −1.672 |
| `kube_replicaset_*` | −648 |
| Cauda longa | −415 |
| Arredondamento entre grupos | −(~-31) |
| **Mantido** | **1.254** |

## Como habilitar uma família

No `values.yaml` do ambiente:

```yaml
collection:
  clusterObjectAllowlist:
    # ... a lista existente ...
    - kube_replicaset_status_ready_replicas   # +81 séries neste cluster
```

⚠️ **A lista SUBSTITUI, não acrescenta.** Values do Helm troca arrays inteiros — o
values do ambiente tem de conter a lista completa, não só o item novo. Omitir uma
família que estava lá a remove silenciosamente.

⚠️ **Lista vazia é erro fatal, de propósito.** `regex = ""` com `action = "keep"`
descartaria toda métrica de objeto sem erro nenhum. O chart recusa renderizar.

## O que NÃO está aqui

Este documento cobre apenas o kube-state-metrics. Outras allowlists do chart:

| Fonte | Parâmetro | Documentação |
|---|---|---|
| cAdvisor (consumo por contêiner) | `collection.containerUsageAllowlist` | comentários no `values.yaml` — 16 de 78 famílias, medido −94,6% |
| node-exporter (infra de nó) | `collection.nodeAllowlist` | `nodeInfrastructure: false` por padrão — 612 famílias / 46.575 séries se ligado sem filtro |
| Auto-observação do agente | `collection.selfMetricsAllowlist` | 21 métricas |
