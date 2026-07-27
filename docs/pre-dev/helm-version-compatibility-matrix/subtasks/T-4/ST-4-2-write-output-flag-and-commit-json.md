# ST-4-2 — `--output` gravável e `docs/compatibility.json` versionado (verificação)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Confirmar que `--output` (default `docs/compatibility.json`, relativo a `--root`) grava o artefato final e que ele é o entregável de máquina (US-5) — determinístico, sem `tier`, batendo com o schema do data-model §B.4. Gerar o `docs/compatibility.json` inicial do repo para commit.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-4-1.)

## Files
- create/modify: `./docs/compatibility.json` (artefato gerado)

## Steps

### Passo 1 — Gerar o artefato final no lugar canônico
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output docs/compatibility.json 2>/tmp/t4-2.stderr; echo "exit=$?"
```
Saída esperada: `exit=0` e uma linha `wrote ../../docs/compatibility.json (N products)`.

### Passo 2 — Conferir que o arquivo existe no caminho versionado
```bash
cd "$(git rev-parse --show-toplevel)" && test -f docs/compatibility.json && head -6 docs/compatibility.json
```
Saída esperada: as 6 primeiras linhas do JSON, começando por `{` e `"schemaVersion": 1`.

### Passo 3 — `--output` alternativo funciona (grava onde mandado)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output /tmp/alt-compat.json 2>/dev/null && test -f /tmp/alt-compat.json && echo "OUTPUT_FLAG_OK"
```
Saída esperada: `OUTPUT_FLAG_OK`.

### Passo 4 — Idempotência: regerar não muda o arquivo versionado
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output docs/compatibility.json 2>/dev/null && cd "$(git rev-parse --show-toplevel)" && git diff --stat docs/compatibility.json
```
Saída esperada após a PRIMEIRA geração já commitada: VAZIA (regerar = mesmo byte). Na primeiríssima criação, o `git status` mostrará o arquivo como novo (esperado — é o commit inicial do artefato).

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)" && python3 -c "import json,sys; d=json.load(open('docs/compatibility.json')); assert d['schemaVersion']==1; assert 'products' in d; assert all('tier' not in c for p in d['products'].values() for c in p.get('cycles',[])); print('SCHEMA_OK', len(d['products']), 'products')"
```
Saída esperada: `SCHEMA_OK <N> products` (N ~= 21). O assert falha se aparecer `tier` em qualquer cycle.

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)" && git checkout docs/compatibility.json 2>/dev/null || rm -f docs/compatibility.json
```
