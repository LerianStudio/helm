# matcher — Runbook de instalação

> Como instalar, validar e diagnosticar o Matcher a partir deste chart. Para operadores,
> inclusive clientes BYOC. English: [00-getting-start.en.md](00-getting-start.en.md).

---

## 0. Metadados

| Campo | Valor |
|---|---|
| Produto / Chart | `matcher-helm` **4.0.0** / app **6.1.0** |
| Registro do chart | `oci://ghcr.io/lerianstudio/matcher-helm` (público, sem login) |
| Componentes | Deployment `matcher` (API na porta `8080`, health na `8099`, workers de export e cleanup no mesmo processo), Job PreSync `matcher-migrations` (opcional) |
| Imagens | `lerianstudio/matcher:6.1.0` (Docker Hub, pública), `ghcr.io/lerianstudio/matcher-migrations:6.1.0` (GHCR, veja "Imagem de migração" na seção 4) |
| Kubernetes | 1.27 ou superior (`kubeVersion` no `Chart.yaml`) |
| Última revisão deste runbook | 27/11/2026, contra o chart 4.0.0 / app 6.1.0 |
| Contato de escalonamento | `@LerianStudio/G_Github_Devops` |

---

## 1. Perfis de instalação

> **A infraestrutura embutida serve só para desenvolvimento e quickstart.** Instalações de produção usam PostgreSQL, Redis/Valkey e RabbitMQ externos e gerenciados.

| Perfil | O que roda | Uso |
|---|---|---|
| **Quickstart** | matcher, Job de migração, PostgreSQL (primário + réplica), Valkey e RabbitMQ embutidos | Avaliação, POC |
| **Produção / infra externa** | matcher, Job de migração; PostgreSQL, Redis/Valkey, RabbitMQ e object storage externos | Ambientes reais |

---

## 2. Dependências externas

| Dependência | Quando é necessária | Como o chart recebe |
|---|---|---|
| Licença Lerian | Sempre | `matcher.secrets.LICENSE_KEY`, ou `matcher.licenseFile.existingSecret` (chave `license.lic`), ou `LICENSE_KEY` no Secret indicado em `matcher.existingSecretName` |
| PostgreSQL (primário e réplica) | Sempre. O Matcher não sobe com o schema sem migração | Embutido (`postgresql.enabled: true`, o padrão) ou externo (`postgresql.enabled: false` + `matcher.configmap.POSTGRES_*` e `POSTGRES_REPLICA_*` + as senhas no Secret) |
| Migrações de schema | Sempre, na instalação e em todo upgrade | `migrations.enabled: true`. Desligado por padrão |
| Redis / Valkey | Sempre | Embutido (`valkey.enabled: true`) ou externo (`matcher.configmap.REDIS_HOST` como `host:porta`, `REDIS_TLS` + `REDIS_PASSWORD` no Secret) |
| RabbitMQ | Sempre | Embutido (`rabbitmq.enabled: true`) ou externo (`matcher.configmap.RABBITMQ_URI`, `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_VHOST`, `RABBITMQ_HEALTH_URL` + `RABBITMQ_PASSWORD` no Secret). `RABBITMQ_PASSWORD` é obrigatório nos dois casos |
| Object storage compatível com S3 | Para exports (o worker de export vem ligado). O app sobe sem endpoint acessível, mas os exports falham na hora do uso | `matcher.configmap.OBJECT_STORAGE_ENDPOINT`, `OBJECT_STORAGE_REGION`, `OBJECT_STORAGE_BUCKET` + `OBJECT_STORAGE_ACCESS_KEY_ID` / `OBJECT_STORAGE_SECRET_ACCESS_KEY` no Secret |
| Chaves de criptografia | `APP_ENC_KEY` é obrigatória em produção. `IDEMPOTENCY_HMAC_SECRET` para `DEPLOYMENT_MODE` `byoc` e `saas` | Chaves do Secret `APP_ENC_KEY` (base64, 32 bytes) e `IDEMPOTENCY_HMAC_SECRET` |
| plugin-access-manager | Quando a autenticação está ligada (`PLUGIN_AUTH_ENABLED: "true"`) | `matcher.configmap.PLUGIN_AUTH_ENABLED` + `PLUGIN_AUTH_ADDRESS` |

---

## 3. Ordem de instalação

### 3.1 Namespace

