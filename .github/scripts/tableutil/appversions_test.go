package tableutil

import (
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"
)

func writeValues(t *testing.T, body string) string {
	t.Helper()
	dir := t.TempDir()
	p := filepath.Join(dir, "values.yaml")
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatalf("write values: %v", err)
	}
	return p
}

func TestExtractAppVersionsFromValues(t *testing.T) {
	t.Run("multi-component: found + missing", func(t *testing.T) {
		vals := `fees:
  image:
    tag: "3.3.0"
mongodb:
  enabled: true
`
		p := writeValues(t, vals)
		res, err := ExtractAppVersionsFromValues(p, []string{"Chart Version", "Fees Version", "UI Version"})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		want := map[string]string{"Fees Version": "3.3.0"}
		if !reflect.DeepEqual(res.Found, want) {
			t.Errorf("Found = %v, want %v", res.Found, want)
		}
		if !reflect.DeepEqual(res.Missing, []string{"UI Version"}) {
			t.Errorf("Missing = %v, want [UI Version]", res.Missing)
		}
	})

	t.Run("root-level image.tag fallback (product-console shape)", func(t *testing.T) {
		vals := `image:
  tag: "2.5.0"
`
		p := writeValues(t, vals)
		res, err := ExtractAppVersionsFromValues(p, []string{"Chart Version", "Console Version"})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if res.Found["Console Version"] != "2.5.0" {
			t.Errorf("Console Version = %q, want 2.5.0 (root fallback)", res.Found["Console Version"])
		}
	})

	t.Run("numeric tag coerced to string", func(t *testing.T) {
		vals := `app:
  image:
    tag: 42
`
		p := writeValues(t, vals)
		res, _ := ExtractAppVersionsFromValues(p, []string{"App Version"})
		if res.Found["App Version"] != "42" {
			t.Errorf("App Version = %q, want 42", res.Found["App Version"])
		}
	})

	t.Run("missing file => all eligible headers missing + error", func(t *testing.T) {
		res, err := ExtractAppVersionsFromValues(filepath.Join(t.TempDir(), "nope.yaml"), []string{"Chart Version", "Fees Version"})
		if err == nil {
			t.Fatal("expected error for missing file")
		}
		if !reflect.DeepEqual(res.Missing, []string{"Fees Version"}) {
			t.Errorf("Missing = %v, want [Fees Version]", res.Missing)
		}
	})

	t.Run("only Chart Version => nothing eligible", func(t *testing.T) {
		p := writeValues(t, "fees:\n  image:\n    tag: \"1.0.0\"\n")
		res, err := ExtractAppVersionsFromValues(p, []string{"Chart Version"})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(res.Found) != 0 || len(res.Missing) != 0 {
			t.Errorf("expected empty result, got Found=%v Missing=%v", res.Found, res.Missing)
		}
	})
}

func TestGetImageTag(t *testing.T) {
	values := map[string]interface{}{
		"fees": map[string]interface{}{
			"image": map[string]interface{}{"tag": "3.3.0"},
		},
		"image": map[string]interface{}{"tag": "root-1.0.0"},
	}
	if got := GetImageTag(values, "fees"); got != "3.3.0" {
		t.Errorf("fees tag = %q, want 3.3.0", got)
	}
	// Unknown component falls back to root image.tag.
	if got := GetImageTag(values, "ui"); got != "root-1.0.0" {
		t.Errorf("ui tag = %q, want root fallback root-1.0.0", got)
	}
	// No component and no root image => "".
	if got := GetImageTag(map[string]interface{}{"x": 1}, "y"); got != "" {
		t.Errorf("expected empty, got %q", got)
	}
}

func TestExtractAppVersions_DeterministicMissingOrder(t *testing.T) {
	// Missing preserves header input order (stable diagnostics).
	p := writeValues(t, "only:\n  image:\n    tag: \"1\"\n")
	res, _ := ExtractAppVersionsFromValues(p, []string{"B Version", "A Version", "C Version"})
	got := append([]string{}, res.Missing...)
	want := []string{"B Version", "A Version", "C Version"}
	if !reflect.DeepEqual(got, want) {
		// guard against accidental sort
		sort.Strings(want)
		if reflect.DeepEqual(got, want) {
			t.Errorf("Missing was sorted; expected input order, got %v", res.Missing)
		} else {
			t.Errorf("Missing = %v, want input order", res.Missing)
		}
	}
}
