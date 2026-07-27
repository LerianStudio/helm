# ST-5-4 — `ensureCompatBlock`: injetar markers em seção existente OU criar seção mínima (ADR-5) (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Função `ensureCompatBlock(lines []string, chart string, blockBody []string) ([]string, error)` que:
1. Se os markers já existem → delega a `replaceCompatBlock` (ST-5-2).
2. Senão, se a seção `### <Nome>` existe → insere um par de markers + body logo APÓS o cabeçalho da seção (sem tocar a prosa/tabela existente abaixo).
3. Senão (ADR-5, ex.: `br-spi`) → cria uma seção mínima (`### <Título>` + markers + body) no fim do documento, sem inventar dados fora dos markers.
Idempotente nos 3 caminhos.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run 'TestReplaceCompatBlock|TestSectionHeaderIndex' 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-5-2 e ST-5-3.)

## Files
- modify: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/markers.go` (add `ensureCompatBlock` + `sectionTitle`; remover o placeholder `var _ = tableutil...` de ST-5-3)
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/ensure_test.go`

## Steps

### Passo 1 (RED) — Testes dos 3 caminhos + idempotência
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/ensure_test.go`:
```go
package main

import (
	"strings"
	"testing"
)

func TestEnsureCompatBlock(t *testing.T) {
	body := []string{"| Version | Support |", "| :---: | :---: |", "| `1.0.0` | 🟢 |"}

	t.Run("existing markers => replace path", func(t *testing.T) {
		doc := strings.Split("### X\n\n<!-- BEGIN COMPAT:x-helm -->\nOLD\n<!-- END COMPAT:x-helm -->", "\n")
		out, err := ensureCompatBlock(doc, "x-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		s := strings.Join(out, "\n")
		if strings.Contains(s, "OLD") || !strings.Contains(s, "1.0.0") {
			t.Errorf("replace path failed:\n%s", s)
		}
	})

	t.Run("section exists, no markers => inject after header, prose kept", func(t *testing.T) {
		doc := strings.Split("### Matcher\n\nExisting prose.\n\n#### Application Version Mapping\n\n| Chart Version | Matcher Version |\n| :---: | :---: |\n| `3.0.0` | 1.0.0 |", "\n")
		out, err := ensureCompatBlock(doc, "matcher-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		s := strings.Join(out, "\n")
		if !strings.Contains(s, "Existing prose.") {
			t.Error("prose lost")
		}
		if !strings.Contains(s, "| Chart Version | Matcher Version |") {
			t.Error("existing table lost")
		}
		if !strings.Contains(s, "<!-- BEGIN COMPAT:matcher-helm -->") {
			t.Error("markers not injected")
		}
		if !strings.Contains(s, "1.0.0") {
			t.Error("body not injected")
		}
		// Injected block must sit right after the header, before existing prose.
		beginIdx := indexOfLine(out, "<!-- BEGIN COMPAT:matcher-helm -->")
		proseIdx := indexOfLine(out, "Existing prose.")
		if beginIdx == -1 || proseIdx == -1 || beginIdx > proseIdx {
			t.Errorf("block not placed after header/before prose (begin=%d prose=%d)", beginIdx, proseIdx)
		}
	})

	t.Run("no section (ADR-5 br-spi) => create minimal section at end", func(t *testing.T) {
		doc := strings.Split("# Charts\n\n### Midaz Helm Chart\n\nprose", "\n")
		out, err := ensureCompatBlock(doc, "br-spi-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		s := strings.Join(out, "\n")
		if !strings.Contains(s, "### Br Spi") {
			t.Errorf("minimal section title not created:\n%s", s)
		}
		if !strings.Contains(s, "<!-- BEGIN COMPAT:br-spi-helm -->") {
			t.Error("markers not created")
		}
		if !strings.Contains(s, "prose") || !strings.Contains(s, "### Midaz Helm Chart") {
			t.Error("existing content disturbed")
		}
	})

	t.Run("idempotent across all paths", func(t *testing.T) {
		doc := strings.Split("# Charts\n\n### Midaz Helm Chart\n\nprose", "\n")
		once, _ := ensureCompatBlock(doc, "br-spi-helm", body)
		twice, _ := ensureCompatBlock(once, "br-spi-helm", body)
		if strings.Join(once, "\n") != strings.Join(twice, "\n") {
			t.Fatalf("not idempotent:\n--once--\n%s\n--twice--\n%s", strings.Join(once, "\n"), strings.Join(twice, "\n"))
		}
	})
}

func indexOfLine(lines []string, want string) int {
	for i, l := range lines {
		if strings.TrimSpace(l) == want {
			return i
		}
	}
	return -1
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestEnsureCompatBlock 2>&1 | head -8
```
Saída esperada: `undefined: ensureCompatBlock` e `[build failed]`.

### Passo 2 (GREEN) — Implementar ensureCompatBlock em markers.go
Primeiro, REMOVA o placeholder de ST-5-3 (a linha `var _ = tableutil.ParseTableForChart` e o comentário acima dela). Se `tableutil` ficar sem uso, remova-o do import de `markers.go` (deixe só `fmt` e `strings`). Confirme com `go build`.

Adicione ao final de `markers.go`:
```go
// sectionTitle renders the human title used when a chart has no README section
// (ADR-5): strip -helm, hyphens -> spaces, Title Case. e.g. "br-spi-helm" ->
// "Br Spi". Mirrors the tableutil normalization, then title-cases for display.
func sectionTitle(chart string) string {
	base := strings.TrimSuffix(chart, "-helm")
	words := strings.Split(strings.ReplaceAll(base, "-", " "), " ")
	for i, w := range words {
		if w == "" {
			continue
		}
		words[i] = strings.ToUpper(w[:1]) + w[1:]
	}
	return strings.Join(words, " ")
}

// ensureCompatBlock guarantees the chart's COMPAT block reflects blockBody,
// choosing one of three paths (all idempotent):
//  1. markers already present  -> replace their contents (replaceCompatBlock);
//  2. section header present, no markers -> inject markers+body just after it;
//  3. no section (ADR-5)       -> append a minimal section (title + block) at
//     end of document, without touching existing prose.
func ensureCompatBlock(lines []string, chart string, blockBody []string) ([]string, error) {
	// Path 1: markers exist -> replace.
	replaced, found, err := replaceCompatBlock(lines, chart, blockBody)
	if err != nil {
		return nil, err
	}
	if found {
		return replaced, nil
	}

	block := wrapBlock(chart, blockBody)

	// Path 2: section exists -> inject right after the header line.
	if idx := sectionHeaderIndex(lines, chart); idx != -1 {
		out := make([]string, 0, len(lines)+len(block)+1)
		out = append(out, lines[:idx+1]...) // through the "### ..." header
		out = append(out, "")               // blank line after header
		out = append(out, block...)
		out = append(out, lines[idx+1:]...)
		return out, nil
	}

	// Path 3: no section -> minimal section at end (ADR-5).
	out := make([]string, 0, len(lines)+len(block)+3)
	out = append(out, lines...)
	out = append(out, "", "### "+sectionTitle(chart), "")
	out = append(out, block...)
	return out, nil
}

// wrapBlock frames blockBody with the BEGIN/END markers for a chart.
func wrapBlock(chart string, blockBody []string) []string {
	out := make([]string, 0, len(blockBody)+2)
	out = append(out, beginMarker(chart))
	out = append(out, blockBody...)
	out = append(out, endMarker(chart))
	return out
}
```

### Passo 3 — Rodar os testes
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestEnsureCompatBlock 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-5-4_OK"
```
Saída esperada: termina com `ST-5-4_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/ensure_test.go
cd /home/gauchito/lerian/helm/.github/scripts && git checkout generate-compatibility/markers.go 2>/dev/null || true
```
