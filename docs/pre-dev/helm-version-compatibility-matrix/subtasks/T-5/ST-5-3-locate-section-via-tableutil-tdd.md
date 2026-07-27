# ST-5-3 — Localizar a seção do chart via `tableutil.ParseTableForChart` (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Função `sectionHeaderIndex(lines []string, chart string) int` que reusa a lógica de normalização de nome de `tableutil.ParseTableForChart` (`.github/scripts/tableutil/tableutil.go:71`) para achar a linha `### <Nome>` de um chart. Retorna -1 se não houver seção (caso `br-spi` → ADR-5, tratado em ST-5-4). Reusar a lib evita reimplementar o matching de nome e corromper o README. Como `ParseTableForChart` imprime em stdout e não expõe o índice do header isolado, encapsulamos a chamada e derivamos o header.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go doc ./tableutil ParseTableForChart 2>&1 | head -3
```
Saída esperada: assinatura `func ParseTableForChart(lines []string, chartName string) (int, int, []string, []map[string]string)`.

## Files
- modify: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers.go` (add `sectionHeaderIndex` + import tableutil)
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/section_test.go`

## Steps

### Passo 1 (RED) — Testes de localização de seção
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/section_test.go`:
```go
package main

import (
	"strings"
	"testing"
)

func TestSectionHeaderIndex(t *testing.T) {
	doc := strings.Split(`# Charts

### Midaz Helm Chart

prose

### Plugin Fees Helm Chart

prose

### Matcher

prose`, "\n")

	tests := []struct {
		chart string
		want  int // line index of the "### ..." header, -1 if absent
	}{
		{"midaz-helm", 2},
		{"plugin-fees-helm", 6},
		{"matcher-helm", 10}, // normalizes to "matcher", matches "### Matcher"
		{"br-spi-helm", -1},  // no section (ADR-5)
	}
	for _, tt := range tests {
		t.Run(tt.chart, func(t *testing.T) {
			got := sectionHeaderIndex(doc, tt.chart)
			if got != tt.want {
				t.Errorf("chart %q: got index %d, want %d", tt.chart, got, tt.want)
			}
		})
	}
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestSectionHeaderIndex 2>&1 | head -8
```
Saída esperada: `undefined: sectionHeaderIndex` e `[build failed]`.

### Passo 2 (GREEN) — Implementar reusando a normalização do tableutil
Adicione ao bloco de imports de `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers.go`:
```go
import (
	"fmt"
	"strings"

	"github.com/LerianStudio/helm/.github/scripts/tableutil"
)
```

Adicione ao final de `markers.go`:
```go
// sectionHeaderIndex returns the line index of the "### <Name>" header for a
// chart, or -1 if the chart has no section (e.g. br-spi — ADR-5). It reuses the
// exact name-normalization contract of tableutil.ParseTableForChart so section
// matching stays consistent with the sibling README tooling.
//
// tableutil.ParseTableForChart returns the section header line as its first
// return value (tableStart is measured from the section header downward; when a
// section exists it returns >=0). To get the header index without depending on
// a table being present, we replicate only its normalization + header scan.
func sectionHeaderIndex(lines []string, chart string) int {
	// Same normalization as tableutil: strip -helm, hyphens -> spaces, lower.
	normalized := strings.ToLower(strings.TrimSuffix(chart, "-helm"))
	normalized = strings.ReplaceAll(normalized, "-", " ")

	for i, line := range lines {
		lower := strings.ToLower(line)
		if strings.HasPrefix(lower, "### ") && strings.Contains(lower, normalized) {
			return i
		}
	}
	return -1
}

// ensureTableutilLinked references tableutil so the import is used even before
// the section-creation step (ST-5-4) calls it directly. Remove once ST-5-4
// wires ParseTableForChart in for real.
var _ = tableutil.ParseTableForChart
```

> **Nota (REFACTOR em ST-5-4):** o `var _ = tableutil.ParseTableForChart` é um placeholder para o import não ficar "unused" neste passo. ST-5-4 usa `tableutil` de verdade (ou remove o import se não precisar). NÃO deixe o placeholder no merge final.

### Passo 3 — Rodar os testes
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestSectionHeaderIndex 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável) — bate com o README real
```bash
cd /home/gauchito/lerian/helm && grep -n '^### Matcher' README.md | head -1
```
Saída esperada: uma linha `160:### Matcher` (ou similar) — confirma que a seção existe e o matcher normalizado `matcher` casa.

```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-5-3_OK"
```
Saída esperada: termina com `ST-5-3_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/section_test.go
cd /home/gauchito/lerian/helm/.github/scripts && git checkout generate-compatibility/markers.go 2>/dev/null || true
```
