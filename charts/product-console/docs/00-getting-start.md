# product-console — Runbook de instalação

> Preenchido a partir do chart (`README.md`, `values.yaml`, `templates/`) e da
> configuração de referência em
> `lerian-internal-gitops/environments/benedita/helmfile/applications/dev-st/product-console`.
> Objetivo: alguém de fora da squad, só com o chart + este runbook, consegue instalar
> uma versão funcional e sabe o que checar caso algo não se comporte como esperado.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `product-console` (chart `4.0.x` / app `1.12.0`) |
| Tipo de chart | `single-service` — um único Deployment (UI Next.js + BFF do Midaz) |
| Squad responsável | Console / Frontend |
| Última revisão deste runbook | 2026-09-15, contra chart `4.0.x` |
| Contato de escalação | squad Console (ver CODEOWNERS do chart) |

O console é um workload único, não uma app multi-componente. Seu "perfil" não é *quais*
componentes você habilita (só existe um), e sim *para o que ele aponta*: os serviços
Lerian irmãos, o MongoDB onde guarda o estado do console, se a autorização está ligada, e
qual preset de nuvem gerenciada se aplica.

---

## 1. Perfis de instalação

| Perfil | Formato | Caso de uso |
|---|---|---|
| Demo standalone | MongoDB embutido (`mongodb.enabled: true`, default), `ingress.enabled: false`, auth desligado | Só local/experimentação. **Não** usar em nada exposto. |
| Dev/homolog integrado | MongoDB externo, ingress ligado, base paths dos irmãos apontando pros serviços reais no cluster, auth ligado | Topologia de referência `benedita/dev-st` |
| Produção | MongoDB gerenciado externo (DocumentDB via `global.cloud: aws`), ingress + TLS, auth ligado, `NEXTAUTH_SECRET` de um secret manager, `TRUSTED_PROXIES` no CIDR do ingress | Voltado ao cliente |

- O subchart de MongoDB embutido vem **habilitado por default** — conveniente pra demo,
  mas ver seção 5 (ele não sobrevive a `namespaceOverride`, e não é banco gerenciado).
  Produção deve setar `mongodb.enabled: false` e apontar pro Mongo externo.
- Não há eixo de "componentes" aqui; todo knob abaixo é um valor no único Deployment.

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| MongoDB | Sempre — o console guarda o próprio estado (cache de UI de organizações, settings) aqui | Subchart embutido (`mongodb.enabled: true`) **ou** externo via `MONGO_HOST`/`MONGODB_URI`/`MONGODB_USER` em `configmap` + `MONGODB_PASS` em `secrets`, ou a mask `global.datastores.mongo` — seção 4 |
| `lerian-common` (library chart) | Sempre | Dependência do chart; fornece os templates HPA/PDB/Service/Ingress e as masks `global.*`. Nada a configurar. |
| Midaz ledger | Sempre (o console é UI dele) | `MIDAZ_API_HOST` / `MIDAZ_BASE_PATH` / `MIDAZ_TRANSACTION_BASE_*` em `configmap` — default `midaz-ledger.midaz.svc.cluster.local:3002` |
| plugin-access-manager (auth + identity) | Obrigatório quando a autorização está ligada (recomendado em todo ambiente exposto) | `PLUGIN_AUTH_*` / `PLUGIN_IDENTITY_*` em `configmap`, client id/secret em `secrets` — seção 5 |
| Plugins irmãos (CRM, Reporter, Fees, Tracer, Fetcher, Matcher, Flowker, Bank Transfer, Payments) | Só as features que você habilita na UI | Um `*_BASE_PATH` por serviço em `configmap`; cada um default pro FQDN in-cluster do irmão. Uma feature com base path errado só quebra aquela feature, não o startup. |
| OTEL collector | Opcional (telemetria) | `otel.external: true` injeta `OTEL_URL_*`/`HOST_IP` pra um collector DaemonSet node-local; ou `ENABLE_TELEMETRY`/`global.observability` |
| Vault / gerenciador de segredo | Recomendado em produção | `useExistingSecret: true` + `existingSecretName`, ou refs Vault no bloco `secrets:` (o env de referência usa refs AVP `<path:...>`) |

