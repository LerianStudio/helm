# ST-8-2 — [SUPERADO] Step dedicado 2B pós-release

> ⛔ **SUPERADO — NÃO IMPLEMENTAR. Documento histórico, não executável.**
>
> A decisão de write-back foi **revertida de 2B (step dedicado) para 2A (commit único via `@semantic-release/git`)**. Este subtask descrevia a 2B e **não deve ser seguido**. O marcador `For Agents` e os passos executáveis foram removidos de propósito para que nenhum agente/dev o execute por engano.

## Por que foi abandonado (2B → 2A)

A 2B adicionaria um **step dedicado após o Semantic Release** que gerava a matriz e fazia o **próprio commit/push**. Problema fatal: isso produz **dois commits no mesmo release** (o do `@semantic-release/git` + o do step), com risco real de colisão no push e necessidade de `git pull --rebase` num worktree sujo. Ver ADR-1b (atualizado) e §5 do TRD.

## O que vale de verdade (fluxo 2A implementado)

A geração roda **dentro** do release que já existe, sem segundo commit:

- No `prepareCmd` do semantic-release: `generate-compatibility --root . --chart $COMPAT_CHART --write` **substitui** a antiga `update-chart-version-readme`.
- `docs/compatibility.json` entra nos `assets` do `@semantic-release/git`, junto de `Chart.yaml` e `README.md` → **um único commit** de release.
- `git fetch --tags --force` antes, para o histórico N-1..N-3 e as datas Released.
- Anti-loop herdado do mecanismo existente: `paths-ignore` (`README.md`, `**/docs/**`), `[skip ci]` no commit do release, guard de actor `github.actor != 'lerian-studio-midaz-push-bot[bot]'`.

Para os subtasks **executáveis** da integração real, ver os demais ST-8-* (build/fetch, `--check` no PR, allowlist de scope) — nenhum deles cria step dedicado nem faz rebase.
