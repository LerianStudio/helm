package main

import (
	"strings"
	"testing"
)

func joined(lines []string) string { return strings.Join(lines, "\n") }

func TestRenderCompatTable(t *testing.T) {
	t.Run("single app col, Released before Support, EOL ceiling row", func(t *testing.T) {
		p := Product{
			Dir: "midaz", Current: "8.6.0",
			Cycles: []Cycle{
				{Cycle: "8.6", Latest: "8.6.0", Released: "2026-06-01", Supported: true},
				{Cycle: "8.5", Latest: "8.5.0", Released: "2026-05-01", Supported: true},
				{Cycle: "8.4", Latest: "8.4.0", Released: "2026-04-01", Supported: true},
				{Cycle: "8.3", Latest: "8.3.0", Released: "2026-03-01", Supported: true},
				{Cycle: "8.2", Latest: "8.2.0", Released: "2026-02-01", Supported: false},
				{Cycle: "8.1", Latest: "8.1.0", Released: "2026-01-01", Supported: false},
			},
		}
		out := joined(renderCompatTable(p, []string{"Midaz"}, map[string]string{"Midaz": "3.7.8"}))
		for _, must := range []string{
			"| Chart Version | Midaz Version | Released | Support |",
			"| :---: | :---: | :---: | :---: |",
			"| `8.6.0` | 3.7.8 | 2026-06-01 | 🟢 Full (N) |",
			"| `8.5.0` | — | 2026-05-01 | 🔵 Security (N-1) |",
			"| `8.4.0` | — | 2026-04-01 | 🟡 Extended (N-2) |",
			"| `8.3.0` | — | 2026-03-01 | 🟠 Extended (N-3) |",
		} {
			if !strings.Contains(out, must) {
				t.Errorf("missing %q in:\n%s", must, out)
			}
		}
		// EOL row: ceiling reference, Released = — (aggregate).
		if !strings.Contains(out, "| `≤ 8.2.0` | — | — | 🔴 EOL |") {
			t.Errorf("expected EOL ceiling row with Released=— , got:\n%s", out)
		}
		if strings.Contains(out, "8.1") {
			t.Errorf("EOL row must not list lower cycles (8.1 leaked):\n%s", out)
		}
		if strings.Count(out, "🔴") != 1 {
			t.Errorf("expected exactly one EOL (🔴) line, got %d\n%s", strings.Count(out, "🔴"), out)
		}
	})

	t.Run("multi app cols + Released + Requer coexist", func(t *testing.T) {
		p := Product{
			Dir: "plugin-fees", Current: "7.2.0",
			Cycles: []Cycle{
				{Cycle: "7.2", Latest: "7.2.0", Released: "2026-06-15", Supported: true,
					Requires: map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"}},
				{Cycle: "7.1", Latest: "7.1.0", Released: "2026-05-10", Supported: true},
			},
		}
		out := joined(renderCompatTable(p, []string{"Fees", "UI"}, map[string]string{"Fees": "3.3.0", "UI": "3.0.0"}))
		if !strings.Contains(out, "| Chart Version | Fees Version | UI Version | Released | Support | Requer midaz-helm |") {
			t.Errorf("multi-app + Released + Requer header wrong:\n%s", out)
		}
		// N row: both app cols filled, Released set, Requer = real range.
		if !strings.Contains(out, "| `7.2.0` | 3.3.0 | 3.0.0 | 2026-06-15 | 🟢 Full (N) | >=8.4.0 <9.0.0 |") {
			t.Errorf("N row wrong:\n%s", out)
		}
		// N-1 row: app cols —, Released set (its own tag date), Requer —.
		if !strings.Contains(out, "| `7.1.0` | — | — | 2026-05-10 | 🔵 Security (N-1) | — |") {
			t.Errorf("N-1 row wrong:\n%s", out)
		}
	})

	t.Run("unknown release date => Released — ; unresolved app col => — even on N", func(t *testing.T) {
		p := Product{
			Dir: "plugin-fees", Current: "7.2.0",
			Cycles: []Cycle{{Cycle: "7.2", Latest: "7.2.0", Supported: true}}, // no Released
		}
		out := joined(renderCompatTable(p, []string{"Fees", "UI"}, map[string]string{"Fees": "3.3.0"}))
		if !strings.Contains(out, "| `7.2.0` | 3.3.0 | — | — | 🟢 Full (N) |") {
			t.Errorf("expected UI=— and Released=— on N, got:\n%s", out)
		}
	})

	t.Run("no requires => no Requer column (tracer pilot shape) with Released", func(t *testing.T) {
		p := Product{
			Dir: "tracer", Current: "2.1.0",
			Cycles: []Cycle{
				{Cycle: "2.1", Latest: "2.1.0", Released: "2026-06-18", Supported: true},
				{Cycle: "2.0", Latest: "2.0.0", Released: "2026-06-09", Supported: true},
				{Cycle: "1.0", Latest: "1.0.0", Released: "2026-01-30", Supported: true},
			},
		}
		out := joined(renderCompatTable(p, []string{"Tracer"}, map[string]string{"Tracer": "1.0.0"}))
		if strings.Contains(out, "Requer") {
			t.Errorf("did not expect Requer column, got:\n%s", out)
		}
		if !strings.Contains(out, "| Chart Version | Tracer Version | Released | Support |") {
			t.Errorf("expected Tracer header with Released, got:\n%s", out)
		}
		if !strings.Contains(out, "| `2.1.0` | 1.0.0 | 2026-06-18 | 🟢 Full (N) |") {
			t.Errorf("expected N row, got:\n%s", out)
		}
		if !strings.Contains(out, "| `2.0.0` | — | 2026-06-09 | 🔵 Security (N-1) |") {
			t.Errorf("expected N-1 row, got:\n%s", out)
		}
		if !strings.Contains(out, "| `1.0.0` | — | 2026-01-30 | 🟡 Extended (N-2) |") {
			t.Errorf("expected N-2 row, got:\n%s", out)
		}
		if strings.Contains(out, "🔴") {
			t.Errorf("all supported => no EOL line, got:\n%s", out)
		}
	})
}
