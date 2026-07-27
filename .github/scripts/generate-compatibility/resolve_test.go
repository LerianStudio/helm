package main

import (
	"strings"
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
	t.Run("N=8.6.0 with 8.6..8.2 => top-4 supported, 8.2 unsupported", func(t *testing.T) {
		cs, ws := resolveWindow("8.6.0", tagVers(t,
			"8.6.0", "8.5.0", "8.4.0", "8.3.0", "8.2.0"), nil)
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
		cs, _ := resolveWindow("8.6.0", tagVers(t, "8.5.0", "8.4.0"), nil)
		got := cyclePairs(cs)
		// N=8.6 must appear as top cycle, supported, latest=8.6.0 (from Chart.yaml).
		if got[0].cycle != "8.6" || got[0].supported != true || got[0].latest != "8.6.0" {
			t.Fatalf("N cycle wrong: %+v", got[0])
		}
	})

	t.Run("0 tags => only N cycle + INFO", func(t *testing.T) {
		cs, ws := resolveWindow("1.0.0", tagVers(t), nil)
		if len(cs) != 1 || cs[0].Cycle != "1.0" || !cs[0].Supported || cs[0].Latest != "1.0.0" {
			t.Fatalf("expected single supported N cycle, got %+v", cs)
		}
		if !hasINFO(ws) {
			t.Fatal("expected INFO warning for 0 tags")
		}
	})

	t.Run("<4 minors => only existing", func(t *testing.T) {
		cs, _ := resolveWindow("3.0.0", tagVers(t, "3.0.0", "2.9.0"), nil)
		got := cyclePairs(cs)
		want := [][3]string{
			{"3.0", "3.0.0", "true"},
			{"2.9", "2.9.0", "true"},
		}
		assertCycles(t, got, want)
	})

	t.Run("pre-release tag is ignored, does not create a cycle", func(t *testing.T) {
		cs, _ := resolveWindow("8.6.0", tagVers(t, "8.6.0-beta.11", "8.6.0", "8.5.0"), nil)
		for _, c := range cs {
			if c.Cycle == "8.6" && c.Latest != "8.6.0" {
				t.Fatalf("pre-release leaked into cycle: %+v", c)
			}
		}
		if len(cs) != 2 {
			t.Fatalf("expected 2 cycles (8.6, 8.5), got %d: %+v", len(cs), cs)
		}
	})

	t.Run("patch ABOVE N in the same minor must NOT erase the N cycle", func(t *testing.T) {
		// N=8.6.0 (nKey 8.6). A stray tag 8.6.1 (patch above N, same minor) must
		// not hijack the 8.6 slot and then get dropped, which would delete the N
		// cycle entirely. N is authoritative from Chart.yaml: the 8.6 cycle must
		// exist with latest=8.6.0.
		cs, _ := resolveWindow("8.6.0", tagVers(t, "8.6.1", "8.6.0", "8.5.0"), nil)
		var found *Cycle
		for i := range cs {
			if cs[i].Cycle == "8.6" {
				found = &cs[i]
			}
		}
		if found == nil {
			t.Fatalf("N cycle 8.6 disappeared: %+v", cs)
		}
		if found.Latest != "8.6.0" || !found.Supported {
			t.Fatalf("N cycle wrong (want latest=8.6.0 supported=true): %+v", *found)
		}
		if cs[0].Cycle != "8.6" {
			t.Fatalf("top cycle should be N=8.6, got %q", cs[0].Cycle)
		}
		// 8.6.1 must never surface as its own cycle.
		for _, c := range cs {
			if c.Latest == "8.6.1" {
				t.Fatalf("patch above N leaked as latest: %+v", cs)
			}
		}
	})

	t.Run("higher tag than N is dropped (never exceeds N)", func(t *testing.T) {
		// A tag 8.7.0 exists but Chart.yaml says N=8.6.0: 8.7 must NOT appear.
		cs, _ := resolveWindow("8.6.0", tagVers(t, "8.7.0", "8.6.0", "8.5.0"), nil)
		for _, c := range cs {
			if c.Cycle == "8.7" {
				t.Fatalf("cycle above N leaked in: %+v", cs)
			}
		}
		if cs[0].Cycle != "8.6" {
			t.Fatalf("top cycle should be N=8.6, got %q", cs[0].Cycle)
		}
	})

	// Real pilot case: tracer N=2.1.0. Stable tags 1.0.0/2.0.0/2.1.0 plus many
	// betas plus 2.2.0-beta.1 (a pre-release ABOVE N). Expect exactly the three
	// stable minors, all supported (<4), no EOL, and no INFO (tags exist).
	t.Run("tracer pilot: N=2.1.0, betas + 2.2.0-beta.1 above N discarded", func(t *testing.T) {
		cs, ws := resolveWindow("2.1.0", tagVers(t,
			"1.0.0", "1.0.0-beta.1",
			"2.0.0", "2.0.0-beta.1", "2.0.0-beta.2", "2.0.0-beta.3",
			"2.0.0-beta.4", "2.0.0-beta.5", "2.0.0-beta.6", "2.0.0-beta.7",
			"2.1.0", "2.1.0-beta.1", "2.1.0-beta.2",
			"2.2.0-beta.1"), nil)
		got := cyclePairs(cs)
		want := [][3]string{
			{"2.1", "2.1.0", "true"},
			{"2.0", "2.0.0", "true"},
			{"1.0", "1.0.0", "true"},
		}
		assertCycles(t, got, want)
		assertNoINFO(t, ws)
	})

	t.Run("release dates associate to each cycle by its latest version", func(t *testing.T) {
		dates := map[string]string{
			"2.1.0": "2026-06-18",
			"2.0.0": "2026-06-09",
			"1.0.0": "2026-01-30",
			// 2.2.0-beta.1 date intentionally present but must be ignored (pre-release).
			"2.2.0-beta.1": "2026-07-01",
		}
		cs, _ := resolveWindow("2.1.0", tagVers(t, "1.0.0", "2.0.0", "2.1.0", "2.2.0-beta.1"), dates)
		want := map[string]string{"2.1": "2026-06-18", "2.0": "2026-06-09", "1.0": "2026-01-30"}
		if len(cs) != 3 {
			t.Fatalf("expected 3 cycles, got %d: %+v", len(cs), cs)
		}
		for _, c := range cs {
			if c.Released != want[c.Cycle] {
				t.Errorf("cycle %s Released = %q, want %q", c.Cycle, c.Released, want[c.Cycle])
			}
		}
	})

	t.Run("only pre-release tags => INFO with pre-release message, window = only N", func(t *testing.T) {
		// N=2.0.0 but every tag is a pre-release: segregateStable filters them all,
		// leaving only the forced N cycle. This is the same degraded state as "0
		// tags" and must emit an INFO — with a message that says pre-release, not
		// "no published tags".
		cs, ws := resolveWindow("2.0.0", tagVers(t, "2.0.0-beta.1", "1.0.0-beta.2"), nil)
		if len(cs) != 1 || cs[0].Cycle != "2.0" || cs[0].Latest != "2.0.0" || !cs[0].Supported {
			t.Fatalf("expected single N cycle, got %+v", cs)
		}
		if !hasINFO(ws) {
			t.Fatalf("expected INFO for all-pre-release tags, got %+v", ws)
		}
		var infoMsg string
		for _, w := range ws {
			if w.Severity == SevInfo {
				infoMsg = w.Detail
			}
		}
		if !strings.Contains(infoMsg, "pre-release") {
			t.Errorf("INFO message should mention pre-release, got %q", infoMsg)
		}
	})

	t.Run("0 tags keeps the 'no published tags' message", func(t *testing.T) {
		_, ws := resolveWindow("1.0.0", tagVers(t), nil)
		var infoMsg string
		for _, w := range ws {
			if w.Severity == SevInfo {
				infoMsg = w.Detail
			}
		}
		if !strings.Contains(infoMsg, "no published tags") {
			t.Errorf("expected 'no published tags' message, got %q", infoMsg)
		}
	})

	t.Run("cycle with no known date has empty Released", func(t *testing.T) {
		// N=5.0.0 with a tag but no date entry => Released stays "".
		cs, _ := resolveWindow("5.0.0", tagVers(t, "5.0.0"), map[string]string{})
		if len(cs) != 1 || cs[0].Released != "" {
			t.Fatalf("expected empty Released, got %+v", cs)
		}
	})
}

