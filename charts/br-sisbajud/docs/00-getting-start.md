# br-sisbajud — Runbook de instalação

> Como instalar, validar e diagnosticar o br-sisbajud a partir deste chart (dev bundle,
> com o br-sta, standalone, produção). Para quem opera a instalação do chart.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `br-sisbajud-helm` (release **1.2.0**; o pipeline de release define a versão, então o `Chart.yaml` da branch ainda mostra `1.1.0`) / app **1.1.0** |
| Componentes | um binário Go (API HTTP `:4029` + workers de background), Job de migrations, Job de tópicos |
| Imagens | `ghcr.io/lerianstudio/br-sisbajud`, `br-sisbajud-migrations`, `br-sisbajud-topics` (todas públicas no GHCR) |
| Guia de upgrade | vindo do chart 1.1.x: [`UPGRADE-1.2.md`](UPGRADE-1.2.md) |
| Última revisão deste runbook | 2026-09-30, contra chart 1.2.0 / app 1.1.0 |
| Contato de escalação | `@LerianStudio/G_Github_Devops` (ver `.github/CODEOWNERS`) |

---

## 1. Perfis de instalação

> **A infraestrutura embutida é apenas para desenvolvimento e quickstart. Instalações de produção devem usar infraestrutura externa e gerenciada.** Produção significa PostgreSQL com TLS, Valkey/Redis, Kafka/Redpanda com TLS, Vault/OpenBao fora do modo dev (ou AWS KMS) e object storage S3. Os subcharts embutidos `postgresql`, `valkey`, `seaweedfs`, `openbao` e `redpanda` existem para instalações de desenvolvimento, POC e quickstart. O render recusa os bundles de OpenBao e Redpanda fora de um ambiente da classe dev (`local`, `development`, `develop`, `dev`, `test`, `e2e`; staging também é recusado). Os bundles de PostgreSQL, Valkey e SeaweedFS só recebem um aviso no NOTES num ambiente com cara de produção, mas também não são suportados em produção.

| Perfil | Values | O que roda | Uso |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | a app, mais PostgreSQL, Valkey, SeaweedFS (S3), OpenBao (Vault Transit, modo dev) e Redpanda embutidos; `ENVIRONMENT_NAME=development`; auth de entrada, consumer/cliente de transfers do br-sta e multi-tenancy desligados | Avaliação, desenvolvimento local, teste do chart |
| **br-sisbajud + br-sta juntos** | `values-dev.yaml` + `values-dev-with-br-sta.yaml` | a app com PostgreSQL, Valkey e OpenBao próprios, reaproveitando o SeaweedFS e o Redpanda de um dev bundle do br-sta no mesmo namespace; consumer e cliente de transfers do br-sta ligados | Dev integrado do fluxo STA (entrada de remessas, arquivos de retorno) |
| **Standalone (sem br-sta)** | `values-dev.yaml` (ou seu arquivo) com `sta.consumerEnabled` / `sta.transfersEnabled` desligados (o default) | só a app; as remessas entram pela recepção HTTP `POST /v1/remittance-files/notifications` depois que o arquivo bruto é depositado no `STA_INBOUND_BUCKET` | Rodar o SISBAJUD sem o trilho do br-sta (seção 3, "Standalone") |
| **Produção / infra externa** | seu arquivo, a partir do `values-template.yaml` | a app + Jobs de migrations e tópicos; toda dependência externa | Tiers reais. Ambiente default `production` (fail-closed) |

Só com os defaults o chart não renderiza: o ambiente default é `production`, então o
chart falha de propósito até as conexões externas e os secrets estarem setados (seção 5).

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| PostgreSQL | Sempre (single-tenant: o host é obrigatório) | `global.datastores.postgres` + `brSisbajud.secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Sempre (rate limit, idempotência, locks de processamento) | `global.datastores.redis` (`host:porta`) + `brSisbajud.secrets.REDIS_PASSWORD` |
| Kafka / Redpanda | Streaming ligado por default (producer/consumers lib-streaming, tradutor de saldo do Midaz, fatos do br-sta): brokers obrigatórios; TLS + CA em produção | `global.streaming` + `brSisbajud.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
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

