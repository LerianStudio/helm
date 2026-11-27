# flowker — Runbook de instalação

> Como instalar, validar e diagnosticar o Flowker a partir deste chart. Para quem opera a
> instalação, inclusive clientes BYOC. English: [00-getting-start.en.md](00-getting-start.en.md).

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `flowker-helm` **4.0.0** / app **1.7.0** |
| Registry do chart | `oci://ghcr.io/lerianstudio/flowker-helm` (público, sem login) |
| Componentes | Deployment `api` (porta `4021`), Deployment `worker` (porta `4022`, binário `/worker`), sidecar `xsd-validator` nos dois pods (porta `8081`, só loopback) |
| Imagens | `ghcr.io/lerianstudio/flowker:1.7.0`, `ghcr.io/lerianstudio/flowker-xsd-validator:1.7.0` (as duas públicas no GHCR) |
| Kubernetes | 1.27 ou mais novo (`kubeVersion` no `Chart.yaml`) |
| Última revisão deste runbook | 2026-11-26, contra o chart 4.0.0 / app 1.7.0 |
| Contato de escalonamento | `@LerianStudio/G_Github_Devops` |

---

## 1. Perfis de instalação

> **A infraestrutura embutida serve só para desenvolvimento e quickstart.** Produção usa MongoDB e Redis externos e gerenciados.

| Perfil | O que roda | Uso |
|---|---|---|
| **Quickstart** | api, worker, sidecar, MongoDB embutido (Bitnami) e Valkey embutido | Avaliação, POC |
| **Produção / infra externa** | api, worker, sidecar; MongoDB e Redis externos | Ambientes reais |

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| Licença Lerian | Sempre. O Flowker 1.6 ou mais novo não sobe sem ela | `flowker.secrets.LICENSE_KEY`, ou `flowker.licenseFile.existingSecret` (chave `license.lic`), ou `LICENSE_KEY` no Secret indicado em `flowker.existingSecretName` |
| MongoDB | Sempre | Embutido (`mongodb.enabled: true`, o padrão) ou externo (`mongodb.enabled: false` + `flowker.secrets.MONGO_URI` + `flowker.configmap.MONGO_HOST`) |
| Redis / Valkey | Sempre: o worker precisa de um Redis de fila, e toda instalação precisa do worker | Embutido (`valkey.enabled: true`) ou externo (`flowker.configmap.REDIS_HOST`, `REDIS_PORT`, `REDIS_TLS`, `flowker.secrets.REDIS_PASSWORD`) |
| Bucket S3 (Schema Registry) | Para os providers nativos (ledger do Midaz, Tracer, CRM e outros), os uploads de XSD e as rotas de schema OpenAPI. O app sobe sem ele, mas essas funções falham na hora do uso | `flowker.configmap.SCHEMA_REGISTRY_S3_BUCKET` + `SCHEMA_REGISTRY_S3_REGION`. As credenciais AWS vêm da cadeia do SDK: IRSA (`flowker.serviceAccount.annotations` e `worker.serviceAccount.annotations`) ou Roles Anywhere (`aws.rolesAnywhere`) |
| Chave KMS (selagem de credenciais) | Obrigatória para salvar qualquer provider com segredo (`key`, `token`, `password`, `secret`, `client_secret`), ou seja, quase todo provider com autenticação. O app sobe sem ela | Configurações não secretas (`KMS_VENDOR` e, com AWS KMS, `KMS_AWS_KEY_ID` e `AWS_REGION`) por `flowker.extraEnvVars`. Configurações secretas só no Secret existente. Dê acesso à chave às service accounts do api e do worker |
| plugin-access-manager | Obrigatório com `ENV_NAME: "production"`: o Flowker 1.7.0 recusa `PLUGIN_AUTH_ENABLED: "false"` nesse ambiente. Opcional nos outros | `flowker.configmap.PLUGIN_AUTH_ENABLED: "true"` + `flowker.configmap.PLUGIN_AUTH_ADDRESS` (use `https://`) |
| Tenant manager | Só com multi-tenancy | `flowker.multiTenant.enabled` + `flowker.configmap.MULTI_TENANT_URL` e `MULTI_TENANT_REDIS_*` + `flowker.secrets.MULTI_TENANT_SERVICE_API_KEY`. Defina a URL e as chaves de Redis em `flowker.configmap`: valores só em `global.multiTenant` não chegam ao app no chart 4.0.0 |

