# API / Contract Design — Matriz de Compatibilidade (v1)

| | |
|---|---|
| gate | 4 — API/Contract Design |
| date | 2026-07-22 |
| confidence | 87 / 100 |
| refs | [trd.md](trd.md) · [prd.md](prd.md) · [feature-map.md](feature-map.md) · [research.md](research.md) |

> **Nota:** esta feature não expõe API HTTP. As duas interfaces são: **(I) o contrato declarativo da annotation** `lerian.studio/compatibility` (o que o **dev escreve**) e **(II) o contrato CLI** da ferramenta `generate-compatibility` (o que o **CI executa**). O `compatibility.json` (o que **cliente/ferramenta consomem**) é contrato de dados e vai no Gate 5 (Data Model). Todos os três são versionados.

---

## I. Contrato Declarativo — annotation `lerian.studio/compatibility`

### I.1 Localização e forma
- Vive em `Chart.yaml` → `annotations["lerian.studio/compatibility"]`.
- É uma **string** cujo conteúdo é um **documento YAML embutido** (block scalar `|`). Não é nesting YAML nativo (Helm exige annotations = `map[string]string`).
- **Ausência é válida.** Chart sem a annotation → tratado como "sem compatibilidade declarada" (só janela de suporte derivada; sem coluna "Requires").

### I.2 Gramática (v1)
```
compatibility   := requires? testedWith?
requires        := "requires:"    mapping<productKey, semverRange>     # OPCIONAL no v1 (dev declara)
testedWith      := "testedWith:"  mapping<productKey, exactVersion>    # ACEITO p/ forward-compat, mas NÃO usado no v1
                                                                       # (removido do v1; volta na v2 via E2E — ver BACKLOG)
productKey      := nome do chart-alvo tal como publicado (ex.: "midaz-helm", "plugin-access-manager")
semverRange     := constraint Masterminds/semver  (ex.: ">=8.4.0 <9.0.0", "~8.4", "^8.4.0", "8.x || 9.x")
exactVersion    := versão semver exata (ex.: "8.6.0", "1.2.1-beta.11")
```

### I.3 Regras de validação
| # | Regra | Severidade v1 |
|---|---|---|
| V1 | A string deve ser YAML válido | WARN (não bloqueia) |
| V2 | Só as chaves `requires` e `testedWith` são reconhecidas; outras → ignoradas com aviso | WARN |
| V3 | Cada `productKey` em `requires`/`testedWith` deve corresponder a um chart existente no repo | WARN |
| V4 | Cada valor de `requires` deve ser um constraint semver Masterminds parseável | WARN |
| V5 | Cada valor de `testedWith` deve ser versão semver exata | WARN |
| V6 | `requires` pode ser omitido (v1); `testedWith` é esperado (mas ausência não bloqueia) | INFO |

> **Fase futura:** V1–V5 podem ser promovidas a ERRO (bloqueante) quando o gate for ligado. No v1, **tudo é WARN/INFO e o processo continua** (ADR-4).

### I.4 Exemplos

**Válido — completo:**
```yaml
annotations:
  lerian.studio/chart-type: multi-component
  lerian.studio/compatibility: |
    requires:
      midaz-helm: ">=8.4.0 <9.0.0"
    testedWith:
      midaz-helm: "8.6.0"
```

**Válido — só testedWith (o caso típico do v1 pós-backfill):**
```yaml
  lerian.studio/compatibility: |
    testedWith:
      midaz-helm: "8.6.0"
```

**Válido — ausente** (chart base, ex.: midaz; ou chart standalone, ex.: matcher): sem a annotation.

**Inválido → WARN (V4, range não parseável), processo segue:**
```yaml
  lerian.studio/compatibility: |
    requires:
      midaz-helm: "maior que 8"     # não é constraint semver
```

**Inválido → WARN (V3, produto inexistente):**
```yaml
  lerian.studio/compatibility: |
    requires:
      midaz-ledger: ">=8.0.0"       # não existe chart "midaz-ledger"
```

**Inválido → WARN (V1, YAML quebrado):**
```yaml
  lerian.studio/compatibility: |
    requires:
      midaz-helm ">=8.4.0"          # falta os dois-pontos
```

### I.5 Versionamento da annotation
- v1 tem gramática fixa (`requires`/`testedWith`). Chaves novas futuras (ex.: `supportedSince`, `incompatibleWith`) entram como **aditivas e opcionais** — chaves desconhecidas são ignoradas com WARN (V2), garantindo compat retroativa.
- Formalizada em `docs/helm-chart-standard.md` (subseção nova).

---

## II. Contrato CLI — `generate-compatibility`

### II.1 Operações (modos)
Ferramenta batch determinística. Duas operações mutuamente exclusivas, selecionadas por flag.

#### Operação: WRITE (default)
- **Propósito:** gerar/atualizar as saídas (bloco COMPAT no README de cada chart afetado + `docs/compatibility.json`).
- **Idempotência:** rodar 2× sobre o mesmo estado → mesmos bytes. Reescreve integralmente o conteúdo entre markers; nunca faz append.

