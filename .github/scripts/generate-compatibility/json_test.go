package main

import (
	"strings"
	"testing"
)

func TestRenderJSON_DeterministicAndSchemaV1(t *testing.T) {
	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "test",
		Products: map[string]Product{
			"plugin-fees-helm": {Dir: "plugin-fees", Current: "7.2.0"},
			"midaz-helm":       {Dir: "midaz", Current: "8.6.0"},
		},
	}

	out1, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON: %v", err)
	}
	out2, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON (2nd): %v", err)
	}
	if string(out1) != string(out2) {
		t.Fatal("renderJSON not deterministic across runs")
	}

	s := string(out1)
	if !strings.Contains(s, `"schemaVersion": 1`) {
		t.Errorf("missing schemaVersion:1\n%s", s)
	}
	// Products must be emitted in sorted key order: midaz-helm before plugin-fees-helm.
	iMidaz := strings.Index(s, "midaz-helm")
	iFees := strings.Index(s, "plugin-fees-helm")
	if iMidaz == -1 || iFees == -1 || iMidaz > iFees {
		t.Errorf("products not in sorted order\n%s", s)
	}
	if !strings.HasSuffix(s, "\n") {
		t.Error("output must end with a trailing newline")
	}
}

func TestRenderJSON_NoTierField(t *testing.T) {
	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "test",
		Products: map[string]Product{
			"midaz-helm": {
				Dir:     "midaz",
				Current: "8.6.0",
				Cycles: []Cycle{
					{Cycle: "8.6", Latest: "8.6.0", Supported: true},
					{Cycle: "8.2", Latest: "8.2.0", Supported: false},
				},
			},
		},
	}
	out, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON: %v", err)
	}
	s := string(out)
	if strings.Contains(s, `"tier"`) {
		t.Fatalf("JSON must NOT contain a tier field (presentation-only)\n%s", s)
	}
	for _, must := range []string{`"cycle": "8.6"`, `"latest": "8.6.0"`, `"supported": true`, `"supported": false`} {
		if !strings.Contains(s, must) {
			t.Errorf("missing %q\n%s", must, s)
		}
	}
}

func TestRenderJSON_OmitsEmptyRequiresTestedWith(t *testing.T) {
	doc := CompatDoc{
		SchemaVersion: 1,
		Products: map[string]Product{
			"matcher-helm": {Dir: "matcher", Current: "3.0.0", Cycles: []Cycle{{Cycle: "3.0", Latest: "3.0.0", Supported: true}}},
		},
	}
	out, err := renderJSON(doc)
	if err != nil {
		t.Fatalf("renderJSON: %v", err)
	}
	s := string(out)
	if strings.Contains(s, `"requires"`) || strings.Contains(s, `"testedWith"`) {
		t.Fatalf("empty maps must be omitted (omitempty)\n%s", s)
	}
}
