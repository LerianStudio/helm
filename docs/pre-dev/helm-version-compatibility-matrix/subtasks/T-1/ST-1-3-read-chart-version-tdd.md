# ST-1-3 — Ler `Chart.yaml` → `ChartState{Name,Dir,Version,AppVersion}` (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Criar a struct `ChartState` (data-model §A.2, campos deste passo apenas) e a função pura `readChartState(root, dir string) (ChartState, error)` que lê `<root>/charts/<dir>/Chart.yaml` via `gopkg.in/yaml.v3` e extrai `name`, `version` (= N, autoridade) e `appVersion`. Annotation/tags são passos posteriores (T-2/T-3).

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada (contém `ok`):
```
ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility	0.0...s
```
(Se falhar, execute ST-1-2 primeiro.)

## Files
- create: `./.github/scripts/generate-compatibility/state.go`
- create: `./.github/scripts/generate-compatibility/state_test.go`

## Steps

### Passo 1 (RED) — Teste que FALHA
Crie `./.github/scripts/generate-compatibility/state_test.go`:
```go
package main

import (
	"os"
	"path/filepath"
	"testing"
)

func writeChart(t *testing.T, root, dir, chartYAML string) {
	t.Helper()
	full := filepath.Join(root, "charts", dir)
	if err := os.MkdirAll(full, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(full, "Chart.yaml"), []byte(chartYAML), 0o644); err != nil {
		t.Fatalf("write Chart.yaml: %v", err)
	}
}

func TestReadChartState(t *testing.T) {
	root := t.TempDir()
	writeChart(t, root, "midaz", `apiVersion: v2
name: midaz-helm
type: application
version: 8.6.0
appVersion: "3.7.8"
`)

	got, err := readChartState(root, "midaz")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Name != "midaz-helm" {
		t.Errorf("Name = %q, want midaz-helm", got.Name)
	}
	if got.Dir != "midaz" {
		t.Errorf("Dir = %q, want midaz", got.Dir)
	}
	if got.Version != "8.6.0" {
		t.Errorf("Version = %q, want 8.6.0", got.Version)
	}
	if got.AppVersion != "3.7.8" {
		t.Errorf("AppVersion = %q, want 3.7.8", got.AppVersion)
	}
}

func TestReadChartState_MissingFile(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "charts", "empty"), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	_, err := readChartState(root, "empty")
	if err == nil {
		t.Fatal("expected error for missing Chart.yaml, got nil")
	}
}
```

Rode e capture a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestReadChartState 2>&1 | head -10
```
Saída esperada: `undefined: readChartState` e `FAIL ... [build failed]`.

### Passo 2 (GREEN) — Implementar
Crie `./.github/scripts/generate-compatibility/state.go`:
```go
package main

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// ChartState is the normalized state read from one chart's Chart.yaml.
// Version is N, the absolute authority for the support window (ADR-3):
// it is NEVER derived from git tags.
type ChartState struct {
	Name       string // published chart name, e.g. "midaz-helm"
	Dir        string // directory under charts/, e.g. "midaz" (tag prefix)
	Version    string // N — from Chart.yaml.version
	AppVersion string // informational
}

// chartYAML is the minimal shape we parse out of Chart.yaml for T-1.
// Annotations and dependencies are added in later subtasks (T-2/T-3).
type chartYAML struct {
	Name       string `yaml:"name"`
	Version    string `yaml:"version"`
	AppVersion string `yaml:"appVersion"`
}

// readChartState reads <root>/charts/<dir>/Chart.yaml and returns its
// normalized state. Returns an error if the file is missing or unparseable.
func readChartState(root, dir string) (ChartState, error) {
	path := filepath.Join(root, "charts", dir, "Chart.yaml")
	data, err := os.ReadFile(path)
	if err != nil {
		return ChartState{}, err
	}

	var c chartYAML
	if err := yaml.Unmarshal(data, &c); err != nil {
		return ChartState{}, err
	}

	return ChartState{
		Name:       c.Name,
		Dir:        dir,
		Version:    c.Version,
		AppVersion: c.AppVersion,
	}, nil
}
```

### Passo 3 — Rodar o teste
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestReadChartState 2>&1 | tail -3
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`.

## Verification (copiável)
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ && echo "ST-1-3_OK"
```
Saída esperada: termina com `ST-1-3_OK`.

## Rollback
```bash
rm -f ./.github/scripts/generate-compatibility/state.go \
      ./.github/scripts/generate-compatibility/state_test.go
```
