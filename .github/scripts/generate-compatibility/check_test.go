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
