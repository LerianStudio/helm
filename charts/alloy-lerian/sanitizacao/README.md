# Arcabouço de verificação de sanitização

**Executado e validado:** 2026-08-08 · **Subtarefa:** ST-003-02
**Agente:** `grafana/alloy:v1.18.1`

## Por que existe

Em produção as regras rodam com `error_mode = "ignore"`. **Uma regra malformada não gera erro — produz saída que aparenta estar mascarada.** Verificado empiricamente ([evidência](../subtasks/T-003/EVIDENCIA-retrovinculacao.md)): a notação `$$1` emite o texto literal `$1***`, sem qualquer aviso, mesmo em `error_mode = "propagate"`.

Logo, a única verificação válida é **comparar a saída observada com a esperada**. Revisão de configuração não detecta esta classe de falha.

## Uso

```bash
./porta-de-entrega.sh             # PORTA BLOQUEANTE — 5 verificações
./verificar.sh                    # só os casos, todos
./verificar.sh documento-canonico # um caso
```

Código de saída 0 = liberado. Diferente de 0 = bloqueado.

## Porta de entrega — 5 verificações bloqueantes

`porta-de-entrega.sh` é o que bloqueia a entrega. Vai além de rodar os casos:

| # | Verifica | Por quê |
|---|---|---|
| 1 | Nenhuma notação `$$N` no **código** | Emite texto literal sem erro |
| 2 | Nenhuma função editora aninhada em `set()` | Falha na carga do agente |
| 3 | Nenhum lookahead/lookbehind | Não suportado pelo motor |
| 4 | Cada classe tem as 4 categorias; e o `body` esperado das de preservação **não** contém notação | Regra sem cobertura completa passa despercebida |
| 5 | Todos os casos passam contra o agente real | — |

### Bloqueio verificado com 4 defeitos deliberados

| Defeito injetado | Bloqueou |
|---|---|
| Notação `$$1` no código | ✅ |
| Lookahead numa regra | ✅ |
| Categoria de teste removida | ✅ |
| `body` esperado com `$1` literal | ✅ |

### Nota de método: os três primeiros checks inspecionam só o código

Na primeira execução a porta deu **6 falsos positivos** — estava lendo os comentários do arquivo de regras, que documentam justamente as construções proibidas (`NUNCA $$1`, `falha com (?!`), e o campo `descricao` dos casos, que menciona a notação de propósito.

Corrigido: os checks 1 a 3 filtram linhas de comentário; o check 4 lê apenas o campo `body` via `jq`. **Uma porta que falha sempre é ignorada — e aí não protege nada.**

## Integração em CI

`ci-sanitizacao.yml.modelo` é o fluxo pronto, **não instalado**: o chart ainda não existe no repositório. Quando existir (T-004), copiar para `.github/workflows/` ajustando os caminhos.

A versão do agente é **pinada** no fluxo. Atualizá-la exige reverificar as asserções — comportamento de regex pode mudar entre versões, e a falha seria silenciosa em produção.

## Estrutura

```
sanitizacao/
├── regras.alloy      # regras + receptor + exportador de inspeção
├── verificar.sh      # executa o agente real e compara saídas
└── casos/
    ├── <caso>.json           # entrada
    └── <caso>.esperado.json  # saída esperada + categoria
```

## As 4 categorias obrigatórias por regra

| Categoria | O que verifica | Estado |
|---|---|---|
| `formaCanonica` | Caminho principal | ✅ |
| `formaAlternativa` | Variante de formato da mesma classe | ✅ |
| `ausencia` | A regra **não** altera o que não casa | ✅ |
| **`preservacaoDeFragmento`** | **A saída contém o fragmento capturado, não a notação literal** | ✅ |

**A quarta é a única capaz de detectar notação de retrovinculação incorreta.** As outras três passariam com a regra errada.

## Detecção de regressão — verificada

O arcabouço foi testado contra três defeitos deliberados:

| Defeito injetado | Saída produzida | Detectado |
|---|---|---|
| Regra ausente | `documento 12345678901` (dado cru) | ✅ |
| Grupo inexistente (`$9`) | `documento ********` (fragmento **vazio**) | ✅ |
| **Notação errada (`$$1`)** | **`documento $1********`** | ✅ |

O terceiro é o cenário real de risco: asteriscos presentes, formato plausível, dado não mascarado. **Passaria por revisão de configuração.**

Nota sobre o segundo: grupo de captura inexistente resolve para **string vazia**, silenciosamente. Não gera erro.

## Achado sobre as regras (não sobre o arcabouço)

