# ST-8-1 — Build do binário `generate-compatibility` + `git fetch --tags --force` no release.yml

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Preparar o terreno no `release.yml`: (1) compilar o binário `generate-compatibility` no step "Build scripts" existente (release.yml:136-139), e (2) garantir o histórico de tags para a janela N-1..N-3 com `git fetch --tags --force`. Ainda NÃO gera/commita (isso é ST-8-2/8-3). Só adiciona insumos, sem alterar o fluxo do semantic-release.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go build -o /tmp/gc-bin ./generate-compatibility && echo "BUILD_OK"
```
Saída esperada: `BUILD_OK` (a ferramenta compila; complete T-1..T-6 se falhar).

Confirme o step "Build scripts" atual:
```bash
cd "$(git rev-parse --show-toplevel)" && sed -n '136,140p' .github/workflows/release.yml
```
Saída esperada:
```
      - name: Build scripts
        run: |
          cd .github/scripts
          go build -o update-chart-version-readme-bin ./update-chart-version-readme
```

## Files
- modify: `./.github/workflows/release.yml` (step "Build scripts" + novo fetch de tags)

## Steps

### Passo 1 — Adicionar o build do novo binário
No `release.yml`, no step "Build scripts" (linhas ~136-139), substitua o bloco `run:` por:
```yaml
      - name: Build scripts
        run: |
          cd .github/scripts
          go build -o update-chart-version-readme-bin ./update-chart-version-readme
          go build -o generate-compatibility-bin ./generate-compatibility
```

### Passo 2 — Garantir histórico de tags para a janela
Adicione um step logo APÓS "Build scripts" (antes de "Generate .releaserc file"):
```yaml
      - name: Fetch tags for compatibility window
        run: git fetch --tags --force
```
Justificativa: N vem do Chart.yaml (ADR-3), mas N-1..N-3 vêm das tags `<dir>-v*`; o checkout com `fetch-depth: 0` já traz o histórico, e `--force` garante tags atualizadas mesmo em re-runs.

### Passo 3 — Validar sintaxe do YAML do workflow
```bash
cd "$(git rev-parse --show-toplevel)" && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('YAML_OK')"
```
Saída esperada: `YAML_OK`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)" && grep -q 'go build -o generate-compatibility-bin ./generate-compatibility' .github/workflows/release.yml && grep -q 'Fetch tags for compatibility window' .github/workflows/release.yml && echo "ST-8-1_OK"
```
Saída esperada: `ST-8-1_OK`.

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)" && git checkout .github/workflows/release.yml
```
