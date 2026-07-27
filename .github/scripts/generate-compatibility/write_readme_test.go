package main

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// seedValues writes charts/<dir>/values.yaml so resolveAppVersions can resolve
// the N-row app versions from {component}.image.tag (shared tableutil logic).
func seedValues(t *testing.T, root, dir, body string) {
	t.Helper()
	full := filepath.Join(root, "charts", dir)
	if err := os.MkdirAll(full, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", dir, err)
	}
	if err := os.WriteFile(filepath.Join(full, "values.yaml"), []byte(body), 0o644); err != nil {
		t.Fatalf("write values %s: %v", dir, err)
	}
}

func TestWriteReadme_IrregularLayoutsGolden(t *testing.T) {
	in, err := os.ReadFile(filepath.Join("testdata", "readme_irregular_in.md"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}

	root := t.TempDir()
	readmePath := filepath.Join(root, "README.md")
	if err := os.WriteFile(readmePath, in, 0o644); err != nil {
		t.Fatalf("seed README: %v", err)
	}
	// fees.image.tag resolves the "Fees Version" column; there is deliberately no
	// ui: section, so "UI Version" stays "—" (mirrors the real plugin-fees).
	seedValues(t, root, "plugin-fees", "fees:\n  image:\n    tag: \"3.3.0\"\n")
	seedValues(t, root, "matcher", "matcher:\n  image:\n    tag: \"1.0.0\"\n")

	doc := CompatDoc{
		SchemaVersion: 1,
		Products: map[string]Product{
			"plugin-fees-helm": {Dir: "plugin-fees", Current: "7.2.0", Cycles: []Cycle{
				{Cycle: "7.2", Latest: "7.2.0", Supported: true,
					Requires: map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"}},
			}},
			"matcher-helm": {Dir: "matcher", Current: "3.0.0", Cycles: []Cycle{
				{Cycle: "3.0", Latest: "3.0.0", Supported: true},
			}},
		},
	}

	if err := writeReadme(root, doc, io.Discard); err != nil {
		t.Fatalf("writeReadme: %v", err)
	}

	got, err := os.ReadFile(readmePath)
	if err != nil {
		t.Fatalf("read result: %v", err)
	}

	goldenPath := filepath.Join("testdata", "readme_irregular_golden.md")
	if os.Getenv("UPDATE_GOLDEN") == "1" {
		if err := os.WriteFile(goldenPath, got, 0o644); err != nil {
			t.Fatalf("update golden: %v", err)
		}
	}
	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden (run UPDATE_GOLDEN=1 first): %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("README mismatch.\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}

	// Structural invariants that must hold regardless of golden bytes:
	s := string(got)
	if !strings.Contains(s, "-----------------") {
		t.Error("Plugin Fees separator was destroyed")
	}
	if !strings.Contains(s, "### Flowker") {
		t.Error("Flowker section header lost")
	}
	// In-place replacement: the "#### Application Version Mapping" heading stays.
	if strings.Count(s, "#### Application Version Mapping") != 2 {
		t.Errorf("expected both mapping headings preserved, got %d:\n%s", strings.Count(s, "#### Application Version Mapping"), s)
	}
	// The ORIGINAL simple tables must be GONE (replaced in place, not duplicated).
	if strings.Contains(s, "| Chart Version | Matcher Version |\n| :---: | :---: |") {
		t.Errorf("Matcher original 2-col table still present (duplicate!):\n%s", s)
	}
	if strings.Contains(s, "| Chart Version | Fees Version | UI Version |\n| :---: | :---: | :---: |") {
		t.Errorf("Fees original 3-col table still present (duplicate!):\n%s", s)
	}
	// Exactly one COMPAT block per chart.
	if strings.Count(s, "<!-- BEGIN COMPAT:matcher-helm -->") != 1 ||
		strings.Count(s, "<!-- BEGIN COMPAT:plugin-fees-helm -->") != 1 {
		t.Errorf("duplicate COMPAT blocks:\n%s", s)
	}
	// Enriched blocks reuse the existing app label(s) and carry Released+Support.
	// This test has no git tags in the temp root, so Released is "—".
	if !strings.Contains(s, "| Chart Version | Matcher Version | Released | Support |") {
		t.Errorf("Matcher COMPAT block missing rich header:\n%s", s)
	}
	if !strings.Contains(s, "| `3.0.0` | 1.0.0 | — | 🟢 Full (N) |") {
		t.Errorf("Matcher N row wrong (resolved app version/released/support):\n%s", s)
	}
	// Multi-app fees: Fees Version resolved from values.yaml; UI Version has no
	// values source so it stays "—" even on the N row (no invention).
	if !strings.Contains(s, "| Chart Version | Fees Version | UI Version | Released | Support | Requires midaz-helm |") {
		t.Errorf("Plugin Fees COMPAT block missing multi-app rich header:\n%s", s)
	}
	if !strings.Contains(s, "| `7.2.0` | 3.3.0 | — | — | 🟢 Full (N) | >=8.4.0 <9.0.0 |") {
		t.Errorf("Plugin Fees N row wrong (Fees=3.3.0, UI=—, Released=—):\n%s", s)
	}
}

// TestWriteReadme_Idempotent proves running twice yields identical bytes.
func TestWriteReadme_Idempotent(t *testing.T) {
	in, err := os.ReadFile(filepath.Join("testdata", "readme_irregular_in.md"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	root := t.TempDir()
	readmePath := filepath.Join(root, "README.md")
	if err := os.WriteFile(readmePath, in, 0o644); err != nil {
		t.Fatalf("seed README: %v", err)
	}
	seedValues(t, root, "matcher", "matcher:\n  image:\n    tag: \"1.0.0\"\n")

	doc := CompatDoc{SchemaVersion: 1, Products: map[string]Product{
		"matcher-helm": {Dir: "matcher", Current: "3.0.0", Cycles: []Cycle{{Cycle: "3.0", Latest: "3.0.0", Supported: true}}},
	}}

	if err := writeReadme(root, doc, io.Discard); err != nil {
		t.Fatalf("writeReadme (first): %v", err)
	}
	first, err := os.ReadFile(readmePath)
	if err != nil {
		t.Fatalf("read first: %v", err)
	}
	if err := writeReadme(root, doc, io.Discard); err != nil {
		t.Fatalf("writeReadme (second): %v", err)
	}
	second, err := os.ReadFile(readmePath)
	if err != nil {
		t.Fatalf("read second: %v", err)
	}
	if string(first) != string(second) {
		t.Fatalf("writeReadme not idempotent:\n--first--\n%s\n--second--\n%s", first, second)
	}
}

// TestWriteReadme_MigratesLegacyRequerLabel proves a README whose COMPAT block
// was generated with the old Portuguese "Requer" label migrates cleanly to
// "Requires" on the next run: in-place rewrite, one table, no leftover "Requer",
// and the app columns are NOT inflated by the stale generated header.
func TestWriteReadme_MigratesLegacyRequerLabel(t *testing.T) {
	root := t.TempDir()
	readmePath := filepath.Join(root, "README.md")
	// Legacy README: the COMPAT block already carries the old "Requer" header.
	legacy := `# Charts

### Plugin Fees Helm Chart

Fees prose.

#### Application Version Mapping

<!-- BEGIN COMPAT:plugin-fees-helm -->
| Chart Version | Fees Version | UI Version | Released | Support | Requer midaz-helm |
| :---: | :---: | :---: | :---: | :---: | :---: |
| ` + "`7.2.0`" + ` | 3.3.0 | — | 2026-06-15 | 🟢 Full (N) | >=8.4.0 <9.0.0 |
<!-- END COMPAT:plugin-fees-helm -->

-----------------
`
	if err := os.WriteFile(readmePath, []byte(legacy), 0o644); err != nil {
		t.Fatalf("seed legacy README: %v", err)
	}
	seedValues(t, root, "plugin-fees", "fees:\n  image:\n    tag: \"3.3.0\"\n")

	doc := CompatDoc{SchemaVersion: 1, Products: map[string]Product{
		"plugin-fees-helm": {Dir: "plugin-fees", Current: "7.2.0", Cycles: []Cycle{
			{Cycle: "7.2", Latest: "7.2.0", Released: "2026-06-15", Supported: true,
				Requires: map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"}},
		}},
	}}

	if err := writeReadme(root, doc, io.Discard); err != nil {
		t.Fatalf("writeReadme (migrate): %v", err)
	}
	got, err := os.ReadFile(readmePath)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	s := string(got)

	// New label present, old label gone.
	if !strings.Contains(s, "| Chart Version | Fees Version | UI Version | Released | Support | Requires midaz-helm |") {
		t.Errorf("migrated header wrong:\n%s", s)
	}
	if strings.Contains(s, "Requer ") || strings.Contains(s, "| Requer midaz-helm |") {
		t.Errorf("legacy 'Requer' label leaked after migration:\n%s", s)
	}
	// App columns not inflated: exactly one COMPAT block, exactly two app cols
	// (Fees, UI) — the stale generated columns must not have been read as apps.
	if strings.Count(s, "<!-- BEGIN COMPAT:plugin-fees-helm -->") != 1 {
		t.Errorf("expected exactly one block after migration:\n%s", s)
	}
	if !strings.Contains(s, "| `7.2.0` | 3.3.0 | — | 2026-06-15 | 🟢 Full (N) | >=8.4.0 <9.0.0 |") {
		t.Errorf("migrated N row wrong (columns inflated?):\n%s", s)
	}
	// Prose + separator preserved.
	if !strings.Contains(s, "Fees prose.") || !strings.Contains(s, "-----------------") {
		t.Errorf("surrounding content disturbed:\n%s", s)
	}

	// And it is now idempotent under the new label.
	if err := writeReadme(root, doc, io.Discard); err != nil {
		t.Fatalf("writeReadme (second): %v", err)
	}
	again, err := os.ReadFile(readmePath)
	if err != nil {
		t.Fatalf("read again: %v", err)
	}
	if string(again) != s {
		t.Fatalf("not idempotent after migration:\n--first--\n%s\n--second--\n%s", s, again)
	}
}
