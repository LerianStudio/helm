# ST-8-4 — Garantir scope permitido no `pr-title.yml` para os PRs da feature

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Confirmar (e, se faltar, adicionar) que os scopes usados pelos PRs desta entrega (`ci`, `charts`, `doc`) estão na allowlist do `pr-title.yml` — o CI rejeita título de PR com scope fora da lista (regra do repo: Conventional Commits com scope obrigatório). Sem isso, os PRs de T-7/T-8/T-9 falham no lint de título.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)" && test -f .github/workflows/pr-title.yml && echo "WF_EXISTS" || ls .github/workflows/ | grep -i 'pr-title\|semantic\|title'
```
Saída esperada: `WF_EXISTS` (ou o nome real do workflow de validação de título).

## Files
- modify (se necessário): `./.github/workflows/pr-title.yml` (allowlist de scopes)

## Steps

### Passo 1 — Inspecionar a allowlist atual de scopes
```bash
cd "$(git rev-parse --show-toplevel)" && grep -nA20 -iE 'scopes|scope' .github/workflows/pr-title.yml | head -40
```
Saída esperada: o bloco que define os scopes aceitos (pode estar em `with: scopes:` do `amannn/action-semantic-pull-request` ou similar). Anote quais scopes já existem.

### Passo 2 — Verificar se `ci`, `charts`, `doc` estão presentes
```bash
cd "$(git rev-parse --show-toplevel)" && for s in ci charts doc; do grep -qiE "(^|[^a-z])$s([^a-z]|$)" .github/workflows/pr-title.yml && echo "$s: PRESENTE" || echo "$s: FALTA"; done
```
Saída esperada: idealmente todos `PRESENTE`. Anote os que faltam.

> Nota: esta verificação é por busca textual (suficiente para um subtask de planejamento — confirma que o token existe na allowlist). Para checagem estrutural rigorosa (garantir que o token está de fato sob a chave `scopes:` da action, e não em outro lugar do YAML), use `yq '.jobs.*.steps[].with.scopes' .github/workflows/pr-title.yml` no lugar do grep.

### Passo 3 — Adicionar os scopes faltantes (só se algum FALTA)
Se algum scope apareceu como `FALTA`, edite a lista de `scopes` no `pr-title.yml` adicionando-o. Exemplo (formato depende da action; NÃO invente — case ao que o Passo 1 mostrou). Se a lista for multi-linha do tipo:
```yaml
          scopes: |
            midaz
            charts
            ci
```
adicione a(s) linha(s) faltante(s) mantendo a indentação exata.

Se o workflow NÃO restringe scope (só valida o `type`), este passo é no-op — registre isso e siga.

### Passo 4 — Validar sintaxe (se editou)
```bash
cd "$(git rev-parse --show-toplevel)" && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pr-title.yml')); print('YAML_OK')"
```
Saída esperada: `YAML_OK`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)" && for s in ci charts doc; do grep -qiE "(^|[^a-z])$s([^a-z]|$)" .github/workflows/pr-title.yml && echo "$s ok"; done; echo "ST-8-4_DONE"
```
Saída esperada: `ci ok`, `charts ok`, `doc ok` (para os que se aplicam) seguido de `ST-8-4_DONE`. Se o workflow não restringe scope, registre "no-op" e prossiga.

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)" && git checkout .github/workflows/pr-title.yml
```
