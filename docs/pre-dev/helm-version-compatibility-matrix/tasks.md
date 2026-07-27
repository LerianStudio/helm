# Task Breakdown — Matriz de Compatibilidade (v1)

| | |
|---|---|
| gate | 7 — Task Breakdown |
| date | 2026-07-22 |
| confidence | 88 / 100 |
| refs | todos os docs de `docs/pre-dev/helm-version-compatibility-matrix/` + `docs/PROJECT_RULES.md` |

> **Regra transversal (DoD de toda tarefa):** seguir a estratégia de teste do **TRD §10** — nada vai pra `main` sem validação executiva. Risco #1 recorrente: **corromper o README de todos os charts de uma vez**. Toda tarefa que toca geração roda em **clone descartável** antes de qualquer commit real, e é **idempotente** (2× = mesmo byte).

**Caminho crítico:** T-1 → T-2 → T-3 → (T-4 ‖ T-5) → T-6 → T-8. T-7 depende de T-6. T-9 é paralela.

---

## T-1 — Ferramenta gera JSON de versões (esqueleto executável)
- **Deliverable:** binário `generate-compatibility` que roda, lê a versão atual (`Chart.yaml.version`) de todos os charts e emite um `compatibility.json` só com `current` por produto. Demoável: `go run ./generate-compatibility --root ../..` produz JSON válido.
- **Scope inclui:** esqueleto CLI + `go.mod` add `Masterminds/semver/v3 v3.2.1` + iteração de charts (helper estilo `chartDirectories()`) + leitura de `version`. **Exclui:** annotation (T-2), janela (T-3), README (T-5).
- **Success criteria:**
  - `go build ./generate-compatibility` compila com Go 1.21.
  - `go.sum` atualizado; `Masterminds/semver/v3` = **v3.2.1** exato (não v3.4+).
  - Saída: JSON com `schemaVersion:1` + `products{<chart>:{dir,current}}` pra todos os ~21 charts.
  - Determinístico: 2 execuções = bytes idênticos.
- **Value:** técnico — base executável de que tudo depende.
- **Deps:** Requires: —. Blocks: T-2,T-3,T-4.
- **Effort:** S (3 pts, ~2d). **Risco:** baixo. **Teste:** unit (iteração/parse version) + rodar contra o repo real e inspecionar JSON.

## T-2 — Ferramenta entende a annotation de compatibilidade
- **Deliverable:** a ferramenta lê `lerian.studio/compatibility`, parseia `requires`/`testedWith` (two-step unmarshal) e reflete no JSON; annotation ausente/malformada → JSON válido + WARN.
- **Scope inclui:** struct `CompatAnnotation`, two-step unmarshal, regras V1–V6 como WARN, campos `requires`/`testedWith` no JSON. **Exclui:** janela de suporte (T-3), validação bloqueante (backlog TODO-4).
- **Success criteria:**
  - Annotation válida completa → `requires`+`testedWith` no JSON do produto.
  - Só `testedWith` → só ele aparece.
  - Ausente → produto sem esses campos, sem erro.
  - Malformada (YAML quebrado, range inválido, produto inexistente) → **WARN em stderr, exit 0**, JSON dos demais intacto.
- **Value:** cliente/máquina passam a ver compatibilidade cruzada declarada.
- **Deps:** Requires: T-1. Blocks: T-4,T-5.
- **Effort:** M (5 pts, ~3d). **Risco:** médio (parsing frágil) → mitiga com table-driven cobrindo V1–V6.

## T-3 — Ferramenta calcula a janela de suporte N..N-3
- **Deliverable:** para cada produto, `cycles[]` ordenado desc com `cycle`/`latest`/`supported`, onde **N=Chart.yaml.version** e N-1..N-3 das tags git; degradação graciosa.
- **Scope inclui:** derivação de tags (`<dir>-v*`), segregar pre-releases, agrupar por `Major().Minor()`, top-4 minors, `supported=false` p/ N-4+, casos 0/<4 tags. **Exclui:** datas de EOL (backlog TODO-5).
- **Success criteria:**
  - midaz (N=8.6.0) → cycles 8.6(sup)…8.3(sup), 8.2 e anteriores `supported:false`.
  - Chart com 0 tags (br-spi) → só o ciclo N, sem erro (+INFO).
  - Chart com <4 minors → só as existentes.
  - Pre-release (`beta.11`) **não** vira ciclo próprio; ordena corretamente.
  - **N nunca depende das tags** (fetch stale ⇒ janela parcial, nunca N errado).
