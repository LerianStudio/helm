# br-sisbajud — Runbook de instalação

> Como instalar, validar e diagnosticar o br-sisbajud a partir deste chart (dev bundle,
> com o br-sta, standalone, produção). Para quem opera a instalação do chart.

> **Desatualizado: este runbook descreve o monólito br-sisbajud (app 1.2.x).** O chart
> agora implanta a Sisbajud Mensageria (br-sfn `services/sisbajud`, app 1.1.0):
> API principal na 4031, API de execução num listener TLS na 4032, streaming
> obrigatório, verificação de JWT obrigatória (`brSisbajud.auth`), licença em
> todo ambiente e o consumer do br-sta no próprio cluster `sta.stream`. O
> README ("From the monolith ... to the Mensageria", "Execution API", "Fail-fast
> gates") é a referência até este runbook ser reescrito.

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `br-sisbajud-helm` **1.4.3** / app **1.1.0** |
| Componentes | um binário Go (API HTTP principal `:4031`, API de execução `:4032` e workers de background), Job de migrations, Job de tópicos (desligado por default) |
| Imagens | `ghcr.io/lerianstudio/br-sisbajud`, `br-sisbajud-migrations`, `br-sisbajud-topics` (todas públicas no GHCR) |
| Guia de upgrade | vindo do chart 1.1.x: [`UPGRADE-1.2.md`](UPGRADE-1.2.md) |
| Última revisão deste runbook | 2026-10-05, contra chart 1.2.0 / app 1.2.0 |
| Contato de escalação | `@LerianStudio/G_Github_Devops` (ver `.github/CODEOWNERS`) |

---

## 1. Perfis de instalação

> **A infraestrutura embutida é apenas para desenvolvimento e quickstart. Instalações de produção devem usar infraestrutura externa e gerenciada.** Produção significa PostgreSQL com TLS, Valkey/Redis, Kafka/Redpanda com TLS, Vault/OpenBao fora do modo dev (ou AWS KMS) e object storage S3. Os subcharts embutidos `postgresql`, `valkey`, `seaweedfs`, `openbao` e `redpanda` existem para instalações de desenvolvimento, POC e quickstart. O render recusa os bundles de OpenBao e Redpanda fora de um ambiente da classe dev (`local`, `development`, `develop`, `dev`, `test`, `e2e`; staging também é recusado). Os bundles de PostgreSQL, Valkey e SeaweedFS só recebem um aviso no NOTES num ambiente com cara de produção, mas também não são suportados em produção.

| Perfil | Values | O que roda | Uso |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | a app, mais PostgreSQL, Valkey, SeaweedFS (S3), OpenBao (Vault Transit, modo dev) e Redpanda embutidos; `ENVIRONMENT_NAME=development`; auth de entrada, consumer/cliente de transfers do br-sta e multi-tenancy desligados | Avaliação, desenvolvimento local, teste do chart |
| **br-sisbajud + br-sta juntos** | `values-dev.yaml` + `values-dev-with-br-sta.yaml` | a app com PostgreSQL, Valkey e OpenBao próprios, reaproveitando o SeaweedFS e o Redpanda de um dev bundle do br-sta no mesmo namespace; cliente de transfers do br-sta ligado; o consumer do br-sta fica desligado (exige SASL, que o Redpanda do dev bundle do br-sta não oferece) | Dev integrado do fluxo STA (arquivos de retorno) |
| **Produção / infra externa** | seu arquivo, a partir do `values-template.yaml` | a app + Job de migrations (o Job de tópicos é desligado por default); toda dependência externa | Tiers reais. Ambiente default `production` (fail-closed) |

Só com os defaults o chart não renderiza: o ambiente default é `production`, então o
chart falha de propósito até as conexões externas e os secrets estarem setados (seção 5).

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| PostgreSQL | Sempre (single-tenant: o host é obrigatório) | `global.datastores.postgres` + `brSisbajud.secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Sempre (rate limit, idempotência, locks de processamento) | `global.datastores.redis` (`host:porta`) + `brSisbajud.secrets.REDIS_PASSWORD` |
| Kafka / Redpanda | Sempre (streaming obrigatório: o producer lib-streaming): brokers obrigatórios; TLS em produção | `global.streaming` + `brSisbajud.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| HashiCorp Vault Transit **ou** AWS KMS | Sempre (criptografia envelope dos dados de bloqueio judicial) | `global.kms` + `brSisbajud.secrets.VAULT_APPROLE_SECRET_ID` (ou `VAULT_TOKEN`); com AWS KMS: `awsRegion` + `awsKeyMode` (`managed`\|`provided`) e, em `provided`, `awsKeyArn` (em `brSisbajud.kms` ou `global.kms`) |
| Object storage S3 | Sempre (artefatos criptografados + o bucket de transfer do br-sta) | `global.objectStorage.sisbajud` / `.sta` + `SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` |
| br-sta | Entrada de remessas (fatos em `lerian.streaming.br-sta`) e envio de arquivos de retorno (`POST /v1/transfers`) | `brSisbajud.sta.*`, `global.objectStorage.sta` (o mesmo bloco que o br-sta lê) |
| plugin-access-manager | Validação JWT de entrada, bearer m2m do STA, declaração de permissões | `global.auth`, `brSisbajud.identity` |
| Gateway de licença Lerian | Sempre, em todo ambiente (`LICENSE_KEY`, app 1.1.0); o pod precisa de egress até ele | `brSisbajud.secrets.LICENSE_KEY`, `brSisbajud.license.organizationIds` (`global`) |
| Tenant manager | Só com multi-tenancy | `global.multiTenant` + `MULTI_TENANT_SERVICE_API_KEY` |

A Mensageria não chama o ledger Midaz: o plugin-br-sisbajud executa as ordens nele. Cadastre as instituições pela API admin (`POST /v1/institutions`) antes de as ordens poderem executar.

---

## 3. Ordem de instalação

### Dev bundle

> A infraestrutura embutida é apenas para desenvolvimento e quickstart. Instalações de produção devem usar infraestrutura externa e gerenciada. Não promova este perfil para um tier de produção.

```bash
kubectl create namespace sisb-dev
# a chave de licença fica num arquivo: nunca vai para o histórico do shell nem para os args do processo
kubectl create secret generic br-sisbajud-license -n sisb-dev \
  --from-file=LICENSE_KEY=./br-sisbajud.license
helm dependency update charts/br-sisbajud
helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml \
  --set-json 'brSisbajud.secretRefs={"LICENSE_KEY":{"name":"br-sisbajud-license","key":"LICENSE_KEY"}}'
```

A licença é obrigatória aqui também. A app 1.1.0 exige a licença em todo ambiente,
`development` incluído (sem bypass de dev). O `values-dev.yaml` não traz chave: o chart
renderiza, mas o pod não sobe até uma chave real ser configurada.

As imagens são públicas, então não é preciso pull secret (o `imagePullSecrets` de topo
é só para um mirror/registry privado). Com as
dependências embutidas, o pod da app roda initContainers idempotentes (migrations e
mount do Transit; espera do broker e tópicos só com `topics.enabled`) antes de subir,
então nunca sobe sem schema ou Transit montado.

Esperado com o release no ar:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0`, `redpanda-0`, `seaweedfs-master-0`, `seaweedfs-volume-0`, `seaweedfs-filer-0`, `seaweedfs-s3-*` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit`, `br-sisbajud-seaweedfs-buckets` |

Com uma dependência embutida esses Jobs são hooks post-install/post-upgrade só com
`before-hook-creation`, então ficam `Complete` até o `ttlSecondsAfterFinished` (600 s)
removê-los. O próximo upgrade os substitui.

### br-sisbajud + br-sta juntos

```bash
# 0. namespace (as imagens dos dois charts são públicas: sem pull secret)
kubectl create namespace sisb-dev
# 1. dev bundle do br-sta, somando o bucket do br-sisbajud ao Job de buckets dele
kubectl create secret generic br-sta-license -n sisb-dev \
  --from-file=LICENSE_KEY=./br-sta.license
helm dependency update charts/br-sta
helm install br-sta charts/br-sta -n sisb-dev -f charts/br-sta/values-dev.yaml \
  --set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]' \
  --set-json 'common.secretRefs={"LICENSE_KEY":{"name":"br-sta-license","key":"LICENSE_KEY"}}' \
  --set common.license.organizationIds=<organization id do br-sta>
# 2. br-sisbajud ligado a ele (reaproveita o SeaweedFS + Redpanda do br-sta)
kubectl create secret generic br-sisbajud-license -n sisb-dev \
  --from-file=LICENSE_KEY=./br-sisbajud.license
helm dependency update charts/br-sisbajud
helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml -f charts/br-sisbajud/values-dev-with-br-sta.yaml \
  --set-json 'brSisbajud.secretRefs={"LICENSE_KEY":{"name":"br-sisbajud-license","key":"LICENSE_KEY"}}'
```

O overlay assume o release do br-sta com o nome `br-sta` (Service do manager
`br-sta-manager:4028`) e os nomes default das Services do SeaweedFS / Redpanda.

Esperado: pods do br-sisbajud Ready sem restarts, e estes Jobs Complete:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit` |

Os tópicos `lerian.streaming.br-sisbajud` e `.dlq` são criados no Redpanda
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
| `brSisbajud.sta.consumerEnabled` | `STA_CONSUMER_ENABLED` | `false` | Assina os fatos de negócio do br-sta (`lerian.streaming.br-sta`) e recebe as remessas que o br-sta anuncia (precisa dos brokers de `sta.stream`, de SASL (`saslMechanism`, `saslUsername` + `STA_STREAM_SASL_PASSWORD`), de TLS + `STA_STREAM_TLS_CA_CERT` ou do opt-in de texto claro fora de produção, e de `sta.expectedTenantSt`) |
| `brSisbajud.sta.transfersEnabled` | `STA_TRANSFERS_ENABLED` | `false` | Submete os arquivos de retorno gerados ao br-sta (`POST /v1/transfers`), emitindo um bearer m2m a partir do `PLUGIN_AUTH_HOST` (precisa de `sta.transfersBaseUrl`, `sta.clientId` + `STA_CLIENT_SECRET`) |

Com os dois desligados, a app não recebe remessas: a app 1.1.0 só as recebe pelos fatos
de negócio do br-sta (`sta.consumerEnabled`).

**Arquivos de retorno sem br-sta.** Os crons de retorno (`workers.returnFile`,
`workers.informationReturnFile`, desligados por default) continuam gerando os arquivos
AJUD302/AJUD309. Com `transfersEnabled` desligado, "gerado e não submetido" é um estado
válido para o app: ele sobe e loga cada arquivo como não submetido. O app só recusa o
boot quando os transfers estão ligados mas o caminho de submissão não pôde ser montado.
- **Para onde vão os arquivos:** ficam guardados **cifrados** (ciphertext, chave com
  escopo da instituição) no bucket do serviço `SEAWEEDFS_BUCKET`. Não há arquivo em
  texto claro para buscar no bucket.

### Produção

**Como confirmar uma instalação de produção** (`global.env.name=production`, só infra
externa):

- O pod da app fica `1/1 Running` sem restarts.
- O log de boot traz `Organization global has a valid license` e
  `license validation enabled`.
- O `/readyz` fica `healthy`, com `kms`, `postgres`, `redis`, `seaweedfs` e `streaming`
  `up`.
- Os tópicos `lerian.streaming.br-sisbajud` e `.dlq` existem no broker.
- As conexões efetivas são as com TLS: PostgreSQL `sslmode=require`, Valkey e Kafka com
  TLS (SASL quando configurado), Vault Transit ou AWS KMS como KMS, origem CORS
  explícita, `ORGANIZATION_IDS=global`.
- Com o br-sta ligado: `sta_bucket_parity` e `sta_consumer` `up`, e o consumer group
  `br-sisbajud-sta-intake-v1` fica `Stable` em `lerian.streaming.br-sta`.
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
   helm install br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version <versão> \
     -n <namespace> -f my-values.yaml
   ```

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
| `global.env.name` | `ENVIRONMENT_NAME`, `ENV_NAME` | Só `local`/`development`/`staging`/`e2e`/`test` relaxam os gates (nunca a licença); qualquer outro valor é tratado como produção |
| `global.datastores.*` | `POSTGRES_*`, `REDIS_*` | os subcharts embutidos derivam sozinhos |
| `global.objectStorage.sisbajud` | `SEAWEEDFS_S3_ENDPOINT/BUCKET/REGION` | — |
| `global.objectStorage.sta` | `STA_INBOUND_BUCKET` (+ `TRANSFER_OBJECT_STORAGE_BUCKET`), `STA_OBJECT_STORAGE_ENDPOINT` | O endpoint segue o do sisbajud; a app exige paridade de bucket e endpoint com o br-sta |
| `global.kms` | `KMS_PROVIDER`, `VAULT_*`, `AWS_REGION`, `KMS_AWS_KEY_MODE`, `KMS_AWS_KEY_ARN` | `VAULT_APPROLE_SECRET_ID` / `VAULT_TOKEN` são secrets. Modo e ARN: `brSisbajud.configmap` > `brSisbajud.kms` > `global.kms`; `provided` exige o ARN, `managed` o recusa. As chaves `KMS_AWS_*` derivadas pelo chart (`kms.awsKeyMode`/`awsKeyArn` e os knobs de `brSisbajud.vault`) só saem com `KMS_PROVIDER=aws`; `brSisbajud.configmap.KMS_AWS_*` é a válvula de escape e sai com qualquer provider |
| `brSisbajud.vault.awsKmsTimeoutSec` / `awsKmsRotationCheckIntervalSec` | `KMS_AWS_TIMEOUT_SEC` / `KMS_AWS_ROTATION_CHECK_INTERVAL_SEC` | Opcionais, só com `KMS_PROVIDER=aws`; segundos inteiros, `1`..`600` (todo modo aws) e `1`..`86400` (validado só em `provided`) |
| `global.streaming` | `STREAMING_*` | Só o producer lib-streaming; os fatos do br-sta chegam por `brSisbajud.sta.stream` |
| `global.auth` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | O cliente de transfers do STA emite o bearer m2m a partir deste host mesmo com auth desligado |

Ligação com o br-sta (valores agrupados em `brSisbajud.sta`): `consumerEnabled`,
`expectedTenantSt` (= `DEFAULT_TENANT_ID` do br-sta em single-tenant), `transfersEnabled`,
`transfersBaseUrl` (URL do manager do br-sta), `clientId` (+ `STA_CLIENT_SECRET` no Secret).

---

## 5. Pontos de atenção operacional

| Tema | O que saber | Antes de habilitar / como confirmar |
|---|---|---|
| Render fail-fast | Espelha a validação de boot da app: `STA_INBOUND_BUCKET` sempre; host de Postgres/Redis em single-tenant; provider do KMS + credenciais; brokers/SASL/TLS do streaming; `LICENSE_KEY` em ambiente tipo produção (a app exige em todo ambiente); senha do Postgres em ambiente tipo produção; credenciais do cliente de transfers do STA / auth de entrada / publisher de declaração; URL/Redis/API key do multi-tenant; `ORGANIZATION_IDS` obrigatório e `global` | Leia o erro do render: ele diz exatamente o valor |
| Guarda dos bundles dev-only | `openbao` (modo dev, chaves em memória) e `redpandaBundle` são recusados fora de `local`/`development`/`develop`/`dev`/`test`/`e2e` (staging também é recusado). Independe dos relaxamentos da própria app, que `staging` continua tendo | `helm template ... --set global.env.name=production` com o dev bundle falha citando os dois |
| OpenBao modo dev | Reiniciar o pod do OpenBao perde todas as chaves Transit: linhas criptografadas antes ficam ilegíveis | Só dev/avaliação; resete o banco junto |
| Cliente de transfers do STA | Precisa de um plugin-access-manager acessível para emitir o bearer m2m | Sem ele, o envio de arquivo de retorno ao br-sta falha |
| Fatos do br-sta de transfers desconhecidos | Comportamento conhecido da app: um fato em `lerian.streaming.br-sta` de um transfer que o br-sisbajud não criou é reprocessado (segurando a partição) até esgotar o orçamento de tentativas e depois estacionado na DLQ (`transfer_not_found_after_retry`) | Acompanhe `sta_consumer` no `/readyz` (`consumer_not_polling`) |
| Trava de imagem com AWS KMS | Imagens anteriores a `1.1.0-beta.13` ignoram `KMS_AWS_KEY_MODE`/`KMS_AWS_KEY_ARN` e criam a própria chave KMS; com `KMS_PROVIDER=aws` o render recusa essas tags. Só a forma canônica `vX.Y.Z[-(alpha\|beta\|rc).N]` (sem zeros à esquerda, sem `@`) é comparada com o mínimo | Qualquer outra tag (digest `@`, sufixo de arquitetura, `+build`, não-SemVer) exige `brSisbajud.kms.allowUnverifiableImageTag: true` (não é lido de `global.kms`); com a flag, uma tag não canônica passa sem checagem de versão. Uma tag canônica abaixo de `1.1.0-beta.13` falha mesmo com a flag |
| Imagens | Imagens da app, migrations e tópicos são públicas no GHCR | Pull secret (`imagePullSecrets`) só para um mirror/registry privado |

### Licença

| Tema | Comportamento (app `1.1.0`) |
|---|---|
| Todo ambiente | Na app 1.1.0 a licença é obrigatória em todo `ENVIRONMENT_NAME`, `development`/`staging`/`e2e`/`test`/`local` incluídos: sem bypass de dev, sem modo sem licença. O boot falha fechado quando `LICENSE_KEY` está vazio ou `ORGANIZATION_IDS` está vazio ou diferente de `global`. Só um build local com `-tags licensetest` roda sem licença; a imagem publicada nunca |
| No startup | Uma licença válida sobe, e uma licença em carência também, incluindo a carência de indisponibilidade quando o gateway não consegue responder. Uma recusa 4xx do gateway aborta o boot |
| Uma chave por produto | Uma chave licencia um único produto. Chave emitida para outro produto é recusada com `Exiting: LCS-0012: refused by the gateway (LCS-1005)`; chave desconhecida ou adulterada, com `(LCS-1002)` |
| Na recusa | O processo sai e o pod entra em `CrashLoopBackOff`. Num rolling update o pod que já está rodando continua servindo: o rollout trava, mas nada cai |
| Gateway | `https://license.lerian.io`, `POST /licenses/validate`. O egress até ele é obrigatório e a URL não é configurável. Chaves emitidas para staging foram validadas neste gateway de produção. |
| Refresh e carência | A chave é revalidada a cada 6 h. Quando o gateway não responde (erro de rede ou 5xx) depois de ter confirmado a chave uma vez, o processo segue servindo em janelas de carência decrescentes (2 d, 1 d, 12 h, 6 h, no máximo 3 d 18 h) e depois sai. Um processo que nunca foi confirmado ganha só 6 h. Uma recusa 4xx encerra a carência na hora. As janelas vivem em memória: um pod reiniciado durante uma queda começa sem confirmação |
| Offline | Não há modo de licença offline nesta versão da app |
| Gate de render | Um ambiente tipo produção falha o render sem `LICENSE_KEY` (valor no Secret, `secretRefs`, `extraEnvVars` ou `useExistingSecret`); em `local`/`development`/`staging`/`e2e`/`test` o render passa e o pod não sobe. `ORGANIZATION_IDS` precisa ser `global` |
| Como confirmar | Não há check de licença no `/readyz`: procure no log de boot as linhas `Organization global has a valid license` e `license validation enabled` |

---

## 6. Como validar uma instalação bem-sucedida

```bash
kubectl -n <ns> get pods
kubectl -n <ns> get jobs
kubectl -n <ns> port-forward svc/br-sisbajud 14029:4031
curl -s localhost:14029/readyz     # path do readiness probe
curl -s localhost:14029/health     # path do liveness probe
```

| Checagem | Comando/URL | Esperado | Se não bater, verifique primeiro |
|---|---|---|---|
| Pods | `kubectl get pods` | app `1/1 Running`, 0 restarts | `CrashLoopBackOff`: o log diz a dependência que falta |
| Jobs | `kubectl get jobs` | Dev bundle: `migrations`, `openbao-transit`, `seaweedfs-buckets` `Complete` (até o TTL de 600 s). Infra externa: Helm e ArgoCD apagam os Jobs de hook de migrations/tópicos quando terminam com sucesso, então nenhum Job restante significa sucesso | Um Job `Failed` (mantido para os logs): host/senha do Postgres; acesso ao broker para os tópicos |
| Readiness | `GET /readyz` | `healthy`; `postgres`, `redis`, `kms`, `seaweedfs`, `streaming` `up`; com o br-sta ligado: `sta_bucket_parity` `up` e `sta_consumer` `up` | `sta_bucket_parity` continua `up` com um motivo (`unreachable`, `endpoint_mismatch`, `bucket_mismatch`): o store sta está inacessível ou o bucket/endpoint difere dos do br-sta |
| Integração com br-sta | crie um transfer no br-sta (ver o runbook do br-sta): o mock STA leva a `Accepted` e o br-sta publica um fato em `lerian.streaming.br-sta` | O fato chega ao consumer STA do br-sisbajud (grupo `br-sisbajud-sta-intake-v1`) | Um fato de transfer que o br-sisbajud não criou é reprocessado (seção 5) |
| Limitação conhecida | br-sisbajud → br-sta `POST /v1/transfers` exige o plugin-access-manager (o bearer m2m) e instituições/ordens cadastradas; sem ele o envio de transfers falha | — | Aponte `global.auth.host` para um plugin-access-manager real |

---

## 7. Erros conhecidos e o que significam

| Erro/log | Causa | Correção |
|---|---|---|
| Valkey e a app reiniciam a cada `helm upgrade` | O subchart do Valkey regenera uma senha deixada vazia | O `values-dev.yaml` fixa senhas dev públicas para PostgreSQL e Valkey; fixe as suas em outros arquivos de dev |
| Postgres `password authentication failed` depois de mudar as senhas dev | O volume de dados guarda a senha com que foi inicializado | `helm uninstall`, apague os PVCs, reinstale |
| `sta_consumer` `consumer_not_polling`, log `STA inbound event requeued: transfer_not_found` e depois `partition halted (head-of-line blocked)` | Comportamento conhecido da app: um fato do br-sta que referencia um transfer desconhecido pelo br-sisbajud é reprocessado (segurando a partição) até esgotar o orçamento de tentativas e depois estacionado na DLQ (`transfer_not_found_after_retry`) | Monitore `sta_consumer`; em dev, não crie transfers no br-sta por fora do br-sisbajud num tópico compartilhado |
| Job de tópicos falha com TLS ligado | A imagem de tópicos precisa da CA do broker como arquivo quando `STREAMING_TLS_ENABLED=true`, mesmo para broker com CA pública | Sete `brSisbajud.secrets.STREAMING_TLS_CA_CERT`, ou provisione os tópicos por fora e use `topics.enabled=false` |
| Render falha citando `STA_INBOUND_BUCKET` | Sem default por política | `global.objectStorage.sta.bucket` = bucket de transfer do br-sta |
| Boot recusado (qualquer ambiente), erros de licença | `LICENSE_KEY` ausente, chave de outro produto (`LCS-1005`) ou chave desconhecida (`LCS-1002`), ou sem egress até o gateway de licença (não há modo de licença offline nesta versão da app) | Sete a chave deste produto e libere o egress (seção 5, Licença) |
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
