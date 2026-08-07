# ST-8-3 — `--check` como warning no PR (`helm-chart-standard.yml`) + trigger path

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Adicionar ao `helm-chart-standard.yml` um step que roda `generate-compatibility --check` como WARNING no PR (não falha o build — ADR-4, exit 0), e incluir `.github/scripts/generate-compatibility/**` no trigger `paths` do workflow. Assim o CI detecta drift sem bloquear (espírito Ring).

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)" && test -f .github/workflows/helm-chart-standard.yml && echo "WF_EXISTS"
```
Saída esperada: `WF_EXISTS`. Se não existir, PARE e reporte (nome do workflow pode diferir; procure com `ls .github/workflows/ | grep -i standard`).

Inspecione o trigger `paths` atual:
```bash
cd "$(git rev-parse --show-toplevel)" && sed -n '1,40p' .github/workflows/helm-chart-standard.yml
```
Anote a estrutura de `on:`/`paths:` e onde ficam os steps do job de validação.

## Files
- modify: `./.github/workflows/helm-chart-standard.yml` (trigger `paths` + novo step de check)

## Steps

### Passo 1 — Adicionar o path ao trigger
No bloco `on: pull_request: paths:` (ou equivalente), adicione a entrada (mantendo as existentes):
```yaml
      - '.github/scripts/generate-compatibility/**'
```
Se o workflow já dispara para `.github/scripts/**` de forma ampla, este passo é no-op — confirme e siga.

### Passo 2 — Adicionar o step de check (warning, não bloqueante)
No job que roda os validadores Go (onde já há `go run ./validate-helm-charts ...` ou similar), adicione um step:
```yaml
      - name: Compatibility matrix drift check (warning)
        working-directory: .github/scripts
        continue-on-error: true
        run: |
          # v1: --check emits WARN on stderr and exits 0 on drift (ADR-4).
          # continue-on-error is defensive: this step must never fail the PR.
          go run ./generate-compatibility --check --root ../..
```
Justificativa: `--check` já retorna exit 0 no v1 mesmo com drift; `continue-on-error: true` é cinto-e-suspensório para garantir que nunca bloqueie o build.

### Passo 3 — Validar sintaxe
```bash
cd "$(git rev-parse --show-toplevel)" && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/helm-chart-standard.yml')); print('YAML_OK')"
```
Saída esperada: `YAML_OK`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)" && grep -q 'generate-compatibility --check' .github/workflows/helm-chart-standard.yml && grep -q 'generate-compatibility' .github/workflows/helm-chart-standard.yml && echo "ST-8-3_OK"
```
Saída esperada: `ST-8-3_OK`.

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)" && git checkout .github/workflows/helm-chart-standard.yml
```
