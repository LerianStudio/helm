package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// seedRepo builds a minimal repo (charts/ + README.md) for run() tests.
func seedRepo(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	writeChart(t, root, "matcher", `apiVersion: v2
name: matcher-helm
type: application
version: 3.0.0
`)
	readme := "# Charts\n\n### Matcher\n\nprose\n"
	if err := os.WriteFile(filepath.Join(root, "README.md"), []byte(readme), 0o644); err != nil {
		t.Fatalf("seed readme: %v", err)
	}
	if err := os.MkdirAll(filepath.Join(root, "docs"), 0o755); err != nil {
		t.Fatalf("mkdir docs: %v", err)
	}
	return root
}

func TestRun_ExitCodes(t *testing.T) {
	t.Run("conflicting --write and --check => exit 2", func(t *testing.T) {
		var out, errb bytes.Buffer
		code := run([]string{"--write", "--check"}, &out, &errb)
		if code != 2 {
			t.Fatalf("exit = %d, want 2. stderr=%s", code, errb.String())
		}
	})

	t.Run("missing --root => exit 1", func(t *testing.T) {
		var out, errb bytes.Buffer
		code := run([]string{"--root", "/no/such/dir/xyz"}, &out, &errb)
		if code != 1 {
			t.Fatalf("exit = %d, want 1. stderr=%s", code, errb.String())
		}
	})

	t.Run("valid write => exit 0", func(t *testing.T) {
		root := seedRepo(t)
		var out, errb bytes.Buffer
		code := run([]string{"--root", root, "--output", "docs/compatibility.json"}, &out, &errb)
		if code != 0 {
			t.Fatalf("exit = %d, want 0. stderr=%s", code, errb.String())
		}
		if _, err := os.Stat(filepath.Join(root, "docs", "compatibility.json")); err != nil {
			t.Fatalf("expected JSON written: %v", err)
		}
	})

	t.Run("unknown --chart => exit 2, nothing written", func(t *testing.T) {
		root := seedRepo(t)
		// Snapshot the README before the run so we can prove it stays byte-identical
		// (a future partial-write bug that touched README before validating --chart
		// would be caught here).
		readmePath := filepath.Join(root, "README.md")
		before, err := os.ReadFile(readmePath)
		if err != nil {
			t.Fatalf("read README before: %v", err)
		}

		var out, errb bytes.Buffer
		code := run([]string{"--root", root, "--chart", "does-not-exist-helm", "--output", "docs/compatibility.json"}, &out, &errb)
		if code != 2 {
			t.Fatalf("exit = %d, want 2 (usage). stderr=%s", code, errb.String())
		}
		if !strings.Contains(errb.String(), "unknown chart") {
			t.Errorf("stderr should mention unknown chart, got %q", errb.String())
		}
		// Neither the JSON nor the README must be written on a usage error.
		if _, err := os.Stat(filepath.Join(root, "docs", "compatibility.json")); err == nil {
			t.Error("JSON must NOT be written on unknown --chart")
		}
		after, err := os.ReadFile(readmePath)
		if err != nil {
			t.Fatalf("read README after: %v", err)
		}
		if string(after) != string(before) {
			t.Fatalf("README must NOT change on unknown --chart:\n--before--\n%s\n--after--\n%s", before, after)
		}
	})
}
