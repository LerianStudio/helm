# ST-5-2 — Substituir bloco entre markers, idempotente e confinado (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Função pura `replaceCompatBlock(lines []string, chart string, blockBody []string) ([]string, bool, error)` que reescreve APENAS o conteúdo entre `<!-- BEGIN COMPAT:<chart> -->` e `<!-- END COMPAT:<chart> -->`, preservando byte-a-byte tudo fora dos markers. Idempotente: rodar 2× = mesma saída. Se os markers não existirem, retorna `found=false` (a criação de seção é ST-5-4). Este é o núcleo da mitigação do risco #1 (corromper README).

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestRenderCompatTable 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-5-1.)

## Files
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers.go`
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers_test.go`

## Steps

### Passo 1 (RED) — Testes: substituição confinada + idempotência + boundary irregular
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers_test.go`:
```go
package main

import (
	"strings"
	"testing"
)

func lns(s string) []string  { return strings.Split(s, "\n") }
func str(ls []string) string { return strings.Join(ls, "\n") }

func TestReplaceCompatBlock(t *testing.T) {
	t.Run("replaces only between markers, prose untouched", func(t *testing.T) {
		doc := lns(`### Midaz Helm Chart

Intro prose that must survive.

<!-- BEGIN COMPAT:midaz-helm -->
OLD CONTENT
<!-- END COMPAT:midaz-helm -->

-----------------

### Next Chart`)
		body := []string{"| Version | Support |", "| :---: | :---: |", "| ` + "`8.6.0`" + ` | 🟢 |"}
		out, found, err := replaceCompatBlock(doc, "midaz-helm", body)
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if !found {
			t.Fatal("expected found=true")
		}
		s := str(out)
		if !strings.Contains(s, "Intro prose that must survive.") {
			t.Error("prose above block was lost")
		}
		if !strings.Contains(s, "-----------------") {
			t.Error("separator below block was lost")
		}
		if !strings.Contains(s, "### Next Chart") {
			t.Error("next section header was lost")
		}
		if strings.Contains(s, "OLD CONTENT") {
			t.Error("old content not replaced")
		}
		if !strings.Contains(s, "8.6.0") {
			t.Error("new body not inserted")
		}
		// Markers themselves must be preserved exactly once each.
		if strings.Count(s, "<!-- BEGIN COMPAT:midaz-helm -->") != 1 ||
			strings.Count(s, "<!-- END COMPAT:midaz-helm -->") != 1 {
			t.Errorf("markers duplicated/lost:\n%s", s)
		}
	})

	t.Run("idempotent: applying twice yields identical output", func(t *testing.T) {
		doc := lns(`<!-- BEGIN COMPAT:x -->
whatever
<!-- END COMPAT:x -->`)
		body := []string{"NEW"}
		once, _, _ := replaceCompatBlock(doc, "x", body)
		twice, _, _ := replaceCompatBlock(once, "x", body)
		if str(once) != str(twice) {
			t.Fatalf("not idempotent:\n--once--\n%s\n--twice--\n%s", str(once), str(twice))
		}
	})

	t.Run("markers absent => found=false, doc unchanged", func(t *testing.T) {
		doc := lns("### Some Chart\n\nno markers here")
		out, found, err := replaceCompatBlock(doc, "some-chart", []string{"BODY"})
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if found {
			t.Fatal("expected found=false")
		}
		if str(out) != str(doc) {
			t.Fatal("doc changed despite absent markers")
		}
	})

	t.Run("only END marker => error (malformed)", func(t *testing.T) {
		doc := lns("<!-- END COMPAT:x -->")
		_, _, err := replaceCompatBlock(doc, "x", []string{"B"})
		if err == nil {
			t.Fatal("expected error for END-without-BEGIN")
		}
	})
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestReplaceCompatBlock 2>&1 | head -8
```
Saída esperada: `undefined: replaceCompatBlock` e `[build failed]`.

### Passo 2 (GREEN) — Implementar markers.go
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers.go`:
```go
package main

import (
	"fmt"
	"strings"
)

// beginMarker / endMarker build the HTML-comment sentinels for a chart's block.
// Only content strictly between them is ever rewritten (terraform-docs pattern),
// which keeps hand-written prose and irregular separators intact.
func beginMarker(chart string) string { return "<!-- BEGIN COMPAT:" + chart + " -->" }
func endMarker(chart string) string   { return "<!-- END COMPAT:" + chart + " -->" }

// replaceCompatBlock replaces the lines between the BEGIN/END markers for the
// given chart with blockBody, preserving everything outside the markers exactly.
// Returns found=false (and the document unchanged) when the BEGIN marker is
// absent, so the caller can decide to create a section instead. Returns an error
// for a malformed document (END without BEGIN, or BEGIN without END).
func replaceCompatBlock(lines []string, chart string, blockBody []string) ([]string, bool, error) {
	begin, end := beginMarker(chart), endMarker(chart)

	beginIdx, endIdx := -1, -1
	for i, line := range lines {
		switch strings.TrimSpace(line) {
		case begin:
			beginIdx = i
		case end:
			endIdx = i
		}
	}

	if beginIdx == -1 && endIdx == -1 {
		return lines, false, nil
	}
	if beginIdx == -1 || endIdx == -1 || endIdx < beginIdx {
		return nil, false, fmt.Errorf("malformed COMPAT markers for %q (begin=%d end=%d)", chart, beginIdx, endIdx)
	}

	out := make([]string, 0, len(lines)-(endIdx-beginIdx)+len(blockBody)+2)
	out = append(out, lines[:beginIdx+1]...) // keep everything up to & including BEGIN
	out = append(out, blockBody...)          // fresh body
	out = append(out, lines[endIdx:]...)     // END marker onward, unchanged
	return out, true, nil
}
```

### Passo 3 — Rodar os testes
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestReplaceCompatBlock 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-5-2_OK"
```
Saída esperada: termina com `ST-5-2_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers.go \
      /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers_test.go
```
