# ST-2-3 — Ligar a annotation no `ChartState` e emitir WARN no `buildDoc` (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Primeiro passo do two-step no leitor: ler `annotations["lerian.studio/compatibility"]` no `Chart.yaml`, parsear via `parseCompatAnnotation`, guardar em `ChartState.Compat`, e — em `buildDoc` — emitir WARN de YAML quebrado (V1) e chamar `validateCompat` com o conjunto de produtos conhecidos. Annotation ausente/quebrada NUNCA aborta (ADR-4, exit 0).

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run 'TestParseCompatAnnotation|TestValidateCompat' 2>&1 | tail -1
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`
(Se falhar, complete ST-2-1 e ST-2-2.)

## Files
- modify: `./.github/scripts/generate-compatibility/state.go` (add `Compat` + parse da annotation)
- modify: `./.github/scripts/generate-compatibility/state_test.go` (novo caso)
- modify: `./.github/scripts/generate-compatibility/main.go` (buildDoc coleta produtos + valida)

## Steps

### Passo 1 (RED) — Novo teste em state_test.go
Adicione ao FINAL de `./.github/scripts/generate-compatibility/state_test.go`:
```go
func TestReadChartState_ParsesCompatAnnotation(t *testing.T) {
	root := t.TempDir()
	writeChart(t, root, "plugin-fees", `apiVersion: v2
name: plugin-fees-helm
type: application
version: 7.2.0
appVersion: "3.3.0"
annotations:
  lerian.studio/chart-type: multi-component
  lerian.studio/compatibility: |
    requires:
      midaz-helm: ">=8.4.0 <9.0.0"
    testedWith:
      midaz-helm: "8.6.0"
`)

	got, err := readChartState(root, "plugin-fees")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Compat == nil {
		t.Fatal("Compat is nil, want parsed annotation")
	}
	if got.Compat.Requires["midaz-helm"] != ">=8.4.0 <9.0.0" {
		t.Errorf("Requires[midaz-helm] = %q", got.Compat.Requires["midaz-helm"])
	}
	if got.Compat.TestedWith["midaz-helm"] != "8.6.0" {
		t.Errorf("TestedWith[midaz-helm] = %q", got.Compat.TestedWith["midaz-helm"])
	}
}

func TestReadChartState_NoAnnotationIsNilCompat(t *testing.T) {
	root := t.TempDir()
	writeChart(t, root, "matcher", `apiVersion: v2
name: matcher-helm
type: application
version: 3.0.0
`)
	got, err := readChartState(root, "matcher")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Compat != nil {
		t.Errorf("Compat = %+v, want nil", got.Compat)
	}
}
```

Rode e capture a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestReadChartState_ParsesCompatAnnotation 2>&1 | head -8
```
Saída esperada: `got.Compat undefined (type ChartState has no field or method Compat)` e `[build failed]`.

### Passo 2 (GREEN) — Estender ChartState + chartYAML e fazer o parse
Em `./.github/scripts/generate-compatibility/state.go`:

Substitua a struct `ChartState` por:
```go
type ChartState struct {
	Name       string // published chart name, e.g. "midaz-helm"
	Dir        string // directory under charts/, e.g. "midaz" (tag prefix)
	Version    string // N — from Chart.yaml.version
	AppVersion string // informational
	Compat     *CompatAnnotation
}
```

Substitua a struct `chartYAML` por (adiciona `Annotations`):
```go
type chartYAML struct {
	Name        string            `yaml:"name"`
	Version     string            `yaml:"version"`
	AppVersion  string            `yaml:"appVersion"`
	Annotations map[string]string `yaml:"annotations"`
}
```