---

## 3. Ordem de instalação

### 3.1 Namespace

O chart fixa os workloads no `namespaceOverride`, que por padrão é `flowker`. O MongoDB e o Valkey
embutidos seguem o namespace da release do Helm. **Instale no mesmo namespace definido em
`namespaceOverride`.** Use o namespace padrão `flowker`, ou defina os dois com o mesmo valor:

```bash
helm install flowker oci://ghcr.io/lerianstudio/flowker-helm --version 4.0.0 \
  -n <ns> --create-namespace --set namespaceOverride=<ns> -f <seus-values>.yaml
```

Se forem diferentes, o api e o worker vão para `flowker`, o MongoDB vai para `<ns>`, e nenhum pod sobe.

### 3.2 Licença

Não coloque a licença em arquivo de values versionado. Há dois jeitos, um por perfil:

- **Quickstart:** passe a chave a partir de um arquivo com `--set-file flowker.secrets.LICENSE_KEY=./flowker.license`. O chart grava a chave no próprio Secret e monta o `MONGO_URI` do MongoDB embutido.
- **Produção:** crie o seu Secret e defina `flowker.useExistingSecret: true`. Esse Secret substitui o Secret do chart, então precisa ter todas as chaves secretas que os pods leem: `LICENSE_KEY`, `MONGO_URI` (nesse modo o chart não monta a URI) e, quando valer, `REDIS_PASSWORD` e outras.

```bash
kubectl create namespace flowker
# os valores ficam em arquivos: não vão para o histórico do shell
kubectl create secret generic flowker-secrets -n flowker \
  --from-file=LICENSE_KEY=./flowker.license \
  --from-file=MONGO_URI=./mongo-uri.txt
```

### 3.3 Quickstart

```yaml
# quickstart-values.yaml
valkey:
  enabled: true   # o worker precisa de um Redis de fila enquanto o scheduler está ligado
```

```bash
helm install flowker oci://ghcr.io/lerianstudio/flowker-helm --version 4.0.0 \
  -n flowker --create-namespace -f quickstart-values.yaml \
  --set-file flowker.secrets.LICENSE_KEY=./flowker.license
```

### 3.4 Produção / infra externa

```yaml
# production-values.yaml
flowker:
  useExistingSecret: true
  existingSecretName: flowker-secrets    # LICENSE_KEY, MONGO_URI, REDIS_PASSWORD (seção 3.2)
  configmap:
    ENV_NAME: "production"
    DEPLOYMENT_MODE: "byoc"              # o padrão "local" do chart é só para desenvolvimento
    ALLOW_INSECURE_TLS: "false"          # só com MongoDB e Redis com TLS
    PLUGIN_AUTH_ENABLED: "true"          # obrigatório em produção: o app recusa "false"
    PLUGIN_AUTH_ADDRESS: "https://auth.example.com"   # host HTTPS público (veja "URLs de saída" na seção 4)
    MONGO_HOST: "mongo.example.internal" # host que o init container wait-for-mongodb verifica
    REDIS_HOST: "redis.example.internal"
    REDIS_PORT: "6379"
    REDIS_TLS: "true"
    SCHEMA_REGISTRY_S3_BUCKET: "flowker-schema-registry"
    SCHEMA_REGISTRY_S3_REGION: "sa-east-1"
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "<role com acesso ao bucket e à chave KMS>"   # IRSA no EKS
  extraEnvVars:                          # só valores não secretos: isto vai para o ConfigMap
    KMS_VENDOR: "aws-kms"                # o 1.7.0 aceita só "aws-kms" ou "hashicorp-vault"
    KMS_AWS_KEY_ID: "<id-ou-arn-da-chave-kms>"
    AWS_REGION: "sa-east-1"              # região da chave KMS; obrigatória com Roles Anywhere
    CRM_BASE_URL: "https://crm.example.com"   # host HTTPS público; sem value próprio no chart 4.0.0
  ingress:
    enabled: true
    className: "<sua-ingress-class>"
    hosts:
      - host: flowker.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: flowker-tls
        hosts: [flowker.example.com]
worker:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "<role com acesso ao bucket e à chave KMS>"
mongodb:
  enabled: false
```

