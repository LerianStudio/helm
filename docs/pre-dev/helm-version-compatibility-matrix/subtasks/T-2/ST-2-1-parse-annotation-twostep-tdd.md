# ST-2-1 — Two-step unmarshal da annotation `lerian.studio/compatibility` (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Ler a annotation `lerian.studio/compatibility` (string YAML embutida) via TWO-STEP unmarshal e parseá-la em `CompatAnnotation{Requires, TestedWith}` (data-model §A.1). Precedente da leitura de annotation: `validate-helm-charts/main.go:21` (`chartTypeAnnotation`) lido via `chart.Annotations[...]` (`:244`). A nova chave é `"lerian.studio/compatibility"`. Ausência = válida (nil). YAML embutido quebrado NÃO aborta — retorna erro tratável pelo chamador (WARN em ST-2-2).

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`
(Se falhar, complete T-1 primeiro.)

## Files
- create: `./.github/scripts/generate-compatibility/annotation.go`
- create: `./.github/scripts/generate-compatibility/annotation_test.go`

## Steps

### Passo 1 (RED) — Teste table-driven cobrindo válido/ausente/quebrado
Crie `./.github/scripts/generate-compatibility/annotation_test.go`:
```go
package main

import (
	"reflect"
	"testing"
)

func TestParseCompatAnnotation(t *testing.T) {
	tests := []struct {
		name      string
		raw       string
		want      *CompatAnnotation
		wantError bool
	}{
		{
			name: "complete requires + testedWith",
			raw: `requires:
  midaz-helm: ">=8.4.0 <9.0.0"
testedWith:
  midaz-helm: "8.6.0"
`,
			want: &CompatAnnotation{
				Requires:   map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"},
				TestedWith: map[string]string{"midaz-helm": "8.6.0"},
			},
		},
		{
			name: "only testedWith (typical v1 post-backfill)",
			raw: `testedWith:
  midaz-helm: "8.6.0"
`,
			want: &CompatAnnotation{
				TestedWith: map[string]string{"midaz-helm": "8.6.0"},
			},
		},
		{
			name: "empty string => nil (absent)",
			raw:  "",
			want: nil,
		},
		{
			name:      "broken embedded YAML => error (V1)",
			raw:       "requires:\n  midaz-helm \">=8.4.0\"\n", // missing colon
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseCompatAnnotation(tt.raw)
			if (err != nil) != tt.wantError {
				t.Fatalf("err = %v, wantError = %v", err, tt.wantError)
			}
			if tt.wantError {
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}
```

Rode e capture a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestParseCompatAnnotation 2>&1 | head -10
```
Saída esperada: `undefined: CompatAnnotation` / `undefined: parseCompatAnnotation` e `FAIL ... [build failed]`.

### Passo 2 (GREEN) — Implementar o parse (segundo passo do two-step)
Crie `./.github/scripts/generate-compatibility/annotation.go`:
```go
package main

import (
	"strings"

	"gopkg.in/yaml.v3"
)

// compatAnnotationKey is the reverse-DNS annotation carrying compatibility data.
// It follows the precedent of lerian.studio/chart-type
// (validate-helm-charts/main.go:21).
const compatAnnotationKey = "lerian.studio/compatibility"

// CompatAnnotation is the parsed representation of the embedded YAML in the
// lerian.studio/compatibility annotation (data-model §A.1). Both maps are
// optional in v1; a wholly absent annotation is represented by a nil pointer.
type CompatAnnotation struct {
	Requires   map[string]string `yaml:"requires"`
	TestedWith map[string]string `yaml:"testedWith"`
}

// parseCompatAnnotation is the SECOND step of the two-step unmarshal: the caller
// has already pulled the annotation string out of Chart.yaml.annotations; here
// we unmarshal that embedded YAML document. An empty/whitespace-only string
// means "no annotation declared" and returns (nil, nil). Broken YAML returns an
// error so the caller can emit a V1 WARN and continue (never aborts).
func parseCompatAnnotation(raw string) (*CompatAnnotation, error) {
	if strings.TrimSpace(raw) == "" {
		return nil, nil
	}
	var ann CompatAnnotation
	if err := yaml.Unmarshal([]byte(raw), &ann); err != nil {
		return nil, err
	}
	return &ann, nil
}
```

### Passo 3 — Rodar o teste
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestParseCompatAnnotation 2>&1 | tail -3
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ && echo "ST-2-1_OK"
```
Saída esperada: termina com `ST-2-1_OK`.

## Rollback
```bash
rm -f ./.github/scripts/generate-compatibility/annotation.go \
      ./.github/scripts/generate-compatibility/annotation_test.go
```
