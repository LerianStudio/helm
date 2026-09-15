# reporter — Runbook de instalação

> Preenchido a partir do chart (`README.md`, `values.yaml`, `templates/`) e da
> configuração de referência em
> `lerian-internal-gitops/environments/benedita/helmfile/applications/dev-st/reporter`.
> Objetivo: alguém de fora da squad, só com o chart + este runbook, consegue instalar
> uma versão funcional e sabe o que checar caso algo não se comporte como esperado.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `reporter` (chart `4.3.x` / app `3.0.0`) |
| Tipo de chart | `multi-component` — `manager` (API) + `worker` (KEDA ScaledJob) |
| Squad responsável | Reporter |
| Última revisão deste runbook | 2026-09-15, contra chart `4.3.x` |
| Contato de escalação | squad Reporter (ver CODEOWNERS do chart) |

A geração de relatório é um pipeline: a API **manager** aceita a requisição e enfileira
no RabbitMQ; o **worker** (um Job escalado por KEDA, não um Deployment de longa duração)
drena a fila, consulta as datasources registradas, renderiza o documento e grava no
object storage (SeaweedFS/S3). O estado do manager fica no MongoDB.

---

## 1. Perfis de instalação

| Perfil | Formato | Caso de uso |
|---|---|---|
| Tudo embutido (dev) | MongoDB + RabbitMQ + SeaweedFS + Valkey + KEDA embutidos (todos `enabled: true`, default) | Local / experimentação. `ALLOW_INSECURE_TLS` default `true` porque a infra embutida roda sem TLS (seção 5). |
| Infra externa | `mongodb`/`rabbitmq`/`seaweedfs`/`valkey.enabled: false`, endpoints via `global.datastores`/`global.objectStorage`, KEDA embutido ou externo | Topologia de referência `benedita/dev-st` (Postgres/Mongo/Valkey/RabbitMQ gerenciados + S3 externo) |
| Nuvem gerenciada | `global.cloud: aws\|gcp\|azure` seta a topologia de conexão (TLS, path-style S3, e scheme/porta AMQP **só pra AWS** — ver §5); endpoints ainda de `global.*`; `ALLOW_INSECURE_TLS: "false"` | Voltado ao cliente |

- Os dois componentes sempre sobem juntos — o manager sem worker enfileira jobs que
  ninguém drena; o worker sem o manager não tem o que consumir.
- **KEDA é dependência dura** do worker (ele é um ScaledJob). Use o operador embutido
  (`keda.enabled: true`) ou externo (`keda.enabled: false` + `keda.external: true`) —
  mas ele precisa existir.

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| MongoDB | Sempre — estado do manager | Subchart embutido (Pattern A: app lê o Secret `<release>-mongodb` via `secretKeyRef` — deixe `MONGO_PASSWORD` vazio), **ou** externo via `global.datastores.mongo` + `secrets.MONGO_PASSWORD` |
| RabbitMQ | Sempre — fila de jobs manager→worker | Subchart groundhog2k embutido (Pattern B: broker aponta pro Secret da app via `rabbitmq.authentication.existingSecret`), **ou** externo + bootstrap de topologia opcional (`externalRabbitmqDefinitions`, seção 5) |
| SeaweedFS / S3 | Sempre — saída dos relatórios renderizados | Subchart embutido, **ou** externo via `global.objectStorage.s3` (endpoint/region/bucket) |
| Valkey / Redis | Sempre (cache) | Subchart embutido (auth **desligado** — sem `REDIS_PASSWORD`), ou externo via `global.datastores.redis` |
| KEDA | Sempre (worker é ScaledJob) | Operador embutido (`keda.enabled: true`) ou externo (`keda.external: true`) |
| **Datasources** de relatório (DBs onboarding/transaction do Midaz, DBs de plugins, qualquer DB externo) | Sempre — os dados que os relatórios leem | Chaves `DATASOURCE_<NAME>_*` em `common.configmap`; senhas em `secrets` — seções 4/5 |
| `lerian-common` (library chart) | Sempre | Dependência do chart; fornece templates + masks `global.*`. Nada a configurar. |
| plugin-access-manager (auth) | Quando a API do manager é exposta | `global.auth.host` / `PLUGIN_AUTH_*` |
| Vault / gerenciador de segredo | Recomendado em produção | `manager.useExistingSecret`/`worker.useExistingSecret` + `existingSecretName`, ou refs Vault em `secrets:` |

