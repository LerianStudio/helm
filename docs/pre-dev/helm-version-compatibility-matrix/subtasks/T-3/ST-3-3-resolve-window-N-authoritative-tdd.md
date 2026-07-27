# ST-3-3 — `resolveWindow`: N do Chart.yaml + top-4 minors + degradação (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
A função-coração `resolveWindow(chartVersion string, tagVersions []*semver.Version) ([]Cycle, []Warning)`:
- **N = `chartVersion` (Chart.yaml), AUTORIDADE ABSOLUTA** — nunca das tags (ADR-3/NFR-3).
- Combina o ciclo de N com os ciclos das tags (segregadas + agrupadas por minor via ST-3-2), garante que o ciclo de N exista mesmo sem tag, ordena minors DESC, pega as **top-4 minors distintas ≤ N** → `supported=true`; o resto → `supported=false`.
- Degradação: 0 tags → só o ciclo N (+INFO); <4 → só os existentes.
Este passo NÃO preenche `requires`/`testedWith` (isso é T-4/ST-3-4 wiring). Foca na janela + `supported`.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run 'TestSegregateStable|TestGroupByMinor' 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-3-2.)

## Files
- modify: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window.go` (add `resolveWindow`)
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/resolve_test.go`

## Steps

### Passo 1 (RED) — Testes exaustivos (0/1/2/3/4+ minors, N ausente das tags, pre-release)
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/resolve_test.go`:
```go
package main

import (
	"testing"

	"github.com/Masterminds/semver/v3"
)

func tagVers(t *testing.T, ss ...string) []*semver.Version {
	t.Helper()
	out := make([]*semver.Version, 0, len(ss))
	for _, s := range ss {
		v, err := semver.NewVersion(s)
		if err != nil {
			t.Fatalf("bad version %q: %v", s, err)
		}
		out = append(out, v)
	}
	return out
}

// cyclePairs flattens []Cycle to a compact [cycle, latest, supported] view.
func cyclePairs(cs []Cycle) []struct {
	cycle     string
	latest    string
	supported bool
} {
	out := make([]struct {
		cycle     string
		latest    string
		supported bool
	}, 0, len(cs))
	for _, c := range cs {
		out = append(out, struct {
			cycle     string
			latest    string
			supported bool
		}{c.Cycle, c.Latest, c.Supported})
	}
	return out
}

