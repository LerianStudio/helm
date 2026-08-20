package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// writeTree cria uma árvore charts/<name> temporária e devolve o root.
func writeTree(t *testing.T, chartDirs []string, extraFiles map[string]string) string {
	t.Helper()
	root := t.TempDir()
	// Always create the charts/ root so the "empty charts dir" case exercises an
	// existing-but-empty directory (returns []), not a missing one (returns err,
	// which TestChartDirectories_MissingRoot covers separately).
	if err := os.MkdirAll(filepath.Join(root, "charts"), 0o755); err != nil {
		t.Fatalf("mkdir charts: %v", err)
	}
	for _, d := range chartDirs {
		if err := os.MkdirAll(filepath.Join(root, "charts", d), 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", d, err)
		}
	}
	for rel, content := range extraFiles {
		full := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatalf("mkdir for %s: %v", rel, err)
		}
		if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
			t.Fatalf("write %s: %v", rel, err)
		}
	}
	return root
}

func TestChartDirectories(t *testing.T) {
	tests := []struct {
		name      string
		dirs      []string
		extra     map[string]string
		want      []string
		wantError bool
	}{
		{
			name: "sorted ascending, dirs only",
			dirs: []string{"midaz", "plugin-fees", "br-spi"},
			want: []string{"br-spi", "midaz", "plugin-fees"},
		},
		{
			name:  "ignores loose files in charts/",
			dirs:  []string{"midaz"},
			extra: map[string]string{"charts/README.md": "x"},
			want:  []string{"midaz"},
		},
		{
			name: "empty charts dir returns empty slice",
			dirs: []string{},
			want: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			root := writeTree(t, tt.dirs, tt.extra)
			got, err := chartDirectories(root)
			if (err != nil) != tt.wantError {
				t.Fatalf("err = %v, wantError = %v", err, tt.wantError)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestChartDirectories_MissingRoot(t *testing.T) {
	_, err := chartDirectories(filepath.Join(t.TempDir(), "does-not-exist"))
	if err == nil {
		t.Fatal("expected error for missing charts dir, got nil")
	}
}
