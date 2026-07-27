# ST-6-1 — Parsing de flags + exit codes 0/1/2 (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Refatorar o `main` para uma função testável `run(args []string, stdout, stderr io.Writer) int` que devolve o exit code, e adicionar as flags do contrato (api-design §II): `--write` (default), `--check`, `--chart`, `--root` (default `../..`), `--output` (default `docs/compatibility.json`). Exit codes: 2 se `--write`+`--check` juntos (uso); 1 se `--root` inexistente (ambiente); 0 caso contrário (inclui WARN). `main()` vira um wrapper fino.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete T-5.)

## Files
- modify: `./.github/scripts/generate-compatibility/main.go`
- create: `./.github/scripts/generate-compatibility/run_test.go`

## Steps

### Passo 1 (RED) — Testes de exit code
Crie `./.github/scripts/generate-compatibility/run_test.go`:
```go
package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// seedRepo builds a minimal repo (charts/ + README.md) for run() tests.
func seedRepo(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	writeChart(t, root, "matcher", `apiVersion: v2
name: matcher-helm
type: application
version: 3.0.0
`)
	readme := "# Charts\n\n### Matcher\n\nprose\n"
	if err := os.WriteFile(filepath.Join(root, "README.md"), []byte(readme), 0o644); err != nil {
		t.Fatalf("seed readme: %v", err)
	}
	if err := os.MkdirAll(filepath.Join(root, "docs"), 0o755); err != nil {
		t.Fatalf("mkdir docs: %v", err)
	}
	return root
}

func TestRun_ExitCodes(t *testing.T) {
	t.Run("conflicting --write and --check => exit 2", func(t *testing.T) {
		var out, errb bytes.Buffer
		code := run([]string{"--write", "--check"}, &out, &errb)
		if code != 2 {
			t.Fatalf("exit = %d, want 2. stderr=%s", code, errb.String())
		}
	})

	t.Run("missing --root => exit 1", func(t *testing.T) {
		var out, errb bytes.Buffer
		code := run([]string{"--root", "/no/such/dir/xyz"}, &out, &errb)
		if code != 1 {
			t.Fatalf("exit = %d, want 1. stderr=%s", code, errb.String())
		}
	})

	t.Run("valid write => exit 0", func(t *testing.T) {
		root := seedRepo(t)
		var out, errb bytes.Buffer
		code := run([]string{"--root", root, "--output", "docs/compatibility.json"}, &out, &errb)
		if code != 0 {
			t.Fatalf("exit = %d, want 0. stderr=%s", code, errb.String())
		}
		if _, err := os.Stat(filepath.Join(root, "docs", "compatibility.json")); err != nil {
			t.Fatalf("expected JSON written: %v", err)
		}
	})
}
```

Rode e capture a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestRun_ExitCodes 2>&1 | head -8
```
Saída esperada: `undefined: run` e `[build failed]`.

### Passo 2 (GREEN) — Refatorar main.go para `run`
Substitua a função `main()` de `./.github/scripts/generate-compatibility/main.go` por:
```go
func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

// run parses flags and executes the requested mode, returning the process exit
// code (api-design §II.2): 0 success (incl. WARN), 1 environment/usage error
// (unreadable root), 2 conflicting flags. stdout carries the operation result;
// stderr carries diagnostics.
func run(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("generate-compatibility", flag.ContinueOnError)
	fs.SetOutput(stderr)
	write := fs.Bool("write", false, "Write mode (default when no mode given)")
	check := fs.Bool("check", false, "Check mode: detect drift without writing")
	root := fs.String("root", "../..", "Repository root containing charts/")
	chart := fs.String("chart", "", "Restrict README update to a single chart (JSON always full)")
	output := fs.String("output", "docs/compatibility.json", "JSON destination, relative to --root")
	if err := fs.Parse(args); err != nil {
		fmt.Fprintf(stderr, "ERROR invalid flags: %v\n", err)
		return 2
	}

	// Mode selection + conflict check.
	if *write && *check {
		fmt.Fprintln(stderr, "ERROR --write and --check are mutually exclusive")
		return 2
	}

	// Environment check: root must be a readable directory with charts/.
	if info, err := os.Stat(filepath.Join(*root, "charts")); err != nil || !info.IsDir() {
		fmt.Fprintf(stderr, "ERROR --root %q has no readable charts/ directory\n", *root)
		return 1
	}

	doc, err := buildDoc(*root, gitTagLister{root: *root})
	if err != nil {
		fmt.Fprintf(stderr, "ERROR %v\n", err)
		return 1
	}

	if *check {
		return runCheck(*root, *output, doc, stdout, stderr)
	}
	return runWrite(*root, *output, *chart, doc, stdout, stderr)
}

// runWrite writes the JSON and README (chart filter applies to README only; the
// JSON is always regenerated in full for determinism — api-design §II.1).
func runWrite(root, output, chart string, doc CompatDoc, stdout, stderr io.Writer) int {
	data, err := renderJSON(doc)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR marshal compatibility.json: %v\n", err)
		return 1
	}
	if err := os.WriteFile(filepath.Join(root, output), data, 0o644); err != nil {
		fmt.Fprintf(stderr, "ERROR write %s: %v\n", output, err)
		return 1
	}

	readmeDoc := doc
	if chart != "" {
		readmeDoc = filterProduct(doc, chart)
	}
	if err := writeReadme(root, readmeDoc); err != nil {
		fmt.Fprintf(stderr, "ERROR write README.md: %v\n", err)
		return 1
	}
	fmt.Fprintf(stdout, "wrote %s and README.md (%d products)\n", output, len(doc.Products))
	return 0
}

// filterProduct returns a copy of doc containing only the named product, so a
// --chart run touches just that README block.
func filterProduct(doc CompatDoc, chart string) CompatDoc {
	filtered := CompatDoc{SchemaVersion: doc.SchemaVersion, GeneratedFrom: doc.GeneratedFrom, Products: map[string]Product{}}
	if p, ok := doc.Products[chart]; ok {
		filtered.Products[chart] = p
	}
	return filtered
}
```

Adicione `"io"` ao bloco de imports de `main.go` (ordem: `errors`, `flag`, `fmt`, `io`, `os`, `path/filepath`).

> **Nota:** `runCheck` é definido em ST-6-2. Para o GREEN deste passo, adicione um stub temporário AO FINAL de main.go:
> ```go
> // runCheck is implemented in ST-6-2; temporary stub keeps ST-6-1 compiling.
> func runCheck(root, output string, doc CompatDoc, stdout, stderr io.Writer) int {
> 	fmt.Fprintln(stdout, "ok")
> 	return 0
> }
> ```
> ST-6-2 substitui este stub pela implementação real.

### Passo 3 — Rodar os testes
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestRun_ExitCodes 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-6-1_OK"
```
Saída esperada: termina com `ST-6-1_OK`.

## Rollback
```bash
rm -f ./.github/scripts/generate-compatibility/run_test.go
cd "$(git rev-parse --show-toplevel)/.github/scripts" && git checkout generate-compatibility/main.go 2>/dev/null || true
```
