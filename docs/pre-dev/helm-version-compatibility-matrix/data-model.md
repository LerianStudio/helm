# Data Model — Matriz de Compatibilidade (v1)

| | |
|---|---|
| gate | 5 — Data Model |
| date | 2026-07-22 |
| confidence | 89 / 100 |
| refs | [api-design.md](api-design.md) · [trd.md](trd.md) · [prd.md](prd.md) · [research.md](research.md) |

> **Nota:** não há banco de dados. As "entidades" são: **(A) structs internas** do gerador (transientes, em memória) e **(B) o documento `compatibility.json`** — a interface de dados **pública e versionada** que cliente/console consomem. Não há persistência mutável; o JSON é derivado, idempotente e regenerado por completo a cada execução. Sem lifecycle de update/delete: só "gerado".

---

## 0. DOIS EIXOS INDEPENDENTES (fundamento — decisão do usuário 2026-07-22)

A feature tem **dois conceitos ortogonais** que NÃO devem ser confundidos:

| Eixo | O que responde | Fonte | Vale pra | Coluna README |
|---|---|---|---|---|
| **#1 Suporte de versões** | "quais versões da PRÓPRIA app têm suporte" (N/N-1/N-2/N-3) | `version` + tags git | **TODOS os charts, sempre** | **Support** (sempre presente) |
| **#2 Compatibilidade cruzada** | "com qual versão de OUTRO produto combina" | annotation `requires`/`testedWith` | só charts que dependem de outro | **Requer &lt;produto&gt;** (condicional) |

- **#1 é universal e 100% automático** — dev não mantém nada; atualiza no release (version bump + tags).
- **#2 é opcional e manual (v1)** — só multi-component com dependência real de produto Lerian. `requires` = conhecimento humano.

**Regra de auto-avaliação (usa o `lerian.studio/chart-type` que JÁ existe em todos os 21 charts):**
```
chart-type == single-service   → standalone: NÃO espera #2. Sem coluna Requer. Script NÃO cobra (sem INFO).
chart-type == multi-component
   ou dependency-wrapper        → PODE ter #2. Se não declarar requires → INFO (lembrete suave, não bloqueia).
```
Reusa a etiqueta existente (9 single-service, 11 multi-component, 1 dependency-wrapper) — sem variável nova, intenção auditável, distingue "standalone de propósito" de "esqueceram".

**Coluna do README renomeada:** "Status" → **"Support"** (decisão do usuário).

---

## 1. Vocabulário de Tier (APRESENTAÇÃO — derivado de posição, NÃO fica no JSON)

**Decisão (usuário):** `tier` é conceito **interno/de apresentação**, derivável de posição (N-x). **NÃO é campo do `compatibility.json`.** O JSON é factual (`current` + `cycles` ordenados desc + `supported`); qualquer consumidor deriva o tier pelo **índice do ciclo** (0=N, 1=N-1, 2=N-2, 3=N-3, ≥4/`supported:false`=EOL). Evita dado redundante que pode divergir.

Mapa de posição → apresentação (usado só pelo **renderer do README** e, se quiser, pelo console):

| Posição | Nível (contrato LTS) | Custo | Badge (README) |
|---|---|---|---|
| N (índice 0) | Full Support | Incluído | 🟢 |
| N-1 | Security | Incluído | 🔵 |
| N-2 | Extended | +30% | 🟡 |
| N-3 | Extended | +150% | 🟠 |
| N-4+ / `supported:false` | Legacy / EOL | — | 🔴 |

> `VersionRow.tier` (struct interna A.3) permanece como enum interno pra alimentar o render do README, mas **não é serializado** no JSON público.

---

## 2. Entidades internas (A) — em memória, owned pelo gerador

### A.1 `CompatAnnotation` — o que o dev declarou
- **Purpose:** representação parseada da annotation `lerian.studio/compatibility`.
- **Owned by:** C-1 Chart Reader.
- **Primary id:** nenhum (embutido no ChartState).

| Atributo | Tipo | Obrig. | Constraints | Descrição |
|---|---|---|---|---|
| requires | Map&lt;ProductKey, SemverRange&gt; | não (v1) | cada range parseável (V4) | Dependência técnica declarada |
| testedWith | Map&lt;ProductKey, ExactVersion&gt; | não | cada versão exata (V5) | Combinação testada em release |