> A infraestrutura embutida é apenas para desenvolvimento e quickstart. Instalações de produção devem usar infraestrutura externa e gerenciada. Não promova este perfil para um tier de produção.

```bash
helm install br-sisbajud charts/br-sisbajud -n sisb-dev --create-namespace \
  -f charts/br-sisbajud/values-dev.yaml
```

As imagens são públicas, então não é preciso pull secret (o `imagePullSecrets` de topo
é só para um mirror/registry privado). Com as
dependências embutidas, o pod da app roda initContainers idempotentes (migrations,
espera do broker, tópicos, mount do Transit) antes de subir, então nunca sobe sem
schema, tópicos ou Transit montado.

Esperado com o release no ar:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0`, `redpanda-0`, `seaweedfs-master-0`, `seaweedfs-volume-0`, `seaweedfs-filer-0`, `seaweedfs-s3-*` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit`, `br-sisbajud-seaweedfs-buckets`, `br-sisbajud-topics` |

Com uma dependência embutida esses Jobs são hooks post-install/post-upgrade só com
`before-hook-creation`, então ficam `Complete` até o `ttlSecondsAfterFinished` (600 s)
removê-los. O próximo upgrade os substitui.

### br-sisbajud + br-sta juntos

```bash
# 0. namespace + pull secret do GHCR para o br-sta (as imagens dele são privadas)
kubectl create namespace sisb-dev
kubectl -n sisb-dev create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<github-user> --docker-password=<GHCR_READ_TOKEN>
# 1. dev bundle do br-sta, somando o bucket do br-sisbajud ao Job de buckets dele
helm install br-sta charts/br-sta -n sisb-dev -f charts/br-sta/values-dev.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]' \
  --set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'
# 2. br-sisbajud ligado a ele (reaproveita o SeaweedFS + Redpanda do br-sta)
helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml -f charts/br-sisbajud/values-dev-with-br-sta.yaml
```

O overlay assume o release do br-sta com o nome `br-sta` (Service do manager
`br-sta-manager:4028`) e os nomes default das Services do SeaweedFS / Redpanda.