| Parâmetro | Tipo | Obrig. | Default | Descrição |
|---|---|---|---|---|
| `--write` | flag | não | ligado | Modo escrita (implícito se nenhum modo dado) |
| `--root` | caminho | não | `../..` | Raiz do repo (espelha as ferramentas irmãs) |
| `--chart` | string | não | (todos) | Restringe a geração do README a um chart; o JSON é **sempre** regenerado por completo (determinismo) |
| `--output` | caminho | não | `docs/compatibility.json` | Destino do artefato de máquina |

**Saída (sucesso):** arquivos escritos no disco. `stdout`: resumo por chart (`updated`/`unchanged`/`created-section`). Exit **0**.

#### Operação: CHECK (drift)
- **Propósito:** detectar desatualização sem escrever. Gera em memória, compara com o disco.
- **Uso:** PR-time em `helm-chart-standard.yml`.

| Parâmetro | Tipo | Obrig. | Default | Descrição |
|---|---|---|---|---|
| `--check` | flag | sim (p/ este modo) | — | Modo verificação; não escreve nada |
| `--root` | caminho | não | `../..` | idem |

**Saída (v1):** se em dia → `stdout` "ok", exit **0**. Se drift → `stderr` `WARN: <chart> compatibility block is stale` **+ exit 0** (não bloqueia no v1). *(Fase futura: exit 1.)*

### II.2 Contrato de exit codes
| Código | Significado (v1) |
|---|---|
| 0 | Sucesso — inclui casos com WARN (dado malformado, produto inexistente, drift) |
| 1 | Falha **operacional** apenas (não conteúdo, não uso): `--root` inexistente, sem permissão de escrita, README ilegível |
| 2 | **Uso incorreto**: flags conflitantes (`--write` + `--check`), flag inválida/malformada, `--chart` inexistente |

> Princípio v1: **problema de dado do usuário = WARN + exit 0** (não trava CI). **Problema operacional = exit 1. Uso incorreto = exit 2.** (flag inválida é uso → exit 2, não 1.)

### II.3 Contrato de mensagens (stderr)
Formato estável, uma linha por ocorrência, prefixo de severidade:
```
WARN  <chart>: <regra> — <detalhe>        # ex.: WARN plugin-fees: V4 — requires[midaz-helm] range inválido ">2"
INFO  <chart>: <detalhe>                   # ex.: INFO br-spi: nenhuma tag publicada; janela = só N (Chart.yaml)
ERROR <detalhe>                            # só para exit 1/2
```
- Prefixos (`WARN`/`INFO`/`ERROR`) são contrato estável (parseáveis por CI/log).
- `stdout` = resultado da operação (resumo write / "ok"|drift do check). `stderr` = diagnósticos. Separação estrita.

### II.4 Comportamento determinístico (garantias)
- Ordem de charts, de linhas de versão e de chaves no JSON é **estável** (ordenação definida, não depende de iteração de mapa).
- Sem acesso de rede além das tags git já presentes no checkout.
- `N` sempre de `Chart.yaml.version`; `N-1..N-3` das tags. Fetch incompleto → janela parcial + INFO, nunca erro (NFR-3, FR-7).

### II.5 Versionamento do CLI
- Flags v1 são um contrato aditivo: flags novas futuras não removem/renomeiam as existentes.
- `--check` promover a bloqueante (exit 1) é **mudança de comportamento** reservada para uma major da feature, anunciada.

---

## III. Interações entre contratos (fluxo)
```
Dev escreve annotation (Contrato I)
   └─► release/PR executa generate-compatibility (Contrato II)
          ├─ WRITE → README (bloco entre markers) + docs/compatibility.json (Gate 5)
          └─ CHECK → WARN de drift (exit 0 v1)
                 └─► Cliente/ferramenta lê docs/compatibility.json (Contrato de dados — Gate 5)
```

---

## IV. Testing Contracts
- **Annotation (I):** casos por regra V1–V6 (válido completo, só testedWith, ausente, YAML quebrado, range inválido, produto inexistente, chave desconhecida) → asserção de severidade e exit 0.
- **CLI (II):** `--write` idempotente (2× = mesmo byte); `--check` detecta drift e retorna exit 0 + WARN; flags conflitantes → exit 2; `--root` inválido → exit 1; `--chart X` só toca o bloco de X.
- Contrato de mensagem: golden-file dos prefixos WARN/INFO.

---

## Gate 4 — Validação
| Categoria | Status |
|---|---|
| Todas as interfaces com contrato (annotation + CLI; dados no Gate 5) | ✅ |
| Operações com propósito claro e nomes consistentes (WRITE/CHECK) | ✅ |
| Inputs tipados, obrigatórios vs opcionais explícitos | ✅ |
| Erros identificados + severidade + exit codes | ✅ (WARN/INFO/ERROR + 0/1/2) |
| Idempotência documentada | ✅ (II.1, II.4) |
| Validação explícita (V1–V6) com exemplos válidos/inválidos | ✅ |
| Versionamento dos contratos definido | ✅ (I.5, II.5) |
| Backward-compat (aditivo; promoção a bloqueante = major) | ✅ |

**Resultado: ✅ PASS → Gate 5 (Data Model)**
