# ST-1-2 — Helper `chartDirectories` (RED → GREEN) no novo package

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Criar o package `generate-compatibility` e a função pura testável `chartDirectories(root string) ([]string, error)` que lista os subdiretórios de `<root>/charts` ordenados. Copia o padrão de `validate-helm-charts/main.go:292-307` DENTRO do novo package (o standard proíbe importar de outro `package main`).

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && grep 'Masterminds/semver' go.mod
```
Saída esperada:
```
	github.com/Masterminds/semver/v3 v3.2.1
```
(Se falhar, execute ST-1-1 primeiro.)

## Files
- create: `./.github/scripts/generate-compatibility/chart.go`
- create: `./.github/scripts/generate-compatibility/chart_test.go`

## Steps

### Passo 1 (RED) — Escrever o teste table-driven que FALHA
Crie `./.github/scripts/generate-compatibility/chart_test.go` com este conteúdo COMPLETO:
```go
package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// writeTree cria uma árvore charts/<name> temporária e devolve o root.
func writeTree(t *testing.T, chartDirs []string, extraFiles map[string]string) string {
	t.Helper()
	root := t.TempDir()
	for _, d := range chartDirs {
		if err := os.MkdirAll(filepath.Join(root, "charts", d), 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", d, err)
		}
	}
	for rel, content := range extraFiles {
		full := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatalf("mkdir for %s: %v", rel, err)
		}
		if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
			t.Fatalf("write %s: %v", rel, err)
		}
	}
	return root
}

func TestChartDirectories(t *testing.T) {
	tests := []struct {
		name      string
		dirs      []string
		extra     map[string]string
		want      []string
		wantError bool
	}{
		{
			name: "sorted ascending, dirs only",
			dirs: []string{"midaz", "plugin-fees", "br-spi"},
			want: []string{"br-spi", "midaz", "plugin-fees"},
		},
		{
			name:  "ignores loose files in charts/",
			dirs:  []string{"midaz"},
			extra: map[string]string{"charts/README.md": "x"},
			want:  []string{"midaz"},
		},
		{
			name: "empty charts dir returns empty slice",
			dirs: []string{},
			want: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			root := writeTree(t, tt.dirs, tt.extra)
			got, err := chartDirectories(root)
			if (err != nil) != tt.wantError {
				t.Fatalf("err = %v, wantError = %v", err, tt.wantError)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestChartDirectories_MissingRoot(t *testing.T) {
	_, err := chartDirectories(filepath.Join(t.TempDir(), "does-not-exist"))
	if err == nil {
		t.Fatal("expected error for missing charts dir, got nil")
	}
}
```

Rode o teste e CAPTURE a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | head -20
```
Saída esperada (falha de compilação — a função ainda não existe):
```
# github.com/LerianStudio/helm/.github/scripts/generate-compatibility [github.com/LerianStudio/helm/.github/scripts/generate-compatibility.test]
./chart_test.go:...: undefined: chartDirectories
FAIL	github.com/LerianStudio/helm/.github/scripts/generate-compatibility [build failed]
```

### Passo 2 (GREEN) — Implementar a função mínima
Crie `./.github/scripts/generate-compatibility/chart.go` com este conteúdo COMPLETO:
```go
// Command generate-compatibility produces the per-product support-window matrix
// (README blocks + docs/compatibility.json) for the charts in this repo.
//
// It mirrors the sibling tools in .github/scripts (generate-values-schemas,
// update-readme-matrix): invoked with --root ../.., reads the repo state, and
// writes deterministic artifacts. No network access beyond the git tags already
// present in the checkout.
package main

import (
	"os"
	"path/filepath"
	"sort"
)

// chartDirectories returns the names (not full paths) of the immediate
// subdirectories of <root>/charts, sorted ascending. Loose files under charts/
// are ignored. Mirrors validate-helm-charts/main.go:292-307 but returns bare
// names (the caller joins paths), copied here because Go forbids importing one
// package main from another.
func chartDirectories(root string) ([]string, error) {
	chartsRoot := filepath.Join(root, "charts")
	entries, err := os.ReadDir(chartsRoot)
	if err != nil {
		return nil, err
	}

	dirs := []string{}
	for _, entry := range entries {
		if entry.IsDir() {
			dirs = append(dirs, entry.Name())
		}
	}
	sort.Strings(dirs)
	return dirs, nil
}
```

### Passo 3 — Rodar o teste (deve passar)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -5
```
Saída esperada (contém):
```
ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility	0.0...s
```

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-1-2_OK"
```
Saída esperada: termina com `ST-1-2_OK`.

## Rollback
```bash
rm -rf ./.github/scripts/generate-compatibility/chart.go \
       ./.github/scripts/generate-compatibility/chart_test.go
```