Esperado: pods do br-sisbajud Ready sem restarts, e estes Jobs Complete:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit` |

O `br-sisbajud-topics` também roda aqui, mas não como Job de bundle: o Redpanda que ele
usa é o do br-sta, externo do ponto de vista do br-sisbajud. Por isso ele é um hook
`pre-install`/`pre-upgrade` com `hook-succeeded`, e o Helm o apaga quando termina com
sucesso. `helm get hooks br-sisbajud -n sisb-dev` mostra o hook; uma execução com falha
fica para os logs.

Os tópicos `lerian.streaming.br-sisbajud`, `.dlq` e `.commands` são criados no Redpanda
do br-sta, ao lado de `lerian.streaming.br-sta`.

Upgrades: um segundo `helm upgrade` com os mesmos values não muda a generation de nenhum
Deployment/StatefulSet nem recria pods (as senhas dev estão fixas no `values-dev.yaml`,
ver seção 7).

Limpeza:

```bash
helm uninstall br-sisbajud -n sisb-dev
helm uninstall br-sta -n sisb-dev
kubectl -n sisb-dev delete pvc --all   # também necessário depois de mudar as senhas dev
kubectl delete namespace sisb-dev
```

### Standalone (sem br-sta)

O br-sisbajud roda sem o br-sta. As duas pernas do STA são toggles independentes,
**desligados por default** (e desligados no `values-dev.yaml`):

| Value | Chave de env | Default | O que faz quando `true` |
|---|---|---|---|
| `brSisbajud.sta.consumerEnabled` | `STA_CONSUMER_ENABLED` | `false` | Assina os fatos de negócio do br-sta (`lerian.streaming.br-sta`) e recebe as remessas que o br-sta anuncia (precisa de `global.streaming.enabled: true`, `STREAMING_BROKERS` e `sta.expectedTenantSt`) |
| `brSisbajud.sta.transfersEnabled` | `STA_TRANSFERS_ENABLED` | `false` | Submete os arquivos de retorno gerados ao br-sta (`POST /v1/transfers`), emitindo um bearer m2m a partir do `PLUGIN_AUTH_HOST` (precisa de `sta.transfersBaseUrl`, `sta.clientId` + `STA_CLIENT_SECRET`) |

Com os dois desligados, **as remessas entram pela recepção HTTP**, o único caminho de
entrada que não depende do br-sta. O `STA_INBOUND_BUCKET` continua obrigatório: é o
bucket de onde a recepção lê a remessa bruta.

**1. Crie a instituição (uma vez).** Isso provisiona a KEK da instituição (o arquivo
bruto é selado com ela na recepção). O `institutionCode` é a raiz de CNPJ BACEN de 8
dígitos, que precisa bater com o header da remessa. O `connectorMetadata` é validado na
escrita: `baseUrl` e ao menos um `organizations[].organizationId` são obrigatórios mesmo
antes de o Midaz estar ligado. Sem credenciais, o conector não envia header de auth.

```bash
kubectl -n sisb-dev port-forward svc/br-sisbajud 14029:4029 &
INST=44444444-4444-4444-4444-444444444444
curl -s -X POST localhost:14029/v1/institutions -H 'Content-Type: application/json' -d '{
  "institutionId": "'$INST'",
  "connectorType": "midaz",
  "institutionCode": "12345678",
  "connectorMetadata": {
    "baseUrl": "http://midaz-ledger.midaz.svc.cluster.local:3002",
    "organizations": [{"organizationId": "019fcd7b-97df-71a5-8023-6eb3c661968b"}],
    "blockableBalances": ["default"],
    "blockableAccountTypes": ["deposit"]
  }
}'
```

**2. Deposite a remessa bruta no `STA_INBOUND_BUCKET`.** Com o SeaweedFS embutido
(auth S3 desligada no dev bundle), de dentro do namespace:

```bash
kubectl -n sisb-dev run s3-put --rm -i --restart=Never --image=amazon/aws-cli:2.17.0 \
  --env AWS_ACCESS_KEY_ID=any --env AWS_SECRET_ACCESS_KEY=any --env AWS_DEFAULT_REGION=us-east-1 \
  --command -- sh -c 'cat > /tmp/r.txt && aws --endpoint-url http://seaweedfs-s3:8333 \
    s3 cp /tmp/r.txt s3://br-sta-transfer/inbound/12345678/AJUD301_12345678_20260617.txt' \
  < remessa.txt
