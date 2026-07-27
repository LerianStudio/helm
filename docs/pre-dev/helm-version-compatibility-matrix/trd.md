# TRD — Matriz de Compatibilidade de Versões dos Charts (v1)

## Metadata

| Campo | Valor |
|---|---|
| feature | helm-version-compatibility-matrix |
| gate | 3 — TRD |
| date | 2026-07-22 |
| deployment.model | CI/CD tooling (build-time; **não** é runtime/serviço) |
| tech_stack.primary | Go (CLI/ferramental) |
| tech_stack.standards_loaded | golang.md, devops.md |
| project_rules | `docs/PROJECT_RULES.md` (criado no Gate 6 — mínimo, escopado ao ferramental; repo de charts, não serviço). |
| confidence | 86 / 100 (padrão existente no repo; complexidade moderada; risco baixo e mitigado) |

> **Nota sobre abstração de tecnologia:** o gate TRD normalmente exige abstrair nomes de produto. Aqui a feature **é ferramental de build de um repositório concreto** — o "produto" é o próprio repo `LerianStudio/helm`, e o stack (Go, a lib `tableutil`, os workflows, a lib semver) já foi decidido com o usuário e ancorado no `research.md`. Abstrair "Go" para "linguagem compilada" seria teatro e prejudicaria a execução. Portanto este TRD **nomeia** as ferramentas do repo, mas mantém a disciplina do gate onde ela agrega: fronteiras de componente, contratos, ADRs, quality attributes e riscos. As **versões exatas** de dependências novas são formalizadas no Gate 6 (Dependency Map).

Referências: [research.md](research.md) · [prd.md](prd.md) · [feature-map.md](feature-map.md)

---

## 1. Estilo Arquitetural

**Ferramenta CLI determinística única (batch generator), no modelo das ferramentas irmãs já existentes em `.github/scripts/`.** Espelha `generate-values-schemas/main.go`: invocada com `--root ../..`, lê o estado do repo, escreve arquivos determinísticos, sem estado próprio nem rede (exceto tags git, já presentes no checkout).

**Decisão-chave:** **não** estender `validate-helm-charts`. O research (Surpresa 1) mostrou que a tabela do README é produzida por ferramentas separadas (`update-chart-version-readme` + lib `tableutil`), não pelo validador. Portanto a nova capacidade vira uma **ferramenta irmã** — mantém responsabilidade única e não acopla geração a validação.

---

## 2. Componentes (fronteiras e responsabilidades)

Novo diretório: `.github/scripts/generate-compatibility/` (`package main`), + reuso de `tableutil`. Componentes lógicos internos (mapeiam os domínios A→B→C→D do feature-map):

### C-1 — Chart Reader (Domínio A)
- **Responsabilidade:** iterar charts e ler o estado declarado.
- **Entrada:** `--root`. Itera via helper equivalente a `chartDirectories()` (validate-helm-charts/main.go:292-307).
- **Parse:** `gopkg.in/yaml.v3` (já no módulo). Struct própria lê `version`, `appVersion`, `annotations`, `dependencies`. O valor de `annotations["lerian.studio/compatibility"]` é **string YAML embutida** → **two-step unmarshal** (parse externo → pega string → `yaml.Unmarshal([]byte(raw), &compat)`).
- **Saída:** `ChartState{ Name, Dir, Version(=N), AppVersion, Compat{requires, testedWith}, Deps }`.
- **Owns:** interpretação do Chart.yaml. **Provides:** estado normalizado para C-2/C-3.

### C-2 — Support Window Resolver (Domínio B)
- **Responsabilidade:** classificar cada versão em Full/Security/Extended×2/EOL.
- **Regra do N (decisão crítica):** `N = ChartState.Version` (do Chart.yaml, **autoridade absoluta**). `N-1..N-3` = as 3 minors distintas imediatamente inferiores, derivadas das **tags git** `<dir>-v<semver>` (filtro `<dir>-v*`).
- **Processamento semver:** `Masterminds/semver/v3`. Segregar pre-releases (`-beta.N`) **antes** de computar minors; agrupar por `Major().Minor()`; ordenar via `semver.Collection`; pegar as top-4 minors distintas ≤ N. `requires`/ranges avaliados com `NewConstraint().Check()`.
- **Degradação (FR-7):** `<4` minors → só as que existem; `0` tags → só a linha N (do Chart.yaml). Fetch de tags stale **nunca** altera N (NFR-3).
- **Owns:** a política N..N-3. **Consumes:** C-1 + tags. **Provides:** `[]VersionRow{ version, minorCycle, tier, isEOL }`.