Ausência do objeto inteiro = válida (chart sem compatibilidade declarada).

### A.2 `ChartState` — estado lido de um chart
- **Owned by:** C-1. **Primary id:** `name`.

| Atributo | Tipo | Obrig. | Constraints | Descrição |
|---|---|---|---|---|
| name | ProductKey | sim | único no repo | Nome publicado (ex.: `midaz-helm`) |
| dir | String | sim | único | Diretório em `charts/` (ex.: `midaz`) — prefixo das tags |
| version | Semver | sim | válido | **N (autoridade)** — de `Chart.yaml` |
| appVersion | Semver | não | — | Versão do app (informativo) |
| compat | CompatAnnotation | não | — | A.1 |
| tags | List&lt;Semver&gt; | não | derivadas de `<dir>-v*` | Histórico p/ N-1..N-3 |

> **Caso real verificado no repo (2026-07-22):** `midaz` tem `Chart.yaml.version=8.6.0` mas existe a tag `midaz-v8.7.0-beta.1` (**acima** de N e pre-release), além de `8.4.0-beta.{1,2,3}` e `8.5.0-beta.1`. Regras de C-2 confirmadas obrigatórias e viram **casos de teste (T-3)**: (a) **N = Chart.yaml, nunca a maior tag** — senão N sairia `8.7.0-beta`; (b) **descartar tags > N** ao montar N-1..N-3; (c) **segregar pre-releases** antes de agrupar por minor. Filtro `<dir>-v*` confirmado correto (formato real = `midaz-v8.6.0`).

### A.3 `VersionRow` — uma linha da janela de suporte
- **Owned by:** C-2 Support Window Resolver. **Relationship:** ChartState (1) ──< 1..4 >── VersionRow (janela) + até 1 linha-resumo EOL.

| Atributo | Tipo | Obrig. | Constraints | Descrição |
|---|---|---|---|---|
| version | Semver | sim | — | Versão do chart naquele ciclo |
| minorCycle | String | sim | `MAJOR.MINOR` | Ciclo (ex.: `8.6`) |
| tier | TierEnum | sim | §1 | Nível de suporte |
| isEOL | Boolean | sim | — | true → agrupado na linha-resumo |
| requires | Map&lt;ProductKey, SemverRange&gt; | não | — | Copiado de compat p/ render "Requer" |

**Regra de derivação (C-2):** segregar pre-releases → agrupar por `minorCycle` → ordenar desc → N = `version` do Chart.yaml, N-1..N-3 = 3 minors distintas imediatamente inferiores nas tags → resto = `eol` (colapsado em 1 linha-resumo). `<4` minors ⇒ menos linhas; `0` tags ⇒ só a linha N.

---

## 3. Entidade pública (B) — `compatibility.json` (contrato versionado)

- **Purpose:** interface legível por máquina consumida por cliente/console/ferramentas (US-5).
- **Owned by:** C-3b (gerador é a única autoridade de escrita; consumidores são read-only).
- **Consistência:** derivado, eventual (regenerado no release). Fonte de verdade continua sendo Chart.yaml+tags; o JSON é **projeção**.

### B.1 Documento raiz
| Campo | Tipo | Obrig. | Descrição |
|---|---|---|---|
| schemaVersion | Integer | sim | Versão do contrato do documento. v1 = `1`. Monotônico, distinto de qualquer `$schema`. |
| generatedFrom | String | sim | Referência de proveniência (ex.: commit/branch) — informativo |
| products | Map&lt;ProductKey, Product&gt; | sim | Um por chart ativo |

### B.2 `Product`
| Campo | Tipo | Obrig. | Nullable | Descrição |
|---|---|---|---|---|
| dir | String | sim | não | Diretório do chart |
| current | Semver | sim | não | N (= Chart.yaml.version) |
| cycles | List&lt;Cycle&gt; | sim | não | Ordenada desc; até 4 sob suporte + ciclos EOL colapsados conforme render |

