# ST-3-2 — Segregar pre-releases e agrupar por `Major().Minor()` (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Duas funções puras: `segregateStable(vs []*semver.Version) []*semver.Version` (descarta qualquer versão com `.Prerelease() != ""` — decisão do TRD §2: pre-releases `-beta.N`/`-HELM-N` NÃO viram ciclo próprio) e `groupByMinor(vs []*semver.Version) map[string]*semver.Version` (chave `"MAJOR.MINOR"` → maior patch estável daquele ciclo). Isto é o coração da correção da janela; teste EXAUSTIVO.

## Prerequisites
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run TestParseTags 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete ST-3-1.)

## Files
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window.go`
- create: `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window_test.go`

## Steps

### Passo 1 (RED) — Testes table-driven exaustivos
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window_test.go`:
```go
package main

import (
	"sort"
	"testing"

	"github.com/Masterminds/semver/v3"
)

// mustVers parses a list of semver strings, failing the test on any error.
func mustVers(t *testing.T, ss ...string) []*semver.Version {
	t.Helper()
	out := make([]*semver.Version, 0, len(ss))
	for _, s := range ss {
		v, err := semver.NewVersion(s)
		if err != nil {
			t.Fatalf("bad test version %q: %v", s, err)
		}
		out = append(out, v)
	}
	return out
}

func TestSegregateStable(t *testing.T) {
	tests := []struct {
		name string
		in   []string
		want []string
	}{
		{"drops beta", []string{"8.6.0", "8.6.0-beta.11", "8.5.0"}, []string{"8.6.0", "8.5.0"}},
		{"drops HELM prerelease", []string{"1.0.0-HELM-94.1", "1.0.0"}, []string{"1.0.0"}},
		{"all stable kept", []string{"3.2.0", "3.1.0"}, []string{"3.2.0", "3.1.0"}},
		{"all prerelease => empty", []string{"2.0.0-rc.1", "2.0.0-beta.2"}, []string{}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := segregateStable(mustVers(t, tt.in...))
			gotStr := make([]string, 0, len(got))
			for _, v := range got {
				gotStr = append(gotStr, v.String())
			}
			if len(gotStr) != len(tt.want) {
				t.Fatalf("got %v, want %v", gotStr, tt.want)
			}
			for i := range tt.want {
				if gotStr[i] != tt.want[i] {
					t.Fatalf("index %d: got %q want %q", i, gotStr[i], tt.want[i])
				}
			}
		})
	}
}

func TestGroupByMinor(t *testing.T) {
	tests := []struct {
		name string
		in   []string
		want map[string]string // "MAJOR.MINOR" -> latest patch .String()
	}{
		{
			name: "picks highest patch per minor",
			in:   []string{"8.6.0", "8.6.2", "8.6.1", "8.5.0", "8.5.3"},
			want: map[string]string{"8.6": "8.6.2", "8.5": "8.5.3"},
		},
		{
			name: "single minor",
			in:   []string{"3.0.0"},
			want: map[string]string{"3.0": "3.0.0"},
		},
		{
			name: "crosses majors",
			in:   []string{"9.0.0", "8.9.0", "8.9.5"},
			want: map[string]string{"9.0": "9.0.0", "8.9": "8.9.5"},
		},
		{
			name: "empty",
			in:   []string{},
			want: map[string]string{},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := groupByMinor(mustVers(t, tt.in...))
			if len(got) != len(tt.want) {
				t.Fatalf("got %d cycles, want %d (%v)", len(got), len(tt.want), got)
			}
			for cycle, wantLatest := range tt.want {
				v, ok := got[cycle]
				if !ok {
					t.Fatalf("missing cycle %q in %v", cycle, got)
				}
				if v.String() != wantLatest {
					t.Errorf("cycle %q: got latest %q, want %q", cycle, v.String(), wantLatest)
				}
			}
		})
	}
}

// TestGroupByMinor_OrderIndependent proves grouping does not depend on input
// order (map iteration is random; the pick must be deterministic by value).
func TestGroupByMinor_OrderIndependent(t *testing.T) {
	forward := mustVers(t, "8.6.0", "8.6.1", "8.6.2")
	rev := mustVers(t, "8.6.2", "8.6.1", "8.6.0")
	// shuffle-ish: sort rev descending to differ from forward
	sort.Sort(sort.Reverse(semver.Collection(rev)))
	a := groupByMinor(forward)
	b := groupByMinor(rev)
	if a["8.6"].String() != b["8.6"].String() {
		t.Fatalf("order-dependent: %q vs %q", a["8.6"], b["8.6"])
	}
	if a["8.6"].String() != "8.6.2" {
		t.Fatalf("expected latest 8.6.2, got %q", a["8.6"])
	}
}
```

Rode e capture a falha:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run 'TestSegregateStable|TestGroupByMinor' 2>&1 | head -8
```
Saída esperada: `undefined: segregateStable` / `undefined: groupByMinor` e `[build failed]`.

### Passo 2 (GREEN) — Implementar window.go
Crie `/home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window.go`:
```go
package main

import (
	"fmt"

	"github.com/Masterminds/semver/v3"
)

// segregateStable drops every pre-release version (e.g. -beta.N, -HELM-N,
// -rc.N). Per TRD §2, pre-releases never become their own support cycle; they
// are removed before minors are computed. Input order is preserved for the
// survivors.
func segregateStable(vs []*semver.Version) []*semver.Version {
	out := make([]*semver.Version, 0, len(vs))
	for _, v := range vs {
		if v.Prerelease() != "" {
			continue
		}
		out = append(out, v)
	}
	return out
}

// minorKey renders the "MAJOR.MINOR" cycle key for a version.
func minorKey(v *semver.Version) string {
	return fmt.Sprintf("%d.%d", v.Major(), v.Minor())
}

// groupByMinor buckets stable versions by their MAJOR.MINOR cycle, keeping the
// highest patch in each bucket. The result is deterministic regardless of input
// order because the winner is chosen by semver comparison, not by position.
func groupByMinor(vs []*semver.Version) map[string]*semver.Version {
	latest := map[string]*semver.Version{}
	for _, v := range vs {
		key := minorKey(v)
		if cur, ok := latest[key]; !ok || v.GreaterThan(cur) {
			latest[key] = v
		}
	}
	return latest
}
```

### Passo 3 — Rodar os testes
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go test ./generate-compatibility/ -run 'TestSegregateStable|TestGroupByMinor' 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-3-2_OK"
```
Saída esperada: termina com `ST-3-2_OK`.

## Rollback
```bash
rm -f /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window.go \
      /home/gauchito/lerian/helm/.github/scripts/generate-compatibility/window_test.go
```
