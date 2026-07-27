# ST-4-1 — Garantir JSON sem `tier` e conforme data-model §B (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Travar o contrato do `compatibility.json` com um teste: `schemaVersion:1`, `products{dir,current,cycles[]}`, cada cycle com `cycle/latest/supported` e `requires?/testedWith?` — e ZERO ocorrência da chave `tier` (tier é apresentação, nunca vai no JSON — data-model §1). A serialização já existe (T-1/T-3); este passo é a asserção formal do contrato.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestBuildDoc_Golden 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete T-3.)

## Files
- modify: `./.github/scripts/generate-compatibility/json_test.go` (novos casos)

## Steps

### Passo 1 (RED) — Teste de contrato (no-tier + campos obrigatórios)
Adicione ao final de `./.github/scripts/generate-compatibility/json_test.go`:
```go
func TestRenderJSON_NoTierField(t *testing.T) {
	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "test",
		Products: map[string]Product{
			"midaz-helm": {
				Dir:     "midaz",
				Current: "8.6.0",
				Cycles: []Cycle{
					{Cycle: "8.6", Latest: "8.6.0", Supported: true},
					{Cycle: "8.2", Latest: "8.2.0", Supported: false},
				},
			},
		},
	}
	out, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON: %v", err)
	}
	s := string(out)
	if strings.Contains(s, `"tier"`) {
		t.Fatalf("JSON must NOT contain a tier field (presentation-only)\n%s", s)
	}
	for _, must := range []string{`"cycle": "8.6"`, `"latest": "8.6.0"`, `"supported": true`, `"supported": false`} {
		if !strings.Contains(s, must) {
			t.Errorf("missing %q\n%s", must, s)
		}
	}
}

func TestRenderJSON_OmitsEmptyRequiresTestedWith(t *testing.T) {
	doc := CompatDoc{
		SchemaVersion: 1,
		Products: map[string]Product{
			"matcher-helm": {Dir: "matcher", Current: "3.0.0", Cycles: []Cycle{{Cycle: "3.0", Latest: "3.0.0", Supported: true}}},
		},
	}
	out, _ := renderJSON(doc)
	s := string(out)
	if strings.Contains(s, `"requires"`) || strings.Contains(s, `"testedWith"`) {
		t.Fatalf("empty maps must be omitted (omitempty)\n%s", s)
	}
}
```

Rode:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run 'TestRenderJSON_NoTierField|TestRenderJSON_OmitsEmpty' 2>&1 | tail -6
```
Se PASSAR de primeira: o contrato já está correto (structs de T-1 não têm `tier` e usam `omitempty`). Registre o pass como confirmação. Se FALHAR: siga o Passo 2.

### Passo 2 (GREEN, só se necessário) — Corrigir as structs
Se o teste falhou por conter `tier`, remova qualquer campo `Tier` das structs `Cycle`/`Product` em `generate-compatibility/json.go`. Se falhou por não omitir mapas vazios, confirme que `Requires`/`TestedWith` têm a tag `json:"...,omitempty"`. Depois rode o Passo 3.

### Passo 3 — Rodar os testes
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável) — grep no JSON real por `tier`
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output /tmp/compat-t4.json 2>/dev/null && ! grep -q '"tier"' /tmp/compat-t4.json && echo "NO_TIER_OK"
```
Saída esperada: `NO_TIER_OK` (o grep NÃO encontra `tier`).

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && git checkout generate-compatibility/json_test.go 2>/dev/null || true
```