O caso `formaAlternativa` **falhou na primeira execução** e revelou uma lacuna real: a regra de 11 dígitos seguidos **não casa documento com separadores** (`123.456.789-01`). Foi necessária uma regra própria para a forma pontuada.

**Consequência para as regras restantes:** cada classe de dado regulado precisa de verificação de forma alternativa. A ausência dessa categoria de teste é o que permite uma lacuna assim passar.

## Ordem das regras importa

A regra da forma pontuada vem **antes** da de dígitos seguidos. Comentado no arquivo: a mais específica precede a mais geral.

## Diferenças deliberadas em relação à produção

| Aspecto | Aqui | Produção |
|---|---|---|
| `error_mode` | `propagate` | `ignore` |
| Exportador | de inspeção (experimental) | ao concentrador (estável) |
| Nível de estabilidade | rebaixado, só por causa do exportador de inspeção | máximo |

O rebaixamento do nível de estabilidade é **exclusivo deste arcabouço**. A configuração de produção não usa componente abaixo do nível máximo.

## Limitações do motor de regex — verificadas por execução

O motor desta versão é RE2. **Não suporta**:

| Construção | Erro | Consequência |
|---|---|---|
| Lookahead `(?!…)`, `(?=…)` | `invalid or unsupported Perl syntax: (?!` | **Falha na CARGA** — ruidosa e segura |
| Lookbehind | idem | idem |

**Isto é boa notícia:** a ausência de retrovisor força delimitar o valor por outros meios, e o erro aparece na inicialização, não em execução.

## Regra de nome: três tentativas, e o que cada uma ensinou

| Tentativa | Resultado observado | Por que falha |
|---|---|---|
| `(?: \w+)+` guloso | `Joao **********` — **sobrenome APAGADO** | Consome até o fim; último grupo fica vazio. **Pior que não mascarar** — destrói dado |
| `(?: \w+)*?` não-guloso | `Joao ********** Carlos Pereira Silva` | Casa o mínimo; não mascara o meio |
| `[A-Z]\w*` ancorado em caixa | ✅ funciona | Termos de nome começam em maiúscula; o texto seguinte no log é minúsculo — delimita o valor sem retrovisor |

**Foram necessárias DUAS regras**, não uma:
- **3+ termos** — exige ≥1 termo no meio (`(?: [A-Z]\w*)+`)
- **exatamente 2 termos** — a regra de 3+ não casa, porque não há meio

**A ordem é obrigatória: 3+ antes de 2.** Verificado por regressão — invertendo, `Ana Beatriz Costa Lima` vira `Ana ********** Beatriz Costa Lima`: **o nome completo permanece exposto** com uma máscara decorativa antes. Passa em revisão visual.

### Dependência de convenção — registrar como premissa

A regra depende de os termos de nome começarem em **maiúscula** e o texto seguinte no log ser **minúsculo**. Isso vale nos logs analisados, mas é premissa, não garantia. Se alguma aplicação logar nome em caixa alta ou baixa, a regra não casa — e o teste de forma alternativa da classe correspondente é o que detectaria.

## Estado: 7 de 7 classes, 31 casos, todos passando

| Classe | Casos | Regras | Estado |
|---|---|---|---|
| Documento fiscal | 4 | 2 (pontuada + seguida) | ✅ |
| Nome de pessoa | 4 | 2 (3+ termos + 2 termos) | ✅ |
| Correio eletrônico | 4 | 1 | ✅ |
| Telefone | 4 | 2 (E.164 + nacional) | ✅ |
| Chave de pagamento | 4 | 1 (só a forma aleatória) | ✅ |
| Endereço postal | 4 | 1 (integral) | ✅ |
| Identificador opaco | 4 | 1 | ✅ |

Mais três casos além das 4 categorias por classe:

| Caso | Verifica |
|---|---|
| `interacao-multiclasse` | Três classes no mesmo registro |
| `interacao-todas-classes` | **As sete classes no mesmo registro**, sem interferência |
| `risco-falso-positivo` | Comportamento real em números longos que **não** são documento |

## Ordem das regras — três restrições verificadas por regressão

A ordem não é estilística. Cada uma destas foi comprovada quebrando de propósito:

| # | Restrição | O que acontece se inverter |
|---|---|---|
| 1 | **Telefone antes de documento** | `+5511987654321` casa a regra de 11 dígitos → `+551********21`. Mascarado, mas **errado**: perde o DDD e preserva 2 dígitos finais do número — o oposto do desejado |
| 2 | **Documento pontuado antes de documento seguido** | A forma pontuada deixa de casar |
| 3 | **Nome 3+ termos antes de nome 2 termos** | `Ana Beatriz Costa Lima` → `Ana ********** Beatriz Costa Lima`. **Nome completo exposto** atrás de máscara decorativa |

