# ST-3-4 — Ligar `resolveWindow` no `buildDoc` + golden test do JSON com cycles (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Injetar um `tagLister` no `buildDoc`, resolver a janela por produto e preencher `Product.Cycles`. Validar com um GOLDEN test que usa um `tagLister` de fixture (sem git real) e um repo temporário — prova o pipeline C-1→C-2→C-3b ponta a ponta de forma determinística e offline.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestResolveWindow 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-3-3.)

## Files
- modify: `./.github/scripts/generate-compatibility/main.go` (`buildDoc` recebe `tagLister`)
- create: `./.github/scripts/generate-compatibility/builddoc_test.go`
- create: `./.github/scripts/generate-compatibility/testdata/golden_two_products.json`

## Steps

### Passo 1 (RED) — Golden test com fixture lister
Crie `./.github/scripts/generate-compatibility/builddoc_test.go`:
```go
package main

import (
	"os"
	"path/filepath"
	"testing"
)

// fakeTagLister returns canned tags per dir.
type fakeTagLister struct {
	tags map[string][]string
}

func (f fakeTagLister) listTags(dir string) ([]string, error) {
	return f.tags[dir], nil
}

func TestBuildDoc_Golden(t *testing.T) {
	root := t.TempDir()

	// midaz: N=8.6.0, tags cover 8.6..8.2.
	writeChart(t, root, "midaz", `apiVersion: v2
name: midaz-helm
type: application
version: 8.6.0
appVersion: "3.7.8"
`)
	// plugin-fees: N=7.2.0, only its own tag; declares requires+testedWith.
	writeChart(t, root, "plugin-fees", `apiVersion: v2
name: plugin-fees-helm
type: application
version: 7.2.0
appVersion: "3.3.0"
annotations:
  lerian.studio/compatibility: |
    requires:
      midaz-helm: ">=8.4.0 <9.0.0"
    testedWith:
      midaz-helm: "8.6.0"
`)

	lister := fakeTagLister{tags: map[string][]string{
		"midaz": {
			"midaz-v8.6.0", "midaz-v8.5.0", "midaz-v8.4.0",
			"midaz-v8.3.0", "midaz-v8.2.0", "midaz-v8.6.0-beta.11",
		},
		"plugin-fees": {"plugin-fees-v7.2.0"},
	}}

	doc, err := buildDoc(root, lister)
	if err != nil {
		t.Fatalf("buildDoc: %v", err)
	}
	doc.GeneratedFrom = "test" // pin the provenance field for a stable golden

	got, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON: %v", err)
	}

	goldenPath := filepath.Join("testdata", "golden_two_products.json")
	if os.Getenv("UPDATE_GOLDEN") == "1" {
		if err := os.WriteFile(goldenPath, got, 0o644); err != nil {
			t.Fatalf("update golden: %v", err)
		}
	}
	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden (run with UPDATE_GOLDEN=1 first): %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("JSON mismatch.\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}
```

Rode e capture a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestBuildDoc_Golden 2>&1 | head -8
```
Saída esperada: `too many arguments in call to buildDoc` (a assinatura ainda é `buildDoc(root)`), `[build failed]`.

### Passo 2 (GREEN) — `buildDoc` recebe `tagLister` e preenche cycles
Em `./.github/scripts/generate-compatibility/main.go`:

Atualize a chamada em `main()` para construir o lister real e passá-lo:
```go
	doc, err := buildDoc(*root, gitTagLister{root: *root})
```

Substitua a assinatura e o segundo passo de `buildDoc`. A primeira metade (leitura de states + knownProducts) permanece; troque só a assinatura e o loop final:

Assinatura:
```go
func buildDoc(root string, lister tagLister) (CompatDoc, error) {
```

Segundo passo (loop final) — substitua por:
```go
	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "local",
		Products:      map[string]Product{},
	}
	for _, state := range states {
		emitWarnings(os.Stderr, validateCompat(state.Name, state.Compat, knownProducts))

		rawTags, err := lister.listTags(state.Dir)
		if err != nil {
			// A tag-listing failure degrades to "no tags" (window = only N),
			// never an abort (ADR-3): N is authoritative.
			fmt.Fprintf(os.Stderr, "WARN %s: cannot list tags — %v\n", state.Dir, err)
			rawTags = nil
		}
		tagVers := parseTags(state.Dir, rawTags)

		cycles, ws := resolveWindow(state.Version, tagVers)
		emitWarnings(os.Stderr, tagChart(state.Name, ws))

		// Attach declared requires/testedWith to the N cycle (index 0), the only
		// cycle whose cross-compatibility we know from the current Chart.yaml.
		if len(cycles) > 0 && state.Compat != nil {
			if len(state.Compat.Requires) > 0 {
				cycles[0].Requires = state.Compat.Requires
			}
			if len(state.Compat.TestedWith) > 0 {
				cycles[0].TestedWith = state.Compat.TestedWith
			}
		}

		doc.Products[state.Name] = Product{
			Dir:     state.Dir,
			Current: state.Version,
			Cycles:  cycles,
		}
	}

	return doc, nil
}

// tagChart rewrites the Chart field of window warnings (which carry the raw
// version string) to the product name, for a consistent WARN/INFO contract.
func tagChart(name string, ws []Warning) []Warning {
	for i := range ws {
		ws[i].Chart = name
	}
	return ws
}
```

### Passo 3 (GREEN) — Gerar o golden
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && mkdir -p generate-compatibility/testdata && UPDATE_GOLDEN=1 go test ./generate-compatibility/ -run TestBuildDoc_Golden 2>&1 | tail -3
```
Saída esperada: `ok  ...` (o golden foi escrito).

### Passo 4 — Inspecionar e sanity-check do golden
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && cat generate-compatibility/testdata/golden_two_products.json
```
Saída esperada (verifique os pontos-chave): `midaz-helm` com 5 cycles (8.6..8.2, sendo 8.2 `"supported": false`, sem `8.6.0-beta.11` como ciclo); `plugin-fees-helm` com 1 cycle `7.2` carregando `requires` e `testedWith`. Confira que `midaz-helm` aparece ANTES de `plugin-fees-helm` (ordenação de chaves).

### Passo 5 — Rodar o golden test SEM UPDATE (deve passar do disco)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestBuildDoc_Golden 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-3-4_OK"
```
Saída esperada: termina com `ST-3-4_OK`.

## Rollback
```bash
rm -f ./.github/scripts/generate-compatibility/builddoc_test.go \
      ./.github/scripts/generate-compatibility/testdata/golden_two_products.json
cd "$(git rev-parse --show-toplevel)/.github/scripts" && git checkout generate-compatibility/main.go 2>/dev/null || true
```
