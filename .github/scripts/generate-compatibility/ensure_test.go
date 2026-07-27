package main

import (
	"strings"
	"testing"
)

func TestEnsureCompatBlock(t *testing.T) {
	body := []string{"| Version | Support |", "| :---: | :---: |", "| `1.0.0` | 🟢 |"}

	t.Run("existing markers => replace path", func(t *testing.T) {
		doc := strings.Split("### X\n\n<!-- BEGIN COMPAT:x-helm -->\nOLD\n<!-- END COMPAT:x-helm -->", "\n")
		out, err := ensureCompatBlock(doc, "x-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		s := strings.Join(out, "\n")
		if strings.Contains(s, "OLD") || !strings.Contains(s, "1.0.0") {
			t.Errorf("replace path failed:\n%s", s)
		}
	})

	t.Run("existing table => replaced IN PLACE (no duplicate), prose+heading kept", func(t *testing.T) {
		doc := strings.Split("### Matcher\n\nExisting prose.\n\n#### Application Version Mapping\n\n| Chart Version | Matcher Version |\n| :---: | :---: |\n| `3.0.0` | 1.0.0 |\n\n-----------------", "\n")
		out, err := ensureCompatBlock(doc, "matcher-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		s := strings.Join(out, "\n")
		// Prose, heading and trailing separator preserved.
		if !strings.Contains(s, "Existing prose.") {
			t.Error("prose lost")
		}
		if !strings.Contains(s, "#### Application Version Mapping") {
			t.Error("mapping heading lost")
		}
		if !strings.Contains(s, "-----------------") {
			t.Error("trailing separator lost")
		}
		// Markers + new body present.
		if !strings.Contains(s, "<!-- BEGIN COMPAT:matcher-helm -->") || !strings.Contains(s, "1.0.0") {
			t.Errorf("markers/body not present:\n%s", s)
		}
		// The OLD simple table must be GONE (replaced in place, not duplicated).
		if strings.Contains(s, "| Chart Version | Matcher Version |") {
			t.Errorf("old table still present (duplicate!):\n%s", s)
		}
		// Exactly one marker pair.
		if strings.Count(s, "<!-- BEGIN COMPAT:matcher-helm -->") != 1 ||
			strings.Count(s, "<!-- END COMPAT:matcher-helm -->") != 1 {
			t.Errorf("markers duplicated:\n%s", s)
		}
		// Block sits where the table was: AFTER the mapping heading, BEFORE the separator.
		beginIdx := indexOfLine(out, "<!-- BEGIN COMPAT:matcher-helm -->")
		headingIdx := indexOfLine(out, "#### Application Version Mapping")
		sepIdx := indexOfLine(out, "-----------------")
		if !(headingIdx != -1 && beginIdx > headingIdx && beginIdx < sepIdx) {
			t.Errorf("block not placed at table location (heading=%d begin=%d sep=%d)", headingIdx, beginIdx, sepIdx)
		}
	})

	t.Run("in-place replace is idempotent (run 1 converts table, run 2 swaps body)", func(t *testing.T) {
		doc := strings.Split("### Matcher\n\nprose\n\n#### Application Version Mapping\n\n| Chart Version | Matcher Version |\n| :---: | :---: |\n| `3.0.0` | 1.0.0 |\n\n-----------------", "\n")
		once, err := ensureCompatBlock(doc, "matcher-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		twice, err := ensureCompatBlock(once, "matcher-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		if strings.Join(once, "\n") != strings.Join(twice, "\n") {
			t.Fatalf("in-place path not idempotent:\n--once--\n%s\n--twice--\n%s", strings.Join(once, "\n"), strings.Join(twice, "\n"))
		}
		// No duplicate markers after two runs.
		s := strings.Join(twice, "\n")
		if strings.Count(s, "<!-- BEGIN COMPAT:matcher-helm -->") != 1 {
			t.Errorf("markers duplicated after 2 runs:\n%s", s)
		}
	})

	t.Run("no section (ADR-5 br-spi) => create minimal section at end", func(t *testing.T) {
		doc := strings.Split("# Charts\n\n### Midaz Helm Chart\n\nprose", "\n")
		out, err := ensureCompatBlock(doc, "br-spi-helm", body)
		if err != nil {
			t.Fatal(err)
		}
		s := strings.Join(out, "\n")
		if !strings.Contains(s, "### Br Spi") {
			t.Errorf("minimal section title not created:\n%s", s)
		}
		if !strings.Contains(s, "<!-- BEGIN COMPAT:br-spi-helm -->") {
			t.Error("markers not created")
		}
		if !strings.Contains(s, "prose") || !strings.Contains(s, "### Midaz Helm Chart") {
			t.Error("existing content disturbed")
		}
	})

	t.Run("idempotent across all paths", func(t *testing.T) {
		doc := strings.Split("# Charts\n\n### Midaz Helm Chart\n\nprose", "\n")
		once, _ := ensureCompatBlock(doc, "br-spi-helm", body)
		twice, _ := ensureCompatBlock(once, "br-spi-helm", body)
		if strings.Join(once, "\n") != strings.Join(twice, "\n") {
			t.Fatalf("not idempotent:\n--once--\n%s\n--twice--\n%s", strings.Join(once, "\n"), strings.Join(twice, "\n"))
		}
	})
}

func indexOfLine(lines []string, want string) int {
	for i, l := range lines {
		if strings.TrimSpace(l) == want {
			return i
		}
	}
	return -1
}