O console alcança os irmãos por **FQDN in-cluster** (`<svc>.<ns>.svc.cluster.local`) já
de fábrica, então funciona entre namespaces sem mesh/DNS — sobrescreva um `*_BASE_PATH`
só quando os nomes de serviço/namespace diferirem.

---

## 3. Ordem de instalação

1. Definir a estratégia de MongoDB: embutido (`mongodb.enabled: true`, só demo) **ou**
   externo (`mongodb.enabled: false` + `MONGO_HOST`/`MONGODB_URI` reais + `MONGODB_PASS`).
   Pra Mongo gerenciado (DocumentDB) setar também `global.cloud: aws` pra aplicar
   automaticamente o formato da connection string TLS (seção 5).
2. Fornecer os secrets de produção obrigatórios **antes** do `helm install`:
   `secrets.NEXTAUTH_SECRET` (chave de assinatura do NextAuth — a app não é segura sem
   ela), `secrets.MONGODB_PASS`, e — quando auth ligado — `PLUGIN_AUTH_CLIENT_ID`/`_SECRET`.
3. Ligar a autorização **explicitamente** em qualquer ambiente exposto:
   `global.auth.enabled: "true"` (ou `configmap.PLUGIN_AUTH_ENABLED: "true"`). O console
   **não** fail-close na ausência do toggle — ver seção 5.
4. Apontar os base paths inter-serviço pros serviços reais se os namespaces diferirem dos
   defaults (Midaz, access-manager, CRM, Reporter, …).
5. Setar `TRUSTED_PROXIES` no CIDR dos hops na frente do console (normalmente o CIDR de
   pod/service do ingress controller) — vazio significa que nenhum client IP é resolvido e
   o allowlist de IP do tenant nunca é aplicado (seção 5).
6. Configurar `ingress` (class, host, TLS) e setar `NEXTAUTH_URL` pra URL pública que o
   browser usa nos callbacks OAuth (default: primeiro host do ingress como `https://…`).
7. `helm install … -n <ns> --create-namespace`. Deixar `namespaceOverride` vazio a menos
   que saiba que precisa — com o MongoDB embutido ele separa recursos entre namespaces
   (seção 5).

---

## 4. Contrato de configuração compartilhada (masks / lerian-common)

O console consome masks do `lerian-common`: setar um valor **uma vez por ambiente** em
`global.*` e toda chave consumidora pega. Um `configmap.<KEY>` nativo sempre vence a mask.

```yaml
global:
  # Gate/host do Access Manager — LIGUE em qualquer ambiente exposto (default é OFF)
  auth:
    enabled: "true"
    host: "plugin-access-manager-auth.<ns>.svc.cluster.local"
  # Telemetria
  observability:
    enabled: "true"
  # Conexão MongoDB env-wide (Mongo externo). MONGODB_DB_NAME fica por-app.
  datastores:
    mongo:
      host: ""
      port: "27017"
      user: ""
      params: ""     # deixe vazio na AWS — global.cloud: aws seta o formato DocumentDB
  # Preset de nuvem gerenciada (connection string TLS do DocumentDB), aplicado quando
  # nada mais específico sobrescreve. gcp/azure não têm preset de Mongo hoje.
  cloud: "aws"
```

| Campo global | Efeito (env var) | Chave nativa que sobrescreve |
|---|---|---|
| `global.auth.enabled` / `.host` | `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` | `configmap.PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` |
| `global.observability.enabled` | `ENABLE_TELEMETRY` | `configmap.ENABLE_TELEMETRY` |
| `global.datastores.mongo.{uri,host,port,user,params}` | `MONGODB_URI`/`MONGO_HOST`/`MONGO_PORT`/`MONGODB_USER`/`MONGO_PARAMETERS` | o `configmap.<KEY>` correspondente |
| `global.cloud: aws` | Seta `MONGO_PARAMETERS` no formato DocumentDB (`tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&…`) | `configmap.MONGO_PARAMETERS` ou `global.datastores.mongo.params` |

