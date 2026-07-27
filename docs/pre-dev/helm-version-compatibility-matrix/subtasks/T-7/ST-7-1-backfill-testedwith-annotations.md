# ST-7-1 — Backfill de `testedWith` nas annotations (PR de teste)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Preencher a annotation `lerian.studio/compatibility` com `testedWith` DERIVÁVEL do release atual nos charts que dependem de outro produto Lerian (ex.: plugins que dependem de `midaz-helm`). `requires` fica opcional/vazio no v1 (backlog TODO-1). Objetivo: a matriz nasce populada (métrica M3), validada com `--check` ANTES de abrir o PR real (TRD §10 passo 5). Rodar num branch de teste.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --check --root ../.. ; echo "exit=$?"
```
Saída esperada: `exit=0` (complete T-6 se falhar).

Confirme a branch (não `main`):
```bash
cd "$(git rev-parse --show-toplevel)" && git branch --show-current
```
Saída esperada: uma branch de feature. Se estiver em `main`, crie com `git switch -c feat/compat-matrix-backfill`.

## Files
- modify: `charts/<chart>/Chart.yaml` (bloco `annotations`) para cada chart que declara dependência de produto Lerian.

## Steps

### Passo 1 — Listar candidatos e annotations atuais
```bash
cd "$(git rev-parse --show-toplevel)" && for d in charts/*/; do n=$(grep -m1 '^name:' "$d/Chart.yaml" | awk '{print $2}'); echo "== $d ($n) =="; grep -q 'lerian.studio/compatibility' "$d/Chart.yaml" && echo "  JA TEM" || echo "  (sem annotation)"; done
```
Saída esperada: uma linha por chart indicando `JA TEM` ou `(sem annotation)`. Anote os que dependem de `midaz-helm` (plugins, fees, pix, bank-transfer, payments, reporter etc.).

### Passo 2 — Descobrir a versão testada de cada dependência
Para cada chart candidato, a versão em `testedWith` é a `version:` ATUAL do chart-alvo (o release corrente). Ex.: midaz:
```bash
cd "$(git rev-parse --show-toplevel)" && grep -m1 '^version:' charts/midaz/Chart.yaml
```
Saída esperada: `version: 8.6.0` (ou a atual). Use esse valor como `testedWith[midaz-helm]`.

### Passo 3 — Editar UMA annotation (exemplo: plugin-fees)
No `charts/plugin-fees/Chart.yaml`, localize o bloco:
```yaml
annotations:
  lerian.studio/chart-type: multi-component
```
E transforme em (mantendo a chave existente, ADICIONANDO a nova — atenção à indentação do block scalar `|`):
```yaml
annotations:
  lerian.studio/chart-type: multi-component
  lerian.studio/compatibility: |
    testedWith:
      midaz-helm: "8.6.0"
```
Repita para cada chart candidato, ajustando o(s) produto(s)-alvo e a versão testada conforme o Passo 2. NÃO preencha `requires` no v1.

### Passo 4 — Validar YAML embutido de cada annotation editada
Após cada edição, rode o gerador em modo write num destino /tmp e confira que NÃO surgiu WARN de V1/V4/V5 para aquele chart:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output docs/compat-backfill.json 2>&1 >/dev/null | grep -E 'V1|V3|V4|V5' || echo "NO_ANNOTATION_WARN"
```
Saída esperada: `NO_ANNOTATION_WARN` (nenhuma violação de regra). Se aparecer `WARN <chart>: V...`, corrija a annotation daquele chart (indentação/aspas/versão).

### Passo 5 — Regenerar as saídas de verdade (README + JSON) no repo
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output docs/compatibility.json 2>/tmp/backfill.stderr; echo "exit=$?"
```
Saída esperada: `exit=0`. Revise `git diff docs/compatibility.json README.md` — os cycles N dos charts editados agora carregam `testedWith`.

## Verification (copiável) — 100% dos candidatos com testedWith + check verde
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --check --root ../.. ; echo "check_exit=$?"
```
Saída esperada: `check_exit=0` e stdout `ok` (README e JSON já regenerados e batendo). Confirme também:
```bash
cd "$(git rev-parse --show-toplevel)" && python3 -c "import json; d=json.load(open('docs/compatibility.json')); tw=[k for k,v in d['products'].items() if v.get('cycles') and v['cycles'][0].get('testedWith')]; print('with_testedWith:', len(tw)); print(tw)"
```
Saída esperada: uma lista com todos os charts que você editou (contagem > 0).

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)" && git checkout charts/ docs/compatibility.json README.md
```