A primeira foi descoberta **pelo teste**, não por análise: o caso canônico de telefone falhou no RED com a saída já mascarada pela regra de documento.

## Decisão de projeto: chave de pagamento não duplica regras

Uma chave pode ser documento, telefone, correio eletrônico ou identificador aleatório. **Só a última tem regra própria** — as três primeiras são cobertas pelas regras dessas classes, independentemente do nome do campo.

**Verificado por teste** (`chavepgto-forma-alternativa`): as três formas são mascaradas corretamente sem regra dedicada. Duplicar seria redundância com risco de divergência.

## O que cada classe preserva, e por quê

| Classe | Preserva | Razão |
|---|---|---|
| Documento | 3 primeiros dígitos | Correlação de registros sem reconstrução |
| Nome | primeiro e último termo | Legibilidade em diagnóstico |
| Correio eletrônico | 2 do local + **domínio inteiro** | Domínio identifica provedor ou cliente corporativo, **não a pessoa** |
| Telefone | país + DDD | Região é útil em diagnóstico; o número não |
| Chave aleatória | primeiro e último bloco | Rastreabilidade sem reconstrução |
| **Endereço postal** | **nada — integral** | **Qualquer fragmento reduz drasticamente o espaço de busca da pessoa** |
| Identificador opaco | prefixo + 4 caracteres | Correlação do mesmo recurso |

O endereço é o único com mascaramento integral, e é decisão deliberada.

## ⚠️ Falso positivo conhecido e aceito

A regra de documento mascara **qualquer sequência de 11+ dígitos**:

```
latencia 12345678901234        → latencia 123********234
transactionId=98765432109876   → transactionId=987********876543210
```

**Trade-off aceito:** falso positivo (perde legibilidade em diagnóstico) é preferível a falso negativo (vaza documento).

**Alternativa avaliada e rejeitada:** exigir prefixo de campo (`documento=`, `cpf=`). Rejeitada porque documento aparece em log sem prefixo — o caso canônico da suíte é exatamente `documento 12345678901` em texto corrido.

**Está capturado como teste**, com o comportamento real documentado. Qualquer mudança nele passa a ser detectada.

**Item a medir:** quantos logs reais contêm sequência de 11+ dígitos que não seja documento. Se for volume alto, vale revisitar — mas a decisão de segurança não muda.

## Próximo passo

**ST-003-03 e seguintes:** traduzir as regras restantes (nome, correio eletrônico, endereço, telefone, chave de pagamento, identificador opaco), cada uma com as 4 categorias. O padrão de trabalho está estabelecido: caso primeiro (falha), regra depois (passa), quebra deliberada (detecta).

## Limite de alcance: CORPO de REGISTRO, e nada mais

Medido em cluster real (T-005), nao inferido do codigo. As 12 regras operam sobre
`body` dentro de `log_statements`. Consequencia direta:

| Onde o dado esta | Sanitizado |
|---|---|
| Corpo de registro de log | **Sim** — as 8 classes |
| Atributo de registro de log | **Nao** |
| Atributo de recurso | **Nao** |
| Ponto de dado de metrica (rotulo) | **Nao** |
| Atributo de span | **Nao** |

### Evidencia

Emitidos por uma aplicacao no cluster, atravessando o agente, lidos no destino:

```
metrica pagamentos_total, rotulo  cpf_titular    -> Str(529.982.247-25)      INTACTO
span    POST /transactions, attr  usuario_email  -> Str(titular@lerian.studio) INTACTO
registro de log, corpo            cpf=...        -> 529.***.***-**            MASCARADO
```

Mesmo CPF, mesmo agente, mesmo instante: mascarado no corpo, intacto no rotulo.

### Por que nao foi simplesmente estendido

Nao e uma linha a mais. Varrer atributo exige decidir **quais** — iterar sobre
todos custa CPU por registro no caminho quente, e enumerar uma lista fixa erra
por omissao no primeiro atributo novo que uma aplicacao inventar. Em metrica ha
agravante: rotulo faz parte da identidade da serie, entao reescrever rotulo
**cria serie nova** e mexe em cardinalidade — exatamente o que esta migracao
existe para reduzir.

### Mitigacao vigente

PII em rotulo de metrica ja e defeito de instrumentacao por outra razao: destroi
a cardinalidade. O caminho certo e nao emitir, e isso e responsabilidade da
biblioteca compartilhada, nao do agente.

**Fica registrado como lacuna conhecida**, para decisao explicita — nao como algo
que o arcabouco cobre e nao cobre.