- **Value:** cliente vê exatamente o que está sob suporte.
- **Deps:** Requires: T-1. Blocks: T-4,T-5.
- **Effort:** M (8 pts, ~4d). **Risco:** médio-alto (semver/pre-release/tags removidas) → table-driven exaustivo é o coração do teste.

## T-4 — `compatibility.json` completo e consumível
- **Deliverable:** JSON final schemaVersion:1 unindo T-2+T-3 (products→cycles com requires/testedWith), **sem `tier`**, determinístico, gravado em `docs/compatibility.json`.
- **Scope inclui:** serialização ordenada, `--output`, exemplo do data-model §B.4 reproduzível. **Exclui:** README (T-5), campos extras do console (backlog TODO-3).
- **Success criteria:**
  - JSON bate com o schema do data-model (B.1–B.3); **sem** campo `tier`.
  - Chaves e arrays em ordem estável; 2× = idêntico.
  - Valida contra um JSON Schema de referência (opcional mas recomendado).
- **Value:** entrega a interface de máquina (US-5) — console/ferramentas podem consumir.
- **Deps:** Requires: T-2,T-3. Blocks: T-8.
- **Effort:** S (3 pts, ~2d). **Risco:** baixo.

## T-5 — README mostra a matriz por produto (o entregável ao cliente)
- **Deliverable:** bloco entre `<!-- BEGIN/END COMPAT:<chart> -->` no README de cada produto, tabela com badge de tier (🟢N…🔴EOL), coluna "Requires" quando declarada, EOL como linha-resumo. **É o valor visível ao cliente (US-1,US-2,US-4).**
- **Scope inclui:** reuso de `tableutil`, markers idempotentes, respeitar boundaries irregulares (2–6 colunas; Matcher/BC Correios sem separador), **ADR-5: criar seção mínima p/ br-spi** (sem seção hoje). **Exclui:** edição de prosa existente.
- **Success criteria:**
  - Só o conteúdo entre markers muda; prosa/separadores intactos (diff review).
  - Todos os ~21 charts (incl. br-spi) têm bloco COMPAT; 0 seções corrompidas.
  - Idempotente (2× = mesmo README).
  - Badges e coluna "Requires" corretos vs. o JSON.
- **Value:** ⭐ o cliente lê e decide migração em segundos.
- **Deps:** Requires: T-2,T-3. Blocks: T-8.
- **Effort:** L (13 pts, ~1-2sem — é o mais arriscado). **Risco:** ALTO (corromper README em massa) → **obrigatório**: testar em clone descartável, golden-files por chart cobrindo os layouts irregulares, review de diff antes de qualquer commit.

## T-6 — Modos de operação e verificação de drift
- **Deliverable:** contrato CLI completo: `--write`(default)/`--check`/`--chart`/`--root`/`--output`, exit codes 0/1/2, mensagens WARN/INFO/ERROR estáveis. `--check` detecta drift sem escrever.
- **Scope inclui:** parsing de flags, `--check` (gera em memória, compara, WARN+exit0), separação stdout/stderr, exit 1 (ambiente) / 2 (uso). **Exclui:** promover `--check` a bloqueante (backlog TODO-4).
- **Success criteria:**
  - `--check` em repo em dia → "ok" exit 0; com drift → WARN exit 0.
  - `--write`+`--check` juntos → exit 2.
  - `--root` inexistente → exit 1.
  - `--chart X` → só toca o bloco de X (JSON regenera inteiro).
- **Value:** CI ganha detecção de drift (espírito Ring) sem bloquear.
- **Deps:** Requires: T-4,T-5. Blocks: T-8. Optional: T-7.
- **Effort:** M (5 pts, ~3d). **Risco:** médio.

