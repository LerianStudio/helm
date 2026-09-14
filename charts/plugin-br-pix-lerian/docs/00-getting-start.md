# plugin-br-pix-lerian — Runbook de instalação

> Preenchido a partir do chart (`README.md`, `values.schema.json`, templates) e da
> configuração de referência em
> `lerian-internal-gitops/environments/benedita/helmfile/applications/dev-st/plugin-br-pix-lerian`.
> Objetivo: alguém de fora da squad, só com o chart + este runbook, consegue instalar
> uma versão funcional e sabe o que checar caso algo não se comporte como esperado.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `plugin-br-pix-lerian` (chart 1.0.0 / app `1.0.0-beta.337`) |
| Squad responsável | Pix Lerian |
| Última revisão deste runbook | 2026-09-14, contra chart 1.0.0 |
| Contato de escalação | squad Pix Lerian (ver CODEOWNERS do chart) |

---

## 1. Perfis de instalação

O chart não expõe um flag único de "perfil" — o perfil é definido pela combinação de
quais dos 14 workloads você habilita. Um `helm template`/`helm install` sem values
customizados só valida a estrutura do chart; para uma instalação funcional é preciso
habilitar os workloads do seu caso de uso, apontar Postgres, e definir `LICENSE_KEY` +
`ORGANIZATION_IDS` conforme o `DEPLOYMENT_MODE` (ver seção 3).

