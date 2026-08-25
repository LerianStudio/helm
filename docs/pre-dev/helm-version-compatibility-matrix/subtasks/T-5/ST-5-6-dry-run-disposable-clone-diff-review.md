# ST-5-6 — Dry-run em CLONE DESCARTÁVEL: revisar `git diff` do README real (TRD §10 passo 2)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Prova executiva do risco #1 antes de qualquer commit: rodar o gerador contra um CLONE DESCARTÁVEL do repo e inspecionar o `git diff` do `README.md`. Confirmar: (a) só o conteúdo entre markers muda; (b) prosa e separadores irregulares intactos; (c) `br-spi` ganha seção (ADR-5); (d) 2× = diff idêntico (idempotência). NADA é commitado. NADA no repo principal é tocado.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-5-5.)

## Files
- (nenhum arquivo do repo principal é modificado; tudo acontece num clone em /tmp)

## Steps

### Passo 1 — Criar o clone descartável
```bash
rm -rf /tmp/helm-dryrun && git clone --local . /tmp/helm-dryrun && cd /tmp/helm-dryrun && git fetch --tags --force origin 2>/dev/null; echo "clone_ready=$?"
```
Saída esperada: `clone_ready=0`. (O `--local` copia o repo; `git clone` local traz as tags. Se o remoto não estiver acessível, o fetch pode falhar sem problema — as tags locais já vieram no clone.)

### Passo 2 — Rodar o gerador no clone (write real, MAS no clone)
```bash
cd /tmp/helm-dryrun/.github/scripts && go run ./generate-compatibility --root ../.. --output docs/compatibility.json 2> /tmp/dryrun.stderr; echo "exit=$?"
```
Saída esperada: `exit=0`.

### Passo 3 — Revisar o diff do README: só entre markers
```bash
cd /tmp/helm-dryrun && git diff --unified=1 README.md | head -80
```
Revisão MANUAL (critérios de aceite):
- Toda linha adicionada/removida está DENTRO de um par `<!-- BEGIN COMPAT:... -->` / `<!-- END COMPAT:... -->`, OU é a criação de uma seção nova (só para `br-spi`, ADR-5).
- NENHUMA linha de prosa existente aparece como removida/alterada.
- Os separadores `-----------------` (Plugin Fees, Plugin BR Pix Indirect BTG etc.) permanecem — não aparecem como removidos.

### Passo 4 — Confirmar seção do br-spi criada (ADR-5)
```bash
cd /tmp/helm-dryrun && grep -n 'COMPAT:br-spi-helm' README.md && grep -n '### Br Spi' README.md
```
Saída esperada: linhas mostrando os markers `BEGIN/END COMPAT:br-spi-helm` e um cabeçalho `### Br Spi` (a seção mínima nova). Antes, `br-spi` não tinha seção.

### Passo 5 — Idempotência: rodar 2× e comparar
```bash
cd /tmp/helm-dryrun && cp README.md /tmp/readme-run1.md && cd .github/scripts && go run ./generate-compatibility --root ../.. --output docs/compatibility.json 2>/dev/null && cd /tmp/helm-dryrun && diff /tmp/readme-run1.md README.md && echo "README_IDEMPOTENT_OK"
```
Saída esperada: `README_IDEMPOTENT_OK` (segunda execução não muda nada).

### Passo 6 — Contar seções corrompidas (deve ser 0)
```bash
cd /tmp/helm-dryrun && echo "headers antes vs depois:" && git show HEAD:README.md | grep -c '^### ' && grep -c '^### ' README.md
```
Saída esperada: o número DEPOIS = número ANTES + 1 (a seção nova do `br-spi`). Nenhum header existente sumiu.

## Verification (copiável)
```bash
cd /tmp/helm-dryrun && CHANGED=$(git diff README.md | grep -E '^[-+]' | grep -vE '^[-+]{3}' | grep -v 'COMPAT:' | grep -vE 'BEGIN COMPAT|END COMPAT' | grep -c '🟢\|🔵\|🟡\|🟠\|🔴\|Version\|:---:\|`\|### Br Spi\|^[-+]$'); echo "linhas de diff fora do padrão esperado (aprox): revisar manualmente se >0"; echo "DRYRUN_DONE"
```
Saída esperada: `DRYRUN_DONE`. A heurística é auxiliar; a ACEITAÇÃO REAL é a revisão manual do Passo 3.

## Rollback
```bash
rm -rf /tmp/helm-dryrun /tmp/readme-run1.md /tmp/dryrun.stderr
```
(O repo principal nunca foi tocado.)