## T-7 — Todos os produtos nascem com `testedWith` preenchido (backfill)
- **Deliverable:** as ~21 annotations `lerian.studio/compatibility` recebem `testedWith` derivável do release atual; `requires` fica opcional/vazio (v1).
- **Scope inclui:** preencher só o derivável, num **PR de teste** validado antes do real. **Exclui:** preencher `requires` (backlog TODO-1, via agent Ring no futuro).
- **Success criteria:**
  - 100% dos produtos ativos com `testedWith` (métrica M3).
  - `generate-compatibility --check` verde após o backfill.
  - Cada annotation é YAML válido (V1) e passa V2–V5.
- **Value:** matriz nasce populada no dia 1 (não vazia).
- **Deps:** Requires: T-6. Blocks: —.
- **Effort:** M (5 pts, ~3d). **Risco:** médio (21 edições) → rodar `--check` antes de abrir PR.

## T-8 — Geração automática no release (write-back 2B)
- **Deliverable:** `release.yml` regenera e commita a matriz automaticamente ao publicar um chart; `helm-chart-standard.yml` roda `--check` como warning no PR.
- **Scope inclui:** build do binário, `git fetch --tags --force`, **step dedicado 2B** pós-release (commit GPG reusando infra, `[skip ci]`, guard de actor, tratamento de 2 commits/rebase), add do path ao trigger do standard, scope no pr-title. **Exclui:** gate bloqueante.
- **Success criteria:**
  - Publicar um chart → README+JSON atualizados **automaticamente**, commit **GPG-verified**.
  - Push do bot **NÃO** re-dispara o workflow (3 camadas comprovadas).
  - `--check` aparece como warning no PR, não falha o build.
  - **Validado sem push real primeiro** (TRD §10 passo 4: `--dry-run`, branch de teste).
- **Value:** zero manutenção manual (US-3,US-4; métrica M2).
- **Deps:** Requires: T-6 (e T-7 idealmente antes, p/ 1º commit já populado). Blocks: —.
- **Effort:** M (8 pts, ~4d). **Risco:** ALTO (loop de CI / commit unverified / colisão de commits) → validação sem push real é DoD obrigatório.

## T-9 — Contrato da annotation documentado (paralela)
- **Deliverable:** subseção nova em `docs/helm-chart-standard.md` formalizando `lerian.studio/compatibility` (gramática, opcionalidade de `requires` no v1, exemplos válido/inválido do api-design §I.4).
- **Success criteria:** dev consegue escrever uma annotation válida só lendo a doc; não altera regras existentes do contrato.
- **Value:** dev sabe declarar sem adivinhar (mitiga erro manual até o agent Ring — TODO-1b).
- **Deps:** Requires: T-2 (gramática estável). Blocks: —. **Effort:** S (2 pts, ~1d). **Risco:** baixo.

---

## Sequência de entrega
| Fase | Tarefas | Entrega demoável |
|---|---|---|
| 1 | T-1 | JSON com versões atuais roda |
| 2 | T-2, T-3 (paralelas após T-1) | JSON com compatibilidade + janela de suporte |
| 3 | T-4 ‖ T-5 | JSON final + README visível ao cliente |
| 4 | T-6 | modos --write/--check |
| 5 | T-7 | matriz populada |
| 6 | T-8 | automação no release |
| ∥ | T-9 | doc (a qualquer momento após T-2) |

---

## Gate 7 — Validação
| Categoria | Status |
|---|---|
| Todos os componentes do TRD (C-1..C-4) cobertos | ✅ (T-1..T-6) |
| Toda tarefa entrega software funcionando/demoável | ✅ |
| Nenhuma tarefa > 2 semanas | ✅ (max = T-5 L) |
| Critérios de sucesso testáveis | ✅ |
| Dependências mapeadas + caminho crítico | ✅ |
| Estratégia de teste por tarefa (TRD §10) | ✅ |
| Riscos + mitigação (T-5/T-8 alto risco cedo priorizados) | ✅ |

**Resultado: ✅ PASS → Gate 8 (Subtasks)**
