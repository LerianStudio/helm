# ST-8-6 — Confirmar que o push do bot NÃO re-dispara o workflow (3 camadas comprovadas)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Verificar ESTATICAMENTE (por leitura do workflow) e, quando o PR real rodar, OBSERVACIONALMENTE, que o push do bot no step 2B não gera um novo run de release — provando as 3 camadas anti-loop (paths-ignore, `[skip ci]`, guard de actor). Esta é a última salvaguarda antes de liberar T-8 para `main`.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)" && grep -q 'Write-back compatibility matrix' .github/workflows/release.yml && echo "STEP_EXISTS"
```
Saída esperada: `STEP_EXISTS`.

## Files
- (nenhum; apenas verificação/leitura)

## Steps

### Passo 1 — Camada 1: paths-ignore cobre README.md e docs
```bash
cd "$(git rev-parse --show-toplevel)" && sed -n '3,15p' .github/workflows/release.yml
```
Saída esperada: bloco `on: push:` com `paths-ignore:` contendo `'README.md'` e `'**/docs/**'`. Como o step 2B só altera esses dois caminhos, o push do bot casa o `paths-ignore` → NÃO dispara `release.yml`.

### Passo 2 — Camada 2: `[skip ci]` na mensagem do commit 2B
```bash
cd "$(git rev-parse --show-toplevel)" && grep -n 'chore: update compatibility matrix \[skip ci\]' .github/workflows/release.yml
```
Saída esperada: uma linha com a mensagem contendo `[skip ci]`. Muitos workflows/Actions respeitam `[skip ci]` no head commit para não iniciar runs.

### Passo 3 — Camada 3: guard de actor no job e no step
```bash
cd "$(git rev-parse --show-toplevel)" && echo "job guard (:23):" && sed -n '23p' .github/workflows/release.yml && echo "step 2B guard:" && grep -n "github.actor != 'lerian-studio-midaz-push-bot\[bot\]'" .github/workflows/release.yml
```
Saída esperada: o job `get-changed-paths` tem `if: github.actor != 'lerian-studio-midaz-push-bot[bot]'` (:23) — então mesmo que um push do bot passasse pelos filtros de path, o job não roda. E o próprio step 2B repete o guard (não commita quando o ator é o bot).

### Passo 4 — Sanidade: as 3 camadas são independentes (qualquer uma quebra o loop)
Documente a conclusão da revisão estática:
- Camada 1 (paths-ignore): impede o trigger por conteúdo alterado.
- Camada 2 ([skip ci]): impede o start do run.
- Camada 3 (actor guard): impede o job de rodar mesmo se as duas anteriores falharem.
Basta UMA para quebrar o loop; as três juntas dão defesa em profundidade.

### Passo 5 — (Observacional, no PR/release real) confirmar zero re-trigger
Após o merge que ativa o step (feito pelo usuário — NÃO pela IA), quando um release real ocorrer, verifique que o push do bot não iniciou novo run:
```bash
cd "$(git rev-parse --show-toplevel)" && gh run list --workflow release.yml --limit 5 --json displayTitle,event,headBranch,createdAt,conclusion 2>/dev/null || echo "gh indisponível (ver reference_gh_servers_night); reexecutar depois"
```
Saída esperada: entre os runs recentes, o commit `chore: update compatibility matrix [skip ci]` NÃO aparece como gatilho de um novo run de `release.yml`. (Se `gh` estiver indisponível à noite, deixar pendente e reexecutar.)

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)" && \
  L1=$(sed -n '8,14p' .github/workflows/release.yml | grep -Ec "README.md|docs") && \
  L2=$(grep -c 'update compatibility matrix \[skip ci\]' .github/workflows/release.yml) && \
  L3=$(grep -c "github.actor != 'lerian-studio-midaz-push-bot" .github/workflows/release.yml) && \
  echo "L1=$L1 L2=$L2 L3=$L3" && [ "$L1" -ge 2 ] && [ "$L2" -ge 1 ] && [ "$L3" -ge 2 ] && echo "ST-8-6_OK"
```
Saída esperada: `L1=2 L2=1 L3=2` (ou maiores) seguido de `ST-8-6_OK`.

## Rollback
Nada a reverter (só leitura/verificação).
