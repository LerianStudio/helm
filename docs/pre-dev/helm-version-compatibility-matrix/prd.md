# PRD — Matriz de Compatibilidade de Versões dos Charts (v1)

| | |
|---|---|
| **Date** | 2026-07-22 |
| **Feature** | helm-version-compatibility-matrix |
| **Track** | Large (9 gates) |
| **Gate** | 1 — PRD |
| **Research** | `docs/pre-dev/helm-version-compatibility-matrix/research.md` |
| **Confidence** | 82 / 100 (proven pattern, dor qualitativa clara, valor de negócio direto) |

---

## 1. Executive Summary

Os clientes que instalam os produtos Lerian não têm hoje uma forma confiável de saber **quais versões ainda são suportadas** e **quais versões de produtos diferentes funcionam juntas**. Esta feature entrega uma visualização única, sempre atualizada e fácil de escanear, que mostra — por produto — as versões cobertas pela política de suporte (as quatro releases mais recentes: atual, e três anteriores) com seu respectivo nível de suporte, além de com quais versões de outros produtos cada uma combina. O valor: o cliente decide sozinho e com segurança quando migrar, e o time de suporte para de responder "essa versão ainda é suportada?" manualmente.

---

## 2. Problem Definition

**Problema:** Não existe fonte única e confiável que diga ao cliente se a versão que ele roda ainda é suportada e com o que ela é compatível. A informação de versões hoje é mantida à mão, mostra apenas a versão atual (não o histórico coberto por suporte), e não expressa compatibilidade entre produtos diferentes.

**Impacto (qualitativo — não há telemetria de suporte disponível para quantificar):**
- Cliente não sabe se está em versão suportada → migra tarde demais (risco) ou cedo demais (custo desnecessário).
- Compatibilidade entre produtos (ex.: qual versão do produto A roda com qual versão do produto B) **não existe documentada em lugar nenhum** — descoberta só em incidente.
- Manutenção manual da informação de versões gera divergência (drift) entre o que está documentado e o que foi realmente publicado.
- Suporte recebe perguntas repetidas de "essa versão ainda tem suporte?" que poderiam ser autoatendidas.

**Workaround atual:** Tabelas de "mapeamento de versão" editadas manualmente, mostrando só a versão corrente de cada produto, sem nível de suporte e sem compatibilidade cruzada.

---

## 3. Política de Suporte (contrato de negócio existente — a base da feature)

A empresa já opera com um contrato LTS de suporte às **quatro releases minor mais recentes** de cada produto:

| Posição | Nível | Custo adicional | Cobertura |
|---|---|---|---|
| N (atual) | Full Support | Incluído | Todas as funcionalidades |
| N-1 | Security | Incluído | Patches de segurança |
| N-2 | Extended | +30% | Suporte sob demanda |
| N-3 | Extended | +150% | Suporte limitado |
| N-4+ | Legacy / EOL | — | Sem suporte |

Ciclo: major anual, minor trimestral, patches conforme necessidade, notificação de EOL com 6 meses de antecedência. Esta feature **torna esse contrato visível e automático** — não o cria nem o altera.

---

## 4. Personas

**P1 — Operador do cliente (BYOC / Lerian Cloud)** — instala e mantém os produtos no ambiente do cliente.
- Objetivo: saber, em segundos, se a versão instalada é suportada e até quando; planejar migração.
- Frustração: hoje precisa perguntar ao suporte ou inferir; não enxerga compatibilidade entre produtos antes de atualizar um deles.

**P2 — Time de suporte / CSM Lerian** — atende dúvidas de versão e suporte.
- Objetivo: apontar o cliente a uma fonte única e confiável em vez de responder caso a caso.
- Frustração: informação espalhada e manual, que envelhece.

**P3 — Engenharia de produto Lerian** — publica novas versões dos produtos.
- Objetivo: que a informação de compatibilidade/suporte se atualize sozinha ao publicar, sem edição manual.
- Frustração: manter tabelas de versão à mão é trabalho repetitivo e fonte de erro.

