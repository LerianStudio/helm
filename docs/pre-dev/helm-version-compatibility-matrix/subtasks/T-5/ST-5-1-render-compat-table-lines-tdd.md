# ST-5-1 — Renderizar as linhas da tabela COMPAT com badges (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Função pura `renderCompatTable(product Product) []string`: recebe o `Product` (com cycles ordenados desc) e devolve as linhas markdown do bloco COMPAT — cabeçalho, separador e uma linha por cycle SUPORTADO com badge por posição (🟢N 🔵N-1 🟡N-2 🟠N-3), coluna "Requer &lt;produto&gt;" SÓ quando `requires` declarado no cycle, e os cycles EOL (`supported:false`) colapsados numa ÚNICA linha-resumo com 🔴. NÃO toca arquivos; só gera linhas. Reusa a estética de `tableutil.FormatTable` (separador `:---:`).

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete T-3/T-4.)

## Files
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/render_readme.go`
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/render_readme_test.go`

## Steps

### Passo 1 (RED) — Testes table-driven do render
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/render_readme_test.go`:
```go
package main

import (
	"strings"
	"testing"
)

func joined(lines []string) string { return strings.Join(lines, "\n") }

func TestRenderCompatTable(t *testing.T) {
	t.Run("badges by position + EOL summary line", func(t *testing.T) {
		p := Product{
			Dir: "midaz", Current: "8.6.0",
			Cycles: []Cycle{
				{Cycle: "8.6", Latest: "8.6.0", Supported: true},
				{Cycle: "8.5", Latest: "8.5.0", Supported: true},
				{Cycle: "8.4", Latest: "8.4.0", Supported: true},
				{Cycle: "8.3", Latest: "8.3.0", Supported: true},
				{Cycle: "8.2", Latest: "8.2.0", Supported: false},
			},
		}
		out := joined(renderCompatTable(p))
		for _, must := range []string{
			"| Version | Support |",
			"| :---: | :---: |",
			"🟢", "🔵", "🟡", "🟠", "🔴",
			"`8.6.0`", "`8.5.0`", "`8.4.0`", "`8.3.0`",
		} {
			if !strings.Contains(out, must) {
				t.Errorf("missing %q in:\n%s", must, out)
			}
		}
		// The single EOL summary must NOT list each EOL patch; one 🔴 line only.
		if strings.Count(out, "🔴") != 1 {
			t.Errorf("expected exactly one EOL (🔴) summary line, got %d\n%s", strings.Count(out, "🔴"), out)
		}
	})

	t.Run("requires adds a Requires column only when declared", func(t *testing.T) {
		p := Product{
			Dir: "plugin-fees", Current: "7.2.0",
			Cycles: []Cycle{
				{Cycle: "7.2", Latest: "7.2.0", Supported: true,
					Requires: map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"}},
			},
		}
		out := joined(renderCompatTable(p))
		if !strings.Contains(out, "Requires midaz-helm") {
			t.Errorf("expected Requires column header, got:\n%s", out)
		}
		if !strings.Contains(out, ">=8.4.0 <9.0.0") {
			t.Errorf("expected requires range in cell, got:\n%s", out)
		}
	})

	t.Run("no requires => no Requires column", func(t *testing.T) {
		p := Product{
			Dir: "matcher", Current: "3.0.0",
			Cycles: []Cycle{{Cycle: "3.0", Latest: "3.0.0", Supported: true}},
		}
		out := joined(renderCompatTable(p))
		if strings.Contains(out, "Requires") {
			t.Errorf("did not expect Requires column, got:\n%s", out)
		}
	})

	t.Run("all supported => no EOL line", func(t *testing.T) {
		p := Product{
			Dir: "x", Current: "3.0.0",
			Cycles: []Cycle{{Cycle: "3.0", Latest: "3.0.0", Supported: true}},
		}
		out := joined(renderCompatTable(p))
		if strings.Contains(out, "🔴") {
			t.Errorf("did not expect EOL line, got:\n%s", out)
		}
	})
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestRenderCompatTable 2>&1 | head -8
```
Saída esperada: `undefined: renderCompatTable` e `[build failed]`.

### Passo 2 (GREEN) — Implementar render_readme.go
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/render_readme.go`:
```go
package main

import (
	"fmt"
	"sort"
	"strings"
)

// positionBadge maps a supported cycle's position (0=N, 1=N-1, ...) to its
// emoji badge (data-model §1). Positions >=4 are never supported here.
var positionBadge = []string{"🟢", "🔵", "🟡", "🟠"}

// eolBadge is the single summary badge for all end-of-life cycles.
const eolBadge = "🔴"

// requiresHeaderPrefix labels the optional cross-compat column.
const requiresHeaderPrefix = "Requires"

// renderCompatTable produces the markdown lines for one product's compatibility
// block: a table whose supported cycles carry a position badge, an optional
// "Requires <product>" column when any supported cycle declares requires, and a
// single collapsed EOL summary row. Cycles must arrive ordered descending
// (index 0 = N); this function does not re-sort them.
func renderCompatTable(p Product) []string {
	// Split supported vs EOL, preserving order.
	var supported, eol []Cycle
	for _, c := range p.Cycles {
		if c.Supported {
			supported = append(supported, c)
		} else {
			eol = append(eol, c)
		}
	}

	// Determine whether any supported cycle declares requires, and collect the
	// distinct target products (sorted for determinism) for the column.
	requireTargets := map[string]bool{}
	for _, c := range supported {
		for target := range c.Requires {
			requireTargets[target] = true
		}
	}
	var targets []string
	for target := range requireTargets {
		targets = append(targets, target)
	}
	sort.Strings(targets)
	hasRequires := len(targets) > 0

	// Header.
	headers := []string{"Version", "Support"}
	for _, tgt := range targets {
		headers = append(headers, fmt.Sprintf("%s %s", requiresHeaderPrefix, tgt))
	}

	lines := []string{tableRow(headers), separator(len(headers))}

	// Supported rows.
	for i, c := range supported {
		badge := eolBadge
		if i < len(positionBadge) {
			badge = positionBadge[i]
		}
		row := []string{"`" + c.Latest + "`", badge}
		for _, tgt := range targets {
			row = append(row, c.Requires[tgt]) // empty string if not declared for this cycle
		}
		lines = append(lines, tableRow(row))
	}

	// Single collapsed EOL summary line.
	if len(eol) > 0 {
		cycles := make([]string, 0, len(eol))
		for _, c := range eol {
			cycles = append(cycles, c.Cycle)
		}
		summary := []string{eolBadge + " EOL: " + strings.Join(cycles, ", "), "unsupported"}
		for range targets {
			summary = append(summary, "")
		}
		lines = append(lines, tableRow(summary))
	}

	return lines
}

func tableRow(cells []string) string {
	return "| " + strings.Join(cells, " | ") + " |"
}

func separator(n int) string {
	seps := make([]string, n)
	for i := range seps {
		seps[i] = ":---:"
	}
	return "| " + strings.Join(seps, " | ") + " |"
}
```

### Passo 3 — Rodar os testes
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestRenderCompatTable 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-5-1_OK"
```
Saída esperada: termina com `ST-5-1_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/render_readme.go \
      /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/render_readme_test.go
```
