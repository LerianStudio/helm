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
./verificar.sh telefone-canonico  # um caso
```

Código de saída 0 = liberado. Diferente de 0 = bloqueado.

## Porta de entrega — 6 verificações bloqueantes

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

## Estado: 7 classes, 10 regras, 49 casos

| Classe | Casos | Regras |
|---|---|---|
| Nome de pessoa (`nome`, `nomejson`, `nomeparticula`) | 15 | 1 |
| Correio eletrônico | 5 | 1 |
| Telefone | 5 | 2 (E.164 + nacional) |
| Conta e agência | 5 | 2 |
| Chave Pix | 5 | 1 (por rótulo) |
| Endereço postal | 5 | 1 (integral) |
| Credencial | 5 | 2 (esquema/chave + atribuição) |

CPF, CNPJ, matrícula, número de contrato, UUID e id de recurso ficam em **claro** por
decisão (2026-10-10); `risco-falso-positivo` falha se alguma regra voltar a mascará-los.

Mais três casos além das 4 categorias por classe:

| Caso | Verifica |
|---|---|
| `interacao-multiclasse` | Três classes no mesmo registro |
| `interacao-todas-classes` | **Todas as classes no mesmo registro**, sem interferência |
| `risco-falso-positivo` | Identificadores decididos em claro saem **intactos** |

## Decisão: chave Pix por rótulo

CPF, CNPJ e UUID ficam em claro, então a chave Pix é mascarada pelo **rótulo**
(`chave_pix`, `chavePix`, `pix_key`, `pixKey`, inclusive em JSON), valor inteiro.
Sem rótulo, vale a forma do valor: e-mail e telefone mascarados, CPF e UUID em claro.

## O que cada classe preserva, e por quê

| Classe | Preserva | Razão |
|---|---|---|
| Nome | primeiro e último termo | Legibilidade em diagnóstico |
| Correio eletrônico | 2 do local + **domínio inteiro** | Domínio identifica provedor ou cliente corporativo, **não a pessoa** |
| Telefone | país + DDD | Região é útil em diagnóstico; o número não |
| Chave Pix | nada, só o rótulo | O valor pode ser CPF ou UUID, que não têm forma própria a mascarar |
| **Endereço postal** | **nada — integral** | **Qualquer fragmento reduz drasticamente o espaço de busca da pessoa** |

O endereço é o único com mascaramento integral, e é decisão deliberada.

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
(Medido com a regra de documento, removida em 2026-10-10; o limite vale para toda regra.)

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

## Segundo limite: corpo NÃO-STRING atravessa intocado

`replace_pattern` opera sobre `body` como **string**. Um corpo `kvlist`/`map`
(OTLP permite) passa por todas as 8 classes sem ser tocado, e sob
`error_mode = "ignore"` isso não gera erro nem aviso.

### Medido, não suposto

Amostrei 20 registros reais chegando ao destino na benedita, de 7 serviços
distintos: **20 de 20 têm corpo string.** A lacuna não se manifesta no tráfego
atual — mas o mecanismo permite, e "hoje ninguém faz" não é controle.

### Por que não foi fechado agora

As opções são caras ou destrutivas:

| Opção | Custo |
|---|---|
| Descartar corpo não-string | perde dado legítimo de aplicação que logue estruturado |
| Normalizar para string antes | reescreve o corpo de TODA aplicação, mudando o formato que os painéis consomem |
| Sanitizar recursivamente o mapa | OTTL não tem iteração sobre mapa aninhado nesta versão |

A decisão é de produto, não de implementação, e depende de saber se alguma
aplicação nossa pretende logar estruturado.

### O que fica no lugar

O caso `risco-corpo-estruturado` **é um teste que passa reconhecendo a lacuna**,
não ignorando-a. E ele falha se a premissa mudar: se o agente passar a emitir
corpo string para essa entrada, o caso quebra e alguém revisita.

O verificador trata o marcador `__CORPO_NAO_STRING__` de forma explícita, porque a
evidência aqui é a **ausência** de uma linha `Body: Str(` — comparar texto nunca
detectaria isso.

## As 10 regras são de DUAS naturezas — e isso decide o que elas resistem

Distinção que não estava escrita e é a mais importante deste arquivo:

| | Reconhece por | Se a aplicação renomear o campo |
|---|---|---|
| **Por FORMA** | a forma do próprio valor | **continua mascarando** |
| **Por NOME DE CAMPO** | um rótulo esperado | **passa em claro** |

**Por forma:** telefone, e-mail e a forma de esquema da credencial (`Bearer <token>`).

**Por nome de campo:** nome de pessoa, conta e agência, chave Pix, endereço, e a
credencial por chave ou atribuição (`token=`, `password=`).

### Por que as ancoradas não podem simplesmente ser convertidas

`João Silva` é indistinguível de `Rua Augusta` sem o rótulo do campo. Nome e
endereço **não têm forma distintiva**, então a âncora é inevitável — é propriedade do
dado, não atalho de implementação.

### O tamanho da exposição, medido

500 registros reais de um cluster em operação: **22 nomes de campo distintos, e
NENHUM** era um dos rótulos que as regras ancoradas procuram. Essas regras
protegem uma convenção de nomenclatura que nada obriga.

### Ao editar uma regra ancorada

Acrescentar um rótulo à lista (`beneficiario`, `nomeCliente`, `pix_key`) é **baixo
risco e alto retorno** — cada rótulo novo é cobertura que não existia. Remover um é
o oposto, e a porta só percebe se algum dos 36 casos usar aquele rótulo:
**verificado por injeção** — retirar apenas `holder` expõe `holderName=Ana Silva` e a
porta libera com "36 casos, 0 falhas".

Se remover um rótulo, escreva um caso para ele antes, para que a remoção apareça.
