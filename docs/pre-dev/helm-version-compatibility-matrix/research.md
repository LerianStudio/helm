# Research — Helm Version Compatibility Matrix (Gate 0)

| | |
|---|---|
| **Date** | 2026-07-21 |
| **Feature** | helm-version-compatibility-matrix |
| **Research mode** | modification (extending existing Go tooling + release pipeline) |
| **Agents** | repo-research-analyst (primary), best-practices-researcher, framework-docs-researcher |
| **Repo** | `/home/gauchito/lerian/helm` (github.com/LerianStudio/helm) |

---

## Executive Summary

O repo já tem **toda a fundação** para gerar a matriz de compatibilidade: um módulo Go em `.github/scripts/` que itera charts e parseia `Chart.yaml` (com precedente exato de leitura de annotation `lerian.studio/chart-type`), uma lib compartilhada `tableutil` que já edita as tabelas do README de forma segura, e um pipeline de release que já commita o README de volta via `@semantic-release/git` + push-bot GPG-assinado. A implementação é **extensão**, não greenfield. Três descobertas mudam o desenho inicial (ver "Surpresas"). Não existe padrão de mercado para "compatibility matrix declarativa em Helm" — vamos **definir convenção**, ancorada em Artifact Hub (shape da annotation) + endoflife.date (schema do JSON) + terraform-docs (markers no README).

---

## SURPRESAS vs. o plano inicial (ler primeiro)

1. **A tabela do README NÃO é gerada pelo validador.** É gerada por duas ferramentas Go irmãs — `update-chart-version-readme` (release-time) e `update-readme-matrix` (dispatch) — que usam a lib `tableutil`. Consequência: o gerador de compatibilidade encaixa melhor como **nova ferramenta Go irmã** (`generate-compatibility` ou similar), espelhando `generate-values-schemas`, e **não** como flag do validador.

2. **Tags git locais estão DESATUALIZADAS vs. Chart.yaml.** Ex.: Chart.yaml diz midaz `8.6.0`, mas a tag mais alta neste clone é `midaz-v8.2.0`. A janela N..N-3 derivada de tags precisa **buscar tags no CI** (`git fetch --tags`) e/ou reconciliar com o `version` do Chart.yaml. **Decisão pendente para o TRD.** Sem isso, a janela sai errada.

3. **App-token DISPARA CI** (diferente do `GITHUB_TOKEN`). O push do bot pode re-disparar o próprio workflow. O repo já se defende com **3 camadas** (`paths-ignore` + `[skip ci]` no commit + guard `github.actor != '...push-bot[bot]'`). O gerador DEVE usar as 3. Bom: `docs/**` e `README.md` já estão em `paths-ignore` do release.yml, então escrever nesses caminhos não re-dispara.

---

## Codebase Research (estado atual — file:line)

### Módulo Go — `.github/scripts/`
Um único `go.mod` (`go 1.21`; deps: `gopkg.in/yaml.v3 v3.0.1`, `golang.org/x/text v0.21.0`; **sem lib semver**). Quatro `package main` + uma lib:

| Path | Papel |
|---|---|
| `.github/scripts/tableutil/tableutil.go` | Lib compartilhada: parser/formatter das tabelas do README |
| `.github/scripts/validate-helm-charts/main.go` | Validador de contrato + render gate (1581 linhas) |
| `.github/scripts/update-chart-version-readme/main.go` | Escreve chart version + app versions no README (release-time) |
| `.github/scripts/update-readme-matrix/main.go` | Escreve 1 componente no README (fluxo dispatch) |
| `.github/scripts/generate-values-schemas/main.go` | Gera `values.schema.json` por chart — **template estrutural pro nosso gerador** |

**Pontos de extensão concretos:**
- Iterar charts: `chartDirectories(root)` em `validate-helm-charts/main.go:292-307` (enumera dirs de `charts/`, não glob).
- Parse Chart.yaml: struct `chartYAML` em `main.go:66-70` — **hoje NÃO lê `version`/`appVersion`**, só `type`, `annotations`, `dependencies`. Novo gerador estende ou define struct própria.
- Precedente de leitura de annotation: `chartTypeAnnotation = "lerian.studio/chart-type"` em `main.go:21`, lido via `chart.Annotations[...]` em `main.go:244`. **Mesmo padrão para `lerian.studio/compatibility`.**
- Precedente de geração de arquivo determinístico: `generate-values-schemas/main.go` inteiro, e `writeRenderInventory` em `main.go:1474-1488` (strings.Builder → `os.MkdirAll` + `os.WriteFile` 0644).
- Erros vs warnings: tudo é `violation{Chart,Rule,Path,Reason}` (`main.go:78-83`), `newViolation()` em `main.go:965`, impresso por `printViolations` `main.go:1010`. Exit 1 em `--strict`.

### `tableutil` — motor das tabelas do README (reusar exatamente)
`tableutil/tableutil.go`: `ParseTableForChart(lines, chartName)` `:71-166` — normaliza nome (`TrimSuffix "-helm"`, hífens→espaços), acha `### <Name>`, acha a tabela, para no `-----------------` ou próximo `### `. `FormatTable` `:169-196` re-emite com separador `:---:`. **Detecção de fronteira depende do header literal `| Chart Version |` e da linha `-----------------`.**

