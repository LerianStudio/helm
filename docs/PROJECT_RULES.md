# PROJECT_RULES — repo `LerianStudio/helm`

> Regras específicas de tecnologia deste repositório. Ring Standards (coding patterns) valem por cima; este arquivo fixa **versões e escolhas locais**. Escopo atual: ferramental de build em `.github/scripts/` (não há serviço de produto neste repo).

## Deployment model
- **Build-time tooling** (CLIs Go executadas em GitHub Actions). Sem runtime de produção, banco, cache, fila, auth ou licenciamento neste repo.

## Tech stack (ferramental `.github/scripts/`)
| Categoria | Escolha | Versão | Constraint / Racional |
|---|---|---|---|
| Linguagem | Go | **1.21** | Piso duro (`go.mod`). Não subir sem bump coordenado de `setup-go`. |
| Parse YAML | `gopkg.in/yaml.v3` | v3.0.1 | Já presente; padrão do módulo. |
| SemVer | `github.com/Masterminds/semver/v3` | **v3.2.1** | Ranges + sort + grouping. **Capado em `<3.4`** enquanto Go=1.21 (v3.4+ sobem piso). Paridade com Helm 3.14.4. |
| Lib interna | `tableutil` | — | Edição das tabelas do README. Reusar, não duplicar. |
| Token CI | `actions/create-github-app-token` | @v1 | Manter pin do repo. |

## Regras de dependência
- Versões **explícitas** (sem `@latest`/ranges soltos). `go.sum` é o cache key de CI.
- Não adotar `helm.sh/helm/v3` no ferramental (árvore transitiva pesada; tags `json:`).
- Novas deps devem ser compatíveis com Go 1.21.

## Licenças
- Apenas permissivas (MIT/Apache-2.0/BSD). Sem GPL. Sem dependência comercial.
