# br-sisbajud — Runbook de instalação

> Preenchido a partir do chart (`README.md`, `values.yaml`, `values-dev.yaml`,
> `values-dev-with-br-sta.yaml`, `values-template.yaml`, templates) e de uma instalação
> real ao lado de um dev bundle do br-sta num minikube isolado (6 CPU / 7 GB).
> Objetivo: alguém de fora da squad, só com o chart + este runbook, consegue instalar
> uma versão funcional e sabe o que checar caso algo não se comporte como esperado.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `br-sisbajud-helm` (release **1.2.0**) / app **1.1.0** |
| Componentes | um binário Go (API HTTP `:4029` + workers de background), Job de migrations, Job de tópicos |
| Imagens | `ghcr.io/lerianstudio/br-sisbajud`, `br-sisbajud-migrations`, `br-sisbajud-topics` (todas privadas no GHCR) |
| Guia de upgrade | vindo do chart 1.1.x: [`UPGRADE-1.2.md`](UPGRADE-1.2.md) |
| Última revisão deste runbook | 2026-09-30, contra chart 1.2.0 / app 1.1.0 |
| Contato de escalação | squad SISBAJUD (ver CODEOWNERS do chart) |

---

## 1. Perfis de instalação

| Perfil | Values | O que roda | Uso |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | a app, mais PostgreSQL, Valkey, SeaweedFS (S3), OpenBao (Vault Transit, modo dev) e Redpanda embutidos; `ENVIRONMENT_NAME=development`; auth de entrada, consumer/cliente de transfers do br-sta e multi-tenancy desligados | Avaliação, desenvolvimento local, teste do chart |
| **br-sisbajud + br-sta juntos** | `values-dev.yaml` + `values-dev-with-br-sta.yaml` | a app com PostgreSQL, Valkey e OpenBao próprios, reaproveitando o SeaweedFS e o Redpanda de um dev bundle do br-sta no mesmo namespace; consumer e cliente de transfers do br-sta ligados | Dev integrado do fluxo STA (entrada de remessas, arquivos de retorno) |
| **Produção / infra externa** | seu arquivo, a partir do `values-template.yaml` | a app + Jobs de migrations e tópicos; toda dependência externa | Tiers reais. Ambiente default `production` (fail-closed) |

Só com os defaults o chart não renderiza: o ambiente default é `production`, então o
chart falha de propósito até as conexões externas e os secrets estarem setados (seção 5).

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| PostgreSQL | Sempre (single-tenant: o host é obrigatório) | `global.datastores.postgres` + `brSisbajud.secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Sempre (rate limit, idempotência, locks de processamento) | `global.datastores.redis` (`host:porta`) + `brSisbajud.secrets.REDIS_PASSWORD` |
| Kafka / Redpanda | Streaming ligado por default (producer/consumers lib-streaming, tradutor de saldo do Midaz, fatos do br-sta) | `global.streaming` + `brSisbajud.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| HashiCorp Vault Transit **ou** AWS KMS | Sempre (criptografia envelope dos dados de bloqueio judicial) | `global.kms` + `brSisbajud.secrets.VAULT_APPROLE_SECRET_ID` (ou `VAULT_TOKEN`) |
| Object storage S3 | Sempre (artefatos criptografados + o bucket de transfer do br-sta) | `global.objectStorage.sisbajud` / `.sta` + `SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` |
| br-sta | Entrada de remessas (fatos em `lerian.streaming.br-sta`) e envio de arquivos de retorno (`POST /v1/transfers`) | `brSisbajud.sta.*`, `global.objectStorage.sta` (o mesmo bloco que o br-sta lê) |
| plugin-access-manager | Validação JWT de entrada, bearer m2m do STA, declaração de permissões | `global.auth`, `brSisbajud.identity` |
| Stream do ledger Midaz | Gatilho de mudança de saldo (`lerian.streaming.ledger`, criado pelo Midaz) | `brSisbajud.midaz.balanceTopic` |
| Gateway de licença Lerian | Produção (`LICENSE_KEY`); o pod precisa de egress até ele | `brSisbajud.secrets.LICENSE_KEY`, `brSisbajud.license.organizationIds` (`global`) |
| Tenant manager | Só com multi-tenancy | `global.multiTenant` + `MULTI_TENANT_SERVICE_API_KEY` |

Os conectores do ledger Midaz e do CRM não são configurados pelo chart: cadastre uma
instituição por tenant pela API admin (`POST /v1/institutions`) antes de as ordens
poderem executar.

---

## 3. Ordem de instalação

### Dev bundle

```bash
kubectl create namespace sisb-dev
kubectl -n sisb-dev create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<github-user> --docker-password=<GHCR_READ_TOKEN>

helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]'
```

O `imagePullSecrets` de topo cobre os pods da app, migrations, tópicos e buckets. Com as
dependências embutidas, o pod da app roda initContainers idempotentes (migrations,
espera do broker, tópicos, mount do Transit) antes de subir, então nunca sobe sem
schema, tópicos ou Transit montado.

### br-sisbajud + br-sta juntos (comprovado em minikube)