**Todo default de `configmap.<KEY>` vive em `templates/configmap.yaml`** (como
`KEY | default "…"`), nunca no `values.yaml` — o map `configmap:` vem vazio. Setar uma
chave lá só pra sobrescrever um default de fábrica.

**`TRUSTED_PROXIES` é uma chave `configmap` comum** (não é mask): só renderiza no
ConfigMap nas versões do chart que carregam a chave allowlistada (LerianStudio/helm
#2120). Em charts anteriores a chave é aceita por `helm lint`/`template` e
**silenciosamente descartada** — setar e confirmar que caiu (seção 6).

---

## 5. Pontos de atenção operacional

| Tópico | O que saber | Antes de habilitar / como confirmar |
|---|---|---|
| **Autorização é OFF por default** | O console aplica permissões só quando o valor renderizado é a palavra literal `true` (`PLUGIN_AUTH_ENABLED` no servidor, `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` no browser). `false`/vazio/`1`/`TRUE`/`yes` leem como OFF; o console **não** fail-close. | Setar `global.auth.enabled: "true"` (ou a chave nativa) em todo release staging/prod. Confirmar com request sem token → deve ser 401/403. |
| **Split auth servidor × browser** | A chave do browser copia o valor do servidor só enquanto `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` está vazia. Uma chave de browser não-vazia é usada literal e nunca reconciliada com o servidor — `"TRUE"` ao lado de um servidor ligado dá servidor ON / browser OFF. | Deixar a chave do browser vazia, ou setar as duas na palavra exata `true`. |
| **`NEXTAUTH_SECRET` é obrigatório em produção** | NextAuth secret vazio ⇒ sessões não são assinadas com segurança. | Fornecer via `secrets` / secret manager antes do install. |
| **`TRUSTED_PROXIES` vazio = nenhum client IP** | Vazio significa que nenhum hop do `X-Forwarded-For` é acreditado, então o allowlist de IP do tenant nunca é aplicado e as chamadas de saída levam `X-Client-Ip-Resolution: unresolved; reason=trusted-proxies-not-configured`. | Setar no CIDR de pod/service do ingress (ex.: `10.42.0.0/16`). **Não alargue** — um range que cobre callers reais os esconde. |
| **MongoDB embutido não sobrevive a `namespaceOverride`** | O Service do subchart é `<release>-mongodb` no namespace de **release**; não herda `namespaceOverride`. Com `namespaceOverride` setado e `MONGO_HOST: "mongodb"`, o console aponta pra um host que não existe em lugar nenhum e nunca fica Ready. | Pra qualquer coisa além de demo no mesmo namespace, usar Mongo **externo**. Se manter o embutido, deixar `namespaceOverride` vazio e setar `MONGO_HOST` no `<release>-mongodb` real. |
| **Namespace da ServiceAccount** | Em charts antes do fix (LerianStudio/helm #2120), `templates/serviceaccount.yaml` não pinava namespace, então com `namespaceOverride` a SA caía no namespace de release enquanto os pods a pediam no namespace do override → pods nunca criados (`Replicas: 0/1`). | Usar versão do chart que pina o namespace da SA, ou deixar `namespaceOverride` vazio. |
| **Preset de nuvem gerenciada** | `global.cloud: aws` auto-seta o formato `MONGO_PARAMETERS` do DocumentDB quando nada mais específico sobrescreve. `gcp`/`azure` não têm preset de Mongo hoje. | No DocumentDB, não escreva `MONGO_PARAMETERS` na mão — deixe o preset aplicar. |
| **OTEL é externo por default no env de referência** | `otel.external: true` injeta `HOST_IP`/`OTEL_URL_*` pra um collector DaemonSet node-local; não instala collector. | Apontar pra um collector real, ou setar `ENABLE_TELEMETRY: "false"` se não houver. |

---

## 6. Como validar que subiu certo

```bash
kubectl get pods -n <namespace>
kubectl get deploy,svc,cm -n <namespace> -l app.kubernetes.io/name=product-console
# endpoints de health (servidos pelo BFF na porta do service, 8081):
kubectl -n <namespace> port-forward svc/product-console 8081:8081 &
curl -fsS http://localhost:8081/api/admin/health/alive   # liveness
curl -fsS http://localhost:8081/api/admin/health/readyz  # readiness
```

| Check | Comando/URL | Esperado | Se não bater, checar primeiro |
|---|---|---|---|
| Pod | `kubectl get pods -n <ns>` | `Running`, `1/1` | `0/1` sem pod → bug de namespace da SA (seção 5); `CreateContainerConfigError` → Secret ausente; `CrashLoopBackOff` → log indica a variável faltante |
| Liveness | `curl …/api/admin/health/alive` | `200` | Container de pé mas não servindo → conferir se `MIDAZ_CONSOLE_PORT`/`service.port` batem (8081) |
| Readiness | `curl …/api/admin/health/readyz` | `200` | Não fica Ready → quase sempre o console não alcança o MongoDB (seção 5) |
| `TRUSTED_PROXIES` caiu | `kubectl get cm product-console -n <ns> -o jsonpath='{.data.TRUSTED_PROXIES}'` | seu CIDR | Vazio/ausente num chart anterior à #2120 → chave descartada em silêncio; bumpar o chart |
| Auth ativo | request sem token numa rota protegida | `401`/`403` | `200` → `PLUGIN_AUTH_ENABLED` não é o literal `true` (seção 5) |
| UI acessível | host do ingress / port-forward | login ou app carrega | 502/504 → `proxy-buffer-size` do ingress pequeno pro payload Next.js (o env de referência aumenta) |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Fix |
|---|---|---|
| Release "instalado", Deployment travado em `Replicas: 0/1`, sem pod | `namespaceOverride` + chart onde a ServiceAccount não pina namespace → SA cai no namespace de release, pods a exigem no namespace do override | Usar versão do chart que pina o namespace da SA (#2120), ou limpar `namespaceOverride` |
| Pod roda mas nunca fica Ready | Console não alcança o MongoDB — em geral Mongo embutido + `namespaceOverride`, ou `MONGO_HOST` apontando pra nome que não resolve | Usar Mongo externo, ou alinhar `MONGO_HOST` ao `<release>-mongodb` real no namespace de release |
| Páginas abrem sem checagem de permissão / chamadas de saída sem bearer | Autorização OFF: o `PLUGIN_AUTH_ENABLED` renderizado não é o literal `true` | Setar `global.auth.enabled: "true"` (ou chave nativa); confirmar com request sem token |
| Servidor aplica auth mas o browser não (ou vice-versa) | `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` numa palavra não-`true`, usada literal e nunca reconciliada com o servidor | Deixar a chave do browser vazia, ou setar as duas em `true` |
| `TRUSTED_PROXIES` setado mas o allowlist de IP do tenant nunca aplica | Num chart anterior à #2120 a chave é aceita e descartada; ou o valor está vazio; ou um range largo demais confia o caller real pra fora | Bumpar pra um chart que renderiza a chave (confirmar no ConfigMap), e manter o range estreito |
| `502`/`504` na UI pelo ingress | Resposta do Next.js maior que o buffer de proxy do ingress | Aumentar `nginx.ingress.kubernetes.io/proxy-buffer-size` (env de referência usa `512k`) |
| Falhas de handshake TLS do Mongo no DocumentDB | `MONGO_PARAMETERS` sem o formato de TLS gerenciado | Setar `global.cloud: aws` (aplica o preset DocumentDB) em vez de escrever params na mão |
