# br-sta — Runbook de instalação

> Preenchido a partir do chart (`README.md`, `values.yaml`, `values-dev.yaml`,
> `values-template.yaml`, templates) e de uma instalação real do dev bundle num
> minikube isolado (6 CPU / 7 GB). Objetivo: alguém de fora da squad, só com o chart +
> este runbook, consegue instalar uma versão funcional e sabe o que checar caso algo
> não se comporte como esperado.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `br-sta-helm` (primeiro release **1.0.0**) / app **1.0.0** (primeiro release estável do STA) |
| Componentes | `manager` (API HTTP, `:4028`), `worker` (processo de background, probe server `:4029`, exatamente uma réplica), Job de migrations |
| Imagens | `ghcr.io/lerianstudio/br-sta-manager`, `br-sta-worker`, `br-sta-migrations` (todas privadas no GHCR); só dev: `mock-sta-server` (privada) |
| Última revisão deste runbook | 2026-09-30, contra chart 1.0.0 / app 1.0.0 |
| Contato de escalação | squad STA (ver CODEOWNERS do chart) |

---

## 1. Perfis de instalação

O perfil é escolhido pelo arquivo de values que você aplica, não por um flag.

| Perfil | Values | O que roda | Uso |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | manager + worker + migrations, mais PostgreSQL, Valkey, RabbitMQ, SeaweedFS (S3), Redpanda e o mock STA server embutidos, tudo no namespace do release; `ENV_NAME=development`, auth de entrada desligado | Avaliação, desenvolvimento local, teste do chart. Nada chega ao BACEN |
| **Dev bundle para o br-sisbajud** | `values-dev.yaml` + `--set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'` | O mesmo, mais o bucket do br-sisbajud | Par com o `values-dev-with-br-sta.yaml` do br-sisbajud no mesmo namespace (seção 3) |
| **Produção / infra externa** | seu arquivo, a partir do `values-template.yaml` | só manager + worker + migrations; toda dependência externa | Tiers reais. `ENV_NAME=production` por default (fail-closed) |

Só com os defaults o chart não renderiza: o ambiente default é `production`, então o
chart falha de propósito até as conexões externas e os secrets estarem setados (seção 5).

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| PostgreSQL | Sempre (single-tenant: o chart exige o host) | `global.datastores.postgres` + `common.secrets.POSTGRES_PASSWORD`. DB/usuário default `br_sta` |
| Valkey / Redis | Sempre (rate limit, idempotência, leader election do scheduler) | `global.datastores.redis` (`host:porta`) + `common.secrets.REDIS_PASSWORD` |
| RabbitMQ | Sempre em produção (transporte de auditoria + canal de business events; a app recusa produção sem ele) | `global.datastores.broker` + `common.secrets.RABBITMQ_DEFAULT_PASS` (ou um `RABBITMQ_URL` completo). A API de management precisa estar acessível: a app faz health check nela a cada conexão |
| Object storage S3 | Sempre em produção (o bucket de transfer guarda as duas direções) | `global.objectStorage.sta` (+ `staAuditExports` para exports de auditoria) + `common.secrets.AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` ou anotação IRSA / workload identity no `serviceAccount` |
| Kafka / Redpanda | Opcional: fatos de negócio em `lerian.streaming.br-sta` (+ `.dlq`), o tópico que o br-sisbajud consome | `global.streaming` + `common.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT`. Os tópicos precisam existir antes de ligar o streaming |
| plugin-access-manager | Obrigatório fora da classe de desenvolvimento (a app só aceita `PLUGIN_AUTH_ENABLED=false` em development/develop/dev/local/test) | `global.auth.enabled` + `global.auth.host` |
| Gateway de licença Lerian | Produção (`LICENSE_KEY` + `ORGANIZATION_IDS`); os pods precisam de egress até ele | `common.secrets.LICENSE_KEY`, `common.license.organizationIds` |
| BACEN STA | O upstream real (host de homologação ou produção) | `common.bacen.environment` (default `homologation`) |
| Tenant manager | Só com multi-tenancy | `global.multiTenant` + `common.secrets.MULTI_TENANT_SERVICE_API_KEY` |

Contra infra externa o chart não cria bancos, usuários/vhosts do RabbitMQ nem buckets;
ele roda as migrations SQL (single-tenant). A app declara as próprias exchanges e filas
do RabbitMQ no boot.

---

## 3. Ordem de instalação

### Dev bundle (comprovado em minikube)

