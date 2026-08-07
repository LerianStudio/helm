package main

import (
	"io"
	"os"
	"path/filepath"
	"testing"
)

// fakeTagLister returns canned tags (and optional dates) per dir.
type fakeTagLister struct {
	tags  map[string][]string
	dates map[string]map[string]string // dir -> (tag -> YYYY-MM-DD)
}

func (f fakeTagLister) listTags(dir string) ([]string, error) {
	return f.tags[dir], nil
}

func (f fakeTagLister) listTagDates(dir string) (map[string]string, error) {
	if f.dates == nil {
		return map[string]string{}, nil
	}
	return f.dates[dir], nil
}

func TestBuildDoc_Golden(t *testing.T) {
	root := t.TempDir()

	// midaz: N=8.6.0, tags cover 8.6..8.2.
	writeChart(t, root, "midaz", `apiVersion: v2
name: midaz-helm
type: application
version: 8.6.0
appVersion: "3.7.8"
`)
	// plugin-fees: N=7.2.0, only its own tag; declares requires+testedWith.
	writeChart(t, root, "plugin-fees", `apiVersion: v2
name: plugin-fees-helm
type: application
version: 7.2.0
appVersion: "3.3.0"
annotations:
  lerian.studio/compatibility: |
    requires:
      midaz-helm: ">=8.4.0 <9.0.0"
    testedWith:
      midaz-helm: "8.6.0"
`)

	lister := fakeTagLister{
		tags: map[string][]string{
			"midaz": {
				"midaz-v8.6.0", "midaz-v8.5.0", "midaz-v8.4.0",
				"midaz-v8.3.0", "midaz-v8.2.0", "midaz-v8.6.0-beta.11",
			},
			"plugin-fees": {"plugin-fees-v7.2.0"},
		},
		dates: map[string]map[string]string{
			"midaz": {
				"midaz-v8.6.0": "2026-06-01", "midaz-v8.5.0": "2026-05-01",
				"midaz-v8.4.0": "2026-04-01", "midaz-v8.3.0": "2026-03-01",
				"midaz-v8.2.0": "2026-02-01",
			},
			"plugin-fees": {"plugin-fees-v7.2.0": "2026-06-15"},
		},
	}

	doc, err := buildDoc(root, lister, io.Discard)
	if err != nil {
		t.Fatalf("buildDoc: %v", err)
	}
	doc.GeneratedFrom = "test" // pin the provenance field for a stable golden

	got, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON: %v", err)
	}

	goldenPath := filepath.Join("testdata", "golden_two_products.json")
	if os.Getenv("UPDATE_GOLDEN") == "1" {
		if err := os.WriteFile(goldenPath, got, 0o644); err != nil {
			t.Fatalf("update golden: %v", err)
		}
	}
	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden (run with UPDATE_GOLDEN=1 first): %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("JSON mismatch.\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}