O chart fixa os workloads do matcher no `namespaceOverride`, que tem o padrão `matcher`. O PostgreSQL,
o Valkey e o RabbitMQ embutidos, e os hosts que o chart monta para eles, seguem o namespace da release
do Helm. **Instale no mesmo namespace definido em `namespaceOverride`.** Use o namespace padrão
`matcher` ou defina os dois com o mesmo valor:

```bash
helm install matcher oci://ghcr.io/lerianstudio/matcher-helm --version 4.0.0 \
  -n <ns> --create-namespace --set namespaceOverride=<ns> -f <seus-values>.yaml
```

Se forem diferentes, o matcher fica em `matcher` e as dependências em `<ns>`, e os pods ficam em `Init`.

### 3.2 Secrets

Mantenha a licença e as senhas fora dos arquivos de values no git. Há dois caminhos, um por perfil:

- **Quickstart:** passe os valores a partir de arquivos com `--set-file`. O chart grava esses valores no próprio Secret. O PostgreSQL e o Valkey embutidos geram as próprias senhas, e o matcher e o Job de migração leem essas senhas dos Secrets dos subcharts.
- **Produção:** crie o seu Secret e defina `matcher.useExistingSecret: true`. Esse Secret substitui o Secret do chart, então ele precisa ter todas as chaves secretas que os pods leem: `LICENSE_KEY`, `POSTGRES_PASSWORD`, `POSTGRES_REPLICA_PASSWORD`, `REDIS_PASSWORD`, `RABBITMQ_PASSWORD`, `APP_ENC_KEY`, `IDEMPOTENCY_HMAC_SECRET`, e `OBJECT_STORAGE_ACCESS_KEY_ID` / `OBJECT_STORAGE_SECRET_ACCESS_KEY` quando os exports usam chaves fixas. O Job de migração lê `POSTGRES_PASSWORD` e `LICENSE_KEY` do mesmo Secret, então crie o Secret antes da instalação.

```bash
kubectl create namespace matcher
openssl rand -base64 32 | tr -d '\n' > app-enc-key.txt
openssl rand -base64 32 | tr -d '\n' > idempotency-hmac.txt
# os valores ficam em arquivos: eles nunca entram no histórico do shell
kubectl create secret generic matcher-secrets -n matcher \
  --from-file=LICENSE_KEY=./matcher.license \
  --from-file=POSTGRES_PASSWORD=./pg-password.txt \
  --from-file=POSTGRES_REPLICA_PASSWORD=./pg-password.txt \
  --from-file=REDIS_PASSWORD=./redis-password.txt \
  --from-file=RABBITMQ_PASSWORD=./rabbitmq-password.txt \
  --from-file=APP_ENC_KEY=./app-enc-key.txt \
  --from-file=IDEMPOTENCY_HMAC_SECRET=./idempotency-hmac.txt \
  --from-file=OBJECT_STORAGE_ACCESS_KEY_ID=./s3-access-key-id.txt \
  --from-file=OBJECT_STORAGE_SECRET_ACCESS_KEY=./s3-secret-access-key.txt
```

Guarde uma cópia da `APP_ENC_KEY` no seu cofre de segredos. As credenciais de engine que o Matcher grava são cifradas com ela.

### 3.3 Quickstart

```yaml
# quickstart-values.yaml
matcher:
  configmap:
    DEPLOYMENT_MODE: "local"      # postura de desenvolvimento; instalações de cliente usam "byoc"
    ENV_NAME: "development"
migrations:
  enabled: true                   # o matcher não sobe com o schema sem migração
```

```bash
openssl rand -hex 16 > rabbitmq-password.txt
helm install matcher oci://ghcr.io/lerianstudio/matcher-helm --version 4.0.0 \
  -n matcher --create-namespace -f quickstart-values.yaml \
  --set-file matcher.secrets.LICENSE_KEY=./matcher.license \
  --set-file matcher.secrets.RABBITMQ_PASSWORD=./rabbitmq-password.txt
```

O worker de export não tem object storage neste perfil. Os exports falham até você definir `OBJECT_STORAGE_*`.

### 3.4 Produção / infra externa