```bash
kubectl create namespace sta-dev
# Pull secret do GHCR (as imagens do br-sta são privadas). Use um token com read:packages.
kubectl -n sta-dev create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<github-user> --docker-password=<GHCR_READ_TOKEN>

helm install br-sta charts/br-sta -n sta-dev \
  -f charts/br-sta/values-dev.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]'
```

O `imagePullSecrets` (chave raiz) vale para manager, worker, Job de migrations e mock
STA server; a infra embutida e os Jobs de bootstrap usam imagens públicas.

Esperado depois de cerca de **105 s** num namespace limpo:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sta-manager-*`, `br-sta-worker-*` (**0 restarts**), `br-sta-mock-sta-*`, `br-sta-postgresql-0`, `br-sta-valkey-primary-0`, `br-sta-rabbitmq-0`, `redpanda-0` (2/2), `seaweedfs-master-0`, `seaweedfs-volume-0`, `seaweedfs-filer-0`, `seaweedfs-s3-*` | `br-sta-migrations-<hash>`, `br-sta-seaweedfs-buckets-<hash>`, `br-sta-redpanda-topics-<hash>` |

Os Jobs de bootstrap são Jobs normais com nome derivado do hash do spec (não hooks): o
`/readyz` da app depende do bucket de transfer, então um hook post-install nunca rodaria.

Upgrades são idempotentes: dois `helm upgrade` seguidos com os mesmos values não deram
erro, não mudaram a generation de nenhum Deployment/StatefulSet e mantiveram os mesmos pods.

Limpeza:

```bash
helm uninstall br-sta -n sta-dev
kubectl -n sta-dev delete pvc --all   # também necessário se você mudar as senhas dev (seção 7)
kubectl delete namespace sta-dev
```

### Com o br-sisbajud

1. Instale o br-sta como acima, somando `--set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'`
   (o Job de buckets passa a criar também o bucket do br-sisbajud).
2. Instale o br-sisbajud no mesmo namespace com `values-dev.yaml` +
   `values-dev-with-br-sta.yaml` (ver o runbook do br-sisbajud). Ele reaproveita o
   SeaweedFS e o Redpanda do br-sta e chama `http://br-sta-manager:4028`.

### Produção

1. Provisione PostgreSQL (banco/usuário `br_sta` por default), Valkey, RabbitMQ (com a
   API de management acessível), os buckets S3 e, se o streaming estiver ligado, os
   tópicos `lerian.streaming.br-sta` e `lerian.streaming.br-sta.dlq`.
2. Gere a master key uma única vez (`openssl rand -hex 32`) e guarde `v1:<hex>` como
   `MASTER_KEYS` no seu cofre. Nunca substitua: adicione uma versão nova.
3. Crie o Secret da app fora do chart (`common.useExistingSecret: true` +
   `existingSecretName`) ou preencha `common.secrets` com placeholders `<path:...>`.
4. Crie o pull secret do GHCR no namespace.
5. `helm install` com seus values. Com Postgres externo as migrations rodam como hook
   PreSync do ArgoCD (Job normal no Helm puro), então a app nunca sobe sem schema.
6. Cadastre as credenciais de operador do BACEN (`POST /v1/credentials`) e as configs de
   tipo de documento / inbound pela API antes de os transfers rodarem.

---

## 4. Contrato de configuração compartilhada (masks / lerian-common)

Declare as conexões uma vez em `global:`; o chart renderiza as chaves nativas da app.
Não repita chaves nativas em `common.configmap`: uma chave nativa ali vence a mask.

```yaml
global:
  env: { name: "production" }
  datastores:
    postgres: { host: "", ssl: "require" }                      # user/name default br_sta
    redis:    { host: "<host>:6379", tls: "true" }
    broker:   { host: "", amqpPort: "5671", scheme: "amqps", user: "br_sta" }
  objectStorage:
    sta:             { endpoint: "", region: "", bucket: "" }   # o mesmo bloco que o br-sisbajud lê
    staAuditExports: { bucket: "" }                             # endpoint/region seguem o sta
  kms:       { vendor: "envvar" }                               # aws => MASTER_KEYS embrulhada no KMS + keyId
  auth:      { enabled: true, host: "" }
  streaming: { enabled: false, brokers: "", tlsEnabled: true, saslMechanism: "SCRAM-SHA-256", saslUsername: "br-sta" }
```

