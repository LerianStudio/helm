# Dependency Map — Matriz de Compatibilidade (v1)

| | |
|---|---|
| gate | 6 — Dependency Map |
| date | 2026-07-22 |
| standards_loaded | golang.md, devops.md (Gate 3) |
| project_rules | ver `docs/PROJECT_RULES.md` (mínimo, escopado à ferramenta) |
| confidence | 92 / 100 (stack familiar, versões verificadas, sem CVE, licenças permissivas) |
| refs | [trd.md](trd.md) · [api-design.md](api-design.md) · [data-model.md](data-model.md) · [research.md](research.md) |

> **Escopo:** ferramental de **build-time** (CLI Go + steps de CI). **Sem** runtime de produção, banco, cache, fila, rede, auth ou licenciamento — logo as seções de Auth/License/Cost de infra do gate **não se aplicam** (custo incremental = 0; roda no runner de CI existente).

---

## 1. Runtime / Toolchain

| Item | Versão | Constraint | Justificativa |
|---|---|---|---|
| Go | **1.21** | **piso duro — NÃO subir** | `directive go 1.21` em `.github/scripts/go.mod`. Subir o piso quebraria o módulo e forçaria bump de `actions/setup-go`. Toda dep nova deve ser compatível com 1.21. |
| Módulo Go | `github.com/LerianStudio/helm/.github/scripts` | — | Módulo único que já hospeda as 4 ferramentas irmãs + lib `tableutil`. A nova ferramenta entra aqui. |

## 2. Dependências Go

### 2.1 Reusadas (já no go.mod — sem mudança)
| Pacote | Versão | Uso nesta feature | Licença |
|---|---|---|---|
| `gopkg.in/yaml.v3` | v3.0.1 | Parse do Chart.yaml + two-step unmarshal da annotation (string YAML embutida) | MIT/Apache-2.0 |
| `golang.org/x/text` | v0.21.0 | (indireto, já presente; não usado diretamente) | BSD-3-Clause |
| `tableutil` (interno) | — | Edição segura das tabelas do README entre markers | (repo) |

### 2.2 NOVA dependência a adicionar
| Pacote | Versão | Uso | Licença |
|---|---|---|---|
| **`github.com/Masterminds/semver/v3`** | **v3.2.1** | Ordenar tags (`semver.Collection`), avaliar ranges de `requires` (`NewConstraint().Check`), agrupar por minor (`Major()/Minor()`) | MIT |

**Análise da versão (crítica):**
- **v3.2.1** → `go 1.18` directive. **Compatível com o piso 1.21.** É **exatamente** a versão que Helm 3.14.4 pina → paridade com o ecossistema Helm.
- v3.3.1 → `go 1.21` (também compatível, mas floors exatamente em 1.21). **v3.5.0 (latest) → exige `go 1.26` = PROIBIDO** (forçaria bump do módulo).
- **Decisão:** pinar **v3.2.1**. Não usar `@latest`.
- **Alternativa rejeitada:** `golang.org/x/mod/semver` — só compara strings, **não tem parser de range** (`>=8.4.0 <9.0.0`), inviável para `requires`.
- **Alternativa rejeitada:** `helm.sh/helm/v3` (traria `chart.Metadata`) — **overkill**: árvore transitiva enorme (k8s.io/*, oras, containerd), tags `json:` incompatíveis com o parse yaml.v3 atual. Modelar structs próprias é mais leve.

**Segurança:** Masterminds/semver v3.2.1 — sem CVE conhecido (biblioteca pura, sem I/O/rede). Mantida (usada pelo Helm). Adição ao `go.sum` verificável.

## 3. Dependências de CI (GitHub Actions) — reusadas

| Ação/recurso | Versão/pin | Uso | Nota |
|---|---|---|---|
| `actions/create-github-app-token` | **@v1** (manter pin do repo) | Token do bot p/ o step de write-back (2B) | App-token dispara CI → 3 camadas anti-loop obrigatórias |
| `crazy-max/ghaction-import-gpg` | (já no job) | **Reusar** o GPG já importado — commit verified | NÃO reimportar |
| `actions/setup-go` | (já no repo, go 1.21) | Build da ferramenta | cache key = `.github/scripts/go.sum` |
| `git` (runner) | nativo | `git fetch --tags --force` p/ histórico N-1..N-3 | `fetch-depth: 0` já usado |

## 4. Manifest & Lock
- **Manifest:** `.github/scripts/go.mod` — adicionar `require github.com/Masterminds/semver/v3 v3.2.1`.
- **Lock:** `.github/scripts/go.sum` — atualizado por `go mod tidy`; é o **cache key de CI**.
- **Upgrade policy:** semver/v3 **capado em `<3.4`** enquanto o módulo for `go 1.21` (v3.4+ sobem o piso). Documentar no PROJECT_RULES.

## 5. Licenças (resumo)
| Licença | Pacotes | Ação |
|---|---|---|
| MIT | Masterminds/semver, yaml.v3 | Nenhuma restrição a uso comercial; atribuição já coberta pelo go.sum |
| BSD-3-Clause | golang.org/x/text | idem |
Sem GPL. Sem dependência comercial. Nada a notificar ao jurídico.

## 6. Custo
**Incremental = US$ 0.** Roda no runner de CI que já executa `validate-helm-charts`/`generate-values-schemas`. Sem infra nova, sem serviço gerenciado, sem armazenamento pago (o JSON vive no repo git).

## 7. Mudanças fora de código (recap do TRD §9)
- `pr-title.yml`: garantir scope permitido para os PRs (ex.: `ci`, `charts`, `doc`) — checar allowlist existente antes de abrir PR.
- `docs/helm-chart-standard.md`: subseção nova formalizando a annotation (não é dependência, é contrato/doc).

---

## Gate 6 — Validação
| Categoria | Status |
|---|---|
| Standards carregados (golang.md, devops.md) | ✅ (Gate 3) |
| PROJECT_RULES.md gerado (mínimo, escopado) | ✅ |
| Toda dep com versão explícita (sem @latest) | ✅ (semver v3.2.1 pinado) |
| Sem conflito de versão (compat Go 1.21 verificada) | ✅ |
| Sem CVE crítico/alto | ✅ (semver puro, sem I/O) |
| Licenças compatíveis (MIT/BSD, sem GPL) | ✅ |
| Auth/License libs | N/A (ferramental de build, não serviço) |
| Custo documentado | ✅ (US$ 0 incremental) |
| Todo componente do TRD mapeado a tecnologia | ✅ |

**Resultado: ✅ PASS → Gate 7 (Task Breakdown)**