```yaml
# production-values.yaml
matcher:
  useExistingSecret: true
  existingSecretName: matcher-secrets      # todas as chaves secretas (seção 3.2)
  configmap:
    ENV_NAME: "production"
    DEPLOYMENT_MODE: "byoc"
    ALLOW_INSECURE_TLS: "false"            # o padrão "true" do chart é só para desenvolvimento
    CORS_ALLOWED_ORIGINS: "https://console.example.com"   # o padrão "*" do chart é recusado em produção
    PUBLIC_BASE_HOST: "matcher.example.com"   # host das URLs de webhook e callback que o Matcher entrega
    TRUSTED_PROXIES: "10.0.0.0/16"         # CIDR do seu load balancer ou ingress
    POSTGRES_HOST: "postgres.example.com"
    POSTGRES_SSLMODE: "require"
    POSTGRES_REPLICA_HOST: "postgres-ro.example.com"   # o mesmo host do POSTGRES_HOST se não houver réplica
    POSTGRES_REPLICA_SSLMODE: "require"
    REDIS_HOST: "redis.example.com:6379"
    REDIS_TLS: "true"
    RABBITMQ_URI: "amqps"
    RABBITMQ_HOST: "rabbitmq.example.com"
    RABBITMQ_PORT: "5671"
    RABBITMQ_VHOST: "matcher"
    RABBITMQ_HEALTH_URL: "https://rabbitmq.example.com:443"
    OBJECT_STORAGE_ENDPOINT: "https://s3.sa-east-1.amazonaws.com"   # HTTPS: produção recusa http
    OBJECT_STORAGE_REGION: "sa-east-1"
    OBJECT_STORAGE_BUCKET: "matcher-exports"
    OBJECT_STORAGE_USE_PATH_STYLE: "false"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "https://auth.example.com"
  ingress:
    enabled: true
    className: "<sua-ingress-class>"
    hosts:
      - host: matcher.example.com
        paths:
          - path: /v1
            pathType: Prefix
          - path: /system
            pathType: Prefix
          - path: /health
            pathType: Exact
          - path: /version
            pathType: Exact
    tls:
      - secretName: matcher-tls
        hosts: [matcher.example.com]
migrations:
  enabled: true                            # lê POSTGRES_PASSWORD e LICENSE_KEY do matcher-secrets
postgresql:
  enabled: false
valkey:
  enabled: false
rabbitmq:
  enabled: false
```

```bash
helm install matcher oci://ghcr.io/lerianstudio/matcher-helm --version 4.0.0 \
  -n matcher -f production-values.yaml
```

Parta do [`values.yaml`](../values.yaml) para ver todas as chaves.

---

## 4. Notas de operação

- **Imagem de migração.** O cluster precisa conseguir baixar `ghcr.io/lerianstudio/matcher-migrations`. Se o cluster recebe `401`/`ImagePullBackOff` nessa imagem, fale com a Lerian. Não desligue as migrações para contornar: o Matcher não sobe com o schema sem migração.
- **Migrações fora do ArgoCD.** O Job de migração e o Secret dele têm anotações de hook `PreSync` do ArgoCD. O ArgoCD roda os dois antes do Deployment. O `helm install` e o `helm upgrade` puros ignoram essas anotações e criam o Job junto com o Deployment, então os pods do matcher podem reiniciar até o Job terminar. Isso é esperado. Se um pod continua em `CrashLoopBackOff` depois que o Job fica `Complete`, leia o log do pod (seção 6). Com ArgoCD, o Job roda antes de cada sync.
- **Multi-tenant.** Não ligue `migrations.enabled` com `MULTI_TENANT_ENABLED: "true"`: o runner recusa, e o Tenant Manager cuida das migrações dos schemas dos tenants.
- **Travas de produção.** Com `ENV_NAME: "production"`, o app recusa os padrões do chart que só são seguros em desenvolvimento: `CORS_ALLOWED_ORIGINS: "*"`, endpoint de object storage `http://` e `SWAGGER_ENABLED: "true"`. Defina os valores da seção 3.4. Um exporter OpenTelemetry sem TLS também precisa de `ALLOW_INSECURE_OTEL` (um texto com o motivo) em `matcher.extraEnvVars`.
- **Workers em segundo plano.** O app liga os workers por padrão. Confirme com o time do Matcher quais workers uma instalação BYOC mantém ligados (por exemplo, workers de cobrança ou de provisionamento que só fazem sentido na Lerian Cloud) e desligue os outros com `<NOME>_WORKER_ENABLED: "false"` em `matcher.configmap`.
- **Usuário do RabbitMQ.** Com o broker embutido, o chart cria o usuário `matcher` com `RABBITMQ_PASSWORD`. Com broker externo, crie o usuário e o vhost você mesmo, ou ligue `global.externalRabbitmqDefinitions` (só API de gerenciamento HTTPS).
- **Bootstrap do PostgreSQL externo.** O chart pode criar a role e o banco `matcher` num servidor externo com `global.externalPostgresDefinitions` (credenciais de admin de um Secret existente). Sem isso, crie a role e o banco antes da instalação.
- **Health e rollout.** Probes, PDB e rollout vêm do preset de health do `lerian-common` e não são values. O chart recusa tag de imagem abaixo de `6.1.0-beta.1`.
- **Image pull secrets.** `lerianstudio/matcher` é pública no Docker Hub. `matcher.imagePullSecrets` pode ficar `[]`. Use `migrations.imagePullSecrets` só se a Lerian entregar uma credencial para a imagem de migração.
- **Endpoint do object storage.** O endpoint padrão aponta para `matcher-seaweedfs` no namespace da release. O chart não instala o SeaweedFS. Defina `OBJECT_STORAGE_ENDPOINT` em todo perfil que usa exports.

