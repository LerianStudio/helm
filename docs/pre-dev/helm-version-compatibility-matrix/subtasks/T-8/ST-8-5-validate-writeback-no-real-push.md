# ST-8-5 — Validar o write-back SEM push real (TRD §10 passo 4 — o mais arriscado)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Prova executiva do step 2B ANTES de qualquer push real (DoD obrigatório do TRD §10 passo 4). Simular localmente, num CLONE DESCARTÁVEL com um "remote" bare local, o encadeamento "semantic-release commit + nosso commit": conferir (a) `git pull --rebase` + commit-só-se-diff funcionam com 2 commits no mesmo release; (b) o commit fica **GPG-verified** (localmente: assinado, dado que a chave exista); (c) `git push --dry-run` sucede; (d) a mensagem tem `[skip ci]`. Nenhuma alteração no repo real, nenhum push para o GitHub.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go build -o /tmp/gc-bin ./generate-compatibility && echo "BUILD_OK"
```
Saída esperada: `BUILD_OK`.

```bash
cd /home/gauchito/lerian/helm && grep -q 'Write-back compatibility matrix' .github/workflows/release.yml && echo "STEP_EXISTS"
```
Saída esperada: `STEP_EXISTS` (ST-8-2 concluído).

## Files
- (nenhum arquivo do repo real é modificado; tudo em /tmp)

## Steps

### Passo 1 — Montar remote bare local + clone de trabalho
```bash
rm -rf /tmp/helm-bare.git /tmp/helm-wb && \
git clone --bare /home/gauchito/lerian/helm /tmp/helm-bare.git && \
git clone /tmp/helm-bare.git /tmp/helm-wb && \
cd /tmp/helm-wb && git fetch --tags --force 2>/dev/null; echo "setup=$?"
```
Saída esperada: `setup=0`. Agora `/tmp/helm-wb` tem `origin` = `/tmp/helm-bare.git` (um remote real, mas local e descartável).

### Passo 2 — Configurar identidade e (se disponível) assinatura GPG no clone
```bash
cd /tmp/helm-wb && git config user.name "CI Test" && git config user.email "gauchito@lerian.studio" && \
KEY=$(git config --global user.signingkey || true); \
if [ -n "$KEY" ]; then git config commit.gpgsign true; git config user.signingkey "$KEY"; echo "GPG_ON key=$KEY"; else echo "GPG_OFF (sem chave global; valida-se só o fluxo, não a assinatura)"; fi
```
Saída esperada: `GPG_ON key=...` (se houver chave global — o commit será assinado) ou `GPG_OFF ...` (valida o fluxo; a assinatura real acontece no CI com a chave importada). NÃO sobrescrever identidade global (regra [[feedback_git_identity]]); só config LOCAL do clone.

### Passo 3 — Simular o commit do semantic-release (1º commit do release)
```bash
cd /tmp/helm-wb && echo "# fake release bump" >> charts/matcher/Chart.yaml && \
git add charts/matcher/Chart.yaml && \
git commit -m "chore(matcher): release 3.0.1 [skip ci]" >/dev/null && \
git push origin HEAD:main >/dev/null 2>&1; echo "release_commit_pushed=$?"
```
Saída esperada: `release_commit_pushed=0` (o "semantic-release" commitou e empurrou pro remote bare).

### Passo 4 — Executar o MIOLO do step 2B (as mesmas linhas do release.yml)
```bash
cd /tmp/helm-wb && set -e && \
/tmp/gc-bin --root . --output docs/compatibility.json && \
if git diff --quiet -- README.md docs/compatibility.json; then echo "NO_DRIFT (nada a commitar — ok se já gerado antes)"; else \
  git pull --rebase origin main && \
  git add README.md docs/compatibility.json && \
  git commit -m "chore: update compatibility matrix [skip ci]" && \
  echo "WB_COMMIT_CREATED"; fi
```
Saída esperada: `WB_COMMIT_CREATED` (havia drift → nosso commit foi criado sobre o commit do release, via rebase, sem conflito). Se sair `NO_DRIFT`, force um drift apagando o bloco: veja Passo 4b.

### Passo 4b — (só se saiu NO_DRIFT) forçar drift e repetir
```bash
cd /tmp/helm-wb && test -f docs/compatibility.json && rm -f docs/compatibility.json && \
/tmp/gc-bin --root . --output docs/compatibility.json && \
git add README.md docs/compatibility.json && git commit -m "chore: update compatibility matrix [skip ci]" && echo "WB_COMMIT_CREATED"
```
Saída esperada: `WB_COMMIT_CREATED`.

### Passo 5 — Conferir `[skip ci]` e (se GPG on) assinatura
```bash
cd /tmp/helm-wb && echo "--- mensagem ---" && git log -1 --pretty=%B && echo "--- assinatura (N=não assinado, G=boa) ---" && git log -1 --pretty='%G?'
```
Saída esperada: a mensagem contém `[skip ci]`; `%G?` retorna `G` (assinatura boa) se GPG estava ON, ou `N` se OFF (esperado localmente sem chave — a verificação real é no CI).

### Passo 6 — `git push --dry-run` (NÃO empurra de verdade)
```bash
cd /tmp/helm-wb && git push --dry-run origin HEAD:main; echo "dry_run_exit=$?"
```
Saída esperada: `dry_run_exit=0` e o git lista o range de commits que SERIA empurrado (ex.: `abc..def  HEAD -> main`) — sem efetuar o push. Confirma que o rebase deixou o histórico limpo e "empurrável".

### Passo 7 — Confirmar que o repo REAL não foi tocado
```bash
cd /home/gauchito/lerian/helm && git status --porcelain | head; echo "real_repo_clean_check_done"
```
Saída esperada: nenhuma linha referente a esta simulação (o trabalho todo foi em /tmp).

## Verification (copiável)
```bash
cd /tmp/helm-wb && git log -1 --pretty=%B | grep -q '\[skip ci\]' && git push --dry-run origin HEAD:main >/dev/null 2>&1 && echo "ST-8-5_OK"
```
Saída esperada: `ST-8-5_OK`.

## Rollback
```bash
rm -rf /tmp/helm-bare.git /tmp/helm-wb /tmp/gc-bin
```
(O repo real e o GitHub nunca foram tocados.)
