# ST-5-5 — Ligar a escrita do README no `main`/`buildDoc` + golden por layout irregular (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Criar `writeReadme(root string, doc CompatDoc) error` que lê `<root>/README.md`, para cada produto renderiza o body (ST-5-1) e aplica `ensureCompatBlock` (ST-5-4), e reescreve o arquivo UMA vez. Chamar em `main()` no modo write. Golden-test cobrindo os layouts irregulares reais: Matcher/BC Correios (sem separador final) e Plugin Fees/Plugin BR Pix Indirect BTG (linha em branco antes do `-----------------`), provando confinamento aos markers.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run 'TestEnsureCompatBlock|TestRenderCompatTable' 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-5-1..ST-5-4.)

## Files
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/write_readme.go`
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/write_readme_test.go`
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/testdata/readme_irregular_in.md`
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/testdata/readme_irregular_golden.md`
- modify: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/main.go` (chamar `writeReadme`)

## Steps

### Passo 1 — Criar a fixture de entrada com layouts irregulares
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/testdata/readme_irregular_in.md` com este conteúdo EXATO:
```markdown
# Charts

### Plugin Fees Helm Chart

Fees prose.

#### Application Version Mapping

| Chart Version | Fees Version | UI Version |
| :---: | :---: | :---: |
| `7.2.0` | 3.3.0 | `3.0.0` |

-----------------

### Matcher

Matcher prose.

#### Application Version Mapping

| Chart Version | Matcher Version |
| :---: | :---: |
| `3.0.0` | 1.0.0 |

### Flowker

Flowker prose.
```
(Note: Matcher NÃO tem `-----------------` após sua tabela — vai direto para `### Flowker`. Plugin Fees tem linha em branco antes do separador. Estes são os boundaries irregulares reais do README.)

### Passo 2 (RED) — Golden test
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/write_readme_test.go`:
```go
package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteReadme_IrregularLayoutsGolden(t *testing.T) {
	in, err := os.ReadFile(filepath.Join("testdata", "readme_irregular_in.md"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}

	root := t.TempDir()
	readmePath := filepath.Join(root, "README.md")
	if err := os.WriteFile(readmePath, in, 0o644); err != nil {
		t.Fatalf("seed README: %v", err)
	}

	doc := CompatDoc{
		SchemaVersion: 1,
		Products: map[string]Product{
			"plugin-fees-helm": {Dir: "plugin-fees", Current: "7.2.0", Cycles: []Cycle{
				{Cycle: "7.2", Latest: "7.2.0", Supported: true,
					Requires: map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"}},
			}},
			"matcher-helm": {Dir: "matcher", Current: "3.0.0", Cycles: []Cycle{
				{Cycle: "3.0", Latest: "3.0.0", Supported: true},
			}},
		},
	}

	if err := writeReadme(root, doc); err != nil {
		t.Fatalf("writeReadme: %v", err)
	}

	got, err := os.ReadFile(readmePath)
	if err != nil {
		t.Fatalf("read result: %v", err)
	}

	goldenPath := filepath.Join("testdata", "readme_irregular_golden.md")
	if os.Getenv("UPDATE_GOLDEN") == "1" {
		if err := os.WriteFile(goldenPath, got, 0o644); err != nil {
			t.Fatalf("update golden: %v", err)
		}
	}
	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden (run UPDATE_GOLDEN=1 first): %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("README mismatch.\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}

	// Structural invariants that must hold regardless of golden bytes:
	s := string(got)
	if !strings.Contains(s, "-----------------") {
		t.Error("Plugin Fees separator was destroyed")
	}
	if !strings.Contains(s, "| Chart Version | Matcher Version |") {
		t.Error("Matcher existing mapping table was destroyed")
	}
	if !strings.Contains(s, "### Flowker") {
		t.Error("Flowker section header lost")
	}
}

// TestWriteReadme_Idempotent proves running twice yields identical bytes.
func TestWriteReadme_Idempotent(t *testing.T) {
	in, _ := os.ReadFile(filepath.Join("testdata", "readme_irregular_in.md"))
	root := t.TempDir()
	readmePath := filepath.Join(root, "README.md")
	_ = os.WriteFile(readmePath, in, 0o644)

	doc := CompatDoc{SchemaVersion: 1, Products: map[string]Product{
		"matcher-helm": {Dir: "matcher", Current: "3.0.0", Cycles: []Cycle{{Cycle: "3.0", Latest: "3.0.0", Supported: true}}},
	}}

	_ = writeReadme(root, doc)
	first, _ := os.ReadFile(readmePath)
	_ = writeReadme(root, doc)
	second, _ := os.ReadFile(readmePath)
	if string(first) != string(second) {
		t.Fatalf("writeReadme not idempotent:\n--first--\n%s\n--second--\n%s", first, second)
	}
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestWriteReadme 2>&1 | head -8
```
Saída esperada: `undefined: writeReadme` e `[build failed]`.

### Passo 3 (GREEN) — Implementar write_readme.go
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/write_readme.go`:
```go
package main

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// writeReadme rewrites <root>/README.md so every product's COMPAT block matches
// the document. Products are processed in sorted name order for deterministic
// output. Only content between (or newly wrapped in) markers changes; prose,
// existing tables and irregular separators are preserved (risk #1 mitigation).
func writeReadme(root string, doc CompatDoc) error {
	readmePath := filepath.Join(root, "README.md")
	data, err := os.ReadFile(readmePath)
	if err != nil {
		return err
	}
	lines := strings.Split(string(data), "\n")

	names := make([]string, 0, len(doc.Products))
	for name := range doc.Products {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		body := renderCompatTable(doc.Products[name])
		lines, err = ensureCompatBlock(lines, name, body)
		if err != nil {
			return err
		}
	}

	out := strings.Join(lines, "\n")
	return os.WriteFile(readmePath, []byte(out), 0o644)
}
```

### Passo 4 (GREEN) — Chamar writeReadme em main()
Em `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/main.go`, após escrever o JSON (`os.WriteFile(outPath, ...)`) e antes do `fmt.Printf` final, adicione:
```go
	if err := writeReadme(*root, doc); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR write README.md: %v\n", err)
		os.Exit(1)
	}
```

### Passo 5 (GREEN) — Gerar o golden e revisar
```bash
cd /home/gauchito/lerian/helm/.github/scripts && UPDATE_GOLDEN=1 go test ./generate-compatibility/ -run TestWriteReadme_IrregularLayoutsGolden 2>&1 | tail -3 && echo "--- GOLDEN ---" && cat generate-compatibility/testdata/readme_irregular_golden.md
```
Saída esperada: `ok ...` e o golden impresso. REVISE À MÃO: o `-----------------` do Plugin Fees deve continuar presente; a tabela `| Chart Version | Matcher Version |` intacta; blocos COMPAT injetados logo após cada `### <header>`; `### Flowker` intacto.

### Passo 6 — Rodar o golden SEM update + idempotência
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestWriteReadme 2>&1 | tail -3
```
Saída esperada: `ok  ...` (golden bate do disco; idempotência verde).

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-5-5_OK"
```
Saída esperada: termina com `ST-5-5_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/write_readme.go \
      /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/write_readme_test.go \
      /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/testdata/readme_irregular_in.md \
      /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/testdata/readme_irregular_golden.md
cd /home/gauchito/lerian/helm/.github/scripts && git checkout generate-compatibility/main.go 2>/dev/null || true
```