A datasource `onboarding` é a embutida; toda outra (transaction, DBs de plugins, DBs
externos) é registrada pelo operador — ver seção 4.

---

## 3. Ordem de instalação

1. Decidir embutido vs externo pra cada um de MongoDB / RabbitMQ / SeaweedFS / Valkey.
   Pra externo, setar `global.datastores.{mongo,redis,broker}` + `global.objectStorage.s3`
   (e `global.cloud` pro preset de TLS/topologia).
2. Fornecer os secrets obrigatórios **antes** do `helm install`:
   - `secrets.DATASOURCE_CRED_ENC_KEY` — chave AES hex (`openssl rand -hex 32`).
     **Obrigatória a partir do app 3.0.0** nos dois componentes, **precisa ser idêntica**,
     **não rotacionável**. O render falha se uma `image.tag >= 3.0.0` for setada e ela
     estiver vazia.
   - `secrets.DATASOURCE_ONBOARDING_PASSWORD` — a datasource onboarding embutida.
   - Com RabbitMQ embutido: `secrets.RABBITMQ_DEFAULT_PASS` e um
     `secrets.RABBITMQ_ERLANG_COOKIE` **estável** (`openssl rand -hex 32`; não pode mudar
     entre upgrades).
   - Senha do MongoDB: deixar vazia com o subchart embutido (single-source); setar
     `secrets.MONGO_PASSWORD` só pra Mongo externo.
3. Registrar as datasources de relatório: chaves de conexão `DATASOURCE_<NAME>_*` em
   `common.configmap`, com `DATASOURCE_<NAME>_PASSWORD` correspondente em `secrets`
   (seção 4).
4. Garantir KEDA disponível (embutido ou externo) — o worker não escala sem ele.
5. `ALLOW_INSECURE_TLS`: manter `"true"` pra infra embutida sem TLS (default); setar
   `"false"` em qualquer topologia com TLS/gerenciada (os presets de `global.cloud` fazem
   isso por você).
6. ClusterRole: o manager cria um ClusterRole+Binding (acesso a CRD/deployment). Se já
   existir de um install anterior, setar `manager.clusterRole.create: false`.
7. `helm install reporter … -n reporter --create-namespace`. Os **hosts de infra
   hardcoded** do chart (ex.: os defaults de `MONGO_HOST`/`RABBITMQ_HOST`) assumem release
   **`reporter`**; se renomear a release, sobrescreva esses hosts (seção 5). A ref de
   Secret `<release>-mongodb` **auto-segue** o nome da release (via
   `reporter.infraSecretRef`), então não precisa de mudança manual; o
   `rabbitmq.authentication.existingSecret` só precisa ser reapontado se você mudar
   `manager.name` / `manager.existingSecretName`.

---

## 4. Contrato de configuração compartilhada (masks / lerian-common) + datasources

Setar endpoints **uma vez por ambiente** em `global.*`; um `common.configmap.<KEY>` nativo
sempre vence a mask.

```yaml
global:
  cloud: "aws"          # aws|gcp|azure — seta topologia TLS/AMQP/S3; vazio = dev embutido
  datastores:
    mongo:  { host: "", port: "27017", user: "" }
    redis:  { host: ":6379" }            # host carrega host:port; REDIS_USER via mask
    broker: { host: "" }                 # RabbitMQ
  objectStorage:
    s3: { endpoint: "", region: "", bucket: "" }
  observability: { enabled: true }
  auth: { host: "" }                     # plugin-access-manager
```

