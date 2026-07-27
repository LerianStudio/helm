# ST-2-2 — Validação V1–V6 da annotation como WARN/INFO (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Implementar `validateCompat(chart string, ann *CompatAnnotation, knownProducts map[string]bool) []Warning` que aplica as regras V1–V6 (api-design §I.3) SEM abortar: cada violação vira um `Warning` com regra + detalhe. Regras: V3 (produto inexistente), V4 (range `requires` não-parseável via Masterminds), V5 (`testedWith` não é versão exata), V6 (INFO se `testedWith` ausente). V1/V2 (YAML/chaves) já cobertos por ST-2-1 e pela struct tipada. Contrato de mensagem (api-design §II.3): `WARN <chart>: <regra> — <detalhe>`.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && grep -c compatAnnotationKey generate-compatibility/annotation.go
```
Saída esperada: número `>= 1` (ST-2-1 concluído).

## Files
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/warn.go`
- modify: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/annotation.go` (adiciona `validateCompat`)
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/warn_test.go`

## Steps

### Passo 1 (RED) — Teste table-driven das regras
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/warn_test.go`:
```go
package main

import (
	"testing"
)

func rulesOf(ws []Warning) []string {
	out := make([]string, 0, len(ws))
	for _, w := range ws {
		out = append(out, w.Rule)
	}
	return out
}

func containsRule(ws []Warning, rule string) bool {
	for _, r := range rulesOf(ws) {
		if r == rule {
			return true
		}
	}
	return false
}

func TestValidateCompat(t *testing.T) {
	known := map[string]bool{"midaz-helm": true, "plugin-fees-helm": true}

	tests := []struct {
		name      string
		ann       *CompatAnnotation
		wantRules []string // rules that MUST be present
		absent    []string // rules that must NOT be present
	}{
		{
			name:      "nil annotation => single V6 INFO",
			ann:       nil,
			wantRules: []string{"V6"},
		},
		{
			name: "valid complete => no warnings",
			ann: &CompatAnnotation{
				Requires:   map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"},
				TestedWith: map[string]string{"midaz-helm": "8.6.0"},
			},
			absent: []string{"V3", "V4", "V5", "V6"},
		},
		{
			name: "V3 unknown product in requires",
			ann: &CompatAnnotation{
				Requires: map[string]string{"midaz-ledger": ">=8.0.0"},
			},
			wantRules: []string{"V3"},
		},
		{
			name: "V4 unparseable range",
			ann: &CompatAnnotation{
				Requires: map[string]string{"midaz-helm": "maior que 8"},
			},
			wantRules: []string{"V4"},
		},
		{
			name: "V5 testedWith not an exact version",
			ann: &CompatAnnotation{
				TestedWith: map[string]string{"midaz-helm": ">=8.6.0"},
			},
			wantRules: []string{"V5"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := validateCompat("plugin-fees-helm", tt.ann, known)
			for _, r := range tt.wantRules {
				if !containsRule(got, r) {
					t.Errorf("expected rule %s in %v", r, rulesOf(got))
				}
			}
			for _, r := range tt.absent {
				if containsRule(got, r) {
					t.Errorf("did not expect rule %s in %v", r, rulesOf(got))
				}
			}
		})
	}
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestValidateCompat 2>&1 | head -10
```
Saída esperada: `undefined: Warning` / `undefined: validateCompat` e `[build failed]`.

### Passo 2 (GREEN) — Tipo `Warning` + emissor de mensagem estável
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/warn.go`:
```go
package main

import (
	"fmt"
	"io"
	"sort"
)

// Severity is the stable, CI-parseable prefix (api-design §II.3).
type Severity string

const (
	SevWarn Severity = "WARN"
	SevInfo Severity = "INFO"
)

// Warning is one diagnostic tied to a chart and a validation rule.
type Warning struct {
	Severity Severity
	Chart    string
	Rule     string // e.g. "V3", "V4", "V6"
	Detail   string
}

// Line renders the stable message contract: "WARN <chart>: <rule> — <detail>".
func (w Warning) Line() string {
	return fmt.Sprintf("%s %s: %s — %s", w.Severity, w.Chart, w.Rule, w.Detail)
}

// emitWarnings writes each warning as one line to stderr, sorted by chart then
// rule for deterministic output. Returns the count of SevWarn (not INFO).
func emitWarnings(stderr io.Writer, ws []Warning) int {
	sorted := make([]Warning, len(ws))
	copy(sorted, ws)
	sort.SliceStable(sorted, func(i, j int) bool {
		if sorted[i].Chart != sorted[j].Chart {
			return sorted[i].Chart < sorted[j].Chart
		}
		return sorted[i].Rule < sorted[j].Rule
	})
	warnCount := 0
	for _, w := range sorted {
		fmt.Fprintln(stderr, w.Line())
		if w.Severity == SevWarn {
			warnCount++
		}
	}
	return warnCount
}
```

### Passo 3 (GREEN) — `validateCompat` em annotation.go
Adicione ao FINAL de `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/annotation.go` (mantenha o import existente e ACRESCENTE os novos):

Primeiro, ajuste o bloco de imports no topo do arquivo para:
```go
import (
	"strings"

	"github.com/Masterminds/semver/v3"
	"gopkg.in/yaml.v3"
)
```

Depois, adicione ao final do arquivo:
```go
// validateCompat applies rules V3–V6 (api-design §I.3) without ever failing.
// V1 (valid YAML) and V2 (unknown keys) are handled by parseCompatAnnotation
// and the typed struct respectively. knownProducts is the set of chart names
// present in the repo, used for the V3 existence check.
func validateCompat(chart string, ann *CompatAnnotation, knownProducts map[string]bool) []Warning {
	var out []Warning

	if ann == nil || (len(ann.Requires) == 0 && len(ann.TestedWith) == 0) {
		// V6: testedWith is expected in v1 but its absence is INFO, not WARN.
		out = append(out, Warning{
			Severity: SevInfo,
			Chart:    chart,
			Rule:     "V6",
			Detail:   "no compatibility declared (testedWith expected in v1)",
		})
		return out
	}

	// V3 + V4: requires.
	for product, rng := range ann.Requires {
		if !knownProducts[product] {
			out = append(out, Warning{SevWarn, chart, "V3", fmt.Sprintf("requires[%s] — unknown chart", product)})
		}
		if _, err := semver.NewConstraint(rng); err != nil {
			out = append(out, Warning{SevWarn, chart, "V4", fmt.Sprintf("requires[%s] — invalid semver range %q", product, rng)})
		}
	}

	// V3 + V5: testedWith.
	for product, ver := range ann.TestedWith {
		if !knownProducts[product] {
			out = append(out, Warning{SevWarn, chart, "V3", fmt.Sprintf("testedWith[%s] — unknown chart", product)})
		}
		if _, err := semver.NewVersion(ver); err != nil {
			out = append(out, Warning{SevWarn, chart, "V5", fmt.Sprintf("testedWith[%s] — not an exact version %q", product, ver)})
		}
	}

	return out
}
```

Note: `fmt` já não estava importado em annotation.go — o `strings` estava. Se `go build` reclamar de `fmt` faltando, adicione `"fmt"` ao bloco de imports (ordem: `"fmt"`, `"strings"`, depois os externos).

### Passo 4 — Rodar o teste
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestValidateCompat 2>&1 | tail -3
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`.

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-2-2_OK"
```
Saída esperada: termina com `ST-2-2_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/warn.go \
      /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/warn_test.go
cd /home/gauchito/lerian/helm/.github/scripts && git checkout generate-compatibility/annotation.go 2>/dev/null || true
```