```bash
# 1. dev bundle do br-sta, somando o bucket do br-sisbajud ao Job de buckets dele
helm install br-sta charts/br-sta -n sisb-dev -f charts/br-sta/values-dev.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]' \
  --set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'
# 2. br-sisbajud ligado a ele (reaproveita o SeaweedFS + Redpanda do br-sta)
helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml -f charts/br-sisbajud/values-dev-with-br-sta.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]'
```

O overlay assume o release do br-sta com o nome `br-sta` (Service do manager
`br-sta-manager:4028`) e os nomes default das Services do SeaweedFS / Redpanda.

Observado: pods do br-sisbajud saudáveis cerca de 50 s depois da instalação dele (o
br-sta sozinho levou cerca de 105 s), **0 restarts**:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit` |

Os tópicos `lerian.streaming.br-sisbajud`, `.dlq` e `.commands` são criados no Redpanda
do br-sta, ao lado de `lerian.streaming.br-sta`.

Upgrades: dois `helm upgrade` seguidos com os mesmos values não mudaram a generation de
nenhum Deployment/StatefulSet (as senhas dev estão fixas no `values-dev.yaml`, ver seção 7).

Limpeza:

```bash
helm uninstall br-sisbajud -n sisb-dev
helm uninstall br-sta -n sisb-dev
kubectl -n sisb-dev delete pvc --all   # também necessário depois de mudar as senhas dev
kubectl delete namespace sisb-dev
```

### Produção

1. Provisione PostgreSQL, Valkey, os buckets S3 (`global.objectStorage.sisbajud.bucket`
   e o bucket de transfer do br-sta), Vault Transit (ou AWS KMS) e o broker.
2. Crie o Secret fora do chart (`brSisbajud.useExistingSecret` + `existingSecretName`)
   ou preencha `brSisbajud.secrets` com placeholders `<path:...>`; crie o pull secret do GHCR.
3. `helm install`. Contra infra externa os Jobs de migrations e tópicos são hooks Helm
   `pre-install/pre-upgrade` + PreSync do ArgoCD, então a app nunca sobe sem schema.
4. Cadastre as instituições pela API admin (`POST /v1/institutions`).

---

## 4. Contrato de configuração compartilhada (masks / lerian-common)

```yaml
global:
  env: { name: "production" }             # local|development|staging|e2e|test relaxam os gates da app
  datastores:
    postgres: { host: "", user: "br_sisbajud", name: "br_sisbajud", ssl: "require" }
    redis:    { host: "<host>:6379", tls: "true" }
  objectStorage:
    sisbajud: { endpoint: "", region: "", bucket: "sisbajud" }
    sta:      { bucket: "" }                # = bucket de transfer do br-sta (obrigatório, sem default)
  kms: { vendor: "hashicorp-vault", vaultAddr: "", vaultAuthMethod: "approle", vaultRoleId: "", vaultMount: "transit" }
  streaming: { brokers: "", tlsEnabled: true, saslMechanism: "SCRAM-SHA-256", saslUsername: "br-sisbajud" }
  auth: { enabled: true, host: "" }