---

## 5. Como validar a instalação

```bash
kubectl -n matcher get jobs,pods
# esperado: matcher-migrations Complete (o ArgoCD apaga o Job depois do sucesso),
# matcher-* Running e Ready, e os embutidos matcher-postgresql-*, matcher-valkey-*
# e matcher-rabbitmq-* quando estão ligados
kubectl -n matcher rollout status deploy/matcher --timeout=600s
```

Depois verifique a API de dentro do cluster, pelo Service na porta `8080`:

```bash
kubectl -n matcher run matcher-check --rm -i --restart=Never --image=busybox:1.37 -- \
  wget -qO- http://matcher:8080/health
```

O readiness (`/readyz`) fica na porta de health `8099` de cada pod.

---

## 6. Erros conhecidos e o que significam

| Erro/log | Causa | Correção |
|---|---|---|
| Render falha: `missing property 'DEPLOYMENT_MODE'` ou `matcher.configmap.DEPLOYMENT_MODE is required` | Sem modo de deploy | Defina `DEPLOYMENT_MODE` (`byoc` em instalações de cliente) |
| Render falha: `matcher.secrets.RABBITMQ_PASSWORD is required ...` | Sem senha do RabbitMQ | Defina a senha (seção 3.2) |
| Render falha: `migrations.postgres.password (or matcher.secrets.POSTGRES_PASSWORD) is required ...` | Migrações ligadas, PostgreSQL externo, sem senha e sem Secret existente | Use `matcher.useExistingSecret: true` (seção 3.2) |
| Render falha: `ui is no longer part of this chart` | Um arquivo de values ainda define `ui` | Remova o bloco `ui`. O console vem no product-console |
| Render falha: `global.externalRabbitmqDefinitions.connection.protocol must be "https"` | Job de bootstrap por `http://` | Use a API de gerenciamento HTTPS |
| Pod `matcher-migrations` em `ImagePullBackOff` | O cluster não consegue baixar `ghcr.io/lerianstudio/matcher-migrations` | Veja "Imagem de migração" na seção 4 |
| matcher em `CrashLoopBackOff`, log sobre schema ou migrações | Migrações desligadas, ou o Job não terminou ou falhou | Ligue `migrations.enabled` e confira `kubectl -n matcher logs job/matcher-migrations` |
| Pods presos em `Init`, `wait-for-dependencies` em loop num host | PostgreSQL ou Redis inacessível, ou em outro namespace | Confira os hosts, as portas e a regra de namespace (seção 3.1) |
| Pods em `CreateContainerConfigError` | Secret ou chave ausente no namespace | Confira `existingSecretName` e as chaves (seção 3.2) |
| matcher sai no boot com erro de licença | Licença ausente ou recusada | Confira `LICENSE_KEY` no Secret que os pods leem e a saída de rede para o gateway de licença |
| matcher sai no boot por CORS, TLS ou endpoint do object storage | Um padrão de desenvolvimento em produção | Defina os valores da seção 3.4 ("Travas de produção" na seção 4) |
| Exports falham | Object storage inacessível ou sem credenciais | Defina `OBJECT_STORAGE_*` e as chaves de acesso |
