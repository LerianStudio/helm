# ST-6-2 — Modo `--check`: detecta drift sem escrever, WARN + exit 0 (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Implementar `runCheck` (substituindo o stub de ST-6-1): gera JSON+README esperados EM MEMÓRIA, compara com o disco, e — se divergir — emite `WARN <chart>: compatibility block is stale` em stderr com **exit 0** (não bloqueia no v1, ADR-4). Em dia → `stdout` "ok", exit 0. NÃO escreve nada.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestRun_ExitCodes 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-6-1.)

## Files
- modify: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/main.go` (substituir stub `runCheck`)
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/check_test.go`

## Steps

### Passo 1 (RED) — Testes de drift/em-dia
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/check_test.go`:
```go
package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestRun_Check(t *testing.T) {
	t.Run("in-sync repo => ok, exit 0, no WARN", func(t *testing.T) {
		root := seedRepo(t)
		// First write so disk matches expectation.
		var w1out, w1err bytes.Buffer
		if code := run([]string{"--root", root, "--output", "docs/compatibility.json"}, &w1out, &w1err); code != 0 {
			t.Fatalf("seed write exit=%d err=%s", code, w1err.String())
		}
		// Now check: should be clean.
		var out, errb bytes.Buffer
		code := run([]string{"--check", "--root", root}, &out, &errb)
		if code != 0 {
			t.Fatalf("check exit = %d, want 0. stderr=%s", code, errb.String())
		}
		if !strings.Contains(out.String(), "ok") {
			t.Errorf("stdout should say ok, got %q", out.String())
		}
		if strings.Contains(errb.String(), "stale") {
			t.Errorf("unexpected drift WARN: %s", errb.String())
		}
	})

	t.Run("drift => WARN on stderr, still exit 0", func(t *testing.T) {
		root := seedRepo(t)
		// Do NOT write first: disk README has no COMPAT block => drift.
		var out, errb bytes.Buffer
		code := run([]string{"--check", "--root", root}, &out, &errb)
		if code != 0 {
			t.Fatalf("check exit = %d, want 0 (non-blocking v1). stderr=%s", code, errb.String())
		}
		if !strings.Contains(errb.String(), "stale") {
			t.Errorf("expected drift WARN with 'stale', got stderr=%q", errb.String())
		}
	})
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestRun_Check 2>&1 | head -12
```
Saída esperada: FALHA nos asserts (o stub sempre imprime "ok" e nunca detecta drift) — ex.: `expected drift WARN with 'stale'`.

### Passo 2 (GREEN) — Implementar runCheck de verdade
Substitua o stub `runCheck` em `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/main.go` por:
```go
// runCheck compares the expected JSON + README against what is on disk without
// writing. Drift is reported as WARN on stderr but never fails the build in v1
// (ADR-4): exit stays 0. A clean repo prints "ok".
func runCheck(root, output string, doc CompatDoc, stdout, stderr io.Writer) int {
	drift := false

	// JSON drift.
	expectedJSON, err := renderJSON(doc)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR marshal compatibility.json: %v\n", err)
		return 1
	}
	actualJSON, err := os.ReadFile(filepath.Join(root, output))
	if err != nil || string(actualJSON) != string(expectedJSON) {
		fmt.Fprintf(stderr, "WARN %s: compatibility JSON is stale\n", output)
		drift = true
	}

	// README drift: render expected README into a temp copy of the current one.
	readmePath := filepath.Join(root, "README.md")
	current, err := os.ReadFile(readmePath)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR read README.md: %v\n", err)
		return 1
	}
	expectedLines := strings.Split(string(current), "\n")
	names := sortedProductNames(doc)
	for _, name := range names {
		body := renderCompatTable(doc.Products[name])
		expectedLines, err = ensureCompatBlock(expectedLines, name, body)
		if err != nil {
			fmt.Fprintf(stderr, "ERROR render README for %s: %v\n", name, err)
			return 1
		}
	}
	if strings.Join(expectedLines, "\n") != string(current) {
		fmt.Fprintln(stderr, "WARN README.md: compatibility block is stale")
		drift = true
	}

	if drift {
		fmt.Fprintln(stdout, "drift detected (non-blocking v1)")
	} else {
		fmt.Fprintln(stdout, "ok")
	}
	return 0
}

// sortedProductNames returns the product keys in stable ascending order.
func sortedProductNames(doc CompatDoc) []string {
	names := make([]string, 0, len(doc.Products))
	for name := range doc.Products {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}
```

Adicione `"sort"` e `"strings"` ao bloco de imports de `main.go` (se ainda não presentes). Ordem: `errors`, `flag`, `fmt`, `io`, `os`, `path/filepath`, `sort`, `strings`.

> **Nota (dedupe REFACTOR):** `writeReadme` (ST-5-5) já tem o loop de `ensureCompatBlock` sobre nomes ordenados. Considere extrair um helper `renderReadmeLines(current []string, doc) ([]string, error)` reusado por `writeReadme` e `runCheck`. Faça isso no REFACTOR se o code review pedir; não é obrigatório para o GREEN.

### Passo 3 — Rodar os testes
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestRun_Check 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável) — check contra o repo real
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go run ./generate-compatibility --check --root ../.. ; echo "exit=$?"
```
Saída esperada: `exit=0`. stdout diz `ok` (se README/JSON já gerados e commitados) ou `drift detected (non-blocking v1)` com WARN em stderr (se ainda não gerados). NUNCA exit≠0.

```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-6-2_OK"
```
Saída esperada: termina com `ST-6-2_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/check_test.go
cd /home/gauchito/lerian/helm/.github/scripts && git checkout generate-compatibility/main.go 2>/dev/null || true
```
