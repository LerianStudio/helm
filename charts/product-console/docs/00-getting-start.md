# product-console — Runbook de instalação

> Preenchido a partir do chart (`README.md`, `values.yaml`, `templates/`).
> Objetivo: alguém de fora da squad, só com o chart + este runbook, consegue instalar
> uma versão funcional e sabe o que checar caso algo não se comporte como esperado.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `product-console` (chart `4.0.x` em diante; versão da app: `appVersion` no `Chart.yaml` / `image.tag` no `values.yaml`) |
| Tipo de chart | `single-service` — um único Deployment (UI Next.js + BFF do Midaz) |
| Squad responsável | Console / Frontend |
| Contato de escalação | Lerian Studio, support@lerian.studio (maintainer no `Chart.yaml`) |

O console é um workload único, não uma app multi-componente. Seu "perfil" não é *quais*
componentes você habilita (só existe um), e sim *para o que ele aponta*: os serviços
Lerian irmãos, o MongoDB onde guarda o estado do console, se a autorização está ligada, e
qual preset de nuvem gerenciada se aplica.

---

## 1. Perfis de instalação

| Perfil | Formato | Caso de uso |
|---|---|---|
| Demo standalone | MongoDB embutido (`mongodb.enabled: true`, default), `ingress.enabled: false`, auth desligado | Só local/experimentação. A imagem publicada não sobe com auth desligado (seção 5): setar `global.auth.enabled: "true"` aqui também. **Não** usar em nada exposto. |
| Dev/homolog integrado | MongoDB externo, ingress ligado, base paths dos irmãos apontando pros serviços reais no cluster, auth ligado | Ambiente compartilhado de desenvolvimento ou homologação |
| Produção | MongoDB gerenciado externo (DocumentDB via `global.cloud: aws`), ingress + TLS, auth ligado, `NEXTAUTH_SECRET` de um secret manager, `TRUSTED_PROXIES` nos endereços do ingress e dos load balancers na frente do console | Voltado ao cliente |

- O subchart de MongoDB embutido vem **habilitado por default** — conveniente pra demo,
  mas ver seção 5 (ele não é banco gerenciado).
  Produção deve setar `mongodb.enabled: false` e apontar pro Mongo externo.
- Não há eixo de "componentes" aqui; todo knob abaixo é um valor no único Deployment.

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| MongoDB | Sempre — o console guarda o próprio estado (cache de UI de organizações, settings) aqui | Subchart embutido (`mongodb.enabled: true`) **ou** externo via `MONGO_HOST`/`MONGODB_USER` em `configmap` + `MONGODB_PASS` em `secrets`, ou a mask `global.datastores.mongo` — seção 4 |
| `lerian-common` (library chart) | Sempre | Dependência do chart; fornece os templates HPA/PDB/Service/Ingress e as masks `global.*`. Nada a configurar. |
| Midaz ledger | Sempre (o console é UI dele) | `MIDAZ_BASE_PATH` / `MIDAZ_TRANSACTION_BASE_PATH` / `MIDAZ_V2_BASE_PATH` em `configmap` — default `midaz-ledger.midaz.svc.cluster.local:3002` |
| plugin-access-manager (auth + identity) | Obrigatório quando a autorização está ligada (recomendado em todo ambiente exposto) | `PLUGIN_AUTH_*` / `PLUGIN_IDENTITY_*` em `configmap`, client id/secret em `secrets` — seção 3 (ordem de instalação) |
| Serviços irmãos (Reporter, Tracer, Matcher, Flowker, Lender, Bank Transfer, Payments, …) | Só as features que você habilita na UI | Um `*_BASE_PATH` por serviço. `REPORTER_BASE_PATH` tem default in-cluster; `TRACER_BASE_PATH`, `MATCHER_BASE_PATH`, `FLOWKER_BASE_PATH` e `LENDER_BASE_PATH` são declaradas sem default; a chave de qualquer outro serviço vai por `extraEnvVars`. CRM e Fees são servidos pelo ledger via `MIDAZ_V2_BASE_PATH`. Uma feature com base path errado só quebra aquela feature, não o startup. |
| OTEL collector | Opcional (telemetria) | `otel.external: true` injeta `OTEL_URL_*`/`HOST_IP` pra um collector DaemonSet node-local; ou `ENABLE_TELEMETRY`/`global.observability` |
| Vault / gerenciador de segredo | Recomendado em produção | `useExistingSecret: true` + `existingSecretName`, ou refs Vault no bloco `secrets:` |

