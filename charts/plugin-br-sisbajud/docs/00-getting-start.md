# plugin-br-sisbajud — Primeiros passos

> O executor SISBAJUD: busca as ordens judiciais na **Sisbajud Mensageria** (br-sfn) pelo
> contrato de execução (sempre HTTPS; **mTLS opcional**, `sisbajud.mensageria.mtlsEnabled`, igual ao da Mensageria), executa no **Midaz** (bloqueio,
> desbloqueio, transferência, informação) e devolve o resultado. Roda no cluster do cliente,
> ao lado do Midaz (BYOC), ou na Lerian Cloud.

## 1. Pré-requisitos

| Dependência | Como o chart recebe |
|---|---|
| Sisbajud Mensageria (URL https) | `sisbajud.mensageria.baseUrl` |
| CA do servidor da Mensageria | `sisbajud.mensageria.ca.existingSecret` (chave `ca.crt`); opcional em TLS one-way (vazio = trust store do sistema), obrigatória com mTLS |
| Par cliente do executor (só mTLS) | `sisbajud.mensageria.mtlsEnabled: true` + `sisbajud.mensageria.tls.existingSecret` (chaves `tls.crt`, `tls.key`), encadeado na CA de cliente da Mensageria |
| Cliente M2M do executor no plugin-access-manager | `sisbajud.executor.m2mSubject` (o `sub` do token) + `MENSAGERIA_CLIENT_ID` / `MENSAGERIA_CLIENT_SECRET` no Secret |
| plugin-access-manager | `global.auth.host` (o token da Mensageria é emitido ali, mesmo com auth de entrada desligado) |
| Licença | `LICENSE_KEY` no Secret; `ORGANIZATION_IDS` = `global` |
| KMS | `global.kms` — Vault Transit (`VAULT_TOKEN` ou AppRole) ou AWS KMS (`awsRegion` + `awsKeyMode` em `sisbajud.kms` ou `global.kms`). `provided` exige `awsKeyArn` e `awsCredentialsKeyArn`, distintos; `managed` exige os dois vazios. `sisbajud.vault.awsKmsTimeoutSec` (`1`..`600`) e `awsKmsRotationCheckIntervalSec` (`1`..`86400`) são opcionais e validados em todo modo aws. AWS KMS com multi-tenant é recusado. Imagem mínima `1.1.0-beta.1`: qualquer tag não canônica exige `sisbajud.kms.allowUnverifiableImageTag: true` (não lido de `global.kms`). Não existe provider em memória |
| PostgreSQL (TLS) | `global.datastores.postgres` + `POSTGRES_PASSWORD` |
| Redis/Valkey | `global.datastores.redis` + `REDIS_PASSWORD` (o `/readyz` depende dele) |
| Streaming Hub | assinatura webhook: `EXECUTOR_HUB_WEBHOOK_SECRET` no Secret; ou `executor.transport: sqs` |
| Tenant do Streaming Hub | `sisbajud.executor.streamingHubTenantId` (obrigatório; mesmo valor do `STREAMING_HUB_TENANT_ID` do Streaming Hub) |

Rota e credenciais do Midaz são **por instituição** (API de configuração de instituição, selado no banco), não values do chart.

## 2. Instalação

```bash
kubectl create namespace sisbajud
kubectl -n sisbajud create secret generic sisbajud-mensageria-ca --from-file=ca.crt=mensageria-ca.pem
# só com mTLS:
kubectl -n sisbajud create secret tls sisbajud-mensageria-client --cert=client.pem --key=client-key.pem

cp values-template.yaml my-values.yaml   # preencha todos os <...>
helm install plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud -f my-values.yaml
```

Só com os defaults o chart **não renderiza**: cada valor obrigatório ausente falha o render com a chave exata a configurar.

Ordem no install/upgrade: Secret de senha da migração (hook -10) → Job `plugin-br-sisbajud-migrations` (hook -5, ArgoCD PreSync) → Deployment. Migração com falha aborta o release antes de qualquer workload mudar.

## 3. Webhook do Streaming Hub

O listener roda em `:9082` (Service `plugin-br-sisbajud-webhook`). Exponha só o path `sisbajud.executor.webhook.path` (`/v1/webhooks/hub`) via `sisbajud.executor.webhook.ingress`. Fora de `DEPLOYMENT_MODE=local` é preciso TLS próprio (`webhook.tls.existingSecret`) **ou** TLS terminado e validado na frente (`webhook.upstreamTlsValidated: true`).

## 4. Verificação

```bash
kubectl -n sisbajud get pods,jobs
kubectl -n sisbajud port-forward svc/plugin-br-sisbajud 4029:4029
curl -s localhost:4029/readyz | jq .
```

`/readyz` lista cada dependência. Limitação conhecida da aplicação (ainda presente na `1.0.0`): o probe de object store (`seaweedfs`) é registrado em todo modo e aponta por padrão para `http://localhost:8333`; no modo executor o pod fica NotReady até `SEAWEEDFS_S3_ENDPOINT` (via `sisbajud.configmap`) apontar para um S3 alcançável. Ver o README do chart.

## 5. Perfil de desenvolvimento

`postgresql.enabled=true`, `valkey.enabled=true` e `sisbajud.app.environmentName=development`: infra embutida sem TLS, senhas lidas dos Secrets dos subcharts e schema aplicado por um initContainer `migrations` no pod da aplicação. Não suportado em produção.