```

O bucket é o `global.objectStorage.sta.bucket` (`br-sta-transfer` no
`values-dev.yaml`). O repositório do br-sisbajud traz uma remessa 5301 válida com CNPJ
`12345678` no header em `internal/bootstrap/testdata/remittance_notification_remessa.txt`.

**3. Notifique o serviço.** O corpo é camelCase e os quatro campos são obrigatórios:

```bash
curl -s -X POST localhost:14029/v1/remittance-files/notifications \
  -H 'Content-Type: application/json' -d '{
  "objectKey": "inbound/12345678/AJUD301_12345678_20260617.txt",
  "institutionId": "'$INST'",
  "institutionCode": "12345678",
  "fileType": "5301"
}'
# => {"status":"processed","fileId":"<uuid>","environment":"PRODUCTION"}
```

| Campo | Regra |
|---|---|
| `objectKey` | Chave do objeto já presente no `STA_INBOUND_BUCKET`. Para `5303`/`5313` (resultados de validação do BACEN) precisa ser `inbound/<protocolo só com dígitos>/<nome do arquivo>`; nos demais, qualquer chave não vazia |
| `institutionId` | UUID de uma instituição existente |
| `institutionCode` | CNPJ BACEN de 8 dígitos da instituição; o parser confere com o header do arquivo |
| `fileType` | Código numérico SISBAJUD, nunca um rótulo: `5301`/`5303`/`5308` (PRODUCTION: remessa de bloqueio / resultado de validação sintática / requisição AJUD308), `5311`/`5313`/`5318` (os mesmos três em HOMOLOGATION). `5302`/`5312` são produzidos por este serviço, nunca aceitos |

Respostas:
- `200 {"status":"processed","fileId","environment"}`;
- `200 {"status":"skipped","reason":"skipped"}` numa reentrega idempotente, ou
  `"reason":"lock_held"` enquanto outro worker processa o mesmo arquivo;
- `422` SBJ-0006: corpo inválido, `fileType` desconhecido ou formato de chave inválido;
- `404` SBJ-0005: o objeto não está no bucket;
- `503` SBJ-0008.
- `500` SBJ-0002 para uma instituição que não existe (comportamento conhecido da app `1.1.0`: cadastre a instituição antes).

A recepção roda de forma síncrona na requisição.

**Auth.** Com `PLUGIN_AUTH_ENABLED=false` (o dev bundle) a rota fica aberta. Com auth
ligada, quem chama precisa do escopo `remittance_file:receive`: o papel
`br-sisbajud-admin` ou o papel editor M2M. O `POST /v1/institutions` precisa do escopo de
escrita de instituição.

**Arquivos de retorno sem br-sta.** Os crons de retorno (`workers.returnFile`,
`workers.informationReturnFile`, desligados por default) continuam gerando os arquivos
AJUD302/AJUD309. Com `transfersEnabled` desligado, "gerado e não submetido" é um estado
válido para o app: ele sobe e loga cada arquivo como não submetido. O app só recusa o
boot quando os transfers estão ligados mas o caminho de submissão não pôde ser montado.
- **Para onde vão os arquivos:** ficam guardados **cifrados** (ciphertext, chave com
  escopo da instituição) no bucket do serviço `SEAWEEDFS_BUCKET`. Não há arquivo em
  texto claro para buscar no bucket.
- **Export em dev:** só em `local`/`development`, o
  `GET /v1/admin/return-file/{id}/content` devolve os bytes decifrados (base64).
- **Produção:** o app 1.1.0 não tem endpoint de export em produção. Entregar os
  arquivos de retorno ao BACEN é papel do br-sta (`transfersEnabled`). Sem br-sta, a
  perna de retorno precisa ser coberta pelo canal STA do próprio operador, e isso está
  fora do que esta versão do app oferece.

**Como confirmar que a recepção funciona:**

- `POST /v1/institutions` responde `201`; recriar um código de instituição existente
  responde `409`.
- A primeira notificação de uma remessa responde `200` com `"status":"processed"` e o
  `environment` do arquivo (`PRODUCTION` para um arquivo 5301/5303/5308).
- A mesma notificação reenviada responde `skipped` (dedup pelo hash do arquivo).
- Uma notificação para uma instituição que não existe responde `500` SBJ-0002 na app
  `1.1.0` (não um 4xx): cadastre a instituição antes.

### Produção

**Como confirmar uma instalação de produção** (`global.env.name=production`, só infra
externa):

- O pod da app fica `1/1 Running` sem restarts.
- O log de boot traz `Organization global has a valid license` e
  `license validation enabled`.
- O `/readyz` fica `healthy`, com `kms`, `postgres`, `redis`, `seaweedfs` e `streaming`
  `up`.
- Os tópicos `lerian.streaming.br-sisbajud`, `.dlq` e `.commands` existem no broker.
- As conexões efetivas são as com TLS: PostgreSQL `sslmode=require`, Valkey e Kafka com
  TLS (SASL quando configurado), Vault Transit ou AWS KMS como KMS, origem CORS
  explícita, `ORGANIZATION_IDS=global`.
- Com o br-sta ligado: `sta_bucket_parity` e `sta_consumer` `up`, e o consumer group
  `sisbajud-sta-consumer` fica `Stable` em `lerian.streaming.br-sta`. Isso exige
  transfers ligados (ver "Modo só-consumer" na seção 5).
- Limitação conhecida: enviar transfers br-sisbajud -> br-sta exige o
  plugin-access-manager para o bearer m2m.

1. Provisione PostgreSQL, Valkey, os buckets S3 (`global.objectStorage.sisbajud.bucket`
   e o bucket de transfer do br-sta), Vault Transit (ou AWS KMS) e o broker.
2. Crie o Secret fora do chart (`brSisbajud.useExistingSecret` + `existingSecretName`)
   ou preencha `brSisbajud.secrets` com placeholders `<path:...>`.
3. Pull secret: opcional. As imagens são públicas no GHCR e o default do chart é
   `imagePullSecrets: []`. Só para um mirror/registry privado, crie o Secret e defina a
   lista raiz, usada pelos pods da app, de migrations, tópicos e buckets:

   ```bash
   kubectl -n <namespace> create secret docker-registry <seu-secret> \
     --docker-server=<registry> --docker-username=<usuario> --docker-password=<token>
   ```

   ```yaml
   imagePullSecrets: [{name: <seu-secret>}]
   ```
4. `helm install` a partir do registry OCI, fixando a versão do chart:

   ```bash
   helm install br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.2.0 \
     -n <namespace> -f my-values.yaml
   ```

   A versão do chart é definida pelo pipeline de release no merge, então o `Chart.yaml`
   de uma branch ainda mostra a versão anterior (`1.1.0`) até o `1.2.0` ser publicado.
   Instale uma versão publicada do registry, nunca um checkout de branch. Contra infra
   externa os Jobs de migrations e tópicos são hooks Helm `pre-install/pre-upgrade` +
   PreSync do ArgoCD, então a app nunca sobe sem schema.
5. Cadastre as instituições pela API admin (`POST /v1/institutions`).

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
  streaming: { enabled: true, brokers: "", tlsEnabled: true, saslMechanism: "SCRAM-SHA-256", saslUsername: "br-sisbajud" }
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
| Guarda dos bundles dev-only | `openbao` (modo dev, chaves em memória) e `redpandaBundle` são recusados fora de `local`/`development`/`develop`/`dev`/`test`/`e2e` (staging também é recusado). Independe dos relaxamentos da própria app, que `staging` continua tendo | `helm template ... --set global.env.name=production` com o dev bundle falha citando os dois |
| OpenBao modo dev | Reiniciar o pod do OpenBao perde todas as chaves Transit: linhas criptografadas antes ficam ilegíveis | Só dev/avaliação; resete o banco junto |
| Cliente de transfers do STA | Precisa de um plugin-access-manager acessível para emitir o bearer m2m | Sem ele, o envio de arquivo de retorno ao br-sta falha |
| Fatos do br-sta de transfers desconhecidos | Comportamento conhecido da app: um fato em `lerian.streaming.br-sta` de um transfer que o br-sisbajud não criou é tratado como transitório e segura a partição | Acompanhe `sta_consumer` no `/readyz` (`degraded`, `consumer_not_polling`) |
| Imagens | Imagens da app, migrations e tópicos são públicas no GHCR | Pull secret (`imagePullSecrets`) só para um mirror/registry privado |

### Modo só-consumer (limitação conhecida da app 1.1.0)

Com `brSisbajud.sta.consumerEnabled: true` e `transfersEnabled: false`, o `/readyz`
reporta `sta_bucket_parity` `down` (`not_configured`) e o pod nunca fica Ready. O motivo
é que a app só constrói o store de paridade de bucket junto com o cliente de transfers.
Até a app mudar isso, ligue os transfers também:

```yaml
global:
  auth: { host: "<URL do auth do plugin-access-manager>" }