```

| Campo global | Chaves nativas | Observação |
|---|---|---|
| `global.env.name` | `ENVIRONMENT_NAME`, `ENV_NAME` | Só `local`/`development`/`staging`/`e2e`/`test` relaxam os gates; qualquer outro valor é tratado como produção |
| `global.datastores.*` | `POSTGRES_*`, `REDIS_*` | os subcharts embutidos derivam sozinhos |
| `global.objectStorage.sisbajud` | `SEAWEEDFS_S3_ENDPOINT/BUCKET/REGION` | — |
| `global.objectStorage.sta` | `STA_INBOUND_BUCKET` (+ `TRANSFER_OBJECT_STORAGE_BUCKET`), `STA_OBJECT_STORAGE_ENDPOINT` | O endpoint segue o do sisbajud; a app exige paridade de bucket e endpoint com o br-sta |
| `global.kms` | `KMS_PROVIDER`, `VAULT_*`, `AWS_REGION` | `VAULT_APPROLE_SECRET_ID` / `VAULT_TOKEN` são secrets |
| `global.streaming` | `STREAMING_*` | os fatos do br-sta chegam em `lerian.streaming.br-sta` |
| `global.auth` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | O cliente de transfers do STA emite o bearer m2m a partir deste host mesmo com auth desligado |

Ligação com o br-sta (valores agrupados em `brSisbajud.sta`): `consumerEnabled`,
`expectedTenantSt` (= `DEFAULT_TENANT_ID` do br-sta em single-tenant), `transfersEnabled`,
`transfersBaseUrl` (URL do manager do br-sta), `clientId` (+ `STA_CLIENT_SECRET` no Secret).

---

## 5. Pontos de atenção operacional

| Tema | O que saber | Antes de habilitar / como confirmar |
|---|---|---|
| Render fail-fast | Espelha a validação de boot da app: `STA_INBOUND_BUCKET` sempre; host de Postgres/Redis em single-tenant; provider do KMS + credenciais; brokers/SASL/TLS do streaming; `LICENSE_KEY` + senha do Postgres em ambiente tipo produção; credenciais do cliente de transfers do STA / auth de entrada / publisher de declaração; URL/Redis/API key do multi-tenant; `ORGANIZATION_IDS` precisa ser `global` | Leia o erro do render: ele diz exatamente o valor |
| Guarda de produção | `openbao` (modo dev, chaves em memória) e `redpandaBundle` são recusados fora de `local`/`development`/`staging`/`e2e`/`test` | `helm template ... --set global.env.name=production` com o dev bundle falha citando os dois |
| OpenBao modo dev | Reiniciar o pod do OpenBao perde todas as chaves Transit: linhas criptografadas antes ficam ilegíveis | Só dev/avaliação; resete o banco junto |
| Cliente de transfers do STA | Precisa de um plugin-access-manager acessível para emitir o bearer m2m | Sem ele, o envio de arquivo de retorno ao br-sta falha |
| Fatos do br-sta de transfers desconhecidos | Comportamento conhecido da app: um fato em `lerian.streaming.br-sta` de um transfer que o br-sisbajud não criou é tratado como transitório e segura a partição | Acompanhe `sta_consumer` no `/readyz` (`degraded`, `consumer_not_polling`) |
| Imagens privadas | Imagens da app, migrations e tópicos são privadas no GHCR | Pull secret no namespace (`imagePullSecrets`) |

---

## 6. Como validar uma instalação bem-sucedida

```bash
kubectl -n <ns> get pods
kubectl -n <ns> get jobs
kubectl -n <ns> port-forward svc/br-sisbajud 14029:4029
curl -s localhost:14029/readyz     # path do readiness probe
curl -s localhost:14029/health     # path do liveness probe
```

| Checagem | Comando/URL | Esperado | Se não bater, verifique primeiro |
|---|---|---|---|
| Pods | `kubectl get pods` | app `1/1 Running`, 0 restarts | `CrashLoopBackOff`: o log diz a dependência que falta |
| Jobs | `kubectl get jobs` | migrations (e em dev `openbao-transit`, buckets, tópicos) `Complete` | Host/senha do Postgres; acesso ao broker para os tópicos |
| Readiness | `GET /readyz` | `healthy`; `postgres`, `redis`, `kms`, `seaweedfs`, `streaming` `up`; com o br-sta ligado: `sta_bucket_parity` `up` e `sta_consumer` `up` | `sta_bucket_parity` down: bucket/endpoint sta diferentes dos do br-sta |
| Integração com br-sta (comprovada) | crie um transfer no br-sta (ver o runbook do br-sta): o mock STA leva a `Accepted` e o br-sta publica um fato em `lerian.streaming.br-sta` | O fato chega ao consumer STA do br-sisbajud (grupo `sisbajud-sta-consumer`) | Um fato de transfer que o br-sisbajud não criou é reprocessado (seção 5) |
| Não exercitado | br-sisbajud → br-sta `POST /v1/transfers` (precisa de plugin-access-manager e de instituições/ordens cadastradas); arquivos inbound do BACEN/mock até o br-sisbajud | — | — |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Correção |
|---|---|---|
| Valkey e a app reiniciam a cada `helm upgrade` | O subchart do Valkey regenera uma senha deixada vazia | O `values-dev.yaml` agora fixa senhas dev públicas para PostgreSQL e Valkey; fixe as suas em outros arquivos de dev |
| Postgres `password authentication failed` depois de mudar as senhas dev | O volume de dados guarda a senha com que foi inicializado | `helm uninstall`, apague os PVCs, reinstale |
| `sta_consumer` `degraded` / `consumer_not_polling`, log `STA inbound event requeued: transfer_not_found` e depois `partition halted (head-of-line blocked)` | Comportamento conhecido da app: um fato do br-sta que referencia um transfer desconhecido pelo br-sisbajud é reprocessado e bloqueia a partição | Monitore `sta_consumer`; em dev, não crie transfers no br-sta por fora do br-sisbajud num tópico compartilhado |
| Job de tópicos falha com TLS ligado | A imagem de tópicos precisa da CA do broker como arquivo quando `STREAMING_TLS_ENABLED=true`, mesmo para broker com CA pública | Sete `brSisbajud.secrets.STREAMING_TLS_CA_CERT`, ou provisione os tópicos por fora e use `topics.enabled=false` |
| Render falha citando `STA_INBOUND_BUCKET` | Sem default por política | `global.objectStorage.sta.bucket` = bucket de transfer do br-sta |
| Boot recusado em produção, erros de licença | `LICENSE_KEY` ausente, ou sem egress até o gateway de licença (não há modo de licença offline nesta versão da app) | Sete a chave e libere o egress |
| Chamadas do browser bloqueadas mesmo com origens CORS setadas | O middleware de CORS do lib-commons lê `ACCESS_CONTROL_ALLOW_ORIGIN` | Use `brSisbajud.cors.allowedOrigins` (o chart mapeia); wildcard exige o opt-in explícito |
| br-sta `1.0.0` "mais velho" que `1.2.0-beta.x` | A linha de versões do br-sta recomeçou no release estável: `1.0.0` é o release posterior e compatível | Fixe o br-sta em `1.0.0` explicitamente |