### Workflows — `.github/workflows/`
- **release.yml** — gatilho push em `main`/`develop`, `paths-ignore` inclui `README.md`, `**/CHANGELOG.md`, `.github/workflows/**`, `**/docs/**` (`:8-14`). Detecta charts alterados via `LerianStudio/github-actions-changed-paths@main` (`:22-41`). **Padrão de write-back (SEGUIR):** `@semantic-release/git` com `assets=[Chart.yaml, README.md]` (`:158`) + `prepareCmd = update-chart-version-readme-bin` (`:156`); tag format `$CHART_NAME-v${version}` (`:154`). Bot `lerian-studio-midaz-push-bot[bot]`, token via `actions/create-github-app-token@v1` (`:54-58`), commit GPG-assinado (`:124-134`). Guard anti-loop `github.actor != '...push-bot[bot]'` (`:23`).
- **helm-chart-standard.yml** — PR-time, `permissions: contents: read` (não commita), roda `--strict` (`:41`) e `--render-gate`. Gatilho em `charts/**` + `.github/scripts/validate-helm-charts/**`. Um check v1 não-bloqueante entra aqui MAS não pode emitir violação `--strict` (senão falha CI).
- **helm-upgrade-doc.yml** — só chama shared-workflow externo `@v1.29.0` (lógica de commit não é inspecionável localmente). Gatilho tag `'**-v[0-9]*'`.
- Outros: app-sync (dispatch update), gptchangelog (AI changelog em tag), pr-title (Conventional Commits, `requireScope: true` — PR nova precisa scope permitido), pr-sizing (label de tamanho).

### README.md — formato exato
`### <Name>` → prosa → `#### Application Version Mapping` → `| Chart Version | <Comp> Version | ... |` → linhas → `-----------------`. **Colunas variam 2–6** (BR Pix Indirect BTG tem 6; maioria tem 2). Boundaries irregulares: Matcher e Plugin BC Correios **não têm** o separador final; Fees e Pix Indirect BTG têm linha em branco antes. **20 seções no README vs 21 dirs de chart** — `br-spi` existe em `charts/` mas NÃO tem seção no README. Gerador deve ser **schema-driven por chart**, respeitar boundaries irregulares, e lidar com chart sem seção.

### Inventário de annotations (backfill target)
**Nenhum chart tem `lerian.studio/compatibility` hoje** (grep zero). Todos os 21 têm exatamente `lerian.studio/chart-type`. Versões atuais e chart-type por chart estão tabelados no relatório do agente (midaz 8.6.0/multi-component, reporter 3.1.1, fees 7.2.0, etc.). `go-boilerplate-ddd` tem `deprecated: true`. Charts sem tags git ainda: `br-spi`, `br-sisbajud`, `notifications` → gerador deve tratar "<4 minors" e "0 tags".

### Tags git — formato confirmado
`<chart-dir>-v<semver>` (ex: `midaz-v8.2.0`). Corroborado por release.yml `:154`, helm-upgrade-doc gatilho, e release-notification.yml `:76` (`git tag -l "${CHART}-v*" --sort=-v:refname | head -1`). **Filtrar com `<dir>-v*`** (o `-v` desambigua `plugin-br-bank-transfer` de `...-jd`, e `otel-collector` de `otel-collector-lerian`). Tags de charts removidos existem (plugin-crm, etc.) — pular. **Staleness tag↔Chart.yaml é o risco #1** (ver Surpresa 2).

### `docs/helm-chart-standard.md` — contrato existente
Exige `annotations.lerian.studio/chart-type ∈ {single-service, multi-component, dependency-wrapper}`. **Não proíbe** annotations adicionais → `lerian.studio/compatibility` é compatível com o contrato, mas o doc precisaria de subseção nova pra formalizar. Baseline de migração deve ficar vazio; "CI usa strict mode" → check v1 não pode virar violação strict.

### Knowledge base — NEGATIVO
Não existe `docs/solutions/` nem qualquer KB. `docs/` só tem `helm-chart-standard.md`. Sem solução prévia de versionamento/compatibilidade.

---

## Best Practices Research (URLs)

