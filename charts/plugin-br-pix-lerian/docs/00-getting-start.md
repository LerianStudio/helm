# plugin-br-pix-lerian — Getting Started Runbook

> Preenchido a partir do chart (`README.md`, `values.schema.json`, templates) e da
> config real em `lerian-internal-gitops/environments/benedita/helmfile/applications/dev-st/plugin-br-pix-lerian`.
> Critério de aceite: alguém de fora da squad, só com o chart + este runbook, instala uma
> versão funcional e sabe o que checar quando algo quebra.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `plugin-br-pix-lerian` (chart 1.0.0 / app `1.0.0-beta.337`) |
| Squad responsável | Pix Lerian |
| Última revisão deste runbook | 2026-09-14, contra chart 1.0.0 |
| Contato de escalação | squad Pix Lerian (ver CODEOWNERS do chart) |

---

## 1. Profiles de instalação

O chart não tem um flag "profile" — o profile é a combinação de quais dos 14 workloads
você habilita. **O default do `helm template` sem values não é uma instalação
funcional**: 6 dos 14 workloads vêm desligados, nenhum DSN de Postgres é setado (logo
nenhum Job de migração renderiza), Postgres/Valkey/RabbitMQ e as 3 ingresses estão OFF,
e `LICENSE_KEY` vazio com `DEPLOYMENT_MODE=byoc` (default) faz a app se recusar a subir.

| Profile | Componentes habilitados | Caso de uso | Default recomendado? |
|---|---|---|---|
| SPI only | `spi` + `spiSystemplane` | Só iniciação/liquidação Pix | Não — é o piso mínimo, não o alvo |
| SPI + DICT + COB (produção real) | `spi`+`spiSystemplane`, `dictHub`+`dictSystemplane` (+`dictHubVsync` se precisar reconciliação), `cobHub`+`cobSystemplane` | Topologia de produção documentada no README | **Sim** |
| + Pix Automático | acima + `pixauto`+`pixautoSystemplane` | Se o produto oferece Pix Automático (payer side) | Opcional |
| Dev/homologação com provider mock | acima + `adapterProviderMock` | Testar ponta a ponta sem provider real | Só em dev — nunca em BYOC/SaaS (sem auth nas rotas) |

- [x] Existe profile mínimo sem integrações externas opcionais? Não totalmente — mesmo o
      mínimo (`spi`) exige Postgres (`pix-spi`) e `LICENSE_KEY`+`ORGANIZATION_IDS` fora do modo `local`.
- [x] Cada componente aparece em algum profile? `dictProxy`/`cobProxy` (tier proxy) e
      `adapterLerian`/`adapterLerianSystemplane` **não aparecem em nenhum profile de
      produção** — proxy é "estrutural apenas" nesta release (sem forwarding real) e
      `adapterLerian` é **Development only** (crash-loop fora de `DEPLOYMENT_MODE=local`).

---

## 2. Dependências externas

| Dependência | Obrigatória? | Requisitos mínimos | Como o chart recebe |
|---|---|---|---|
| PostgreSQL | Sim, por domínio habilitado | 5 databases possíveis no total: `pix-spi`, `pix-dict`, `pix-cob`, `pix-adapter-lerian`, `pix-pixauto` — só cria/migra as dos workloads habilitados | `DATABASE_URL` / `SYSTEMPLANE_POSTGRES_DSN` em `secrets` (ou Secret externo via `useExistingSecret`) |
| Valkey/Redis | Depende do workload — **obrigatório** em `dictHubVsync` e `adapterLerian` (quando habilitado); opcional (degrada) em `spi`/`dictHub`/`cobHub`/`pixauto` | — | Masked via `global.datastores.redis` (host/port/user/db/tls) — ver seção 4 |
| RabbitMQ | **Obrigatório** se `dictHubVsync` habilitado (o chart **falha o render** sem `RABBITMQ_URI`); opcional/publish-only em `dictHub` | — | `RABBITMQ_URI` em `secrets`, hoje só setado nativamente em `dictHubVsync` |
| Streaming (Kafka/Redpanda) | Opcional, off por default | `spi`, `dictHub`, `cobHub`, `pixauto` podem emitir CloudEvents | Masked via `global.streaming` — ver seção 4. **`STREAMING_CLOUDEVENTS_SOURCE` deve ficar vazio**: um valor que não bate com o source interno da app recusa o boot, streaming habilitado ou não |
| MongoDB | **Não usado** — confirmado (nenhum template referencia Mongo) | — | — |
| `plugin-access-manager` (auth) | Opcional por default, mas **exigido em produção** (ver seção 5) | Endpoint HTTP resolvível | `PLUGIN_AUTH_ENABLED` + `PLUGIN_AUTH_HOST`, masked via `global.auth` |
| Vault / secret manager | Sim, para produção | — | `useExistingSecret: true` + `existingSecretName` por componente — **sem merge**, o Secret externo precisa ter TODAS as chaves daquele workload |
| Streaming Hub (callbacks) | Externo a este chart | — | Este chart **não configura callback nenhum** — publica no broker via `lib-streaming`; o Streaming Hub resolve subscrições e faz o callback HTTP |

