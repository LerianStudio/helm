package main

import (
	"strings"
	"testing"
)

func lns(s string) []string  { return strings.Split(s, "\n") }
func str(ls []string) string { return strings.Join(ls, "\n") }

func TestReplaceCompatBlock(t *testing.T) {
	t.Run("replaces only between markers, prose untouched", func(t *testing.T) {
		doc := lns(`### Midaz Helm Chart

Intro prose that must survive.

<!-- BEGIN COMPAT:midaz-helm -->
OLD CONTENT
<!-- END COMPAT:midaz-helm -->

-----------------

### Next Chart`)
		body := []string{"| Version | Support |", "| :---: | :---: |", "| `8.6.0` | 🟢 |"}
		out, found, err := replaceCompatBlock(doc, "midaz-helm", body)
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if !found {
			t.Fatal("expected found=true")
		}
		s := str(out)
		if !strings.Contains(s, "Intro prose that must survive.") {
			t.Error("prose above block was lost")
		}
		if !strings.Contains(s, "-----------------") {
			t.Error("separator below block was lost")
		}
		if !strings.Contains(s, "### Next Chart") {
			t.Error("next section header was lost")
		}
		if strings.Contains(s, "OLD CONTENT") {
			t.Error("old content not replaced")
		}
		if !strings.Contains(s, "8.6.0") {
			t.Error("new body not inserted")
		}
		// Markers themselves must be preserved exactly once each.
		if strings.Count(s, "<!-- BEGIN COMPAT:midaz-helm -->") != 1 ||
			strings.Count(s, "<!-- END COMPAT:midaz-helm -->") != 1 {
			t.Errorf("markers duplicated/lost:\n%s", s)
		}
	})

	t.Run("idempotent: applying twice yields identical output", func(t *testing.T) {
		doc := lns(`<!-- BEGIN COMPAT:x -->
whatever
<!-- END COMPAT:x -->`)
		body := []string{"NEW"}
		once, _, _ := replaceCompatBlock(doc, "x", body)
		twice, _, _ := replaceCompatBlock(once, "x", body)
		if str(once) != str(twice) {
			t.Fatalf("not idempotent:\n--once--\n%s\n--twice--\n%s", str(once), str(twice))
		}
	})

	t.Run("markers absent => found=false, doc unchanged", func(t *testing.T) {
		doc := lns("### Some Chart\n\nno markers here")
		out, found, err := replaceCompatBlock(doc, "some-chart", []string{"BODY"})
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if found {
			t.Fatal("expected found=false")
		}
		if str(out) != str(doc) {
			t.Fatal("doc changed despite absent markers")
		}
	})

	t.Run("only END marker => error (malformed)", func(t *testing.T) {
		doc := lns("<!-- END COMPAT:x -->")
		_, _, err := replaceCompatBlock(doc, "x", []string{"B"})
		if err == nil {
			t.Fatal("expected error for END-without-BEGIN")
		}
	})

	t.Run("duplicate BEGIN markers => error (malformed)", func(t *testing.T) {
		doc := lns("<!-- BEGIN COMPAT:x -->\nA\n<!-- END COMPAT:x -->\n<!-- BEGIN COMPAT:x -->\nB\n<!-- END COMPAT:x -->")
		_, _, err := replaceCompatBlock(doc, "x", []string{"NEW"})
		if err == nil {
			t.Fatal("expected error for duplicate COMPAT markers")
		}
		if !strings.Contains(err.Error(), "duplicate") {
			t.Errorf("error should mention 'duplicate', got: %v", err)
		}
	})

	t.Run("duplicate END markers => error (malformed)", func(t *testing.T) {
		doc := lns("<!-- BEGIN COMPAT:x -->\nA\n<!-- END COMPAT:x -->\n<!-- END COMPAT:x -->")
		_, _, err := replaceCompatBlock(doc, "x", []string{"NEW"})
		if err == nil {
			t.Fatal("expected error for duplicate END markers")
		}
	})

	t.Run("exactly one pair => ok", func(t *testing.T) {
		doc := lns("<!-- BEGIN COMPAT:x -->\nOLD\n<!-- END COMPAT:x -->")
		_, found, err := replaceCompatBlock(doc, "x", []string{"NEW"})
		if err != nil || !found {
			t.Fatalf("single pair should be ok, got found=%v err=%v", found, err)
		}
	})
}

func TestAppLabelsFromHeader(t *testing.T) {
	tests := []struct {
		name   string
		header string
		want   []string
	}{
		{
			name:   "original mapping table (no generated columns)",
			header: "| Chart Version | Fees Version | UI Version |",
			want:   []string{"Fees", "UI"},
		},
		{
			name:   "generated header with Released+Support cuts before them",
			header: "| Chart Version | Fees Version | UI Version | Released | Support | Requires midaz-helm |",
			want:   []string{"Fees", "UI"},
		},
		{
			name:   "LEGACY generated header with Requer cuts before it (migration)",
			header: "| Chart Version | Fees Version | UI Version | Released | Support | Requer midaz-helm |",
			want:   []string{"Fees", "UI"},
		},
		{
			name:   "malformed legacy header without Released/Support still ignores Requer",
			header: "| Chart Version | Fees Version | Requer midaz-helm |",
			want:   []string{"Fees"},
		},
		{
			name:   "malformed header without Released/Support still ignores Requires",
			header: "| Chart Version | Fees Version | Requires midaz-helm |",
			want:   []string{"Fees"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := appLabelsFromHeader(tt.header)
			if strings.Join(got, "|") != strings.Join(tt.want, "|") {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
