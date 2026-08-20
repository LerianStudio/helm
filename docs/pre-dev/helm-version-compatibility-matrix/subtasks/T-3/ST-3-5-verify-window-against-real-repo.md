# ST-3-5 — Validar a janela contra o repo real (clone descartável, sem escrever no repo)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Prova executiva (TRD §10 passo 2, parcial): rodar o gerador contra o repo REAL num diretório de saída em /tmp e conferir que a janela de suporte bate com a realidade (ex.: midaz N vindo do Chart.yaml; degradação para charts sem tags como `br-spi`). NÃO escreve no repo. Não toca README ainda (isso é T-5).

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-3-4.)

Confirme que as tags git existem no checkout (o CI usa `fetch-depth: 0`; localmente pode faltar histórico):
```bash
cd "$(git rev-parse --show-toplevel)" && git tag --list 'midaz-v*' | wc -l
```
Saída esperada: um número `> 0`. Se for `0`, rode `git fetch --tags --force` antes de prosseguir (a janela N-1..N-3 depende das tags; N ainda vem do Chart.yaml).

## Files
- (nenhum arquivo do repo é modificado; saída vai para /tmp)

## Steps

### Passo 1 — Gerar contra o repo real, saída em /tmp
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output docs/compat-verify.json 2> /tmp/compat-real.stderr; echo "exit=$?"
```
Saída esperada: `exit=0` (nunca ≠0 por dado ausente).

### Passo 2 — Conferir que N do midaz vem do Chart.yaml (autoridade)
```bash
cd "$(git rev-parse --show-toplevel)" && echo "Chart.yaml version:" && grep '^version:' charts/midaz/Chart.yaml && echo "JSON current:" && grep -A2 '"midaz-helm"' docs/compat-verify.json | grep current
```
Saída esperada: o `current` no JSON é IDÊNTICO ao `version:` do `charts/midaz/Chart.yaml` (ex.: ambos `8.6.0`), independentemente das tags.

### Passo 3 — Conferir degradação de um chart sem tags (br-spi)
```bash
cd "$(git rev-parse --show-toplevel)" && git tag --list 'br-spi-v*' | wc -l && echo "--- INFO esperado no stderr ---" && grep 'br-spi' /tmp/compat-real.stderr
```
Saída esperada: contagem de tags `0` e uma linha `INFO br-spi-...: N — no published tags; window = only N (Chart.yaml)`. No JSON, `br-spi-*` deve ter apenas 1 cycle.

### Passo 4 — Determinismo contra repo real (2×)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && \
  go run ./generate-compatibility --root ../.. --output docs/compat-verify-a.json 2>/dev/null && \
  go run ./generate-compatibility --root ../.. --output docs/compat-verify-b.json 2>/dev/null && \
  diff docs/compat-verify-a.json docs/compat-verify-b.json && echo "DETERMINISTIC_REAL_OK"
```
Saída esperada: `DETERMINISTIC_REAL_OK` (sem diff).

### Passo 5 — Garantir que o repo NÃO foi alterado
```bash
cd "$(git rev-parse --show-toplevel)" && git status --porcelain docs/compatibility.json charts/ README.md
```
Saída esperada: VAZIA (nenhuma linha). Se algo aparecer, você escreveu no repo por engano — reverta com `git checkout <arquivo>`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && test -s docs/compat-verify.json && grep -q '"schemaVersion": 1' docs/compat-verify.json && echo "ST-3-5_OK"
```
Saída esperada: `ST-3-5_OK`.

## Rollback
Nada a reverter (só escreveu em /tmp). Opcional:
```bash
rm -f docs/compat-verify*.json /tmp/compat-real.stderr
```