| Campo global | Efeito | Chave nativa que sobrescreve |
|---|---|---|
| `global.datastores.mongo.*` | `MONGO_HOST`/`PORT`/`USER` (+ topologia de `global.cloud`) | `common.configmap.MONGO_*` |
| `global.datastores.redis.*` | `REDIS_HOST`/`REDIS_USER` | `common.configmap.REDIS_*` |
| `global.datastores.broker.*` | `RABBITMQ_HOST` (+ scheme/porta AMQP de `global.cloud`) | `common.configmap.RABBITMQ_*` |
| `global.objectStorage.s3.*` | `OBJECT_STORAGE_ENDPOINT`/region/bucket | `common.configmap.OBJECT_STORAGE_*` |
| `global.observability.enabled` | `ENABLE_TELEMETRY` | `common.configmap.ENABLE_TELEMETRY` |
| `global.auth.host` | `PLUGIN_AUTH_HOST` | `common.configmap.PLUGIN_AUTH_HOST` |

### 4.1 Datasources (as fontes de dados dos relatórios) — config obrigatória

Datasources são o que os relatórios de fato leem. São um **namespace aberto declarado**:
`DATASOURCE_<NAME>_<PROPERTY>` é aceito pelo `values.schema.json` estrito pra qualquer
`<NAME>` que você escolher (guard: `propertyNames: pattern ^DATASOURCE_...`), então você
registra datasources sem tocar no schema, enquanto um typo *fora* da família (ex.:
`REDIS_HOSTX`) ainda é rejeitado no `helm install`. Escolha um `<NAME>` maiúsculo único por
datasource (`ONBOARDING`, `TRANSACTION`, `SALES`, …). As chaves de conexão vão em
`common.configmap`; a `DATASOURCE_<NAME>_PASSWORD` correspondente vai em `secrets`.

**Obrigatórias por datasource** (`DATASOURCE_<NAME>_…`):

| Propriedade | Descrição | Exemplo |
|---|---|---|
| `CONFIG_NAME` | Nome lógico usado pra referenciar nos templates de relatório | `external_db` |
| `HOST` | Host ou IP do banco | `external-postgres.example.com` |
| `PORT` | Porta do banco | `5432` |
| `USER` | Usuário do banco | `db_user` |
| `PASSWORD` | Senha — **precisa estar em `secrets`**, não em `configmap` | `…` |
| `DATABASE` | Nome do banco | `external_database` |
| `TYPE` | Engine — `postgresql` ou `mongodb` | `postgresql` |

**Opcionais** (SQL): `SSLMODE` (default `disable`), `SSLROOTCERT` (default `""`),
`DB_SCHEMAS` (lista separada por vírgula, default `public`).
**Datasources MongoDB** usam adicionalmente `URI` (ex.: `mongodb`), `OPTIONS`
(ex.: `authSource=admin&directConnection=true&maxIdleTimeMS=60000`) e `MAX_POOL_SIZE` no
lugar das chaves SSL de SQL.

A datasource embutida **`ONBOARDING`** (o DB de onboarding do Midaz) é sempre registrada —
sua senha é `secrets.DATASOURCE_ONBOARDING_PASSWORD` (um secret obrigatório).

**Exemplo mínimo (uma datasource Postgres externa):**

```yaml
common:
  configmap:
    DATASOURCE_SALES_CONFIG_NAME: sales_db
    DATASOURCE_SALES_HOST: sales-postgres.example.com
    DATASOURCE_SALES_PORT: "5432"
    DATASOURCE_SALES_USER: sales_user
    DATASOURCE_SALES_DATABASE: sales
    DATASOURCE_SALES_TYPE: postgresql
    DATASOURCE_SALES_SSLMODE: require
    DATASOURCE_SALES_DB_SCHEMAS: sales,inventory   # opcional
secrets:
  DATASOURCE_SALES_PASSWORD: "…"
```