```bash
helm install flowker oci://ghcr.io/lerianstudio/flowker-helm --version 4.0.0 \
  -n flowker -f production-values.yaml
```

Parta do [`values-template.yaml`](../values-template.yaml) para ver todas as chaves.

---

## 4. Notas de operação

- **MongoDB externo.** O `MONGO_URI` é lido do Secret (`secretKeyRef`) e nunca vai para o PodSpec. O init container `wait-for-mongodb` verifica o `MONGO_HOST` na porta `27017`, então um MongoDB em outra porta deixa os pods em `Init`. Use uma senha sem `:`, `/`, `@` ou `%`, ou faça percent-encoding dela na URI.
- **Redis.** Com os padrões (`SCHEDULER_ENABLED: "true"`, `valkey.enabled: false`, `REDIS_HOST` vazio), o worker fica sem fila e não sobe. Ligue o Valkey ou defina o `REDIS_HOST`. Mantenha o worker ligado mesmo sem triggers `schedule`: no Flowker 1.7.0, só o worker inicia execuções `durable_external`, acorda nós `wait` e encerra com falha as execuções com lease expirado. Com `worker.enabled: false`, essas execuções ficam pendentes ou esperando para sempre. O binário `/worker` não sobe com `SCHEDULER_ENABLED: "false"`, então toda instalação precisa de um Redis de fila.
- **Access Manager em `http://`.** O sidecar XSD herda o `PLUGIN_AUTH_*` e sai com endereço sem TLS. O chart recusa o render até você definir `flowker.xsdValidator.pluginAuth.allowInsecureHttp: "true"` ou usar `https://`. Desligar o sidecar também tira o erro, mas leia o próximo item antes.
- **Sidecar XSD.** Ligado por padrão. Ele valida webhooks XML e uploads de XSD. Com `flowker.xsdValidator.enabled: false`, a validação fica desligada: webhooks vinculados a um XSD **aceitam XML bem formado mas fora do schema e executam os workflows**, e os uploads de XSD não são conferidos. Desligue só em instalações sem workflows XML vinculados a schema.
- **Health e rollout.** Probes, PDB e rollout vêm do preset de health do `lerian-common` e não são values. O chart recusa tag de imagem abaixo de `1.7.0-beta.50`. Veja o [README](../README.md#health-drain-and-rollout) do chart.
- **Schema Registry (S3).** Os health checks passam sem `SCHEMA_REGISTRY_S3_BUCKET`, então um rollout verde não prova que os providers nativos funcionam. Defina o bucket em todo perfil que roda workflows com providers nativos ou webhooks vinculados a XSD, e dê ao api e ao worker acesso a ele. **Ponto em aberto:** as specs dos providers nativos também precisam estar no bucket, ou todo provider nativo falha na hora do uso. O pipeline de publicação da Lerian só grava em buckets da Lerian, e ainda não há procedimento documentado para um bucket do cliente. Combine com o time do Flowker (chaves dos objetos, versões e quem faz o upload) antes de o cliente rodar workflows com providers nativos.
- **Modo de deploy.** O chart usa `DEPLOYMENT_MODE: local` por padrão. Com `ENV_NAME: "production"`, o app loga um aviso no boot, e `local` ainda permite auth por token no Vault para o KMS. Defina `DEPLOYMENT_MODE: "byoc"` em instalações de cliente.
- **Provider CRM.** O app lê `CRM_BASE_URL`, mas o chart 4.0.0 só tem os values `MIDAZ_BASE_URL` e `TRACER_BASE_URL`. Defina o `CRM_BASE_URL` por `flowker.extraEnvVars`, com um host HTTPS público (veja o próximo item).
- **URLs de saída (proteção contra SSRF).** O Flowker confere toda chamada de saída contra uma proteção de SSRF. Ela bloqueia hostnames `.internal`, `.local` e `.cluster.local` antes do DNS e, com `SSRF_ALLOW_PRIVATE: "false"` (o padrão do chart, e o único valor seguro em produção), também bloqueia nomes que resolvem para IP privado. Isso vale para o `PLUGIN_AUTH_ADDRESS` (a URL do token M2M dos workflows é montada a partir dele), o `CRM_BASE_URL`, o `MIDAZ_BASE_URL`, o `TRACER_BASE_URL` e as URLs base dos providers. Use hosts HTTPS públicos para eles. Um nome de Service interno do cluster faz falhar todo step que o chama, enquanto os health checks e o rollout passam. `MONGO_HOST` e `REDIS_HOST` não são afetados.
- **Image pull secrets.** As imagens são públicas. `flowker.imagePullSecrets` pode ficar `[]`.
- **Credenciais de workflow.** O Flowker 1.7.0 guarda as credenciais de provider config e de node auth seladas por KMS no MongoDB e precisa de uma chave de criptografia (`KMS_VENDOR` e as permissões dela). O chart 4.0.0 não tem values próprios de `KMS_*`. Coloque as configurações secretas de KMS (por exemplo o secret ID de um AppRole do Vault) só no Secret existente (`flowker.useExistingSecret: true`). Nunca em `flowker.extraEnvVars`: ele vai para o ConfigMap. O `extraEnvVars` serve para configurações não secretas, como `KMS_VENDOR`. O `FLOWKER_SECRETS_BACKEND` não tem efeito no app 1.7.0. Sem `KMS_VENDOR`, a instalação fica saudável mas recusa guardar qualquer segredo de provider (409 `FLK-0966`). O cliente KMS pega a região da cadeia do SDK da AWS, não do `SCHEMA_REGISTRY_S3_REGION`. No EKS com IRSA a região é injetada automaticamente. Com Roles Anywhere (fora do EKS), não: defina `AWS_REGION` com a região da chave em `flowker.extraEnvVars`, ou todo save de provider falha enquanto a instalação parece saudável.

---

## 5. Como validar a instalação

```bash
kubectl -n flowker get pods
# esperado: flowker-* (2/2: api + sidecar), flowker-worker-* (2/2) e, quando ligados,
# flowker-mongodb / flowker-valkey
kubectl -n flowker rollout status deploy/flowker --timeout=300s
kubectl -n flowker rollout status deploy/flowker-worker --timeout=300s
```

Depois confira a API de dentro do cluster, pelo Service na porta `4021`:

```bash
kubectl -n flowker run flowker-check --rm -i --restart=Never --image=busybox:1.37 -- \
  wget -qO- http://flowker:4021/health
```

O readiness (`/readyz`) e o `/metrics` ficam na porta interna de health `8099` de cada pod.

---

## 6. Erros conhecidos e o que significam

| Erro/log | Causa | Correção |
|---|---|---|
| Render falha: `flowker.secrets.LICENSE_KEY ... is required` | Licença não configurada | Configure a licença (seção 3.2) |
| Log: `license: validation failed; flowker drains and exits` | Chave ausente ou não aceita no boot | Confira o `LICENSE_KEY` no Secret que os pods carregam e a saída para o gateway de licença |
| Render falha: `flowker.configmap.MONGO_HOST is required when mongodb is external` | `mongodb.enabled: false` sem `MONGO_HOST` | Defina o `MONGO_HOST` com o host do MongoDB |
| Render falha: `flowker.xsdValidator: PLUGIN_AUTH_ADDRESS ... is cleartext http://` | Auth ligado com Access Manager em `http://` | Defina `allowInsecureHttp: "true"` ou use `https://` (veja "Sidecar XSD" na seção 4 antes de desligá-lo) |
| api e worker saem no boot: `PLUGIN_AUTH_ENABLED=false is not permitted in production` | `ENV_NAME: "production"` com auth desligado | Defina `PLUGIN_AUTH_ENABLED: "true"` e `PLUGIN_AUTH_ADDRESS` (seção 3.4) |
| Worker sai: `worker binary requires SCHEDULER_ENABLED=true` | Scheduler desligado | Mantenha `SCHEDULER_ENABLED: "true"` e dê um Redis ao worker (veja "Redis" na seção 4). Não desligue o worker |
| Render falha: `lerian-common: MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true` | Multi-tenancy ligado com a URL só em `global.multiTenant` | Defina `flowker.configmap.MULTI_TENANT_URL` (e `MULTI_TENANT_REDIS_HOST`) |
| Pods presos em `Init`, `wait-for-mongodb` em loop em `<host>:27017` | MongoDB inacessível, em outra porta ou em outro namespace | Confira `MONGO_HOST`, a porta e a regra de namespace (seção 3.1) |
| Pods em `CreateContainerConfigError` | Secret ou chave ausente no namespace do pod | Confira o `existingSecretName`, as chaves e a regra de namespace |
| Log do api: URI do MongoDB vazia ou ausente, com `useExistingSecret: true` | O Secret existente não tem a chave `MONGO_URI` | Adicione `MONGO_URI` ao Secret (seção 3.2) |
| Worker em `CrashLoopBackOff` logo após a instalação | Sem Redis de fila com o scheduler ligado | Veja "Redis" na seção 4 |
| api em `CrashLoopBackOff`, log "TLS required" (Mongo) | `ALLOW_INSECURE_TLS: "false"` contra MongoDB sem TLS | Mantenha `"true"` com infra embutida; `"false"` só com TLS real |
| Step de workflow falha com `URL rejected by SSRF policy` ou `token endpoint rejected by SSRF policy` | Uma URL de saída usa hostname interno ou IP privado | Use um host HTTPS público ("URLs de saída" na seção 4) |
| api e worker saem no boot: `unknown KMS_VENDOR` | `KMS_VENDOR` diferente de `aws-kms` ou `hashicorp-vault` | Corrija o valor |
| Salvar um provider retorna 409 `FLK-0966` | KMS não configurado (`KMS_VENDOR` vazio) | Configure a chave KMS (seção 2) |
| Salvar um provider retorna 503 `FLK-0969` | Chave KMS negada ou inacessível | Confira o acesso à chave das service accounts do api e do worker, e a rede até o KMS |
| Step de workflow falha com `ErrCredentialSealerNotConfigured` ou `has no stored credential` | Chave KMS não configurada, ou credenciais não recadastradas depois de ir para o app 1.7.0 | Veja "Credenciais de workflow" na seção 4 |
| Step de provider nativo falha ao salvar ou rodar, upload de XSD falha com `ErrBlobStorageNotConfigured`, ou rotas de schema OpenAPI respondem 503 `FLK-0804` | `SCHEMA_REGISTRY_S3_BUCKET` vazio, ou sem acesso ao bucket | Defina bucket e região, e a permissão por IRSA ou Roles Anywhere (seção 2) |
| Render falha: `... is below 1.7.0-beta.50` | `flowker.image.tag` mais antiga que o chart suporta | Use a tag padrão do chart ou uma tag a partir de `1.7.0-beta.50` |