func TestResolveWindow(t *testing.T) {
	tests := []struct {
		name        string
		chartVer    string
		tags        []string
		wantCycles  [][3]string // {cycle, latest, "true"/"false"}
		wantINFO    bool        // expect an INFO warning (0 tags case)
	}{
		{
			name:     "midaz: N=8.6.0, five minors => top-4 supported, 8.2 EOL",
			chartVer: "8.6.0",
			tags:     []string{"midaz-x"}, // placeholder replaced below in per-test setup
			// NOTE: this test provides tags via tagVers in the loop; see below.
		},
	}
	_ = tests // replaced by explicit cases below to keep versions readable

	// --- Explicit cases (clearer than a giant table for this logic) ---

	t.Run("N=8.6.0 with 8.6..8.2 => top-4 supported, 8.2 unsupported", func(t *testing.T) {
		cs, ws := resolveWindow("8.6.0", tagVers(t,
			"8.6.0", "8.5.0", "8.4.0", "8.3.0", "8.2.0"))
		got := cyclePairs(cs)
		want := [][3]string{
			{"8.6", "8.6.0", "true"},
			{"8.5", "8.5.0", "true"},
			{"8.4", "8.4.0", "true"},
			{"8.3", "8.3.0", "true"},
			{"8.2", "8.2.0", "false"},
		}
		assertCycles(t, got, want)
		assertNoINFO(t, ws)
	})

	t.Run("N authoritative: chart=8.6.0 but tags stale at 8.5 => N cycle still present & supported", func(t *testing.T) {
		cs, _ := resolveWindow("8.6.0", tagVers(t, "8.5.0", "8.4.0"))
		got := cyclePairs(cs)
		// N=8.6 must appear as top cycle, supported, latest=8.6.0 (from Chart.yaml).
		if got[0].cycle != "8.6" || got[0].supported != true || got[0].latest != "8.6.0" {
			t.Fatalf("N cycle wrong: %+v", got[0])
		}
	})

	t.Run("0 tags => only N cycle + INFO", func(t *testing.T) {
		cs, ws := resolveWindow("1.0.0", tagVers(t))
		if len(cs) != 1 || cs[0].Cycle != "1.0" || !cs[0].Supported || cs[0].Latest != "1.0.0" {
			t.Fatalf("expected single supported N cycle, got %+v", cs)
		}
		if !hasINFO(ws) {
			t.Fatal("expected INFO warning for 0 tags")
		}
	})

	t.Run("<4 minors => only existing", func(t *testing.T) {
		cs, _ := resolveWindow("3.0.0", tagVers(t, "3.0.0", "2.9.0"))
		got := cyclePairs(cs)
		want := [][3]string{
			{"3.0", "3.0.0", "true"},
			{"2.9", "2.9.0", "true"},
		}
		assertCycles(t, got, want)
	})

	t.Run("pre-release tag is ignored, does not create a cycle", func(t *testing.T) {
		cs, _ := resolveWindow("8.6.0", tagVers(t, "8.6.0-beta.11", "8.6.0", "8.5.0"))
		for _, c := range cs {
			if c.Cycle == "8.6" && c.Latest != "8.6.0" {
				t.Fatalf("pre-release leaked into cycle: %+v", c)
			}
		}
		if len(cs) != 2 {
			t.Fatalf("expected 2 cycles (8.6, 8.5), got %d: %+v", len(cs), cs)
		}
	})

	t.Run("higher tag than N is dropped (never exceeds N)", func(t *testing.T) {
		// A tag 8.7.0 exists but Chart.yaml says N=8.6.0: 8.7 must NOT appear.
		cs, _ := resolveWindow("8.6.0", tagVers(t, "8.7.0", "8.6.0", "8.5.0"))
		for _, c := range cs {
			if c.Cycle == "8.7" {
				t.Fatalf("cycle above N leaked in: %+v", cs)
			}
		}
		if cs[0].Cycle != "8.6" {
			t.Fatalf("top cycle should be N=8.6, got %q", cs[0].Cycle)
		}
	})
}

func assertCycles(t *testing.T, got []struct {
	cycle     string
	latest    string
	supported bool
}, want [][3]string) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("got %d cycles, want %d: %+v", len(got), len(want), got)
	}
	for i, w := range want {
		sup := w[2] == "true"
		if got[i].cycle != w[0] || got[i].latest != w[1] || got[i].supported != sup {
			t.Errorf("cycle %d: got {%s %s %v}, want {%s %s %v}",
				i, got[i].cycle, got[i].latest, got[i].supported, w[0], w[1], sup)
		}
	}
}

func hasINFO(ws []Warning) bool {
	for _, w := range ws {
		if w.Severity == SevInfo {
			return true
		}
	}
	return false
}