| Campo global | Chaves nativas | Observação |
|---|---|---|
| `global.env.name` | `ENV_NAME` | `production` liga os gates de produção da app; nomes da classe dev permitem auth desligado e os bundles só-dev |
| `global.datastores.postgres.*` | `POSTGRES_HOST/PORT/USER/NAME/SSLMODE`, chaves de réplica | `sslmode=disable` é recusado em produção |
| `global.datastores.broker.*` | `RABBITMQ_HOST/PORT_AMQP/PORT_HOST/DEFAULT_USER/SCHEME` | A URL do health check de management deriva de host + `port` (https com `amqps`) |
| `global.objectStorage.sta.*` | `TRANSFER_OBJECT_STORAGE_BUCKET`, `TRANSFER_S3_*` | Mantenha idêntico ao `global.objectStorage.sta` do br-sisbajud |
| `global.kms.*` | `MASTER_KEY_PROVIDER`, `MASTER_KEY_KMS_KEY_ID`, `MASTER_KEY_KMS_REGION` | `MASTER_KEYS` é sempre secret |
| `global.auth.*` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | Default `true` fora da classe dev |
| `global.streaming.*` | chaves de transporte `STREAMING_*` | `STREAMING_SASL_USERNAME` pode ficar no Secret |
| `global.multiTenant.*` | `MULTI_TENANT_*` | Ajustes finos em `common.multiTenant.*` |
| `global.observability.*` | `ENABLE_TELEMETRY`, `OTEL_*` | Telemetria ligada sem endpoint => `http://$(HOST_IP):4317` (collector do nó) |

Knobs de compatibilidade (só values): mantenha um endereço existente no cluster, como
`br-sta:8080`, com `manager.service.name: br-sta`, `manager.service.port: 8080` e
`manager.containerPort: 4028` (o Ingress segue o nome da Service). Knobs só do worker
ficam em `worker.*` (scheduler, audit publisher/consumer/partition/cleanup/verifier/
export generator).

---

## 5. Pontos de atenção operacional

| Tema | O que saber | Antes de habilitar / como confirmar |
|---|---|---|
| Render fail-fast | O chart espelha a validação de boot da app: `MASTER_KEYS` (formato e versão), switch de auth, host de Postgres/Redis em single-tenant, host do RabbitMQ + URL do health check, gates de produção (senha do Postgres, sem `sslmode=disable`, RabbitMQ + outbox + canal de negócio ligados, bucket de transfer, `LICENSE_KEY` + `ORGANIZATION_IDS`, sem CORS wildcard), brokers/SASL do streaming, exchange + resolver do reporter bridge | Leia o erro do render: ele diz exatamente o valor a setar |
| Guarda de produção | `redpandaBundle` e `mockSta` são recusados fora da classe dev | `helm template ... --set global.env.name=staging` falha citando os dois |
| Worker de réplica única | Não há leader election para todos os loops: exatamente uma réplica, `Recreate` | Não escale o worker; escale o manager |
| Scheduler de transfer | `TRANSFER_SCHEDULER_ENABLED` (default `true`) é o único caminho que envia ao BACEN | Log do worker `Transfers outbound fanout started` |
| Perfil mock | Qualquer `STA_SCHEME` / `STA_FILE_HOST` / `STA_PASSWORD_HOST` desvia o cliente STA do BACEN e relaxa o gate de trust-store do readiness | Nunca sete em produção |
| CORS | O middleware do lib-commons lê `ACCESS_CONTROL_*`; o chart renderiza `ACCESS_CONTROL_ALLOW_ORIGIN` a partir de `common.cors.allowedOrigins`. Vazio = nega tudo | Produção: só origens explícitas |
| Master key | Substituir `MASTER_KEYS` torna indecifráveis todas as credenciais BACEN guardadas | Adicione uma versão nova (`v1:...,v2:...`) e troque `MASTER_KEY_VERSION` |
| Filing sweep | `worker.scheduler.filingSweepEnabled` (default `false`) fecha filings encalhados do reporter; `filingSweepAgeMinutes` é knob de segurança | Ligue por decisão; não reduza a idade |
| Imagens privadas | Todas as imagens da app são privadas no GHCR | Pull secret em cada namespace (`imagePullSecrets`) |

---

## 6. Como validar uma instalação bem-sucedida