### C-3 — Renderers (Domínio C)
- **C-3a Markdown/README:** reusa `tableutil.ParseTableForChart`/`FormatTable`. Escreve **entre markers** `<!-- BEGIN COMPAT:<chart> -->` / `<!-- END COMPAT:<chart> -->` (padrão terraform-docs: só toca entre markers, idempotente). Tabela com badge de tier (🟢N 🔵N-1 🟡N-2 🟠N-3 🔴EOL), coluna "Requires &lt;produto&gt;" **só quando** `requires` declarado, EOL como **linha-resumo única**. Respeita boundaries irregulares (2–6 colunas; Matcher/BC Correios sem separador final; `br-spi` sem seção → **pula ou cria seção**, ver ADR-5).
- **C-3b JSON:** escreve `docs/compatibility.json`, `schemaVersion: 1`, modelado em endoflife.date (linha por ciclo minor + campo de suporte). Determinístico (chaves ordenadas), espelha `generate-values-schemas`.
- **Owns:** formato das saídas. **Consumes:** C-1+C-2. **Provides:** artefatos.

### C-4 — Orchestration & Warnings (Domínio D)
- **Modos:** `--write` (padrão, gera) e `--check` (drift: gera em memória, compara com o disco, **exit 0 + warning** se divergir — não falha no v1). Flags espelham as irmãs (`--root`, `--charts`, `--output` p/ JSON).
- **Warnings (FR-6, não-bloqueante):** annotation malformada, `requires` apontando produto/range inexistente, drift. Emitidos em stderr como `WARN`, **exit 0** no v1. Nunca vira violação `--strict` do validador.
- **Owns:** invocação e sinalização.

---

## 3. Fluxos de Dados

**Geração (write) — no release:**
```
release.yml (chart X publicado)
  → git fetch --tags --force            [garante histórico p/ N-1..N-3]
  → generate-compatibility --write --charts X
      C-1 lê Chart.yaml de X (+ N = version)
      C-2 resolve janela (N do Chart.yaml, N-1..N-3 das tags)
      C-3a reescreve bloco COMPAT:X no README.md (via tableutil, entre markers)
      C-3b regenera docs/compatibility.json (todos os charts; determinístico)
  → semantic-release commita [README.md, docs/compatibility.json] no release commit
      (assets do @semantic-release/git; commit GPG; msg com [skip ci])
```

**Verificação (check) — no PR:**
```
helm-chart-standard.yml (PR toca charts/**)
  → generate-compatibility --check
      compara saída esperada vs. disco → WARN em drift (exit 0 no v1)
```

---

## 4. Contrato da Annotation (interface pública — data model detalhado no Gate 5)

`Chart.yaml`:
```yaml
annotations:
  lerian.studio/chart-type: multi-component        # existente
  lerian.studio/compatibility: |                   # NOVO — string YAML embutida
    requires:            # OPCIONAL no v1 — relação técnica (validada, vira coluna "Requires")
      midaz-helm: ">=8.4.0 <9.0.0"
    testedWith:          # preenchido no v1 (derivável) — informativo
      midaz-helm: "8.6.0"
```
- Chave em reverse-DNS namespaced (segue precedente `lerian.studio/chart-type`; alinhado a Artifact Hub).
- Valores de `requires` são **ranges semver Masterminds** (`>=x <y`, `~`, `^`, `||`).
- Ausência da annotation ou de `requires` é **válida** (v1): chart sem seção "Requires".

---

## 5. Write-back & Loop Prevention (integração CI)

**DECISÃO FINAL: Opção 2A — commit único via `@semantic-release/git`** (revisão posterior à 2B; ver ADR-1b atualizado). Motivo da mudança: a 2B geraria **dois commits** no mesmo release (o do semantic-release + o do step dedicado), com risco real de colisão no push. A 2A elimina isso — a geração pega carona no commit que o release **já faz**.

Como foi implementado em `release.yml`:
- No `prepareCmd` do semantic-release, `generate-compatibility --root . --chart $COMPAT_CHART --write` **substitui** a antiga `update-chart-version-readme` (que fazia um subconjunto — só a versão atual). Nossa ferramenta faz tudo que ela fazia + a matriz.
- `docs/compatibility.json` é adicionado aos `assets` do `@semantic-release/git`, junto de `Chart.yaml` e `README.md` → **um único commit** de release carrega os três.
- Step `git fetch --tags --force` antes, para o histórico N-1..N-3 e as datas Released.
- Commit é o do semantic-release: já **GPG-assinado** (verified) e com `[skip ci]`.