O console alcança o ledger, o Access Manager, o CRM e o Reporter por **FQDN in-cluster** (`<svc>.<ns>.svc.cluster.local`) já
de fábrica, então funcionam entre namespaces sem mesh/DNS — sobrescreva um `*_BASE_PATH`
só quando os nomes de serviço/namespace diferirem.

---

## 3. Ordem de instalação

1. Definir a estratégia de MongoDB: embutido (`mongodb.enabled: true`, só demo) **ou**
   externo (`mongodb.enabled: false` + `MONGO_HOST` real + `MONGODB_PASS`; `MONGODB_URI` é só o esquema, `mongodb` ou `mongodb+srv`).
   Pra Mongo gerenciado (DocumentDB) setar também `global.cloud: aws` pra aplicar
   automaticamente o formato da connection string TLS (seção 5).
2. Fornecer os secrets de produção obrigatórios **antes** do `helm install`: `secrets.NEXTAUTH_SECRET` (chave de assinatura do NextAuth — o console não sobe sem ela), `secrets.MONGODB_PASS` só com MongoDB externo (com o embutido, deixe vazio: o chart conecta a senha), e — quando auth ligado — `PLUGIN_AUTH_CLIENT_ID`/`_SECRET`.
3. Ligar a autorização **explicitamente** em qualquer ambiente exposto:
   `global.auth.enabled: "true"` (ou `configmap.PLUGIN_AUTH_ENABLED: "true"`). A
   imagem publicada do console recusa subir com a autorização desligada (sai com código 1) — ver seção 5.
4. Apontar os base paths inter-serviço pros serviços reais se os namespaces diferirem dos
   defaults (Midaz, access-manager, Reporter, …).
5. Setar `TRUSTED_PROXIES` nos endereços do ingress e dos load balancers na frente do console, como aparecem nos hops do `X-Forwarded-For` — nunca no CIDR de pod ou de Service (ver o README do chart, "Client IP resolution"). Vazio significa que nenhum client IP é resolvido, então o allowlist de IP do tenant não tem o que julgar (seção 5).
6. Configurar `ingress` (class, host, TLS) e setar `NEXTAUTH_URL` pra URL pública que o
   browser usa nos callbacks OAuth (default: primeiro host do ingress como `https://…`).
   Setar `configmap.ALLOWED_ORIGINS` explicitamente sempre que não houver host de ingress, ou a URL voltada ao browser diferir desse primeiro host do ingress (domínio custom, CDN, ou origens extras). O default é a origem do primeiro host do ingress, ou vazio sem ele — **não** o `NEXTAUTH_URL` — e o console recusa com `403` toda escrita (POST, PUT, PATCH, DELETE) vinda de uma origem fora da lista.
7. `helm install … -n product-console --create-namespace`. O chart vem com `namespaceOverride: product-console` e grava esse valor em todo recurso do console, então instale em `product-console` ou defina `namespaceOverride` com o namespace passado em `-n` (ver o README do chart).

---

## 4. Contrato de configuração compartilhada (masks / lerian-common)

O console consome masks do `lerian-common`: setar um valor **uma vez por ambiente** em
`global.*` e toda chave consumidora pega. Um `configmap.<KEY>` nativo sempre vence a mask.

```yaml
global:
  # Gate do Access Manager — LIGUE em qualquer ambiente exposto (default é OFF)
  auth:
    enabled: "true"
  # Telemetria
  observability:
    enabled: "true"
  # Conexão MongoDB env-wide (Mongo externo). MONGODB_DB_NAME fica por-app.
  datastores:
    mongo:
      host: ""
      port: "27017"
      user: ""
      # params: omita na AWS. Qualquer valor aqui, "" inclusive, sobrescreve o preset global.cloud: aws
  # Preset de nuvem gerenciada (connection string TLS do DocumentDB), aplicado quando
  # nada mais específico sobrescreve. gcp/azure não têm preset de Mongo hoje.
  cloud: "aws"
```

| Campo global | Efeito (env var) | Chave nativa que sobrescreve |
|---|---|---|
| `global.auth.enabled` | `PLUGIN_AUTH_ENABLED` | `configmap.PLUGIN_AUTH_ENABLED` |
| `global.observability.enabled` | `ENABLE_TELEMETRY` | `configmap.ENABLE_TELEMETRY` |
| `global.datastores.mongo.{uri,host,port,user,params}` | `MONGODB_URI`/`MONGO_HOST`/`MONGO_PORT`/`MONGODB_USER`/`MONGO_PARAMETERS` | o `configmap.<KEY>` correspondente |
| `global.cloud: aws` | Seta `MONGO_PARAMETERS` no formato DocumentDB (`tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&…`) | `configmap.MONGO_PARAMETERS` ou `global.datastores.mongo.params` |

