# Feature Map — Matriz de Compatibilidade de Versões (v1)

| | |
|---|---|
| **PRD** | `docs/pre-dev/helm-version-compatibility-matrix/prd.md` |
| **Gate** | 2 — Feature Map |
| **Date** | 2026-07-22 |
| **Status** | Locked após validação |
| **Confidence** | 88 / 100 |

---

## 1. Feature Inventory

### Core (bloqueiam o resto)
| ID | Nome | Descrição | Valor | Depende de |
|---|---|---|---|---|
| F-1 | Fonte declarativa por produto | Cada produto declara sua compatibilidade num único lugar, separando "exige" de "testado com" | Verdade única, junto do produto | — |
| F-2 | Janela de suporte derivada | Calcula automaticamente o nível (Full/Security/Extended×2/EOL) da versão atual + histórico | Ninguém digita "N-3"; contrato vira automação | F-1 (versão atual), histórico de versões |
| F-3 | Geração automática na publicação | Ao publicar uma versão, regenera as saídas daquele produto | Zero manutenção manual | F-1, F-2, F-4, F-5 |

### Supporting (materializam a saída)
| ID | Nome | Descrição | Valor | Depende de |
|---|---|---|---|---|
| F-4 | Visualização legível | Tabela por produto: versões sob suporte + nível + compatibilidade cruzada; EOL resumido | Cliente decide migração em segundos | F-1, F-2 |
| F-5 | Representação por máquina | Mesma informação estruturada e versionada, derivada da mesma fonte | Consumo futuro por ferramentas | F-1, F-2 |

### Enhancement (qualidade / confiança)
| ID | Nome | Descrição | Valor | Depende de |
|---|---|---|---|---|
| F-6 | Avisos não-bloqueantes | Alerta sobre dado malformado/inexistente e sobre divergência gerado↔fonte, sem impedir | Higiene sem travar entrega | F-1, F-3 |
| F-7 | Degradação graciosa | Produtos com <4 versões (ou 0) mostram só o que existe | Sem erro em produto novo | F-2 |
| F-8 | Preenchimento inicial derivável | Backfill automático do "testado com" da release atual em todos os produtos ativos | Matriz nasce populada no dia 1 | F-1 |

*Não há categoria Integration no v1: a exibição fora do local público primário (painel, portal de docs) é out-of-scope e consumirá F-5 numa fase futura.*

---

## 2. Domain Groupings

### Domínio A — Declaração de Compatibilidade
- **Propósito:** capturar, junto de cada produto, a verdade sobre o que ele exige e com o que foi testado.
- **Features:** F-1, F-8.
- **Owns:** o dado declarado de compatibilidade por produto.
- **Provides:** a fonte única consumida por todo o resto.
- **Consumes:** nada (é a raiz).

### Domínio B — Cálculo de Suporte
- **Propósito:** transformar versão atual + histórico no nível de suporte por versão, segundo o contrato LTS.
- **Features:** F-2, F-7.
- **Owns:** a regra da janela N..N-3 e o tratamento de histórico incompleto.
- **Consumes:** versão atual e histórico (Domínio A + fonte de histórico).
- **Provides:** a classificação de suporte usada nas saídas.

### Domínio C — Materialização das Saídas
- **Propósito:** produzir as duas visões (legível e por máquina) a partir da fonte + classificação.
- **Features:** F-4, F-5.
- **Consumes:** Domínios A e B.
- **Provides:** artefatos consumíveis por cliente e por ferramenta.

### Domínio D — Orquestração & Higiene
- **Propósito:** disparar a geração na publicação e sinalizar inconsistências.
- **Features:** F-3, F-6.
- **Consumes:** Domínios A, B, C.
- **Provides:** atualização automática e avisos.

Dependências cross-domain fluem em **uma direção**: A → B → C → D. Sem ciclos.

---

## 3. User Journeys

### J-1 — Cliente verifica se sua versão é suportada (P1)
1. Abre o local público de informação de instalação.
2. Localiza o produto e sua versão instalada. *(F-4)*
3. Lê o nível de suporte da versão (Full/Security/Extended/EOL). *(F-2 → F-4)*
4. **Sucesso:** decide migrar ou não. **Falha graciosa:** produto novo com poucas versões mostra só o que há. *(F-7)*