Anti-loop (mantido, agora herdado do mecanismo existente): `paths-ignore` (`README.md`, `**/docs/**`), `[skip ci]` no commit do release, e o guard de actor `github.actor != 'lerian-studio-midaz-push-bot[bot]'`. **Sem segundo commit → sem risco de colisão.**

O `--check` (drift) roda no PR via `helm-chart-standard.yml`, não-bloqueante.

---

## 6. Quality Attributes

| Atributo | Alvo | Como |
|---|---|---|
| Idempotência (NFR-4) | 2 execuções = mesmo byte | markers + saída determinística (chaves/linhas ordenadas) |
| Não-regressão (NFR-2) | 0 corrupção de conteúdo | escrita confinada entre markers via `tableutil`; testes de boundary irregular |
| Confiabilidade do N (NFR-3) | 0 "N errado" | N vem do Chart.yaml, nunca das tags |
| Determinismo | reprodutível offline | sem rede além de tags git locais |
| Performance | trivial | ~21 charts; execução < 1s; não é caminho crítico |
| Sem manutenção manual (NFR-1) | 0 edições manuais | conteúdo entre markers é sempre sobrescrito |

**Testes (golang.md):** table-driven para C-2 (janela: casos 0/1/2/3/4+ minors, pre-releases, tags de charts removidos), C-3a (boundaries irregulares, chart sem seção, markers ausentes), parse de annotation malformada. Determinismo verificado rodando 2×.

---

## 7. ADRs

**ADR-1: Auto-commit por bot vs. padrão Ring "humano commita".**
- Contexto: devops.md do Ring proíbe auto-commit de artefatos gerados (humano roda `make generate` e commita; CI só valida). Mas o repo helm **já opera** com auto-commit via `@semantic-release/git` + push-bot no release.
- Decisão: **seguir o padrão do repo** (auto-commit no release), não o do Ring, para esta feature. (Decisão 1 = A, confirmada pelo usuário.)
- Rationale: a saída depende de `version`/tags que só existem no momento do release; exigir regeneração manual local reintroduz o drift que a feature elimina. O repo já resolveu loop-prevention para esse padrão (3 camadas).
- Consequência: divergência consciente do standard, documentada. O modo `--check` (drift warning no PR) preserva o espírito Ring de "CI detecta desatualização" sem bloquear.

**ADR-1b: Write-back via commit único do semantic-release (2A) — REVISADO de 2B para 2A.**
- Contexto: duas formas de commitar as saídas — somar aos `assets` do semantic-release (2A, ~4 linhas) ou um step próprio pós-release (2B, ~15 linhas).
- Decisão inicial (2B) foi **revertida**: ao implementar, ficou claro que 2B gera **dois commits** no mesmo release (semantic-release + step dedicado) com risco real de colisão no push. Isso pesou mais que o ganho de "separação de responsabilidades".
- **Decisão final: 2A** — `generate-compatibility` roda no `prepareCmd` (substituindo `update-chart-version-readme`) e `docs/compatibility.json` entra nos `assets`. **Um commit só**, o que o release já fazia.
- Rationale: elimina a colisão de dois commits; menos YAML; herda GPG + `[skip ci]` + anti-loop já existentes. A flexibilidade da 2B (gatilhos fora do release) era teórica e sem uso no v1 — reintroduzível depois se necessário.
- Consequência: a geração fica acoplada ao ciclo do semantic-release (aceitável). A ferramenta-irmã `update-chart-version-readme` deixa de ser chamada no release (nossa faz superconjunto).

**ADR-2: Ferramenta irmã, não flag do validador.**
- Contexto: validador ≠ gerador de README (Surpresa 1 do research).
- Decisão: novo `generate-compatibility` no mesmo módulo Go, espelhando `generate-values-schemas`.
- Consequência: responsabilidade única; validador segue `--strict`-puro; gerador nunca falha CI no v1.

**ADR-3: N do Chart.yaml, histórico das tags.**
- Contexto: tags locais estão atrás do Chart.yaml (Surpresa 2).
- Decisão: N = `Chart.yaml.version`; N-1..N-3 = tags.
- Consequência: janela sempre tem N correto mesmo com fetch incompleto; robustez > pureza.

**ADR-4: v1 avisa, não bloqueia.**
- Decisão: warnings em stderr, exit 0; nada entra em `--strict`.
- Consequência: baseline de contrato segue vazio; CI não trava; gate bloqueante é fase futura.