O console não lê `PLUGIN_AUTH_HOST`: setar `configmap.PLUGIN_AUTH_BASE_PATH` pra mudar o endereço do Access Manager.

**Todo default de `configmap.<KEY>` vive em `templates/configmap.yaml`** (como
`KEY | default "…"`), nunca no `values.yaml` — o map `configmap:` vem vazio. Setar uma
chave lá só pra sobrescrever um default de fábrica.

**`TRUSTED_PROXIES` é uma chave `configmap` comum** (não é mask): só renderiza no
ConfigMap nas versões do chart que carregam a chave allowlistada (chart 4.1.0 em diante). Em charts anteriores a chave é aceita por `helm lint`/`template` e
**silenciosamente descartada** — setar e confirmar que caiu (seção 6).

---

## 5. Pontos de atenção operacional

| Tópico | O que saber | Antes de habilitar / como confirmar |
|---|---|---|
| **Autorização é OFF por default** | O console aplica permissões só quando o valor renderizado é a palavra literal `true` (`PLUGIN_AUTH_ENABLED` no servidor, `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` no browser). `false`/vazio/`1`/`TRUE`/`yes` leem como OFF. A imagem publicada recusa subir quando `PLUGIN_AUTH_ENABLED` e `OAUTH_ENABLED` não são `true` (`[startup] FATAL`, exit 1), então o default `false` do chart entra em crash-loop em vez de servir um console aberto. | Setar `global.auth.enabled: "true"` (ou a chave nativa) em todo release staging/prod. Confirmar com request sem token → deve ser 401/403. |
| **Split auth servidor × browser** | A chave do browser copia o valor do servidor só enquanto `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` está vazia. Uma chave de browser não-vazia é usada literal e nunca reconciliada com o servidor — `"TRUE"` ao lado de um servidor ligado dá servidor ON / browser OFF. | Deixar a chave do browser vazia, ou setar as duas na palavra exata `true`. |
| **`NEXTAUTH_SECRET` é obrigatório** | A imagem publicada recusa subir com ele vazio (`[startup] FATAL`, exit 1). | Fornecer via `secrets` / secret manager antes do install. |
| **`TRUSTED_PROXIES` vazio = nenhum client IP** | Vazio significa que nenhum hop do `X-Forwarded-For` é acreditado, então o allowlist de IP do tenant não tem o que julgar, e as chamadas de saída levam `X-Client-Ip-Resolution: unresolved; reason=trusted-proxies-not-configured`. | Setar nos endereços do ingress e dos load balancers na frente do console, nunca no CIDR de pod ou de Service (ver o README do chart, "Client IP resolution"). **Não alargue** — um range que cobre callers reais os esconde. |
| **MongoDB embutido e namespaces** | O `MONGO_HOST` default é o FQDN do Service do MongoDB embutido. O chart conecta a senha só enquanto o subchart e o console dividem um namespace, o que `-n product-console` com `global.namespaceOverride` vazio garante. | Num split de namespace, seguir o README do chart, "MongoDB and readiness". |
| **Namespace da ServiceAccount** | Em charts antes do fix (LerianStudio/helm #2120), `templates/serviceaccount.yaml` não pinava namespace, então com `namespaceOverride` a SA caía no namespace de release enquanto os pods a pediam no namespace do override → pods nunca criados (`Replicas: 0/1`). | Usar versão do chart que pina o namespace da SA, ou deixar `namespaceOverride` vazio. |
| **Preset de nuvem gerenciada** | `global.cloud: aws` auto-seta o formato `MONGO_PARAMETERS` do DocumentDB quando nada mais específico sobrescreve. `gcp`/`azure` não têm preset de Mongo hoje. | No DocumentDB, não escreva `MONGO_PARAMETERS` na mão — deixe o preset aplicar. |
| **⚠️ O preset AWS pula a verificação do cert do Mongo** | O preset `global.cloud: aws` inclui `tlsInsecure=true` — TLS ligado mas o certificado do servidor DocumentDB **não é verificado** (aberto a MITM). É um default de conveniência, **não seguro por si só pra produção**. | Numa produção security-strict, remova `tlsInsecure=true` de `configmap.MONGO_PARAMETERS` e entregue o CA bundle ao console como `MONGO_TLS_CA_CERT` (base64 do PEM) em `secrets`. Este chart não tem valor que monte arquivo. |
| **`otel.external` não instala collector** | `otel.external: true` injeta `HOST_IP`/`OTEL_URL_*` pra um collector DaemonSet node-local; não instala collector. | Apontar pra um collector real, ou setar `ENABLE_TELEMETRY: "false"` se não houver. |

---

## 6. Como validar que subiu certo

```bash
kubectl get pods -n <namespace>
kubectl get deploy,svc,cm -n <namespace> -l app.kubernetes.io/name=product-console
# endpoints de health (servidos pelo BFF na porta do service, 8081):
kubectl -n <namespace> port-forward svc/product-console 8081:8081 &
# aguarde (limitado, ~30s) o forward antes do curl — evita um connection-refused
# transitório sem travar pra sempre se o pod nunca subir:
for i in $(seq 1 30); do curl -fsS --max-time 2 http://localhost:8081/api/admin/health/alive >/dev/null 2>&1 && break; sleep 1; done
curl -fsS http://localhost:8081/api/admin/health/alive   # liveness
curl -fsS http://localhost:8081/api/admin/health/readyz  # readiness
```

| Check | Comando/URL | Esperado | Se não bater, checar primeiro |
|---|---|---|---|
| Pod | `kubectl get pods -n <ns>` | `Running`, `1/1` | `0/1` sem pod → bug de namespace da SA (seção 5); `CreateContainerConfigError` → Secret ausente; `CrashLoopBackOff` → log indica a variável faltante |
| Liveness | `curl …/api/admin/health/alive` | `200` | Container de pé mas não servindo → conferir se `service.port` é 8081, a porta em que a imagem escuta |
| Readiness | `curl …/api/admin/health/readyz` | `200` | Não fica Ready → quase sempre o console não alcança o MongoDB (seção 5) |
| `TRUSTED_PROXIES` caiu | `kubectl get cm product-console -n <ns> -o jsonpath='{.data.TRUSTED_PROXIES}'` | seu CIDR | Vazio/ausente num chart anterior ao 4.1.0 → chave descartada em silêncio; bumpar o chart |
| Auth ativo | request sem token numa rota protegida | `401`/`403` | `200` → `PLUGIN_AUTH_ENABLED` não é o literal `true` (seção 5) |
| UI acessível | host do ingress / port-forward | login ou app carrega | 502/504 → `proxy-buffer-size` do ingress pequeno pro payload Next.js |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Fix |
|---|---|---|
| Release "instalado", Deployment travado em `Replicas: 0/1`, sem pod | `namespaceOverride` + chart onde a ServiceAccount não pina namespace → SA cai no namespace de release, pods a exigem no namespace do override | Usar versão do chart que pina o namespace da SA (#2120), ou limpar `namespaceOverride` |
| Pod reinicia (`CrashLoopBackOff`), log `[startup] FATAL: [MongoDB] All connection attempts failed.` | O console não alcança ou não autentica no MongoDB no startup: tenta de novo e sai com código 1 | Conferir `MONGO_HOST` e `MONGODB_PASS` contra o README do chart, "MongoDB and readiness" |
| Páginas abrem sem checagem de permissão / chamadas de saída sem bearer | Autorização OFF: o `PLUGIN_AUTH_ENABLED` renderizado não é o literal `true` | Setar `global.auth.enabled: "true"` (ou chave nativa); confirmar com request sem token |
| Servidor aplica auth mas o browser não (ou vice-versa) | `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` numa palavra não-`true`, usada literal e nunca reconciliada com o servidor | Deixar a chave do browser vazia, ou setar as duas em `true` |
| `TRUSTED_PROXIES` setado mas o allowlist de IP do tenant nunca aplica | Num chart anterior ao 4.1.0 a chave é aceita e descartada; ou o valor está vazio; ou um range largo demais confia o caller real pra fora | Bumpar pra um chart que renderiza a chave (confirmar no ConfigMap), e manter o range estreito |
| `502`/`504` na UI pelo ingress | Resposta do Next.js maior que o buffer de proxy do ingress | Aumentar `nginx.ingress.kubernetes.io/proxy-buffer-size` |
| Falhas de handshake TLS do Mongo no DocumentDB | `MONGO_PARAMETERS` sem o formato de TLS gerenciado | Setar `global.cloud: aws` (aplica o preset DocumentDB) em vez de escrever params na mão |
