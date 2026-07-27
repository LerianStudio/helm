# ST-8-2 — Step dedicado 2B pós-release: gera + commita com `[skip ci]`, guard de actor, rebase

> ⚠️ **SUPERADO — não implementar.** A decisão de write-back foi revertida de **2B (step dedicado)** para **2A (commit único via `@semantic-release/git`)** — ver ADR-1b atualizado e §5 do TRD. O motivo: 2B gera dois commits no mesmo release (colisão de push). A implementação real está no `prepareCmd` + `assets` do semantic-release (nenhum step dedicado, nenhum `git pull --rebase`). Este arquivo fica só como registro histórico do caminho não seguido.

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Adicionar o STEP DEDICADO (Opção 2B, ADR-1b) ao `release.yml`, APÓS o Semantic Release, que regenera a matriz e commita por conta própria — reusando o App-token (`steps.app-token.outputs.token`) e a chave GPG já importada no job (crazy-max/ghaction-import-gpg, release.yml:124-134). Implementa as 3 camadas anti-loop (paths-ignore já cobre README/docs; `[skip ci]`; guard de actor) e trata os 2 commits do mesmo release com `git pull --rebase` + commit-só-se-diff.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)" && grep -q 'go build -o generate-compatibility-bin' .github/workflows/release.yml && echo "PREREQ_OK"
```
Saída esperada: `PREREQ_OK` (ST-8-1 concluído).

Confirme os âncoras reutilizados:
```bash
cd "$(git rev-parse --show-toplevel)" && sed -n '23p;54,58p' .github/workflows/release.yml
```
Saída esperada: linha 23 = o guard `if: github.actor != 'lerian-studio-midaz-push-bot[bot]'`; linhas 54-58 = o step `Generate GitHub App Token` (`id: app-token`).

## Files
- modify: `./.github/workflows/release.yml` (novo step após "Semantic Release", dentro do job `release-helm-chart`)

## Steps

### Passo 1 — Inserir o step 2B após o Semantic Release
No `release.yml`, IMEDIATAMENTE após o step "Semantic Release" (que termina em ~linha 180) e antes de "Install oras" (~linha 183), insira:
```yaml
      - name: Write-back compatibility matrix
        if: >-
          steps.semantic_changelog.outputs.new_release_published == 'true'
          && github.actor != 'lerian-studio-midaz-push-bot[bot]'
        env:
          GIT_AUTHOR_NAME: ${{ secrets.LERIAN_CI_CD_USER_NAME }}
          GIT_AUTHOR_EMAIL: ${{ secrets.LERIAN_CI_CD_USER_EMAIL }}
          GIT_COMMITTER_NAME: ${{ secrets.LERIAN_CI_CD_USER_NAME }}
          GIT_COMMITTER_EMAIL: ${{ secrets.LERIAN_CI_CD_USER_EMAIL }}
        run: |
          set -euo pipefail

          # Regenerate the full matrix (README blocks + docs/compatibility.json).
          # N comes from Chart.yaml; N-1..N-3 from the tags fetched in ST-8-1.
          ./.github/scripts/generate-compatibility-bin --root . --output docs/compatibility.json

          # Commit only if the generator actually changed something.
          if git diff --quiet -- README.md docs/compatibility.json; then
            echo "No compatibility drift to commit."
            exit 0
          fi

          # Two commits land on the same release (semantic-release + this one):
          # rebase onto the just-pushed release commit before committing.
          git pull --rebase origin "${{ github.ref_name }}"

          git add README.md docs/compatibility.json
          # [skip ci] + the actor guard above are 2 of the 3 anti-loop layers;
          # paths-ignore (README.md, **/docs/**) is the third (release.yml:8-14).
          git commit -m "chore: update compatibility matrix [skip ci]"
          git push origin "HEAD:${{ github.ref_name }}"
        working-directory: ${{ github.workspace }}
```

Notas de ancoragem:
- O commit herda a config GPG global importada em release.yml:124-134 (`git_commit_gpgsign: true`), ficando **verified**. NÃO reimportar GPG.
- O push usa o remote já autenticado com o App-token (checkout em release.yml:60-64 usou `token: ${{ steps.app-token.outputs.token }}`).
- `working-directory` é a raiz do repo (o binário foi gerado em `.github/scripts/` no ST-8-1, mas invocamos pelo caminho relativo `./.github/scripts/generate-compatibility-bin`).

### Passo 2 — Validar sintaxe do YAML
```bash
cd "$(git rev-parse --show-toplevel)" && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('YAML_OK')"
```
Saída esperada: `YAML_OK`.

### Passo 3 — Conferir as 3 camadas anti-loop presentes
```bash
cd "$(git rev-parse --show-toplevel)" && echo "1) paths-ignore README/docs:" && sed -n '8,14p' .github/workflows/release.yml | grep -Ec "README.md|docs" && echo "2) skip ci (>=2: back-merge + write-back):" && grep -c 'skip ci' .github/workflows/release.yml && echo "3) actor guards (>=2):" && grep -c "github.actor != 'lerian-studio-midaz-push-bot" .github/workflows/release.yml
```
Saída esperada: item 1 retorna `2` (README.md e docs ignorados); item 2 retorna `>= 2`; item 3 retorna `>= 2` (o guard do job em :23 + o do step 2B).

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)" && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('YAML_OK')" && grep -q 'Write-back compatibility matrix' .github/workflows/release.yml && grep -q 'git pull --rebase origin' .github/workflows/release.yml && echo "ST-8-2_OK"
```
Saída esperada: `YAML_OK` seguido de `ST-8-2_OK`.

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)" && git checkout .github/workflows/release.yml
```