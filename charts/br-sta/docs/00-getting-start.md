# br-sta — Runbook de instalação

> Escopo: instalar e operar o chart br-sta (dev bundle, par com o br-sisbajud,
> produção sobre infra externa). Público: operadores de fora da squad STA que têm só o
> chart e este runbook.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `br-sta-helm` (primeiro release **1.0.0**) / app **1.0.0** |
| Componentes | `manager` (API HTTP, `:4028`), `worker` (processo de background, probe server `:4029`, exatamente uma réplica), Job de migrations |
| Imagens | `ghcr.io/lerianstudio/br-sta-manager`, `br-sta-worker`, `br-sta-migrations` (todas privadas no GHCR); só dev: `mock-sta-server` (privada) |
| Última revisão deste runbook | 2026-10-01 |
| Contato de escalação | `@LerianStudio/G_Github_Devops` (ver `.github/CODEOWNERS`) |

---

## 1. Perfis de instalação

O perfil é escolhido pelo arquivo de values que você aplica, não por um flag.

> **A infraestrutura embutida é só para desenvolvimento e quickstart. Instalações de produção devem usar infraestrutura externa e gerenciada.** Produção significa infraestrutura externa e gerenciada: PostgreSQL com TLS, Valkey/Redis, RabbitMQ, Kafka/Redpanda com TLS, object storage S3 e o upstream STA real do BACEN/Nuclea. Os subcharts embutidos `postgresql`, `valkey`, `rabbitmq`, `seaweedfs` e `redpanda` e o `mockSta` existem para desenvolvimento, POC e quickstart. O render recusa o Redpanda e o mock STA em ambiente tipo produção e só avisa (NOTES) para os demais, mas nenhum deles é suportado em produção.

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
| Kafka / Redpanda | Ligado por default: fatos de negócio em `lerian.streaming.br-sta` (+ `.dlq`), o tópico que o br-sisbajud consome | `global.streaming` (brokers obrigatórios) + `common.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT`. Com `topicAutoProvision: true` (default) os dois binários criam os tópicos no boot se o principal tiver CreateTopics; com `false` (tópicos via IaC) eles precisam existir antes |
| plugin-access-manager | Obrigatório fora da classe de desenvolvimento (a app só aceita `PLUGIN_AUTH_ENABLED=false` em development/develop/dev/local/test) | `global.auth.enabled` + `global.auth.host` |
| Gateway de licença Lerian | Produção (`LICENSE_KEY` + `ORGANIZATION_IDS`); os pods precisam de egress até ele | `common.secrets.LICENSE_KEY`, `common.license.organizationIds` |
| BACEN STA | O upstream real (host de homologação ou produção) | `common.bacen.environment` (default `homologation`) |
| Tenant manager | Só com multi-tenancy | `global.multiTenant` + `common.secrets.MULTI_TENANT_SERVICE_API_KEY` |

Contra infra externa o chart não cria bancos, usuários/vhosts do RabbitMQ nem buckets;
ele roda as migrations SQL (single-tenant). A app declara as próprias exchanges e filas
do RabbitMQ no boot.

---

## 3. Ordem de instalação

### Dev bundle

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

Esperado num namespace limpo:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sta-manager-*`, `br-sta-worker-*`, `br-sta-mock-sta-*`, `br-sta-postgresql-0`, `br-sta-valkey-primary-0`, `br-sta-rabbitmq-0`, `redpanda-0` (2/2), `seaweedfs-master-0`, `seaweedfs-volume-0`, `seaweedfs-filer-0`, `seaweedfs-s3-*` | `br-sta-migrations-<hash>`, `br-sta-seaweedfs-buckets-<hash>`, `br-sta-redpanda-topics-<hash>` |

Os Jobs de bootstrap são Jobs normais com nome derivado do hash do spec (não hooks): o
`/readyz` da app depende do bucket de transfer, então um hook post-install nunca rodaria.

Upgrades são idempotentes: um `helm upgrade` com os mesmos values não muda a generation
de nenhum Deployment/StatefulSet e mantém os mesmos pods.

Limpeza:

```bash
helm uninstall br-sta -n sta-dev
kubectl -n sta-dev delete pvc --all   # também necessário se você mudar as senhas dev (seção 7)
kubectl delete namespace sta-dev
```

### Com o br-sisbajud

1. Instale o br-sta como acima, somando `--set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'`
   (o Job de buckets cria também o bucket do br-sisbajud).