| Perfil | Componentes habilitados | Caso de uso |
|---|---|---|
| SPI only | `spi` + `spiSystemplane` | Somente iniciação/liquidação Pix |
| SPI + DICT + COB | `spi`+`spiSystemplane`, `dictHub`+`dictSystemplane` (+`dictHubVsync` se precisar reconciliação), `cobHub`+`cobSystemplane` | Topologia de produção recomendada, descrita no [README do chart](../README.md#production-quickstart) |
| + Pix Automático | perfil acima + `pixauto`+`pixautoSystemplane` | Produto oferece Pix Automático (lado pagador) |
| Homologação com provider mock | perfil de produção + `adapterProviderMock` | Testar ponta a ponta sem o provider real — **restrito a ambientes de desenvolvimento/homologação controlados**, ver seção 5 |

- Cada perfil sempre inclui a app do domínio junto com sua Systemplane correspondente.
- `dictProxy`/`cobProxy` e `adapterLerian`/`adapterLerianSystemplane` existem para
  topologias específicas (provider já detém o estado do domínio, ou integração via
  adapter Lerian em ambiente local) — habilite-os apenas se sua topologia de provider
  exigir esse tier; ver [Hub e proxy não são intercambiáveis](../README.md#hub-and-proxy-are-not-interchangeable) no README do chart.

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| PostgreSQL | Por domínio habilitado — até 5 databases possíveis: `pix-spi`, `pix-dict`, `pix-cob`, `pix-adapter-lerian`, `pix-pixauto` | `DATABASE_URL` / `SYSTEMPLANE_POSTGRES_DSN` em `secrets`, ou Secret externo via `useExistingSecret` |
| Valkey/Redis | Obrigatório em `dictHubVsync` e em `adapterLerian` quando habilitado; opcional (com degradação de cache) em `spi`/`dictHub`/`cobHub`/`pixauto` | Mask `global.datastores.redis` (host/port/user/db/tls) — seção 4 |
| RabbitMQ | Obrigatório quando `dictHubVsync` está habilitado; publish-only opcional em `dictHub` | `RABBITMQ_URI` em `secrets` |
| Streaming (Kafka/Redpanda) | Opcional — `spi`, `dictHub`, `cobHub`, `pixauto` podem emitir CloudEvents | Mask `global.streaming` — seção 4. Deixe `STREAMING_CLOUDEVENTS_SOURCE` vazio (exceto em `pixauto`, que usa um valor próprio — ver seção 4) |
| MongoDB | Não utilizado por este chart | — |
| `plugin-access-manager` (auth) | Recomendado em qualquer ambiente exposto — ver seção 5 | Mask `global.auth` (`PLUGIN_AUTH_ENABLED` + `PLUGIN_AUTH_HOST`) |
| Vault / gerenciador de segredo | Recomendado em produção | `useExistingSecret: true` + `existingSecretName` por componente — o Secret externo precisa conter o conjunto completo de chaves daquele workload |
| Streaming Hub (callbacks) | Componente externo a este chart | Este chart publica eventos no broker via `lib-streaming`; o Streaming Hub resolve as subscrições e faz o callback HTTP — nenhuma URL de callback é configurada aqui |

Para desenvolvimento/homologação sem um provider real, use `adapterProviderMock` (seção 5).
As databases precisam existir com o role de conexão correto antes da instalação — o
chart aplica as migrações, não cria o database em si (ver
[Database bootstrap and migrations](../README.md#database-bootstrap-and-migrations)).

---

## 3. Ordem de instalação

1. Provisionar os databases Postgres dos domínios que serão habilitados.
2. Criar os Secrets externos por workload (`useExistingSecret`) com o conjunto completo
   de chaves daquele workload, antes do `helm install` — os hooks de migração
   consultam esses Secrets no início da instalação.
3. Definir `LICENSE_KEY` e `ORGANIZATION_IDS` nos workloads que constroem um client de
   licença: `spi`, `dictHub`, `dictProxy`, `dictHubVsync`, `cobHub`, `cobProxy`,
   `pixauto`, `adapterLerian`. O `values.yaml` de exemplo do chart só traz
   `ORGANIZATION_IDS` em `adapterLerian` e `pixauto` — complete os demais ao partir do
   default.
4. `helm install` (a instalação é sempre nova — não há caminho de upgrade in-place a
   partir de um chart anterior).
5. Se algum hub de domínio permanecer desabilitado, aplicar o schema daquele domínio
   por outro meio — o Job de migração só é renderizado para um hub habilitado.
6. Configurar a identidade single-tenant (`ORGANIZATION_ID`, `ISPB`) tanto na app do
   domínio quanto na sua Systemplane correspondente — a Systemplane semeia a store e a
   app lê de volta.
7. Em topologia multi-tenant, provisionar a configuração de cada tenant separadamente
   — o seeding a partir do ambiente não roda nesse modo (ver
   [Multi-tenant configuration](../README.md#multi-tenant-configuration)).

---

## 4. Contrato de configuração compartilhada (masks / lerian-common)

Este chart segue o contrato `lerian-common`. Os campos abaixo já estão consolidados
como mask no ambiente de referência `benedita/dev-st` e são o padrão recomendado para
qualquer novo ambiente:

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

| Campo global | Efeito | Componentes afetados |
|---|---|---|
| `global.datastores.redis.*` | `REDIS_HOST`/`PORT`/`USER`/`DB`/`TLS` | `spi`, `dictHub`, `dictHubVsync`, `cobHub`, `pixauto` |
| `global.auth.enabled` / `.host` | `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` | Todos os 14 componentes que leem o toggle |
| `global.streaming.*` | `STREAMING_BROKERS`/`TLS_ENABLED`/`SASL_MECHANISM`/`SASL_ALLOW_PLAINTEXT` | `spi`, `dictHub`, `cobHub`, `pixauto` |

Cada campo acima pode ser sobrescrito por componente via `<component>.configmap.<KEY>`
quando esse componente precisar de um valor diferente do global.

**Exceção conhecida:** mantenha `STREAMING_TENANT_ID` e `STREAMING_CLOUDEVENTS_SOURCE`
nativos (fora da mask) em `pixauto` — esse componente usa um valor próprio de
`cloudeventsSource`, diferente dos demais três componentes de streaming.

**Parâmetros de template que não são mask-eligible** (definir esses via `configmap`
não tem efeito, pois nenhum template os consome nesta versão): `REDIS_PROTOCOL`,
`OTEL_EXPORTER_OTLP_ENDPOINT_PORT` (o endpoint OTLP real é resolvido via `HOST_IP` pelo
próprio chart), `global.image.tag` (não existe imagem compartilhada; cada componente
pina sua própria tag em `<component>.image.tag`).

**Atenção a esta dependência entre dois campos:** ao habilitar `dictProxy`/`cobProxy`,
mantenha o "routing mode" de quem chama esse domínio (`spi` tem modo para DICT e para
COB; `cobHub` tem modo para DICT) no mesmo tier do `*_BASE_URL` correspondente — os dois
não são validados um contra o outro no boot.

---

## 5. Pontos de atenção operacional

| Tópico | O que saber | Antes de habilitar / como confirmar |
|---|---|---|
| `PLUGIN_AUTH_ENABLED` × `IDP_DECLARATION_ENABLED` (`pixauto`) | São dois controles independentes: `PLUGIN_AUTH_ENABLED` autentica requests entrantes; `IDP_DECLARATION_ENABLED` controla se `pixauto` publica sua declaração de permissão no `plugin-access-manager` | Registrar a aplicação M2M de `pixauto` no `plugin-access-manager` antes de habilitar `IDP_DECLARATION_ENABLED`. Validar no `plugin-access-manager` que a declaração foi aceita para o slug de `pixauto` |
| `PLUGIN_AUTH_ENABLED` | Controla autenticação nas rotas de negócio e M2M; default é `false` | Habilitar explicitamente (via mask `global.auth.enabled`) em qualquer ambiente exposto — recomendado em todos os 14 componentes |
| Tier proxy (`dictProxy`/`cobProxy`) | Nesta versão, atende apenas `health`, `readyz` e um OpenAPI sem operações de negócio | Não rotear tráfego de negócio para o proxy; usar o hub do domínio para tráfego real. Validar com uma transação de negócio, não só o probe |
| Desabilitar um hub (`dictHub`/`cobHub`/`spi`) | O Job de migração daquele domínio só é renderizado para um hub habilitado | Se o hub ficar desabilitado, aplicar o schema daquele domínio por outro meio antes de subir os demais workloads |
| `STREAMING_CLOUDEVENTS_SOURCE` | Precisa bater com o source interno da aplicação, streaming habilitado ou não | Deixar vazio, exceto em `pixauto` |
| `adapterLerian` | Espera `DEPLOYMENT_MODE=local`; é o adapter usado em desenvolvimento | Manter desabilitado (default) fora de ambiente local |
| `adapterProviderMock` | Suas rotas não têm autorização própria, independente de `PLUGIN_AUTH_ENABLED` | Habilitar somente em ambiente controlado, nunca em ingress compartilhado com callers não confiáveis |
| `ORGANIZATION_ID` em `pixauto` (single-tenant) | A app lê primeiro da Systemplane store, cai para este valor se a store estiver vazia | Definir `ORGANIZATION_ID` (ou seedar a store) antes de enviar tráfego — sem isso, requests retornam `403 TENANT_CONFIG_NOT_FOUND` |
| Chaves "boot-captured" na Systemplane (identidade, URLs, toggle de auth, pool de Postgres) | Mudanças feitas via API administrativa do Systemplane só têm efeito após reiniciar o pod | Reiniciar o workload afetado após qualquer mudança nessas chaves pela API |

---

## 6. Como validar que subiu certo

```bash
kubectl get pods -n <namespace>
kubectl get jobs -n <namespace>   # confirmar que o Job de migração de cada domínio habilitado completou
curl <spi-url>/healthz
curl <spi-url>/readyz
```

| Check | Comando/URL | Esperado | Se não bater, checar primeiro |
|---|---|---|---|
| Pods dos workloads habilitados | `kubectl get pods -n <ns>` | `Running` | `CreateContainerConfigError` → Secret ausente; `CrashLoopBackOff` → log indica a variável faltante |
| Migration Jobs | `kubectl get jobs -n <ns>` | `Complete` para cada domínio habilitado | Job ausente → hub daquele domínio está desabilitado (seção 5) |
| Readiness | `curl <hub>/readyz` | 200, sem `required_keys` pendente no corpo da resposta | O corpo lista as chaves que a Systemplane store ainda não tem |
| Auth ativo | request de negócio sem token contra um hub | 401/403 | Se retornar 200, confirmar que `PLUGIN_AUTH_ENABLED` está `true` naquele componente |
| Roteamento correto | request de negócio contra `dictProxy`/`cobProxy` | 404 (esperado nesta versão) | Se esperava 200, confirmar se o tráfego deveria ir para o hub |
| Transação ponta a ponta | fluxo real via `spi` (ou `adapterProviderMock` em homologação) | Sucesso completo |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Fix |
|---|---|---|
| `403 TENANT_CONFIG_NOT_FOUND` em toda request | Configuração do tenant/organização ausente na Systemplane store | Single-tenant: setar `ORGANIZATION_ID`/`ISPB`. Multi-tenant: provisionar o tenant explicitamente |
| Pod `Ready`, mas requests de negócio falham sem erro visível | Tráfego roteado para `dictProxy`/`cobProxy`, ou schema do hub não migrado | Confirmar routing mode e status do Job de migração daquele domínio |
| `CrashLoopBackOff` citando `LICENSE_KEY`/`ORGANIZATION_IDS` | Uma das duas está vazia num workload que constrói client de licença | Definir ambas nos 8 workloads listados na seção 3 |
| Render falha citando `RABBITMQ_URI` | `dictHubVsync` habilitado sem `RABBITMQ_URI` em `secrets` | Definir `RABBITMQ_URI` antes de habilitar `dictHubVsync` |
| `CrashLoopBackOff` em `adapterLerian` fora de ambiente local | `DEPLOYMENT_MODE` diferente de `local` com o componente habilitado | Manter desabilitado fora de dev, ou usar `DEPLOYMENT_MODE=local` apenas nesse componente |
| Mudança pela API administrativa da Systemplane "não pegou" | Chave é boot-captured | Reiniciar o pod do workload afetado |

---

## Checklist final antes de publicar este runbook

- [x] Conteúdo real em toda seção.
- [x] Datas de "última revisão" batem com a versão atual do chart (1.0.0).
- [x] Revisado para descrever comportamento operacional sem tom de crítica ao chart —
      cada item aqui é uma instrução de operação, não um apontamento de defeito.