### J-2 — Cliente planeja atualizar um produto sem quebrar outro (P1)
1. Vê a versão que pretende adotar do produto A. *(F-4)*
2. Lê com quais versões do produto B ela combina. *(F-1 → F-4)*
3. **Sucesso:** confirma compatibilidade antes de atualizar. **Limitação v1:** se A não declarou "exige", a coluna não aparece — cliente cai no caso J-1. *(R-2 do PRD)*

### J-3 — Engenharia publica uma nova versão (P3)
1. Publica a versão do produto (fluxo existente).
2. A geração regenera as saídas daquele produto. *(F-3 → F-4, F-5)*
3. Se a declaração estiver inconsistente, recebe aviso — publicação segue. *(F-6)*
4. **Sucesso:** saídas atualizadas sem edição manual.

### J-4 — Suporte direciona o cliente (P2)
1. Recebe pergunta "essa versão tem suporte?".
2. Aponta para a visualização única e atual. *(F-4)*
3. **Sucesso:** autoatendimento; sem resposta caso a caso.

---

## 4. Feature Interaction Map

```
[F-1 Fonte declarativa] ──┬─────────────► [F-4 Visualização legível] ──► J-1,J-2,J-4
        ▲                 │                        ▲
        │                 └──► [F-2 Janela] ───────┤
   [F-8 Backfill]              [F-7 gracioso]      │
                                   │               └──► [F-5 Repr. máquina] ──► (fase futura)
                                   ▼
                         [F-3 Geração na publicação] ──► J-3
                                   │
                                   └──► [F-6 Avisos]
```

### Matriz de dependências
| Feature | Depende de | Bloqueia | Opcional |
|---|---|---|---|
| F-1 | — | F-2,F-4,F-5,F-8 | — |
| F-2 | F-1 + histórico | F-4,F-5 | — |
| F-3 | F-1,F-2,F-4,F-5 | J-3 | — |
| F-4 | F-1,F-2 | J-1,J-2,J-4 | — |
| F-5 | F-1,F-2 | fase futura | sim (não bloqueia leitura humana) |
| F-6 | F-1,F-3 | — | sim |
| F-7 | F-2 | — | — |
| F-8 | F-1 | — | sim (matriz funciona vazia, só menos rica) |

---

## 5. Phasing Strategy

**Fase 1 (este v1):** F-1..F-8 sem bloqueio. Entrega: visualização + representação por máquina, geradas automaticamente, com backfill do derivável. Critério de saída: 100% dos produtos ativos com suporte gerado, 0 edições manuais.

**Gatilhos p/ fase futura:** (a) times de produto começam a preencher "exige" → matriz cruzada enriquece; (b) demanda por bloqueio → promover F-6 de aviso a gate; (c) consumo real de F-5 pelo painel do cliente.

---

## 6. Scope Boundaries

- **In:** F-1..F-8 (v1 do PRD §9).
- **Out:** bloqueio de publicação, backfill completo de "exige", exibição em painel/portal, datas de EOL por calendário, notificação ativa de EOL (PRD §9 out-of-scope).
- **Assumções:** versão declarada = autoridade do "N"; histórico recuperável; cada time é autoridade do "exige".
- **Constraint:** saída convive com documentação existente sem corrompê-la (NFR-2).

---

## 7. Risk Assessment

| Risco | Origem | Mitigação |
|---|---|---|
| Histórico incompleto → janela parcial | F-2/F-7 | F-7 degradação; N vem da declaração, não do histórico |
| "Exige" vazio → matriz rasa | F-1/F-8 | aceito; enriquece por fase |
| Divergência gerado↔fonte passa despercebida | F-6 | aviso de drift na publicação |
| Corromper documentação existente | F-4 | geração confinada e idempotente (NFR-4) |

---

## Gate 2 — Validação
| Check | Status |
|---|---|
| Todas as features do PRD mapeadas | ✅ (F-1..F-8) |
| Categorias atribuídas | ✅ |
| Domínios coesos, sem ciclo (A→B→C→D) | ✅ |
| Jornadas completas (happy + falha graciosa) | ✅ (J-1..J-4) |
| Pontos de integração e direção claros | ✅ |
| Prioridade/fase suporta entrega incremental | ✅ |
| Sem detalhe técnico | ✅ |

**Resultado: ✅ PASS → Gate 3 (TRD)**
