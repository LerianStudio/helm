# Subtasks — Matriz de Compatibilidade (Gate 8)

Índice das subtasks zero-context (2–5 min, TDD RED-GREEN-REFACTOR, código completo, verificação copiável + rollback) da feature `helm-version-compatibility-matrix`.

Cada arquivo abre com o header padrão (Goal, Prerequisites com comando+saída, Files) e traz `> **For Agents:** REQUIRED SUB-SKILL: executing-plans`.

Ferramenta-alvo: `.github/scripts/generate-compatibility/` (novo `package main`, mesmo padrão de `generate-values-schemas`). Go **1.21** (piso duro). Deps: `gopkg.in/yaml.v3 v3.0.1` + **`github.com/Masterminds/semver/v3 v3.2.1`** (exato, não v3.4+). Lib interna reusada: `tableutil`.

---

## ⚠️ Gate de teste §10 (regra dura — vale para TODA subtask de geração)

O maior risco da feature é **corromper o README de todos os charts de uma vez** ou o write-back gerar loop/commit unverified. Ordem de validação, do mais barato ao mais arriscado (TRD §10):

1. **Unit (Go, offline):** `go test ./generate-compatibility/` — table-driven de janela (T-3) e boundaries irregulares (T-5).
2. **Dry-run local em CLONE DESCARTÁVEL:** rodar `--write` e revisar `git diff` do README — só muda entre markers; prosa/separadores intactos; `br-spi` ganha seção (ADR-5); 2× = diff idêntico. → **ST-5-6**.
3. **`--check`:** rodar contra o repo real, apontar drift **sem escrever**. → **ST-6-2** (verificação).
4. **Write-back SEM push real:** `git push --dry-run` / remote bare local; commit GPG-verified; `[skip ci]` + guard de actor comprovados. → **ST-8-5**, **ST-8-6**.
5. **Backfill:** `testedWith` nas annotations em **PR de teste** + `--check` verde antes do PR real. → **ST-7-1**.

**Nada vai para `main` sem 1–5 verdes.** Toda geração roda em clone descartável antes de qualquer commit real e é idempotente (2× = mesmo byte). Alinhado a [[feedback_test_changed_artifacts]] e [[feedback_ask_before_push]] (o usuário aprova todo push).

---

## Ordem de execução (caminho crítico: T-1 → T-2 → T-3 → (T-4 ‖ T-5) → T-6 → T-8)