```bash
kubectl -n <ns> get pods
kubectl -n <ns> get jobs                          # migrations (e, em dev, buckets/topics) Complete
kubectl -n <ns> port-forward svc/<service-do-manager> 14028:<porta-da-service>
curl -s localhost:14028/readyz                    # readiness (probe do manager e do worker)
curl -s localhost:14028/health                    # liveness
```

| Checagem | Comando/URL | Esperado | Se não bater, verifique primeiro |
|---|---|---|---|
| Pods | `kubectl get pods` | manager e worker `1/1 Running`, 0 restarts | `CrashLoopBackOff`: a última linha do log diz a dependência que falhou (seção 7) |
| Migrations | `kubectl get jobs` | `br-sta-migrations-<hash>` `Complete` | Host/senha do Postgres, `ALLOW_INSECURE_TLS` para Postgres sem TLS |
| Readiness | `GET /readyz` | `200`, `status: healthy`; `postgres`, `redis`, `rabbitmq`, `storage_transfer` `up` (`license` `n/a` sem chave; `storage_audit_exports` `skipped` no manager) | Um check `down` diz a dependência; bucket inexistente aparece como `storage_transfer` down |
| Liveness | `GET /health` | `200 {"status":"available"}` | — |
| Loops do worker | `kubectl logs deploy/<fullname>-worker` | audit publisher/consumer, business publisher, outbound fanout, `scheduler: starting leader campaign`, `poll outcome` periódico | Loop ausente: o toggle dele em `worker.*` / `common.transfer.*` |
| E2E em dev (comprovado) | suba um arquivo em `outbound/` no bucket de transfer, `POST /v1/credentials`, depois `POST /v1/transfers` (`sourceProduct`, `documentType` ex. `AJUD302`, `fileRef: outbound/<arquivo>`, `fileName`) com um bearer token | O worker empacota, recebe protocolo do mock, faz polling `10 -> 15 -> 35` e o transfer termina `Accepted`; um fato cai em `lerian.streaming.br-sta` | Com auth desligado a API ainda exige um bearer que nomeie um principal (não verificado em development) |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Correção |
|---|---|---|
| `rabbitmq health check failed: rabbitmq health check URL is empty` (manager e worker em crashloop) | O lib-commons consulta a API de management a cada conexão | O chart agora deriva `RABBITMQ_HEALTH_CHECK_URL` de host/porta do broker; sete `global.datastores.broker.port` (management) ou `common.rabbitmq.healthCheckUrl` se o seu for diferente. `http` puro exige `common.rabbitmq.allowInsecureHealthCheck: true` (o render avisa) |
| Job `redpanda-topics` preso em `waiting for ...` | Builds antigos do chart esperavam a admin API em vez da API Kafka | Corrigido: o Job espera `rpk topic list`. Apague o Job preso e faça upgrade |
| Postgres `password authentication failed` depois de mudar as senhas dev | O volume de dados guarda a senha com que foi inicializado | `helm uninstall`, apague os PVCs, reinstale |
| Chamadas do browser bloqueadas mesmo com `CORS_ALLOWED_ORIGINS` setado | O middleware de CORS lê `ACCESS_CONTROL_ALLOW_ORIGIN` | Use `common.cors.allowedOrigins`; `*` exige `common.security.allowCorsWildcard: true` e é recusado em produção |
| Ferramenta escolhe `1.2.0-beta.x` em vez de `1.0.0` | A linha de versões da app recomeçou no release estável: `1.0.0` tem precedência SemVer menor, mas é o release posterior e compatível (mesmo env e migrations) | Fixe `1.0.0` explicitamente |
| Boot recusado em produção, erros de licença | `LICENSE_KEY` / `ORGANIZATION_IDS` ausentes, ou sem egress até o gateway de licença (não há modo de licença offline nesta versão da app) | Sete os dois e libere o egress |
| `PLUGIN_AUTH_ENABLED=false is only accepted in a development-class environment` | Auth desligado em `staging`/`production` | Ligue `global.auth` ou use um `global.env.name` da classe dev |
| `MASTER_KEYS is malformed` / `must reference a key present` | Formato `versão:hex` errado ou `MASTER_KEY_VERSION` divergente | `v1:<64 chars hex>` e `common.credentials.masterKeyVersion: v1` |
| `sta_consumer` degraded no br-sisbajud depois de um fato do br-sta | Comportamento conhecido do br-sisbajud: um fato de um transfer que ele não criou é reprocessado e bloqueia a partição | Monitore `sta_consumer` no `/readyz` do br-sisbajud; ver o runbook do br-sisbajud |