func TestParseTagDates(t *testing.T) {
	raw := "tracer-v2.1.0 2026-06-18\ntracer-v2.0.0 2026-06-09\n\ntracer-v1.0.0\nmalformed-line-no-space\n"
	got := parseTagDates(raw)
	if got["tracer-v2.1.0"] != "2026-06-18" || got["tracer-v2.0.0"] != "2026-06-09" {
		t.Errorf("dates not parsed: %v", got)
	}
	// A tag with no date field is omitted.
	if _, ok := got["tracer-v1.0.0"]; ok {
		t.Errorf("expected tracer-v1.0.0 omitted (no date), got %v", got)
	}
}

func TestReleaseDatesByVersion(t *testing.T) {
	in := map[string]string{
		"tracer-v2.1.0":       "2026-06-18",
		"tracer-v2.2.0-beta.1": "2026-07-01",
		"other-v1.0.0":         "2020-01-01", // wrong prefix, ignored
		"tracer-vNOTSEMVER":    "2020-01-01", // unparseable, ignored
	}
	got := releaseDatesByVersion("tracer", in)
	if got["2.1.0"] != "2026-06-18" {
		t.Errorf("2.1.0 date = %q", got["2.1.0"])
	}
	if got["2.2.0-beta.1"] != "2026-07-01" {
		t.Errorf("pre-release date should still map by version string: %v", got)
	}
	if _, ok := got["1.0.0"]; ok {
		t.Errorf("other-dir tag leaked: %v", got)
	}
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