brSisbajud:
  sta:
    consumerEnabled: true
    transfersEnabled: true
    transfersBaseUrl: "<URL do manager do br-sta>"
    clientId: "br-sisbajud"
# mais STA_CLIENT_SECRET no Secret
```

O token m2m só é pedido quando um transfer é enviado, então um `STA_CLIENT_SECRET`
placeholder basta para o pod subir e ficar Ready. Envios de verdade precisam do client
secret real e de um plugin-access-manager acessível.

### Licença

| Tema | Comportamento (app `1.1.0`, SDK de licença v4.1.0) |
|---|---|
| Uma chave por produto | Uma chave licencia um único produto. Chave emitida para outro produto é recusada com `Exiting: LCS-0012: refused by the gateway (LCS-1005)`; chave desconhecida ou adulterada, com `(LCS-1002)` |
| Na recusa | O processo sai e o pod entra em `CrashLoopBackOff`. Num rolling update o pod que já está rodando continua servindo: o rollout trava, mas nada cai |
| Gateway | `https://license.lerian.io`, `POST /licenses/validate`. O egress até ele é obrigatório e a URL não é configurável. Chaves emitidas para staging foram validadas neste gateway de produção. `brSisbajud.license.isDevelopment: "true"` (`IS_DEVELOPMENT`) troca para `https://license.dev.lerian.io`: use só para chaves emitidas pelo gateway dev |
| Refresh e carência | A chave é revalidada a cada 6 h. Quando o gateway não responde (erro de rede ou 5xx) depois de ter confirmado a chave uma vez, o processo segue servindo em janelas de carência decrescentes (2 d, 1 d, 12 h, 6 h, no máximo 3 d 18 h) e depois sai. Um processo que nunca foi confirmado ganha só 6 h. Uma recusa 4xx encerra a carência na hora. As janelas vivem em memória: um pod reiniciado durante uma queda começa sem confirmação |
| Offline | Não há modo de licença offline nesta versão da app |
| Gate de render | Ambientes production-like falham o render sem `LICENSE_KEY`; `ORGANIZATION_IDS` precisa ser `global` |
| Como confirmar | Não há check de licença no `/readyz`: procure no log de boot as linhas `Organization global has a valid license` e `license validation enabled` |

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
| Jobs | `kubectl get jobs` | Dev bundle: `migrations`, `openbao-transit`, `seaweedfs-buckets`, `topics` `Complete` (até o TTL de 600 s). Infra externa: Helm e ArgoCD apagam os Jobs de hook de migrations/tópicos quando terminam com sucesso, então nenhum Job restante significa sucesso | Um Job `Failed` (mantido para os logs): host/senha do Postgres; acesso ao broker para os tópicos |
| Readiness | `GET /readyz` | `healthy`; `postgres`, `redis`, `kms`, `seaweedfs`, `streaming` `up`; com o br-sta ligado: `sta_bucket_parity` `up` e `sta_consumer` `up` | `sta_bucket_parity` down: bucket/endpoint sta diferentes dos do br-sta, ou `not_configured` no modo só-consumer (seção 5) |
| Integração com br-sta | crie um transfer no br-sta (ver o runbook do br-sta): o mock STA leva a `Accepted` e o br-sta publica um fato em `lerian.streaming.br-sta` | O fato chega ao consumer STA do br-sisbajud (grupo `sisbajud-sta-consumer`) | Um fato de transfer que o br-sisbajud não criou é reprocessado (seção 5) |
| Recepção HTTP | `POST /v1/institutions`, depois `POST /v1/remittance-files/notifications` (seção 3) | `201`, depois `processed`; o reenvio responde `skipped` | `500` SBJ-0002: a instituição não existe |
| Limitação conhecida | br-sisbajud → br-sta `POST /v1/transfers` exige o plugin-access-manager (o bearer m2m) e instituições/ordens cadastradas; sem ele o envio de transfers falha | — | Aponte `global.auth.host` para um plugin-access-manager real |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Correção |
|---|---|---|
| Valkey e a app reiniciam a cada `helm upgrade` | O subchart do Valkey regenera uma senha deixada vazia | O `values-dev.yaml` fixa senhas dev públicas para PostgreSQL e Valkey; fixe as suas em outros arquivos de dev |
| Postgres `password authentication failed` depois de mudar as senhas dev | O volume de dados guarda a senha com que foi inicializado | `helm uninstall`, apague os PVCs, reinstale |
| `sta_consumer` `degraded` / `consumer_not_polling`, log `STA inbound event requeued: transfer_not_found` e depois `partition halted (head-of-line blocked)` | Comportamento conhecido da app: um fato do br-sta que referencia um transfer desconhecido pelo br-sisbajud é reprocessado e bloqueia a partição | Monitore `sta_consumer`; em dev, não crie transfers no br-sta por fora do br-sisbajud num tópico compartilhado |
| Job de tópicos falha com TLS ligado | A imagem de tópicos precisa da CA do broker como arquivo quando `STREAMING_TLS_ENABLED=true`, mesmo para broker com CA pública | Sete `brSisbajud.secrets.STREAMING_TLS_CA_CERT`, ou provisione os tópicos por fora e use `topics.enabled=false` |
| Render falha citando `STA_INBOUND_BUCKET` | Sem default por política | `global.objectStorage.sta.bucket` = bucket de transfer do br-sta |
| Boot recusado em produção, erros de licença | `LICENSE_KEY` ausente, chave de outro produto (`LCS-1005`) ou chave desconhecida (`LCS-1002`), ou sem egress até o gateway de licença (não há modo de licença offline nesta versão da app) | Sete a chave deste produto e libere o egress (seção 5, Licença) |
| Pod nunca fica Ready, `/readyz` `sta_bucket_parity` `not_configured` | Modo só-consumer (`consumerEnabled` ligado, `transfersEnabled` desligado): limitação conhecida da app `1.1.0` | Ligue os transfers também (seção 5, Modo só-consumer) |
| `500` SBJ-0002 em `POST /v1/remittance-files/notifications` | A instituição não existe (comportamento conhecido da app `1.1.0`, em vez de um 4xx) | Cadastre antes com `POST /v1/institutions` |
| Chamadas do browser bloqueadas mesmo com origens CORS setadas | O middleware de CORS do lib-commons lê `ACCESS_CONTROL_ALLOW_ORIGIN` | Use `brSisbajud.cors.allowedOrigins` (o chart mapeia); wildcard exige o opt-in explícito |

---

## 8. Rollback

```bash
helm history br-sisbajud -n <namespace>
helm rollback br-sisbajud <revision> -n <namespace>
```

Com ArgoCD, reverta o commit de values/versão do chart no Git; um rollback manual é
desfeito no próximo sync.

- **Migrations só andam para frente.** O rollback reimplanta o chart e a imagem
  anteriores, mas não reverte o schema: o Job de migrations só roda `migrate up`, e o
  hook da revisão antiga o roda de novo sem efeito. Uma imagem antiga da app só é testada contra o
  próprio schema e pode falhar contra um mais novo. Volte para uma imagem que conheça a versão atual do schema, ou restaure o
  banco de um backup feito antes do upgrade. Faça esse backup antes de todo upgrade que
  traga migrations.
- **As chaves do KMS precisam sobreviver a todo rollback e reinstalação.** Dados
  cifrados, como os arquivos de retorno guardados, são embrulhados pelas chaves Transit (`sisbajud-kek-*`)
  no Vault/OpenBao, ou pela chave do AWS KMS. Nunca apague nem recrie essas chaves: um
  dado cifrado com uma chave perdida é irrecuperável. É também por isso que o bundle
  OpenBao em modo dev, com as chaves em memória, é só para dev.