**ADR-5: Charts sem seção no README (ex.: `br-spi`).**
- Contexto: 20 seções README vs 21 dirs.
- Decisão: se não há `### <Nome>`, o gerador **cria** a seção mínima (título + bloco COMPAT entre markers) no lugar canônico; NÃO inventa dados fora dos markers.
- Consequência: cobertura 100% dos produtos ativos (M3) sem editar prosa existente.

---

## 8. Riscos técnicos

| Risco | Mitigação |
|---|---|
| `tableutil` não cobrir todos os layouts irregulares | testes por-chart de boundary antes do backfill; ADR-5 p/ seção ausente |
| Ordenação semver errada em pre-releases | segregar pre-releases antes; lib Masterminds (não `sort -V`) |
| Tag de chart removido poluir janela | filtro `<dir>-v*` + só considerar dirs existentes |
| `git fetch --tags` falhar no CI | N vem do Chart.yaml (ADR-3) → degrada p/ janela parcial, não erro |
| Loop de CI pelo bot | 3 camadas (ADR-1) |

---

## 9. Mudanças fora do código Go

- `docs/helm-chart-standard.md`: **nova subseção** formalizando `lerian.studio/compatibility` (schema, opcionalidade de `requires` no v1). Não altera regras existentes.
- `helm-chart-standard.yml`: adicionar step `generate-compatibility --check` (warning) e o path `.github/scripts/generate-compatibility/**` ao trigger.
- `release.yml`: adicionar binário ao build + `git fetch --tags --force` + **step dedicado pós-release (2B)** que gera e commita (README + `docs/compatibility.json`) reusando token/GPG do job, com as 3 camadas anti-loop e tratamento de 2 commits.
- `pr-title.yml`: garantir scope permitido para os PRs desta entrega (ex.: `charts`/`ci`/`doc`).
- `go.mod`: adicionar `Masterminds/semver/v3` (versão exata no Gate 6).

---

## 10. Estratégia de Teste ANTES do commit real (lembrete do usuário :D)

⚠️ **Regra dura: nada de push "de verdade" sem validar executivamente primeiro.** O maior risco desta feature é o gerador **corromper o README** de todos os charts de uma vez, ou o step de write-back gerar loop/commit unverified. Ordem de validação, do mais barato ao mais arriscado:

1. **Unit (Go, offline):** `go test ./...` no módulo — table-driven para C-2 (janela) e C-3a (boundaries irregulares). Cobre a lógica sem tocar git/CI.
2. **Dry-run local do gerador:** rodar `generate-compatibility --write` num **clone descartável** e inspecionar o `git diff` do README + JSON. Confirmar: (a) só o conteúdo entre markers muda; (b) prosa e separadores irregulares intactos; (c) `br-spi` ganha seção (ADR-5); (d) roda 2× = diff idêntico (idempotência).
3. **Modo `--check`:** rodar contra o repo real e confirmar que aponta drift corretamente **sem escrever nada**.
4. **Write-back (o mais arriscado):** validar o step 2B **sem push real** primeiro —
   - testar o encadeamento "semantic-release commit + nosso commit" num fork/branch de teste ou com `git push --dry-run`;
   - confirmar commit **GPG-verified** (não unverified);
   - confirmar que o `[skip ci]` + guard de actor realmente impedem o re-trigger (observar que o push do bot NÃO dispara novo run).
5. **Backfill:** aplicar `testedWith` nas ~21 annotations em **um PR de teste** e rodar o `helm-chart-standard.yml --check` antes de abrir o PR real.

Só depois de 1–5 verdes é que o fluxo vai para a `main`. (Alinhado a [[feedback_test_changed_artifacts]] e [[feedback_ask_before_push]].)

## Gate 3 — Validação

| Categoria | Status |
|---|---|
| Todos os domínios do feature-map mapeados p/ componentes (A→C-1, B→C-2, C→C-3, D→C-4) | ✅ |
| Fronteiras de componente claras, responsabilidade única | ✅ |
| Contratos definidos (annotation, VersionRow, JSON schemaVersion) | ✅ |
| Data ownership explícito (C-1 dono do Chart.yaml, C-2 dona da política) | ✅ |
| Quality attributes atingíveis com alvos | ✅ |
| Integração CI + loop-prevention endereçada | ✅ |
| ADRs para as 3 surpresas + divergência de standard | ✅ (ADR-1..5) |
| Sem pendências de correctness (N, boundaries, degradação) | ✅ |

**Resultado: ✅ PASS → Gate 4 (API Design)**

> **PAUSA PARA REVISÃO DO USUÁRIO** (conforme opção 2 escolhida). Gates 4–8 são mais mecânicos dado este TRD.