- **Annotation shape:** Helm permite annotations free-form (`map[string]string`); valores multi-linha são **string com block scalar `|`** (não nesting nativo). Precedente: `artifacthub.io/*` (`changes`, `prerelease`, `containsSecurityUpdates`, `links`). Reusar chaves Artifact Hub onde a semântica bate. https://artifacthub.io/docs/topics/annotations/helm/ · https://helm.sh/docs/topics/charts/
- **Ranges semver:** Masterminds/semver — `>=8.4.0 <9.0.0` válido (space/vírgula=AND, `||`=OR, `~`/`^`/wildcards). **Trap:** constraint ignora pre-releases por padrão; `^0.x` só tolera patch. https://github.com/Masterminds/semver
- **Support matrix legível:** modelar no `endoflife.date` product-schema (linha por ciclo minor, `eol`/`eoas` como união bool-ou-data). Frase de política estilo Kubernetes "N-2" (nós: "as 4 minors mais recentes: N, N-1, N-2, N-3"). Grid X-vs-Y estilo Cilium. https://github.com/endoflife-date/endoflife.date/blob/master/product-schema.json · https://kubernetes.io/releases/version-skew-policy · https://docs.cilium.io/en/stable/network/kubernetes/compatibility/
- **README markers:** padrão terraform-docs `inject` (`<!-- BEGIN_X -->`/`<!-- END_X -->`) — só substitui entre markers, idempotente, diff limpo, tem "check mode" pra falhar em drift. https://terraform-docs.io/reference/markdown/
- **JSON artifact:** `schemaVersion` monotônico distinto de `$schema`. https://offlinetools.org/a/json-formatter/schema-versioning-for-json-configuration-files
- **Anti-patterns:** `sort -V` erra pre-release (segregar antes); nesting YAML nativo em annotation (usar block scalar); editar dentro dos markers; caret em 0.x.

---

## Framework Docs Research (versões concretas)

- **Go:** módulo é `go 1.21` (piso duro). Não adotar lib que exija ≥1.22.
- **YAML:** manter `gopkg.in/yaml.v3 v3.0.1` (já usado). Annotation-YAML-embutido = **two-step unmarshal** (parse outer → pega string → `yaml.Unmarshal([]byte(raw), &struct)`). Preservar comentários/ordem → `yaml.Node`; pra read-and-classify, `map[string]string` basta.
- **SemVer:** adicionar `github.com/Masterminds/semver/v3` **v3.2.1** (piso go 1.18; exatamente o que Helm 3.14.4 pina; v3.5.0 exige go 1.26 — NÃO usar). `semver.NewVersion`, `semver.Collection` (sort), `semver.NewConstraint(...).Check(v)`. Agrupar por minor via `fmt.Sprintf("%d.%d", v.Major(), v.Minor())`. Pre-release inclusion em constraint só v3.3.0+ → tratar grouping de pre-release manualmente no Go.
- **Helm SDK (`helm.sh/helm/v3`):** existe (`chart.Metadata`, `chartutil.LoadChartfile`) mas é **overkill** (árvore transitiva enorme, tags `json:`). Manter parse yaml.v3 direto.
- **Commit-back (Actions):** `actions/create-github-app-token@v1` (manter pin) → checkout com o token → commit GPG + `[skip ci]`. **App-token dispara CI** → usar as 3 camadas anti-loop. `fetch-depth: 0` obrigatório pra enxergar tags; `git fetch --tags --force origin` no topo do step pra evitar drift local.

---

## Synthesis — para o PRD/TRD

### Padrões a seguir (com âncora)
- Nova ferramenta Go irmã `generate-compatibility`, espelhando `generate-values-schemas` (invocada com `--root ../..`, gera arquivos determinísticos). NÃO estender o validador.
- Reusar `tableutil` para editar o README; usar markers `<!-- BEGIN COMPAT:<chart> -->`/`<!-- END COMPAT:<chart> -->` estilo terraform-docs.
- Annotation `lerian.studio/compatibility` como string YAML (block scalar), com `requires` (semver range, validado) e `testedWith` (informativo). Reusar chaves Artifact Hub onde couber.
- JSON em `docs/compatibility.json` com `schemaVersion: 1`, modelado em endoflife.date.
- Write-back via padrão release.yml (`@semantic-release/git` assets ou step dedicado com as 3 camadas anti-loop).
- Adicionar `Masterminds/semver/v3 v3.2.1` ao go.mod.

### Constraints
- Go 1.21 é piso duro.
- v1 não-bloqueante: check só em dado malformado; NÃO emitir violação `--strict`.
- Boundaries do README irregulares (2–6 colunas, separador ausente em 2 seções, br-spi sem seção).
- Charts sem tags / <4 minors precisam degradar graciosamente.
- PR nova precisa scope permitido em pr-title.yml.
- `docs/helm-chart-standard.md` precisa de subseção formalizando a nova annotation.

### Open questions — RESOLVIDAS (decisão do usuário, 2026-07-21)
1. **Fonte da janela N..N-3:** ✅ **`Chart.yaml.version` = N (autoridade); tags git = histórico N-1..N-3.** Elimina o risco de tags stale/não-fetchadas (Surpresa 2 resolvida). CI ainda faz `git fetch --tags` pra preencher o histórico, mas o "N atual" nunca depende disso.
2. Quando um chart tem `<4` minors publicadas: ✅ mostrar só as linhas que existem (parcial), degradar graciosamente.
3. **`docs/compatibility.json`:** ✅ **commitado em `docs/`** (fora do paths-ignore trigger; cliente/console fazem GET no raw). Sem infra nova.
4. **Backfill dos `requires`:** ✅ **v1 preenche só `testedWith` (derivável do release atual); `requires` fica OPCIONAL/vazio** até cada time de produto preencher. Destrava o v1 sem esperar input humano de ~7 times.
5. Check de drift (terraform-docs "check mode"): entra no v1 como **warning** em helm-chart-standard.yml (não-bloqueante); gate bloqueante fica pra fase futura.