2. Instale o br-sisbajud no mesmo namespace com `values-dev.yaml` +
   `values-dev-with-br-sta.yaml` (ver o runbook do br-sisbajud). Ele reaproveita o
   SeaweedFS e o Redpanda do br-sta e chama `http://br-sta-manager:4028`.

### Produção

> **Como confirmar uma instalação de produção** (`global.env.name=production`, infra externa):
>
> - [ ] PostgreSQL com `sslmode=require` (ou mais estrito), Valkey com TLS, RabbitMQ via
>   `amqps` com a API de management via `https` (CA privada: ver "RabbitMQ com CA
>   privada" abaixo), Kafka com TLS + SASL, origens CORS explícitas, `LICENSE_KEY` e
>   `ORGANIZATION_IDS` setados.
> - [ ] O hook de migrations completa e, em seguida, manager e worker ficam `1/1 Running`.
> - [ ] `GET /readyz` responde `200`, com `license`, `postgres`, `rabbitmq`, `redis`
>   (`tls: true`) e `storage_transfer` `up`.
> - [ ] O log do worker mostra business publisher, outbound fanout, leader election e
>   audit consumer subindo.
>
> Limitação conhecida: chamadas autenticadas à API e envio de transfer a partir do
> br-sisbajud precisam de um plugin-access-manager acessível.

1. Provisione PostgreSQL (banco/usuário `br_sta` por default), Valkey, RabbitMQ (com a
   API de management acessível), os buckets S3 e o Kafka/Redpanda (streaming ligado por
   default): os tópicos `lerian.streaming.br-sta` e `lerian.streaming.br-sta.dlq`, ou
   CreateTopics para o principal do br-sta (`global.streaming.topicAutoProvision: true`).
2. Gere a master key uma única vez (`openssl rand -hex 32`) e guarde `v1:<hex>` como
   `MASTER_KEYS` no seu cofre. Nunca substitua: adicione uma versão nova.
3. Crie o Secret da app fora do chart (`common.useExistingSecret: true` +
   `existingSecretName`), referencie chaves avulsas dele com `common.secretRefs.<KEY>:
   {name, key}`, ou preencha `common.secrets` com placeholders `<path:...>`.
4. Crie o pull secret do GHCR no namespace. O default do chart é `ghcr-credential`
   (`imagePullSecrets: [{name: ghcr-credential}]`):

   ```bash
   kubectl -n <namespace> create secret docker-registry ghcr-credential \
     --docker-server=ghcr.io --docker-username=<github-user> --docker-password=<GHCR_READ_TOKEN>
   ```

   Com um Secret de outro nome, sobrescreva a lista raiz, usada por manager, worker, Job
   de migrations e mock STA: `imagePullSecrets: [{name: <seu-secret>}]`.
5. `helm install` com seus values. Com Postgres externo as migrations rodam como hook
   `pre-install`/`pre-upgrade` do Helm e como hook PreSync do ArgoCD (o Secret do hook no
   weight -2, o Job no -1), então a app nunca sobe sem schema em nenhuma das duas.
6. Cadastre as credenciais de operador do BACEN (`POST /v1/credentials`) e as configs de
   tipo de documento / inbound pela API antes de os transfers rodarem.

### RabbitMQ com CA privada (produção)

A app valida tanto a conexão AMQPS quanto o health check do management (`https`) contra
o pool de certificados do sistema do container. Quando o certificado do broker vem de
uma CA privada, entregue ao manager **e** ao worker um bundle via `SSL_CERT_FILE`. O
bundle precisa conter as raízes públicas **mais** a sua CA, porque as raízes públicas
continuam necessárias para falar com o gateway de licença e com qualquer outro endpoint
TLS público.

```bash
cat /etc/ssl/certs/ca-certificates.crt minha-ca-privada.pem > ca-bundle.pem
kubectl -n <namespace> create configmap br-sta-ca-bundle --from-file=ca-bundle.pem
```

```yaml
manager:
  extraVolumes:      [{ name: ca-bundle, configMap: { name: br-sta-ca-bundle } }]
  extraVolumeMounts: [{ name: ca-bundle, mountPath: /etc/br-sta-ca, readOnly: true }]
  extraEnvVars:      [{ name: SSL_CERT_FILE, value: /etc/br-sta-ca/ca-bundle.pem }]
worker:
  extraVolumes:      [{ name: ca-bundle, configMap: { name: br-sta-ca-bundle } }]
  extraVolumeMounts: [{ name: ca-bundle, mountPath: /etc/br-sta-ca, readOnly: true }]
  extraEnvVars:      [{ name: SSL_CERT_FILE, value: /etc/br-sta-ca/ca-bundle.pem }]
```

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
  streaming: { enabled: true, brokers: "", tlsEnabled: true, saslMechanism: "SCRAM-SHA-256", saslUsername: "", topicAutoProvision: true }   # brokers/username obrigatórios
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

### Licença

| Tema | Comportamento (app `1.0.0`, SDK de licença v4.1.0) |
|---|---|
| Uma chave por produto | Uma chave licencia um único produto. Chave emitida para outro produto é recusada com `Exiting: LCS-0012: refused by the gateway (LCS-1005)`; chave desconhecida ou adulterada, com `(LCS-1002)` |
| Na recusa | O processo sai e o pod entra em `CrashLoopBackOff`. Num rolling update o pod que já está rodando continua servindo: o rollout trava, mas nada cai |
| Gateway | `https://license.lerian.io`, `POST /licenses/validate`. O egress até ele é obrigatório e a URL não é configurável. Chaves emitidas para staging também são validadas neste gateway de produção. `common.license.isDevelopment: "true"` (`IS_DEVELOPMENT`) troca para `https://license.dev.lerian.io`: use só para chaves emitidas pelo gateway dev |
| Refresh e carência | A chave é revalidada a cada 6 h. Quando o gateway não responde (erro de rede ou 5xx) depois de ter confirmado a chave uma vez, o processo segue servindo em janelas de carência decrescentes (2 d, 1 d, 12 h, 6 h, no máximo 3 d 18 h) e depois sai. Um processo que nunca foi confirmado ganha só 6 h. Uma recusa 4xx encerra a carência na hora. As janelas vivem em memória: um pod reiniciado durante uma queda começa sem confirmação |
| Offline | Não há modo de licença offline nesta versão da app |
| Gate de render | Com `global.env.name=production` o render falha sem `LICENSE_KEY` e `ORGANIZATION_IDS` |
| Como confirmar | `GET /readyz` -> `checks.license` `up` (`n/a` quando não há cliente de licença) |

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
| Fluxo de transfer em dev | suba um arquivo em `outbound/` no bucket de transfer, `POST /v1/credentials`, depois `POST /v1/transfers` (`sourceProduct`, `documentType` ex. `AJUD302`, `fileRef: outbound/<arquivo>`, `fileName`) com um bearer token | O worker empacota, recebe protocolo do mock, faz polling `10 -> 15 -> 35` e o transfer termina `Accepted`; um fato cai em `lerian.streaming.br-sta` | Com auth desligado a API ainda exige um bearer que nomeie um principal (não verificado em development) |
| Limitação conhecida | Chamadas autenticadas à API e envio br-sisbajud -> br-sta `POST /v1/transfers` | Precisam de um plugin-access-manager acessível | `global.auth.host` |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Correção |
|---|---|---|
| `rabbitmq health check failed: rabbitmq health check URL is empty` (manager e worker em crashloop) | O lib-commons consulta a API de management a cada conexão | O chart deriva `RABBITMQ_HEALTH_CHECK_URL` de host/porta do broker; sete `global.datastores.broker.port` (management) ou `common.rabbitmq.healthCheckUrl` se o seu for diferente. `http` puro exige `common.rabbitmq.allowInsecureHealthCheck: true` (o render avisa) |
| Job `redpanda-topics` preso em `waiting for ...` | A API Kafka do Redpanda embutido ainda não subiu (o Job espera `rpk topic list`) | Confira o pod `redpanda-0` e os logs dele; o Job tenta de novo até o broker responder |
| Postgres `password authentication failed` depois de mudar as senhas dev | O volume de dados guarda a senha com que foi inicializado | `helm uninstall`, apague os PVCs, reinstale |
| Chamadas do browser bloqueadas mesmo com `CORS_ALLOWED_ORIGINS` setado | O middleware de CORS lê `ACCESS_CONTROL_ALLOW_ORIGIN` | Use `common.cors.allowedOrigins`; `*` exige `common.security.allowCorsWildcard: true` e é recusado em produção |
| Boot recusado em produção, erros de licença | `LICENSE_KEY` / `ORGANIZATION_IDS` ausentes, chave de outro produto (`LCS-1005`) ou chave desconhecida (`LCS-1002`), ou sem egress até o gateway de licença (não há modo de licença offline nesta versão da app) | Sete os dois, use a chave deste produto, libere o egress (seção 5, Licença) |
| `Failed to connect to plugin-auth` no boot | O plugin-access-manager não está instalado ou ainda não está acessível | Informativo: os pods ficam Ready mesmo assim. Chamadas autenticadas precisam do plugin-access-manager |
| `PLUGIN_AUTH_ENABLED=false is only accepted in a development-class environment` | Auth desligado em `staging`/`production` | Ligue `global.auth` ou use um `global.env.name` da classe dev |
| `MASTER_KEYS is malformed` / `must reference a key present` | Formato `versão:hex` errado ou `MASTER_KEY_VERSION` divergente | `v1:<64 chars hex>` e `common.credentials.masterKeyVersion: v1` |
| `sta_consumer` degraded no br-sisbajud depois de um fato do br-sta | Comportamento conhecido do br-sisbajud: um fato de um transfer que ele não criou é reprocessado e bloqueia a partição | Monitore `sta_consumer` no `/readyz` do br-sisbajud; ver o runbook do br-sisbajud |

---

## 8. Rollback

```bash
helm history br-sta -n <namespace>
helm rollback br-sta <revision> -n <namespace>
```

Com ArgoCD, reverta o commit de values/versão do chart no Git; um rollback manual é
desfeito no próximo sync.

- **Migrations só andam para frente.** O rollback reimplanta o chart e a imagem
  anteriores, mas não reverte o schema: o Job de migrations só aplica migrations `up`, e
  o hook pre-upgrade/PreSync da revisão antiga as roda de novo sem efeito. Uma imagem
  antiga da app pode recusar um schema mais novo do que o que ela traz (por exemplo, um
  build cuja última migration é menor que a versão do banco falha a checagem de
  migrations no boot). Volte para uma imagem que conheça a versão atual do schema, ou
  restaure o banco de um backup feito antes do upgrade. Faça esse backup antes de todo
  upgrade que traga migrations.
- **`MASTER_KEYS` precisa sobreviver a todo rollback e reinstalação.** As credenciais de
  operador gravadas via `POST /v1/credentials` são cifradas por envelope, e cada texto
  cifrado fica preso à versão da master key que o cifrou. A app decifra por essa versão
  (`unknown master key version` quando ela falta em `MASTER_KEYS`). Nunca altere nem
  remova uma versão existente. Para rotacionar, adicione uma entrada `v2:<hex>` ao lado
  da `v1` e mova `common.credentials.masterKeyVersion` para ela: escritas novas usam `v2`
  e os textos antigos continuam decifrando com `v1`. Perder uma versão, ou o valor dela
  no cofre, torna irrecuperável toda credencial cifrada com ela: é preciso cadastrá-las
  de novo. Com `MASTER_KEY_PROVIDER=aws-kms` vale o mesmo para os blobs embrulhados e a
  chave KMS que os embrulha.