**Topologia de referência (`benedita/dev-st`) — várias datasources dos dois engines** lado
a lado, mostrando os formatos SQL e MongoDB:

```yaml
common:
  configmap:
    # SQL (Postgres do Midaz) — onboarding é a embutida
    DATASOURCE_ONBOARDING_CONFIG_NAME: midaz_onboarding
    DATASOURCE_ONBOARDING_HOST: postgresql.dev-st.lerian.net
    DATASOURCE_ONBOARDING_PORT: "5432"
    DATASOURCE_ONBOARDING_USER: midaz
    DATASOURCE_ONBOARDING_DATABASE: onboarding
    DATASOURCE_ONBOARDING_TYPE: postgresql
    DATASOURCE_ONBOARDING_SSLMODE: disable

    DATASOURCE_TRANSACTION_CONFIG_NAME: midaz_transaction
    DATASOURCE_TRANSACTION_HOST: postgresql.dev-st.lerian.net
    DATASOURCE_TRANSACTION_PORT: "5432"
    DATASOURCE_TRANSACTION_USER: midaz
    DATASOURCE_TRANSACTION_DATABASE: transaction
    DATASOURCE_TRANSACTION_TYPE: postgresql
    DATASOURCE_TRANSACTION_SSLMODE: disable

    # MongoDB (metadata / DBs de plugin) — note URI/OPTIONS/MAX_POOL_SIZE, sem SSLMODE
    DATASOURCE_ONBOARDING_METADATA_CONFIG_NAME: midaz_onboarding_metadata
    DATASOURCE_ONBOARDING_METADATA_URI: mongodb
    DATASOURCE_ONBOARDING_METADATA_HOST: mongodb.dev-st.lerian.net
    DATASOURCE_ONBOARDING_METADATA_PORT: "27017"
    DATASOURCE_ONBOARDING_METADATA_DATABASE: onboarding
    DATASOURCE_ONBOARDING_METADATA_USER: midaz
    DATASOURCE_ONBOARDING_METADATA_TYPE: mongodb
    DATASOURCE_ONBOARDING_METADATA_MAX_POOL_SIZE: "20"
    DATASOURCE_ONBOARDING_METADATA_OPTIONS: "authSource=admin&directConnection=true&maxIdleTimeMS=60000"

    DATASOURCE_FEES_CONFIG_NAME: plugin_fees
    DATASOURCE_FEES_URI: mongodb
    DATASOURCE_FEES_HOST: mongodb.dev-st.lerian.net
    DATASOURCE_FEES_PORT: "27017"
    DATASOURCE_FEES_DATABASE: plugin-fees-db
    DATASOURCE_FEES_USER: plugin-fees
    DATASOURCE_FEES_TYPE: mongodb
    DATASOURCE_FEES_OPTIONS: "authSource=admin&directConnection=true&maxIdleTimeMS=60000"

secrets:
  DATASOURCE_ONBOARDING_PASSWORD: "…"        # obrigatória (embutida)
  DATASOURCE_TRANSACTION_PASSWORD: "…"
  DATASOURCE_ONBOARDING_METADATA_PASSWORD: "…"
  DATASOURCE_FEES_PASSWORD: "…"
```

**Usando uma datasource num template de relatório** — referencie pelo `CONFIG_NAME`,
opcionalmente escopando o schema `config_name:schema.table`:

```
external_db:orders               # schema default (public)
external_db:sales.orders         # schema explícito
analytics_db:reports.monthly_summary
```

> ⚠️ `DATASOURCE_CRED_ENC_KEY` e toda `DATASOURCE_<NAME>_PASSWORD` vão em `secrets:`,
> **nunca** em `common.configmap:` — o escape-hatch do configmap aceita qualquer chave
> `DATASOURCE_*`, então uma credencial no lugar errado cai num ConfigMap em texto puro sem
> nenhum aviso.

