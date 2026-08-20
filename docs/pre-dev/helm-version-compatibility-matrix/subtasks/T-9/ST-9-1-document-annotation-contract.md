# ST-9-1 — Documentar o contrato da annotation em `helm-chart-standard.md`

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Adicionar uma subseção NOVA em `docs/helm-chart-standard.md` formalizando a annotation `lerian.studio/compatibility`: gramática (api-design §I.2), opcionalidade de `requires` no v1, e exemplos válido/inválido (api-design §I.4). NÃO altera regras existentes do contrato. Paralela — pode rodar a qualquer momento após T-2 estabilizar a gramática.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)" && test -f docs/helm-chart-standard.md && grep -c 'lerian.studio/chart-type' docs/helm-chart-standard.md
```
Saída esperada: o arquivo existe e retorna um número `>= 1` (a doc já menciona o precedente `chart-type`). Se o arquivo não existir, PARE e reporte ao orquestrador (path pode ter mudado).

## Files
- modify: `./docs/helm-chart-standard.md` (adicionar subseção ao final da seção de annotations)

## Steps

### Passo 1 — Localizar onde inserir (após a doc de `chart-type`)
```bash
cd "$(git rev-parse --show-toplevel)" && grep -n 'lerian.studio/chart-type' docs/helm-chart-standard.md
```
Saída esperada: número(s) de linha da menção existente. Insira a nova subseção logo APÓS o fim do bloco que documenta `chart-type` (próximo cabeçalho `##`/`###`).

### Passo 2 — Inserir a subseção
Adicione o seguinte trecho markdown na posição identificada (ajuste o nível de cabeçalho `###`/`####` para casar com a hierarquia local):
```markdown
### Annotation `lerian.studio/compatibility`

Declara a compatibilidade cruzada e a combinação testada de um chart. É
**opcional**: um chart sem esta annotation é tratado como "sem compatibilidade
declarada" (a matriz mostra só a janela de suporte derivada, sem coluna
"Requires").

O valor é uma **string** contendo um documento YAML embutido (block scalar `|`),
porque Helm exige `annotations` do tipo `map[string]string`.

#### Gramática (v1)

```
compatibility := requires? testedWith?
requires       := "requires:"   map<productKey, semverRange>   # OPCIONAL no v1
testedWith     := "testedWith:" map<productKey, exactVersion>  # preenchido no v1
productKey     := nome do chart publicado (ex.: "midaz-helm", "plugin-access-manager")
semverRange    := constraint Masterminds (ex.: ">=8.4.0 <9.0.0", "~8.4", "^8.4.0", "8.x || 9.x")
exactVersion   := versão semver exata (ex.: "8.6.0", "1.2.1-beta.11")
```

- `requires` pode ser omitido no v1 (relação técnica; quando presente, vira a
  coluna "Requires <produto>" no README).
- `testedWith` é a combinação validada no release (informativo). Derivável do
  release; preenchido no v1.
- Chaves desconhecidas são ignoradas com aviso (forward-compat aditiva).

#### Exemplo — completo

```yaml
annotations:
  lerian.studio/chart-type: multi-component
  lerian.studio/compatibility: |
    requires:
      midaz-helm: ">=8.4.0 <9.0.0"
    testedWith:
      midaz-helm: "8.6.0"
```

#### Exemplo — só `testedWith` (caso típico do v1)

```yaml
  lerian.studio/compatibility: |
    testedWith:
      midaz-helm: "8.6.0"
```

#### Exemplos inválidos (geram WARN, não bloqueiam no v1)

```yaml
# range não parseável (V4)
  lerian.studio/compatibility: |
    requires:
      midaz-helm: "maior que 8"
```

```yaml
# produto inexistente (V3)
  lerian.studio/compatibility: |
    requires:
      midaz-ledger: ">=8.0.0"
```

```yaml
# YAML quebrado — falta os dois-pontos (V1)
  lerian.studio/compatibility: |
    requires:
      midaz-helm ">=8.4.0"
```

> **v1 é não-bloqueante:** violações V1–V5 são emitidas como `WARN` pela
> ferramenta `generate-compatibility` (exit 0). A promoção a erro bloqueante é
> fase futura (backlog TODO-4).
```

### Passo 3 — Conferir que não quebrou markdown existente
```bash
cd "$(git rev-parse --show-toplevel)" && grep -c '^### Annotation `lerian.studio/compatibility`' docs/helm-chart-standard.md
```
Saída esperada: `1` (a subseção foi inserida exatamente uma vez).

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)" && grep -q 'testedWith' docs/helm-chart-standard.md && grep -q 'block scalar' docs/helm-chart-standard.md && echo "ST-9-1_OK"
```
Saída esperada: `ST-9-1_OK`.

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)" && git checkout docs/helm-chart-standard.md
```
