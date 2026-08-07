# ST-1-4 — `main()` executável: emite `compatibility.json` só com `current` (esqueleto demoável)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Amarrar `chartDirectories` + `readChartState` num `main()` executável que produz um `compatibility.json` determinístico com `schemaVersion:1` e `products{<name>:{dir,current}}` para todos os charts. Flags mínimas: `--root` (default `../..`) e `--output` (default `docs/compatibility.json`). Demoável: `go run ./generate-compatibility --root ../..`.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`
(Se falhar, execute ST-1-2 e ST-1-3 primeiro.)

## Files
- create: `./.github/scripts/generate-compatibility/main.go`
- create: `./.github/scripts/generate-compatibility/json.go`
- create: `./.github/scripts/generate-compatibility/json_test.go`

## Steps

### Passo 1 (RED) — Teste de serialização determinística
Crie `./.github/scripts/generate-compatibility/json_test.go`:
```go
package main

import (
	"strings"
	"testing"
)

func TestRenderJSON_DeterministicAndSchemaV1(t *testing.T) {
	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "test",
		Products: map[string]Product{
			"plugin-fees-helm": {Dir: "plugin-fees", Current: "7.2.0"},
			"midaz-helm":       {Dir: "midaz", Current: "8.6.0"},
		},
	}

	out1, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON: %v", err)
	}
	out2, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON (2nd): %v", err)
	}
	if string(out1) != string(out2) {
		t.Fatal("renderJSON not deterministic across runs")
	}

	s := string(out1)
	if !strings.Contains(s, `"schemaVersion": 1`) {
		t.Errorf("missing schemaVersion:1\n%s", s)
	}
	// Products must be emitted in sorted key order: midaz-helm before plugin-fees-helm.
	iMidaz := strings.Index(s, "midaz-helm")
	iFees := strings.Index(s, "plugin-fees-helm")
	if iMidaz == -1 || iFees == -1 || iMidaz > iFees {
		t.Errorf("products not in sorted order\n%s", s)
	}
	if !strings.HasSuffix(s, "\n") {
		t.Error("output must end with a trailing newline")
	}
}
```

Rode e capture a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestRenderJSON 2>&1 | head -10
```
Saída esperada: `undefined: CompatDoc` / `undefined: renderJSON` e `FAIL ... [build failed]`.

### Passo 2 (GREEN) — Structs do JSON + render determinístico
Crie `./.github/scripts/generate-compatibility/json.go`:
```go
package main

import (
	"bytes"
	"encoding/json"
)

// CompatDoc is the root of docs/compatibility.json (data-model §B.1).
type CompatDoc struct {
	SchemaVersion int                `json:"schemaVersion"`
	GeneratedFrom string             `json:"generatedFrom"`
	Products      map[string]Product `json:"products"`
}

// Product is one chart's projection (data-model §B.2).
// Cycles is added in T-3/T-4; T-1 emits only dir + current.
type Product struct {
	Dir     string  `json:"dir"`
	Current string  `json:"current"`
	Cycles  []Cycle `json:"cycles,omitempty"`
}

// Cycle is one minor-cycle line (data-model §B.3). Populated from T-3 onward.
type Cycle struct {
	Cycle      string            `json:"cycle"`
	Latest     string            `json:"latest"`
	Supported  bool              `json:"supported"`
	Requires   map[string]string `json:"requires,omitempty"`
	TestedWith map[string]string `json:"testedWith,omitempty"`
}

// renderJSON marshals the document deterministically (Go's encoding/json sorts
// map keys) with two-space indent and a trailing newline, matching the sibling
// generate-values-schemas output style.
func renderJSON(doc CompatDoc) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	if err := enc.Encode(doc); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
```

### Passo 3 (GREEN) — `main()` que amarra tudo
Crie `./.github/scripts/generate-compatibility/main.go`:
```go
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	root := flag.String("root", "../..", "Repository root containing the charts/ directory")
	output := flag.String("output", "docs/compatibility.json", "Destination for the JSON artifact (relative to --root)")
	flag.Parse()

	doc, err := buildDoc(*root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR %v\n", err)
		os.Exit(1)
	}

	data, err := renderJSON(doc)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR marshal compatibility.json: %v\n", err)
		os.Exit(1)
	}

	outPath := filepath.Join(*root, *output)
	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR write %s: %v\n", outPath, err)
		os.Exit(1)
	}

	fmt.Printf("wrote %s (%d products)\n", outPath, len(doc.Products))
}

// buildDoc reads every chart under <root>/charts and assembles the document.
// T-1 fills only dir + current per product; cycles/requires/testedWith arrive
// in later subtasks.
func buildDoc(root string) (CompatDoc, error) {
	dirs, err := chartDirectories(root)
	if err != nil {
		return CompatDoc{}, fmt.Errorf("list charts: %w", err)
	}

	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "local",
		Products:      map[string]Product{},
	}

	for _, dir := range dirs {
		state, err := readChartState(root, dir)
		if err != nil {
			// A chart without a parseable Chart.yaml is skipped with a warning;
			// it must never abort the whole run (ADR-4).
			fmt.Fprintf(os.Stderr, "WARN %s: cannot read Chart.yaml — %v\n", dir, err)
			continue
		}
		if state.Name == "" {
			fmt.Fprintf(os.Stderr, "WARN %s: Chart.yaml has no name; skipping\n", dir)
			continue
		}
		doc.Products[state.Name] = Product{
			Dir:     state.Dir,
			Current: state.Version,
		}
	}

	return doc, nil
}
```

### Passo 4 — Rodar testes
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -3
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`.

### Passo 5 — DEMO: rodar contra o repo real
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output docs/compatibility.json && head -12 ../../docs/compatibility.json
```
Saída esperada: uma linha `wrote ../../docs/compatibility.json (N products)` (N ~= 21) seguida do início do JSON:
```
{
  "schemaVersion": 1,
  "generatedFrom": "local",
  "products": {
    "br-sisbajud-helm": {
      "dir": "br-sisbajud",
      "current": "..."
    },
```
(Nomes/versões exatos variam; o importante é `schemaVersion:1` e um bloco por produto com `dir`+`current`.)

## Verification (copiável) — determinismo 2×
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && \
  go run ./generate-compatibility --root ../.. --output /tmp/compat-a.json && \
  go run ./generate-compatibility --root ../.. --output /tmp/compat-b.json && \
  diff /tmp/compat-a.json /tmp/compat-b.json && echo "DETERMINISTIC_OK"
```
Saída esperada: `DETERMINISTIC_OK` (sem linhas de diff).

## Rollback
```bash
rm -f ./.github/scripts/generate-compatibility/main.go \
      ./.github/scripts/generate-compatibility/json.go \
      ./.github/scripts/generate-compatibility/json_test.go
cd "$(git rev-parse --show-toplevel)" && git checkout docs/compatibility.json 2>/dev/null || rm -f docs/compatibility.json
```