---

## 5. User Stories

**US-1** — Como operador do cliente, quero ver, por produto, quais versões estão sob suporte e em que nível (Full / Security / Extended / EOL), para saber se preciso migrar.
- AC: cada produto mostra até 4 versões (atual e três anteriores) com nível de suporte identificável visualmente; versões sem suporte aparecem resumidas como EOL.

**US-2** — Como operador do cliente, quero ver com quais versões de outros produtos cada versão combina, para atualizar um produto sem quebrar a compatibilidade com os demais.
- AC: quando um produto declara depender de outro, essa relação aparece de forma legível na visualização; quando não declara, a coluna simplesmente não aparece para aquele produto.

**US-3** — Como time de suporte, quero uma única fonte pública e sempre atual, para direcionar o cliente em vez de responder manualmente.
- AC: a visualização vive num local público que o cliente já acessa e reflete o que foi de fato publicado.

**US-4** — Como engenharia de produto, quero que a visualização se atualize automaticamente quando publico uma versão, para não manter tabela à mão.
- AC: ao publicar uma nova versão de um produto, a informação de suporte/compatibilidade daquele produto é regenerada sem intervenção manual; o conteúdo gerado nunca é editado à mão.

**US-5** — Como consumidor programático (ferramentas internas / painel do cliente, fase futura), quero a mesma informação em formato consumível por máquina, para exibir "sua versão está em nível X" sem interpretar texto.
- AC: além da visualização legível, existe uma representação estruturada e versionada da mesma informação, derivada da mesma fonte.

---

## 6. Requisitos Funcionais (WHAT)

- **FR-1 — Fonte declarativa por produto.** Cada produto declara sua própria informação de compatibilidade num único lugar mantido junto do produto. Distinguir o que o produto **exige** de outro (relação técnica) do que foi **testado em conjunto** (informativo).
- **FR-2 — Janela de suporte automática.** O nível de suporte de cada versão (Full / Security / Extended×2 / EOL) é **derivado automaticamente** da versão atual do produto e do histórico de versões publicadas, seguindo o contrato da seção 3 — ninguém digita "N-3".
- **FR-3 — Visualização legível.** Uma visualização por produto, fácil de escanear, mostrando as versões sob suporte (atual + 3 anteriores) com nível identificável e, quando aplicável, a compatibilidade com outros produtos; versões fora de suporte resumidas como EOL numa única entrada.
- **FR-4 — Representação por máquina.** A mesma informação disponível também em formato estruturado e versionado, derivado da mesma fonte, para consumo futuro por ferramentas.
- **FR-5 — Geração automática na publicação.** Ao publicar uma nova versão de um produto, as saídas (FR-3 e FR-4) são regeneradas automaticamente para aquele produto; conteúdo gerado é substituído integralmente, nunca editado à mão.
- **FR-6 — Aviso de inconsistência (não bloqueante no v1).** Se a informação declarada estiver malformada ou apontar para algo inexistente, o processo de publicação **avisa** (não impede). Divergência entre o gerado e a fonte também gera aviso. Bloqueio fica para fase futura.
- **FR-7 — Degradação graciosa.** Produtos com menos de quatro versões publicadas (ou nenhuma) mostram apenas o que existe, sem erro.

---

## 7. Requisitos Não-Funcionais

- **NFR-1 — Sem manutenção manual da saída.** Nenhuma tabela de versão volta a ser editada à mão.
- **NFR-2 — Não regressão.** A geração não pode corromper conteúdo existente ao redor (a visualização convive com documentação já presente).
- **NFR-3 — Confiabilidade da janela.** A "versão atual" de um produto deve ser sempre correta, independentemente de o histórico estar completo ou não.
- **NFR-4 — Idempotência.** Rodar a geração duas vezes sobre a mesma fonte produz exatamente o mesmo resultado.
- **NFR-5 — Público correto.** A visualização vive onde o cliente já busca informação de instalação.

