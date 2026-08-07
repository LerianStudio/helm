# Backlog — Fases Futuras (fora do v1)

Itens conscientemente adiados para manter o v1 enxuto. Decisões registradas nesta sessão.

## TODO-1 — Assistência para preencher `requires` (anti-erro manual)
**Contexto:** editar a annotation `lerian.studio/compatibility` à mão é a peça mais frágil do desenho (erro de sintaxe YAML, range semver inválido, produto inexistente). No **v1 fica manual** (aceito para não inflar escopo/tempo). Duas abordagens aprovadas para depois:

- **TODO-1a — Comando CLI que escreve a annotation.** Ex.: `generate-compatibility set-requires --chart plugin-fees --requires midaz-helm@">=8.4 <9"`. A ferramenta escreve o YAML formatado e **já validado** → dev nunca edita YAML cru. Mata erro de sintaxe.
- **TODO-1b — Mapear no AGENT do Ring.** Dev pede em linguagem natural para a IA (agent Ring) e ela gera a annotation validada. **É a solução preferida do usuário.** Precisa: deixar essa capacidade mapeada/documentada no agent Ring apropriado (provável dev-sre / ou skill nova de "declarar compatibilidade de chart"). Não implementado no v1.

**Nota:** `testedWith` NÃO precisa disso — é derivável do release (FR-8, backfill automático). O problema manual é só o `requires`.