- [x] Dá pra rodar local/dev sem provider real? Sim — `adapterProviderMock` (ver seção 5,
      é uma porta aberta sem auth, nunca habilitar fora de dev).
- [x] Alguma dependência exige dado pré-existente? As 5 databases precisam existir com o
      role de conexão correto — o chart cria/roda migração, não cria o database em si.
      Ver [Database bootstrap and migrations](../README.md#database-bootstrap-and-migrations) no README do chart.

---

## 3. Ordem de instalação

1. Provisionar os databases Postgres necessários para os domínios que serão habilitados
   (`pix-spi`, `pix-dict`, `pix-cob`, e opcionalmente `pix-adapter-lerian`/`pix-pixauto`).
2. Criar os Secrets externos por workload (`useExistingSecret`) com o conjunto completo
   de chaves exigidas — **antes do `helm install`**, porque os hooks de migração correm
   primeiro e dependem deles.
3. Definir `LICENSE_KEY` e `ORGANIZATION_IDS` em todo workload que constrói um client de
   licença (`spi`, `dictHub`, `dictProxy`, `dictHubVsync`, `cobHub`, `cobProxy`,
   `pixauto`, `adapterLerian`) — sem isso a app sai no boot. **Atenção**: o
   `values.yaml` de exemplo do chart só seta `ORGANIZATION_IDS` em `adapterLerian` e
   `pixauto` — os outros 6 precisam ser adicionados manualmente se você partir do default.
4. `helm install` (não há upgrade in-place de chart anterior — é sempre instalação nova).
5. Se algum hub de domínio ficou desabilitado, aplicar o schema daquele domínio por
   outro meio — desabilitar um hub remove o único Job de migração daquele schema.
6. Configurar identidade single-tenant (`ORGANIZATION_ID`, `ISPB`) tanto na app do
   domínio quanto no seu Systemplane correspondente — o Systemplane semeia a store e a
   app lê de volta; sem isso a app fica `Ready` mas não funcional.
7. Se for multi-tenant, provisionar a configuração por tenant separadamente — seeding a
   partir do ambiente **não corre** em multi-tenant.

- [x] Passo manual fora do Helm? Sim — provisionamento de tenant em multi-tenant (passo
      7) e criação dos databases (passo 1) são fora do Helm.
- [x] Ordem errada = erro claro ou falha silenciosa? **Maioria é falha silenciosa**: um
      hub desabilitado não migra o schema sem aviso; `ORGANIZATION_ID` ausente em
      `pixauto` retorna `403 TENANT_CONFIG_NOT_FOUND` em runtime, não no boot; ver seção 5.

---

## 4. Contrato de configuração compartilhada (masks / lerian-common)

Este chart usa `lerian-common`. Os campos abaixo já estão consolidados como mask no
values de `benedita/dev-st` (PR #2809) e devem ser o padrão para qualquer novo ambiente:

```yaml
global:
  datastores:
    redis:
      host: ""
      port: "6379"
      user: "default"
      db: "0"
      tls: "false"
  auth:
    enabled: "true"     # PLUGIN_AUTH_ENABLED em todos os componentes
    host: ""             # PLUGIN_AUTH_HOST
  streaming:
    brokers: ""
    tlsEnabled: "true"
    saslMechanism: "SCRAM-SHA-256"
    saslAllowPlaintext: "false"
```

| Campo global | Efeito | Componentes afetados | Pode sobrescrever por componente? |
|---|---|---|---|
| `global.datastores.redis.*` | `REDIS_HOST`/`PORT`/`USER`/`DB`/`TLS` | `spi`, `dictHub`, `dictHubVsync`, `cobHub`, `pixauto` (os que leem Valkey) | Sim, via `<component>.configmap.REDIS_*` — só faça isso se aquele componente **precisar** de um Redis diferente (não é o caso hoje) |
| `global.auth.enabled` / `.host` | `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` | Todos os 14 componentes que leem o toggle | Sim, mesmo esquema — mas ver seção 5 antes de desligar em algum componente |
| `global.streaming.*` | `STREAMING_BROKERS`/`TLS_ENABLED`/`SASL_MECHANISM`/`SASL_ALLOW_PLAINTEXT` | `spi`, `dictHub`, `cobHub`, `pixauto` | Sim — mas **não** mascare `STREAMING_TENANT_ID`/`STREAMING_CLOUDEVENTS_SOURCE`: `pixauto` precisa manter esses dois nativos (seu template não tem fallback igual aos outros 3; default de `cloudeventsSource` é `""` em vez de `"plugin-br-pix-lerian"`) |

**Campos que parecem mask-elegíveis mas não são:**

- `REDIS_PROTOCOL` — não existe mais nenhum template que leia essa chave; é morta, não
  mascarada.
- `OTEL_EXPORTER_OTLP_ENDPOINT_PORT` — confirmado morta (`grep` no chart inteiro não
  acha leitor). O endpoint real de OTLP vem de `HOST_IP` via
  `lerian-common.otel.podEnv`, não dessa chave.
- `global.image.tag` — o schema aceita a chave e a **ignora**. Não existe imagem
  compartilhada; cada componente pina a própria tag em `<component>.image.tag`.

**Regra "duas chaves precisam bater e nada garante isso":**

- Ao habilitar `dictProxy`/`cobProxy`, o "routing mode" em um **caller** (`spi` tem
  modo para DICT e para COB; `cobHub` tem modo para DICT) precisa bater com o
  `*_BASE_URL` correspondente. Um mismatch **não é pego no boot** — o modo só decide
  qual nome de serviço o caller resolve. Mantenha os dois no mesmo tier.

---

## 5. Comportamentos perigosos / modos de falha silenciosa

Esta é a seção mais importante. Uma linha aqui evita produção quebrada silenciosamente.

| Flag / configuração | Comportamento perigoso | Pré-requisito antes de ativar | Como saber que deu errado |
|---|---|---|---|
| `PLUGIN_AUTH_ENABLED` vs `IDP_DECLARATION_ENABLED` (`pixauto`) | São **gates diferentes que parecem a mesma coisa**. `PLUGIN_AUTH_ENABLED` autentica requests entrantes. `IDP_DECLARATION_ENABLED` controla se `pixauto` **publica** sua declaração de permissão/Casbin no `plugin-access-manager` — requer a aplicação M2M já registrada para o slug daquele componente. Se não estiver registrada, o publisher **falha aberto e pula a publicação em silêncio** (sem erro, sem log de falha visível), e nesse estado o próprio auth pode responder 422 nas chamadas que dependem da declaração | Registrar a aplicação M2M de `pixauto` no `plugin-access-manager` **antes** de habilitar `IDP_DECLARATION_ENABLED` | Não há alerta automático — validar manualmente que a declaração foi aceita no `plugin-access-manager` para o slug de `pixauto` antes de confiar no toggle |
| `PLUGIN_AUTH_ENABLED=false` (default) | Superfície de negócio **sem autenticação**, sem erro nenhum — a app sobe normal | Nenhum — é o default; por isso o benedita/dev-st agora força `true` em todos os 14 componentes via mask | Não há sinal automático — é preciso auditar `global.auth.enabled` explicitamente |
| Rotear tráfego pra `dictProxy`/`cobProxy` | Toda rota de negócio responde **404**, mas `health`/`readyz` continuam **200** — monitoramento fica verde com o rail morto | Nenhum — proxy nesta release é estrutural apenas, sem forwarding | Testar uma transação real, não só o probe |
| Desabilitar um hub (`dictHub`/`cobHub`/`spi`) | Remove o **único** Job de migração daquele domínio — o schema nunca é aplicado, mesmo que os workloads restantes (proxy/systemplane) ainda usem o database | Aplicar o schema daquele domínio por outro meio antes de subir os workloads restantes | Nenhum erro de boot — só falha na primeira query que precisar do schema ausente |
| `STREAMING_CLOUDEVENTS_SOURCE` não-vazio e divergente do source interno | Recusa o boot **mesmo com streaming desabilitado** | Deixar vazio, sempre, exceto em `pixauto` onde é intencionalmente diferente | `CrashLoopBackOff` no boot, log nomeia a variável |
| `adapterLerian` habilitado fora de `DEPLOYMENT_MODE=local` | Crash-loop imediato — o workload se recusa a subir | Manter `enabled: false` fora de ambiente local | `CrashLoopBackOff`; ship default já é `disabled` então isso só acontece se alguém habilitar manualmente |
| `adapterProviderMock` habilitado | Suas rotas **não têm autorização, independente de `PLUGIN_AUTH_ENABLED`** | Nunca habilitar onde callers não controlados alcancem o pod; nunca publicar em ingress compartilhado | Nenhum — é responsabilidade de quem habilita restringir a rede |
| `ORGANIZATION_ID` vazio em `pixauto` (single-tenant) | Toda request responde **403 `TENANT_CONFIG_NOT_FOUND`** — pod fica `Ready`, parece saudável | Setar `ORGANIZATION_ID` (a app tenta a Systemplane store primeiro, cai pro configmap depois) | Só aparece na primeira request real, não no boot/readiness |
| Mudar chave "boot-captured" (identidade, URLs, toggle de auth, pool de Postgres) via API administrativa do Systemplane | **Não tem efeito até reiniciar o pod** — a API aceita a mudança mas o processo continua com o valor antigo em memória | — | Comparar o valor lido pela API vs comportamento real; se divergir, é sinal de boot-captured pendente de restart |

- [x] Duas flags com nome parecido controlando coisas diferentes? Sim —
      `PLUGIN_AUTH_ENABLED` × `IDP_DECLARATION_ENABLED`, documentado acima como a
      entrada mais importante desta tabela.
- [x] Existe fail-open em vez de fail-closed? Sim — o publisher de `IDP_DECLARATION_ENABLED`
      e o Job de migração ausente são os dois casos "continua rodando, ação pulada
      silenciosamente" identificados até agora.

---

## 6. Como validar que subiu certo

```bash
kubectl get pods -n <namespace>
kubectl get jobs -n <namespace>   # confirmar que o Job de migração de cada domínio habilitado rodou e completou
curl <spi-url>/healthz
curl <spi-url>/readyz             # readyz reflete estado real de dependência, não só liveness
```

| Check | Comando/URL | Esperado | Se falhar, checar primeiro |
|---|---|---|---|
| Pods de todos os workloads habilitados | `kubectl get pods -n <ns>` | `Running` | `CreateContainerConfigError` → secret ausente; `CrashLoopBackOff` → log da variável faltante |
| Migration Jobs | `kubectl get jobs -n <ns>` | `Complete` para cada domínio habilitado | Job ausente = hub desabilitado sem schema aplicado (seção 5) |
| Readiness real (não só probe) | `curl <hub>/readyz` | 200, sem `required_keys` pendente no body | Body lista as chaves que a Systemplane store ainda não tem — não é a mesma coisa que variável de ambiente ausente |
| Auth ativo | request de negócio sem token contra um hub | 401/403, não 200 | Se passar sem token, `PLUGIN_AUTH_ENABLED` não está de fato `true` naquele componente |
| Proxy não está recebendo tráfego real | request de negócio contra `dictProxy`/`cobProxy` | 404 (esperado — não é bug) | Se você esperava 200, revise se deveria estar em hub, não proxy |
| Transação ponta a ponta | fluxo real via `spi` (ou `adapterProviderMock` em dev) | Sucesso completo, não só `200` de health | — |

- [x] Existe teste ponta a ponta, não só health check? Sim, via `adapterProviderMock` em
      dev/homologação; em produção depende do provider real conectado.

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa real | Fix |
|---|---|---|
| `403 TENANT_CONFIG_NOT_FOUND` em toda request | Configuração daquele tenant/organização ausente na Systemplane store (single-tenant: `ORGANIZATION_ID`/`ISPB` não setados; multi-tenant: tenant nunca provisionado) | Setar a identidade (single-tenant) ou provisionar o tenant explicitamente (multi-tenant) — não é um problema de rede/auth |
| Pod `Ready` mas toda request de negócio falha, sem log de erro | Rota apontando para `dictProxy`/`cobProxy` em vez do hub, ou hub com schema não migrado | Confirmar routing mode e se o Job de migração daquele domínio completou |
| `CrashLoopBackOff`, log cita `LICENSE_KEY`/`ORGANIZATION_IDS` | Workload constrói client de licença e uma das duas está vazia | Setar ambas — 8 workloads exigem: `spi`, `dictHub`, `dictProxy`, `dictHubVsync`, `cobHub`, `cobProxy`, `pixauto`, `adapterLerian` |
| Render falha citando `RABBITMQ_URI` | `dictHubVsync` habilitado sem `RABBITMQ_URI` em `secrets` | Setar `RABBITMQ_URI` antes de habilitar `dictHubVsync` |
| `CrashLoopBackOff` em `adapterLerian` fora de ambiente local | `DEPLOYMENT_MODE` diferente de `local` com o componente habilitado | Manter desabilitado fora de dev, ou setar `DEPLOYMENT_MODE=local` só nesse componente (não recomendado fora de dev) |
| Mudança feita na API administrativa do Systemplane "não pegou" | Chave é boot-captured (identidade, URLs, toggle de auth, pool de conexão) | Reiniciar o pod do workload afetado |

---

## Checklist final antes de publicar este runbook

- [x] Conteúdo real em toda seção, sem placeholder vazio.
- [x] Datas de "última revisão" batem com chart 1.0.0 (esta versão).
- [ ] Alguém de fora da squad Pix Lerian leu e conseguiu seguir sem perguntar no Slack —
      **pendente de validação externa**, este runbook ainda não foi testado por alguém de fora.