**Todo default de `common.configmap.<KEY>`** vive nos templates, nunca no `values.yaml`.
Setar uma chave só pra sobrescrever um default de fábrica.

---

## 5. Pontos de atenção operacional

| Tópico | O que saber | Antes de habilitar / como confirmar |
|---|---|---|
| **`DATASOURCE_CRED_ENC_KEY` (app ≥ 3.0.0)** | Chave AES hex que criptografa as credenciais de datasource registradas em repouso. **Idêntica** no manager + worker, **não rotacionável** nessa release. Render falha se uma `image.tag >= 3.0.0` for setada e ela estiver vazia. | Gerar uma vez (`openssl rand -hex 32`), guardar num secret manager, setar o mesmo valor nos dois componentes. |
| **`ALLOW_INSECURE_TLS` default `true`** | O mongo/redis/rabbitmq embutidos rodam sem TLS e a app dá hard-fail ("TLS required") sem esse bypass, então um install sem override funciona. | Virar pra `"false"` em qualquer topologia gerenciada/com TLS (os presets de `global.cloud` fazem isso). |
| **Erlang cookie do RabbitMQ precisa ser estável** | Com o broker embutido, `RABBITMQ_ERLANG_COOKIE` não pode mudar entre upgrades ou o broker não re-forma o cluster/quorum. | Gerar uma vez e pinar; nunca deixar o CI regerar. |
| **Worker é um KEDA ScaledJob (scale-to-zero)** | Não é Deployment — não tem probe de readiness/liveness. Zero pods de worker em idle é normal; pods aparecem quando a fila do RabbitMQ tem profundidade. | Não alertar em "0 pods de worker". Confirmar escala enfileirando um relatório e vendo os Jobs surgirem. |
| **ServiceAccount do SeaweedFS foi renomeada** | `seaweedfs.global.serviceAccountName` agora é `reporter-seaweedfs` (era `seaweedfs`) pra evitar colisão entre releases. No upgrade dispara um restart único dos pods do SeaweedFS; IRSA/RoleBinding pinados no nome antigo precisam ser atualizados. | Só relevante se `seaweedfs.enabled: true`. Atualizar anotações IAM/IRSA pro novo nome da SA antes do upgrade. |
| **ClusterRole do manager é cluster-scoped** | O manager ganha um ClusterRole+Binding pra acesso a CRD/deployment; nome fixo colide se duas releases criarem. | Setar `manager.clusterRole.create: false` quando já existir. |
| **Bootstrap de RabbitMQ externo é só topologia** | `externalRabbitmqDefinitions` declara exchanges/queues/bindings no vhost `/`; **não** cria o user da app, suas permissões, nem o vhost. | Provisionar o user + permissões no broker primeiro; depois habilitar o job de bootstrap. |
| **Nome da release afeta só os hosts hardcoded** | Os hosts de infra default (`MONGO_HOST`, `RABBITMQ_HOST`, …) assumem release `reporter`. A ref `<release>-mongodb` auto-segue a release (`reporter.infraSecretRef`); `reporter-manager` deriva de `manager.name`, não do nome da release. | Instalar como `reporter`, ou sobrescrever os hosts de infra. Reaponte `rabbitmq.authentication.existingSecret` **só** se mudar `manager.name`/`manager.existingSecretName`. |
| **Preset de topologia do broker é só AWS** | `global.cloud` fornece `broker` (scheme/porta AMQP) **só** pra `aws`. `gcp`/`azure` omitem, então `scheme`/`amqpPort` caem pra `amqp`/`5672` — um broker TLS ou não-default externo então falha pra app e pro trigger do KEDA (compartilham o resolver). | Em GCP/Azure ou qualquer broker TLS/não-default externo, setar `global.datastores.broker.scheme`/`amqpPort` (ou `common.configmap.RABBITMQ_URI`/`RABBITMQ_PORT_AMQP`) explicitamente. |