func assertNoINFO(t *testing.T, ws []Warning) {
	t.Helper()
	if hasINFO(ws) {
		t.Errorf("unexpected INFO: %+v", ws)
	}
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestResolveWindow 2>&1 | head -8
```
Saída esperada: `undefined: resolveWindow` e `[build failed]`.

### Passo 2 (GREEN) — Implementar resolveWindow em window.go
Adicione ao final de `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window.go`:
```go
// supportedWindowSize is the number of most-recent minor cycles that are marked
// supported (N..N-3). Cycles below that are supported=false.
const supportedWindowSize = 4

// resolveWindow builds the ordered support-window cycles for one chart.
//
// N = chartVersion (from Chart.yaml) is authoritative: its cycle is always
// present and supported, even when no matching tag exists (ADR-3, NFR-3). Tag
// history supplies N-1..N-3. Cycles strictly above N are discarded (a stray
// higher tag must never exceed the declared current version). The top
// supportedWindowSize distinct minors are supported=true; the rest false.
//
// Degradation (FR-7): 0 tags => only the N cycle (+ an INFO); <4 minors => only
// those that exist.
func resolveWindow(chartVersion string, tagVersions []*semver.Version) ([]Cycle, []Warning) {
	var warnings []Warning

	nVer, err := semver.NewVersion(chartVersion)
	if err != nil {
		// Chart.yaml version is unparseable: emit WARN, produce no cycles.
		warnings = append(warnings, Warning{SevWarn, chartVersion, "N", fmt.Sprintf("Chart.yaml version %q is not valid semver", chartVersion)})
		return nil, warnings
	}
	nKey := minorKey(nVer)

	// Group stable tag versions by minor cycle.
	byMinor := groupByMinor(segregateStable(tagVersions))

	// Force the N cycle to exist, sourced from Chart.yaml (authority). If a tag
	// for the N cycle also exists, keep the greater of the two as latest.
	if existing, ok := byMinor[nKey]; !ok || nVer.GreaterThan(existing) {
		byMinor[nKey] = nVer
	}

	// Collect the "latest" version of each minor, drop any cycle above N, then
	// sort descending by that latest version.
	latests := make([]*semver.Version, 0, len(byMinor))
	for _, v := range byMinor {
		if v.GreaterThan(nVer) {
			continue // never exceed N
		}
		latests = append(latests, v)
	}
	// Descending sort.
	sortVersionsDesc(latests)

	cycles := make([]Cycle, 0, len(latests))
	for i, v := range latests {
		cycles = append(cycles, Cycle{
			Cycle:     minorKey(v),
			Latest:    v.String(),
			Supported: i < supportedWindowSize,
		})
	}

	if len(tagVersions) == 0 {
		warnings = append(warnings, Warning{SevInfo, chartVersion, "N", "no published tags; window = only N (Chart.yaml)"})
	}

	return cycles, warnings
}

// sortVersionsDesc sorts in place, greatest first, using Masterminds ordering.
func sortVersionsDesc(vs []*semver.Version) {
	coll := semver.Collection(vs)
	// semver.Collection sorts ascending; reverse after.
	for i, j := 0, len(coll)-1; i < j; i, j = i+1, j-1 {
		coll[i], coll[j] = coll[j], coll[i]
	}
	// The swap above only reverses; we must sort first. Do a proper sort:
	sortSemverDesc(vs)
}

// sortSemverDesc performs a stable descending sort of semver versions.
func sortSemverDesc(vs []*semver.Version) {
	// insertion via sort.Slice on the underlying slice
	// (kept explicit to avoid an extra import churn)
	for i := 1; i < len(vs); i++ {
		for j := i; j > 0 && vs[j].GreaterThan(vs[j-1]); j-- {
			vs[j], vs[j-1] = vs[j-1], vs[j]
		}
	}
}
```

> **Nota de simplificação (aplicar no REFACTOR, ST-3-2/3 review):** `sortVersionsDesc` acima contém um reverse redundante antes de `sortSemverDesc`. Simplifique para chamar apenas `sortSemverDesc(vs)` no corpo de `resolveWindow` e apague `sortVersionsDesc`. Deixado aqui só para o GREEN inicial passar de forma óbvia; o REFACTOR abaixo remove.

### Passo 3 (REFACTOR) — Simplificar a ordenação
Substitua, em `resolveWindow`, a chamada `sortVersionsDesc(latests)` por `sortSemverDesc(latests)` e APAGUE a função `sortVersionsDesc` inteira. Rode o teste de novo (Passo 4) para confirmar que continua verde.

### Passo 4 — Rodar os testes
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestResolveWindow 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-3-3_OK"
```
Saída esperada: termina com `ST-3-3_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/resolve_test.go
cd /home/gauchito/lerian/helm/.github/scripts && git checkout generate-compatibility/window.go 2>/dev/null || true
```