### B.3 `Cycle` (linha por ciclo minor — modelo endoflife.date)
| Campo | Tipo | Obrig. | Nullable | Descrição |
|---|---|---|---|---|
| cycle | String | sim | não | `MAJOR.MINOR` (ex.: `8.6`) |
| latest | Semver | sim | não | Maior patch estável do ciclo |
| supported | Boolean | sim | não | `false` ⟺ fora da janela N..N-3 (idioma bool endoflife.date). **Tier NÃO fica no JSON** — deriva-se de posição/`supported` (§1). |
| requires | Map&lt;ProductKey, SemverRange&gt; | não | sim | Compatibilidade cruzada declarada (ausente no v1 se não declarada) |
| testedWith | Map&lt;ProductKey, ExactVersion&gt; | não | sim | Preenchido no v1 (backfill) |

> Ordem de `cycles` (desc) é o contrato: o consumidor lê posição para tier. Índice 0 = `current` = N.

### B.4 Exemplo real (números do repo)
```json
{
  "schemaVersion": 1,
  "generatedFrom": "main@<commit>",
  "products": {
    "midaz-helm": {
      "dir": "midaz",
      "current": "8.6.0",
      "cycles": [
        { "cycle": "8.6", "latest": "8.6.0", "supported": true  },
        { "cycle": "8.5", "latest": "8.5.0", "supported": true  },
        { "cycle": "8.4", "latest": "8.4.0", "supported": true  },
        { "cycle": "8.3", "latest": "8.3.0", "supported": true  },
        { "cycle": "8.2", "latest": "8.2.0", "supported": false }
      ]
    },
    "plugin-fees-helm": {
      "dir": "plugin-fees",
      "current": "7.2.0",
      "cycles": [
        { "cycle": "7.2", "latest": "7.2.0", "supported": true,
          "requires":   { "midaz-helm": ">=8.4.0 <9.0.0" },
          "testedWith": { "midaz-helm": "8.6.0" } }
      ]
    }
  }
}
```
*(Nota: `plugin-fees` só tem 1 ciclo aqui porque as tags de histórico não existem no clone atual — FR-7 degradação graciosa. O `requires` aparece porque foi declarado; no backfill v1 puro só `testedWith` estaria presente.)*

---

## 4. Custom Types
| Tipo | Base | Formato | Exemplo |
|---|---|---|---|
| ProductKey | String | nome de chart publicado | `midaz-helm`, `plugin-access-manager` |
| Semver | String | SemVer 2.0 | `8.6.0`, `1.2.1-beta.11` |
| SemverRange | String | constraint Masterminds | `>=8.4.0 <9.0.0`, `~8.4`, `8.x \|\| 9.x` |
| ExactVersion | Semver | — | `8.6.0` |
| TierEnum | String | enum §1 (**interno**, não serializado no JSON) | `full` |

---

## 5. Migration / Versionamento do schema
- **Aditivo não-quebra:** novos campos opcionais em `Product`/`Cycle` (ex.: `eolDate` numa fase futura) → **não** incrementam `schemaVersion`; consumidores antigos ignoram.
- **Quebra:** remover/renomear campo, mudar semântica de `tier` → incrementa `schemaVersion` para `2`; consumidores validam e migram um passo.
- v1 congela: `schemaVersion:1` com os campos acima.

---

## Gate 5 — Validação
| Categoria | Status |
|---|---|
| Entidades modeladas (CompatAnnotation, ChartState, VersionRow, Product/Cycle) | ✅ |
| Atributos tipados, obrig/opcional e nullability explícitos | ✅ |
| Relacionamentos com cardinalidade (ChartState 1──<1..4 VersionRow) | ✅ |
| Ownership único (C-1 lê, C-2 deriva, C-3b escreve; consumidor read-only) | ✅ |
| Enum de tier canônico e fechado, com regra forward-compat | ✅ |
| Constraints/validação (V4/V5, `supported`⟺`eol`) | ✅ |
| Lifecycle (derivado/regenerado; sem update/delete mutável) | ✅ |
| Versionamento do contrato de dados (schemaVersion aditivo vs quebra) | ✅ |
| Exemplo real com números do repo | ✅ |

**Resultado: ✅ PASS → Gate 6 (Dependency Map)** — PAUSA para validação da interface (conforme pedido).