Substitua o corpo de `readChartState` (o `return`) por:
```go
	compat, err := parseCompatAnnotation(c.Annotations[compatAnnotationKey])
	if err != nil {
		// Broken embedded YAML (V1): surface as a tagged error so buildDoc can
		// emit a WARN and continue. State is still usable (name/version known).
		return ChartState{
			Name:       c.Name,
			Dir:        dir,
			Version:    c.Version,
			AppVersion: c.AppVersion,
		}, &badAnnotationError{chart: c.Name, err: err}
	}

	return ChartState{
		Name:       c.Name,
		Dir:        dir,
		Version:    c.Version,
		AppVersion: c.AppVersion,
		Compat:     compat,
	}, nil
}

// badAnnotationError marks a Chart.yaml whose compatibility annotation is
// unparseable (V1). The chart state is still returned; the caller downgrades
// this to a WARN rather than aborting (ADR-4).
type badAnnotationError struct {
	chart string
	err   error
}

func (e *badAnnotationError) Error() string {
	return fmt.Sprintf("compatibility annotation is invalid YAML: %v", e.err)
}
```

Adicione `"errors"` e `"fmt"` ao bloco de imports de `state.go`:
```go
import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)
```
(`errors` é usado no Passo 3 via `errors.As`; mantenha-o mesmo que o linter não reclame agora — o buildDoc importará via este arquivo? Não: cada arquivo importa o que usa. Se `errors` ficar sem uso em state.go, REMOVA-o daqui e deixe só em main.go. Rode `go build` para confirmar.)

### Passo 3 (GREEN) — buildDoc: coletar produtos, tratar bad annotation, validar
Em `./.github/scripts/generate-compatibility/main.go`, substitua a função `buildDoc` inteira por:
```go
// buildDoc reads every chart under <root>/charts and assembles the document,
// emitting WARN/INFO diagnostics to stderr. It never aborts on data problems
// (ADR-4); only environment errors (unreadable charts/ dir) propagate.
func buildDoc(root string) (CompatDoc, error) {
	dirs, err := chartDirectories(root)
	if err != nil {
		return CompatDoc{}, fmt.Errorf("list charts: %w", err)
	}

	// First pass: read all states so we know the full set of known products
	// before running the V3 existence check.
	states := make([]ChartState, 0, len(dirs))
	knownProducts := map[string]bool{}
	for _, dir := range dirs {
		state, err := readChartState(root, dir)
		var badAnn *badAnnotationError
		switch {
		case errors.As(err, &badAnn):
			fmt.Fprintln(os.Stderr, Warning{SevWarn, badAnn.chart, "V1", err.Error()}.Line())
		case err != nil:
			fmt.Fprintf(os.Stderr, "WARN %s: cannot read Chart.yaml — %v\n", dir, err)
			continue
		}
		if state.Name == "" {
			fmt.Fprintf(os.Stderr, "WARN %s: Chart.yaml has no name; skipping\n", dir)
			continue
		}
		states = append(states, state)
		knownProducts[state.Name] = true
	}

	// Second pass: validate annotations and build the document.
	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "local",
		Products:      map[string]Product{},
	}
	for _, state := range states {
		emitWarnings(os.Stderr, validateCompat(state.Name, state.Compat, knownProducts))
		doc.Products[state.Name] = Product{
			Dir:     state.Dir,
			Current: state.Version,
		}
	}

	return doc, nil
}
```

Garanta que o bloco de imports de `main.go` inclua `"errors"`:
```go
import (
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)
```

### Passo 4 — Rodar testes
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -3
```
Saída esperada: `ok  	github.com/LerianStudio/helm/.github/scripts/generate-compatibility ...`.

## Verification (copiável) — rodar contra repo real, ver WARN/INFO em stderr
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go run ./generate-compatibility --root ../.. --output /tmp/compat-t2.json 2> /tmp/compat-t2.stderr; echo "exit=$?"; echo "--- stderr (primeiras linhas) ---"; head -5 /tmp/compat-t2.stderr
```
Saída esperada: `exit=0` (nunca ≠0 por dado). stderr contém linhas `INFO <chart>: V6 — ...` para charts sem annotation (a maioria no v1 pré-backfill). Nenhuma alteração no `compatibility.json` do repo (usamos /tmp).

## Rollback
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && git checkout generate-compatibility/state.go generate-compatibility/state_test.go generate-compatibility/main.go
```
