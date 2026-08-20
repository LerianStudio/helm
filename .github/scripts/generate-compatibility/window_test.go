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