---

## 8. Success Metrics

- **M1 (adoção):** redução das perguntas de suporte do tipo "essa versão ainda é suportada?" (medida qualitativamente pelo time de suporte no primeiro trimestre pós-lançamento).
- **M2 (frescor):** 0 edições manuais da visualização de versões após o lançamento (toda mudança vem da geração automática).
- **M3 (cobertura):** 100% dos produtos ativos com informação de suporte gerada; ≥1 produto com compatibilidade cruzada declarada até o fim da fase de adoção.
- **M4 (confiabilidade):** 0 casos de "versão atual errada" na visualização.

---

## 9. Escopo

### In-scope (v1)
- Visualização legível de suporte por produto (atual + 3 anteriores + resumo EOL).
- Compatibilidade cruzada **exibida quando declarada** por um produto.
- Representação por máquina, versionada, derivada da mesma fonte.
- Geração automática na publicação de versão.
- Avisos não bloqueantes de inconsistência e de divergência.
- Preenchimento inicial automático do que é derivável (a combinação testada da release atual) para todos os produtos ativos.

### Out-of-scope (v1 — fases futuras)
- **Bloqueio** de publicação por incompatibilidade (v1 só avisa).
- Preenchimento das relações "exige" (dependência técnica declarada) para todos os produtos — depende de conhecimento de cada time de produto; no v1 esse campo é opcional e pode ficar vazio.
- Exibição da matriz fora do local público primário (painel do cliente, portal de docs) — consome a representação por máquina numa fase posterior.
- Datas de EOL calculadas por calendário (o v1 usa posição N-x; datas concretas ficam para depois).
- Notificação ativa de EOL ao cliente (o contrato prevê 6 meses de antecedência; automatizar isso é fase futura).

---

## 10. Premissas e Dependências

- **A1:** A versão declarada por cada produto é a autoridade sobre "versão atual".
- **A2:** O histórico de versões publicadas de cada produto é recuperável de forma confiável.
- **A3:** Cada time de produto é a autoridade sobre as relações "exige" — por isso ficam opcionais no v1.
- **D1:** Depende do processo de publicação existente para disparar a geração automática.
- **D2:** Depende de um local público já acessado pelo cliente para hospedar a visualização.

---

## 11. Riscos (nível de negócio)

- **R1 — Histórico incompleto de um produto** → janela parcial. Mitigado por FR-7 (degradação graciosa) e por A1 (a versão atual nunca depende do histórico).
- **R2 — Relações "exige" vazias no v1** → matriz de compatibilidade cruzada inicialmente rasa. Aceito conscientemente; enriquece conforme os times preenchem.
- **R3 — Percepção de que EOL por posição (N-4) não basta sem data** → comunicado como limitação conhecida do v1; datas concretas são fase futura.

---

## Gate 1 — Validação

| Categoria | Status |
|---|---|
| Problema articulado (1-2 frases) | ✅ |
| Impacto qualificado (sem telemetria → qualitativo, declarado) | ✅ |
| Usuários identificados (P1–P3) | ✅ |
| Features endereçam o problema | ✅ |
| Métricas mensuráveis | ✅ (M1 qualitativa declarada; M2–M4 objetivas) |
| Escopo in/out explícito com racional | ✅ |
| PRD sem detalhe técnico | ✅ (HOW abstraído; guardado para o TRD) |

**Resultado: ✅ PASS → Gate 2 (Feature Map)**

> Nota de separação business/técnico: decisões de HOW já tomadas com o usuário (annotation em metadados do chart, derivação por tags, ferramenta geradora, biblioteca semver, marcadores no documento, formato JSON) foram **deliberadamente omitidas** deste PRD e estão registradas no `research.md` para entrarem no TRD (Gate 3).