| # | Tarefa | Subtask | O que entrega |
|---|--------|---------|---------------|
| 1 | **T-1** | [ST-1-1](T-1/ST-1-1-add-semver-dependency.md) | Dep `Masterminds/semver/v3 v3.2.1` (exata) no go.mod/go.sum |
| 2 | T-1 | [ST-1-2](T-1/ST-1-2-chart-directories-helper-tdd.md) | Package + `chartDirectories` (TDD) |
| 3 | T-1 | [ST-1-3](T-1/ST-1-3-read-chart-version-tdd.md) | `readChartState` → Name/Dir/Version/AppVersion (TDD) |
| 4 | T-1 | [ST-1-4](T-1/ST-1-4-main-emit-current-json.md) | `main()` demoável: JSON com `current` |
| 5 | **T-2** | [ST-2-1](T-2/ST-2-1-parse-annotation-twostep-tdd.md) | Two-step unmarshal da annotation (TDD) |
| 6 | T-2 | [ST-2-2](T-2/ST-2-2-validate-annotation-warnings-tdd.md) | Regras V1–V6 como WARN/INFO (TDD) |
| 7 | T-2 | [ST-2-3](T-2/ST-2-3-wire-annotation-into-state-and-doc.md) | Annotation no ChartState + WARN no buildDoc |
| 8 | **T-3** ⚠️ | [ST-3-1](T-3/ST-3-1-list-git-tags-for-dir-tdd.md) | Listar/parsear tags `<dir>-v*` (TDD) |
| 9 | T-3 ⚠️ | [ST-3-2](T-3/ST-3-2-segregate-prereleases-and-group-by-minor-tdd.md) | Segregar pre-releases + agrupar por minor (TDD) |
| 10 | T-3 ⚠️ | [ST-3-3](T-3/ST-3-3-resolve-window-N-authoritative-tdd.md) | `resolveWindow`: N do Chart.yaml + top-4 + degradação (TDD) |
| 11 | T-3 ⚠️ | [ST-3-4](T-3/ST-3-4-wire-window-into-buildDoc-golden-tdd.md) | Ligar janela no buildDoc + golden JSON |
| 12 | T-3 ⚠️ | [ST-3-5](T-3/ST-3-5-verify-window-against-real-repo.md) | Validar janela contra o repo real (/tmp) |
| 13 | **T-4** | [ST-4-1](T-4/ST-4-1-assert-no-tier-and-schema-shape-tdd.md) | JSON sem `tier`, conforme §B (TDD) |
| 14 | T-4 | [ST-4-2](T-4/ST-4-2-write-output-flag-and-commit-json.md) | `--output` + `docs/compatibility.json` versionado |
| 15 | **T-5** ⚠️ | [ST-5-1](T-5/ST-5-1-render-compat-table-lines-tdd.md) | Render das linhas COMPAT + badges (TDD) |
| 16 | T-5 ⚠️ | [ST-5-2](T-5/ST-5-2-marker-block-replace-idempotent-tdd.md) | Substituição confinada entre markers, idempotente (TDD) |
| 17 | T-5 ⚠️ | [ST-5-3](T-5/ST-5-3-locate-section-via-tableutil-tdd.md) | Localizar seção via normalização do `tableutil` (TDD) |
| 18 | T-5 ⚠️ | [ST-5-4](T-5/ST-5-4-ensure-block-create-section-adr5-tdd.md) | `ensureCompatBlock` + criar seção mínima br-spi (ADR-5) (TDD) |
| 19 | T-5 ⚠️ | [ST-5-5](T-5/ST-5-5-wire-readme-write-into-main-golden-tdd.md) | Escrita do README no main + golden de layout irregular |
| 20 | T-5 ⚠️ | [ST-5-6](T-5/ST-5-6-dry-run-disposable-clone-diff-review.md) | **Dry-run em clone descartável + review de diff (§10 passo 2)** |
| 21 | **T-6** | [ST-6-1](T-6/ST-6-1-flag-parsing-exit-codes-tdd.md) | Flags + exit codes 0/1/2 (`run()` testável) (TDD) |
| 22 | T-6 | [ST-6-2](T-6/ST-6-2-check-mode-drift-tdd.md) | Modo `--check`: drift WARN + exit 0 (TDD) |
| 23 | **T-7** | [ST-7-1](T-7/ST-7-1-backfill-testedwith-annotations.md) | Backfill `testedWith` nas annotations (PR de teste) |
| 24 | **T-8** ⚠️ | [ST-8-1](T-8/ST-8-1-build-binary-and-fetch-tags.md) | Build do binário + `git fetch --tags --force` |
| 25 | T-8 ⚠️ | [ST-8-2](T-8/ST-8-2-writeback-step-2B-skip-ci-actor-guard.md) | Step 2B: commit GPG + `[skip ci]` + guard + rebase |
| 26 | T-8 ⚠️ | [ST-8-3](T-8/ST-8-3-check-warning-in-standard-workflow.md) | `--check` warning no PR + trigger path |
| 27 | T-8 ⚠️ | [ST-8-4](T-8/ST-8-4-pr-title-scope-allowlist.md) | Scope permitido no `pr-title.yml` |
| 28 | T-8 ⚠️ | [ST-8-5](T-8/ST-8-5-validate-writeback-no-real-push.md) | **Validar write-back SEM push real (§10 passo 4)** |
| 29 | T-8 ⚠️ | [ST-8-6](T-8/ST-8-6-verify-no-ci-loop-on-bot-push.md) | Comprovar zero re-trigger (3 camadas anti-loop) |
| ∥ | **T-9** | [ST-9-1](T-9/ST-9-1-document-annotation-contract.md) | Documentar contrato da annotation (após T-2) |

⚠️ = tarefa de **ALTO risco** (T-3 corretude da janela; T-5 corrupção do README; T-8 loop de CI / commit unverified). São as que mais precisam do gate §10.

---

## Paralelização
- **T-2** e **T-3** rodam em paralelo após **T-1**.
- **T-4** e **T-5** rodam em paralelo após **T-2**+**T-3**.
- **T-9** roda a qualquer momento após **T-2** estabilizar a gramática.
- **T-7** idealmente antes de **T-8** (para o 1º commit automático já nascer populado).

## Convenções aplicadas em todas as subtasks
- **TDD:** cada subtask de código tem passo RED (teste que falha, com saída capturada) → GREEN (código mínimo completo) → REFACTOR quando aplicável.
- **Código completo:** sem `...`, sem TODO, sem "adicione imports necessários" implícito — os imports estão explícitos.
- **Testável:** lógica pura extraída de `main` (funções `chartDirectories`, `parseCompatAnnotation`, `resolveWindow`, `renderCompatTable`, `ensureCompatBlock`, `run`), tabelas `table-driven`, golden-files sob `testdata/`.
- **Verificação copiável + saída esperada + rollback** em cada arquivo.
- **Sem libs além de** `yaml.v3` + `Masterminds/semver/v3`. Go **1.21**.