---

## 6. Como validar que subiu certo

```bash
kubectl get pods -n reporter               # manager Running; pods de worker só sob carga
kubectl get scaledobject,scaledjob,triggerauthentication -n reporter
kubectl -n reporter port-forward svc/reporter-manager 4005:4005 &
# aguarde o forward ficar pronto antes do curl (evita um connection-refused transitório):
until curl -fsS http://localhost:4005/health >/dev/null 2>&1; do sleep 1; done
curl -fsS http://localhost:4005/health     # liveness
curl -fsS http://localhost:4005/readyz     # readiness
# Docs da API: http://localhost:4005/swagger/index.html
```

| Check | Comando/URL | Esperado | Se não bater, checar primeiro |
|---|---|---|---|
| Pod do manager | `kubectl get pods -n reporter` | `Running`, `1/1` | `CreateContainerConfigError` → Secret ausente; erro de render/boot citando `DATASOURCE_CRED_ENC_KEY` → setar (seção 5) |
| Liveness / Readiness | `curl …:4005/health` e `/readyz` | `200` | Não fica Ready → manager não alcança Mongo/RabbitMQ; conferir `ALLOW_INSECURE_TLS` vs sua infra |
| Wiring do KEDA | `kubectl get scaledjob,triggerauthentication -n reporter` | presentes | Ausentes → CRDs do KEDA faltando (operador não instalado); worker nunca escala |
| Worker escala | enfileirar um relatório, depois `kubectl get jobs -n reporter` | Jobs surgem e completam | Sem Jobs → trigger/fila do KEDA inalcançável; conferir RabbitMQ + TriggerAuthentication |
| Saída do relatório | gerar um relatório, checar o object storage | arquivo gravado no bucket | Ausente → endpoint ou credenciais do SeaweedFS/S3 errados |
| Query de datasource | um relatório que lê uma datasource registrada | linhas retornadas | Vazio/erro → conexão `DATASOURCE_<NAME>_*` errada, ou senha deixada no `configmap` (tem que estar em `secrets`) |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Fix |
|---|---|---|
| Render falha citando `DATASOURCE_CRED_ENC_KEY` | `image.tag >= 3.0.0` com a chave vazia | Setar a chave AES hex (idêntica no manager + worker) |
| Manager `CrashLoopBackOff`, log "TLS required" (Mongo) | `ALLOW_INSECURE_TLS: "false"` contra infra embutida sem TLS | Manter `"true"` pra infra embutida; `"false"` só com TLS real |
| `ClusterRole … already exists` no install | Uma release anterior criou o ClusterRole do manager (nome fixo) | `manager.clusterRole.create: false` |
| RabbitMQ não sobe / perde o cluster após upgrade | `RABBITMQ_ERLANG_COOKIE` mudou entre installs | Pinar um cookie estável; restaurar o valor original |
| Worker nunca cria Jobs sob carga | Operador KEDA ausente, ou o trigger/TriggerAuthentication do RabbitMQ não alcança o broker | Instalar KEDA (embutido ou externo) e verificar as credenciais do trigger |
| Uma senha de datasource aparece no ConfigMap | `DATASOURCE_<NAME>_PASSWORD` colocada em `common.configmap` em vez de `secrets` | Mover pra `secrets:` e rotacionar a credencial exposta |
| Pods do SeaweedFS reiniciam / IRSA quebra após upgrade | ServiceAccount do SeaweedFS renomeada pra `reporter-seaweedfs` | Atualizar refs IAM/IRSA/RoleBinding pro novo nome da SA |
| Relatórios enfileiram mas nunca produzem saída | Endpoint/bucket do object storage errado, ou worker não escala | Verificar `global.objectStorage.s3` + escala do KEDA (seção 6) |