**Escopo do fardo (CORRIGIDO 2026-07-22 — estimativa anterior estava errada):** dependência entre produtos NÃO é medida pelas `dependencies:` do Chart.yaml (essas só listam INFRA: postgres/mongo/valkey). O sinal REAL está nos `values.yaml`, em variáveis de runtime tipo `MIDAZ_TRANSACTION_URL`, `PLUGIN_AUTH_ADDRESS` (URLs apontando pra outro produto Lerian). Medido assim: **~16 dos 21 charts referenciam outros produtos** (plugins BR Pix/bank-transfer/payments têm dezenas de refs; product-console 10; access-manager 7). Ou seja: **compat cruzada (#2) é a REGRA, não a exceção.** Consequência: mapear `requires` à mão em ~16 charts é inviável → **TODO-1b (IA/agent gera o requires) deixa de ser opcional e vira NECESSÁRIO para escala.** Ressalva: nem toda ref vira `requires` versionável (ex.: access-manager/auth é quase universal); refinar quais deps merecem entrar no `requires` é parte do TODO-1.
O eixo #1 (suporte de versões) permanece 100% automático para TODOS — dev não mantém nada.

## DECISÃO — `testedWith` REMOVIDO do v1 (2026-07-27)
**Contexto:** `requires` (a REGRA: faixa semver que o produto exige) e `testedWith` (o FATO: versão exata testada junto) respondem perguntas diferentes. Mas `testedWith` DIGITADO À MÃO no v1 é fraco (dev só repete o topo da faixa → redundante com requires). Só tem valor quando é VERDADE OBSERVADA de um E2E. **Decisão do usuário:** v1 = annotation com SÓ `requires`; sem `testedWith` manual, sem backfill de testedWith (o FR-8 do PRD sai do v1). `testedWith` volta na v2, preenchido automaticamente pelo E2E (ver TODO-2). A ferramenta CONTINUA aceitando `testedWith` no schema/parser/JSON (omitempty; sem coluna se ausente) — validado: annotation só-requires funciona, JSON omite testedWith. Zero retrabalho pra v2.

## TODO-2 — Preencher `requires`/`testedWith` a partir de teste E2E (v2)
**Contexto:** DECISÃO — no **v1 o DESENVOLVEDOR determina o `requires`** (declara à mão na annotation da versão atual; só o N tem valor, N-1..N-3 mostram `—`). Na **v2**, preencher `requires` E `testedWith` AUTOMATICAMENTE a partir dos **testes automatizados E2E** (pipeline multi-produto **em desenvolvimento**): o que roda verde com os produtos juntos vira a verdade declarada — observada, não digitada. Casa com o TODO-1b (agent/IA) como as duas frentes de tirar o fardo manual do dev. Depende do E2E existir. Fora do v1.

## TODO-3 — Campos do `compatibility.json` a definir com o time do Console
**Contexto:** o time do product-console ainda **não foi consultado** sobre o que vai consumir. O JSON v1 é **mínimo e estável** (`schemaVersion`, `products{current, cycles{cycle, latest, supported, requires?, testedWith?}}`). Campos extras que o console pedir (ex.: label legível, custo, badge) entram como **aditivos** (não incrementam `schemaVersion`, não quebram). Conversar com o console antes de enriquecer.

## TODO-4 — Promover checks de WARN para gate bloqueante
**Contexto:** v1 é não-bloqueante (tudo WARN, exit 0). Quando a adoção estabilizar, promover V1–V5 (annotation) e o drift-check a **ERRO** (exit 1). É mudança de comportamento → major da feature, anunciada.

## RISCO-A — VERIFICADO E DESCARTADO ✅ (2026-07-23)
**Contexto:** `charts/*/Chart.yaml` é atualizado via `app-sync.yml` → shared-workflow externo `helm-update-chart.yml@v1.36.8`. Medo: reescrever o Chart.yaml e apagar a annotation `lerian.studio/compatibility`.
**Verificação:** li o shared-workflow (clone em `/home/gauchito/lerian/github-actions-shared-workflows`). Ele faz UMA edição cirúrgica no Chart.yaml — `yq -i '.appVersion = "..."'` (linha 383, mikefarah/yq v4) — e só isso; o resto é `values.yaml` ({comp}.image.tag) e templates. **NÃO toca annotations/version/dependencies.**
**Teste real:** rodei o EXATO comando (mikefarah/yq -i .appVersion) no Chart.yaml do fees COM a annotation → diff mostrou APENAS a linha appVersion mudada; a annotation compatibility (bloco YAML multi-linha) ficou byte-idêntica, formatação inclusa. **A annotation sobrevive ao app-sync.** Nenhuma ação necessária.

## TODO-6 — Visibilidade dos WARN no CI (decidir na T-8)
**Contexto:** a ferramenta emite WARN em stderr (ex.: coluna de app cuja `{comp}.image.tag` não existe no values → `—` + WARN; annotation malformada; drift). Hoje isso vai só pro log. **Decisão do usuário: manter `—` + WARN (não propagar dado fantasma).** Mas "onde o humano vê o WARN" fica pra T-8 (integração CI): (a) só stderr no log do Actions [fraco, some em job verde]; (b) anotação no PR [médio, autor vê]; (c) resumo agregado / comentário no PR [forte]. Recomendação: decidir (b)/(c) na T-8. No piloto (tracer, 1 coluna que resolve) NÃO há WARN.

**Achado relevante (2026-07-23):** o README atual do plugin-fees mostra `UI Version: 3.0.0` que é HARDCODED manual — o `values.yaml` do fees NÃO tem seção `ui:` (só global/fees/mongodb/otel/aws), então `ui.image.tag` não existe. É dado fantasma (drift manual). A automação, ao pôr `—`+WARN, é mais honesta que o README atual. Investigar (fora do piloto) se a coluna UI ainda faz sentido no fees ou é resíduo.

## TODO-5 — Datas de EOL por calendário
**Contexto:** v1 classifica por posição (N-x), sem data de EOL concreta. Contrato prevê notificação de EOL com 6 meses de antecedência. Fase futura: calcular `eolDate` por ciclo (minor trimestral) e expor no JSON (campo aditivo) + notificação ativa.
**DESTRAVADO parcialmente:** o v1 JÁ captura a data de LANÇAMENTO de cada versão (coluna "Released" no README + campo `released` no JSON, vindo de `git creatordate` da tag). Com released + cadência trimestral do contrato, dá pra derivar `eolDate` = released + N trimestres. A matéria-prima já existe; falta só o cálculo + exposição.
