package main

import (
	"strings"
	"testing"
)

// A file:///tmp/lib dependency yields an absolute relPath ("/tmp/lib"). Helm
// resolves it verbatim at render time (outside the repo), so it must be rejected
// before the containment check — which filepath.Join would otherwise let pass by
// folding the leading slash into chartDir.
func TestMaterializeLocalDependencies_RejectsAbsolutePath(t *testing.T) {
	deps := []chartDependency{{Name: "lib", Repository: "file:///tmp/lib"}}
	err := materializeLocalDependencies("/repo", "/repo/charts/x", "/tmp/render", "/tmp/render/x", deps)
	if err == nil {
		t.Fatal("expected error for absolute file:// dependency, got nil")
	}
	if !strings.Contains(err.Error(), "absolute path") {
		t.Fatalf("expected absolute-path error, got: %v", err)
	}
}

func TestWithinDir(t *testing.T) {
	cases := []struct {
		name         string
		base, target string
		want         bool
	}{
		{"base itself", "/repo", "/repo", true},
		{"nested", "/repo", "/repo/charts/lib", true},
		{"parent traversal", "/repo", "/repo/../etc", false},
		{"sibling absolute", "/repo", "/etc", false},
	}
	for _, c := range cases {
		if got := withinDir(c.base, c.target); got != c.want {
			t.Errorf("%s: withinDir(%q,%q)=%v want %v", c.name, c.base, c.target, got, c.want)
		}
	}
}
