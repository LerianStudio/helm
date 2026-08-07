// Command generate-compatibility produces the per-product support-window matrix
// (README blocks + docs/compatibility.json) for the charts in this repo.
//
// It mirrors the sibling tools in .github/scripts (generate-values-schemas,
// update-readme-matrix): invoked with --root ../.., reads the repo state, and
// writes deterministic artifacts. No network access beyond the git tags already
// present in the checkout.
package main

import (
	"os"
	"path/filepath"
	"sort"
)

// chartDirectories returns the names (not full paths) of the immediate
// subdirectories of <root>/charts, sorted ascending. Loose files under charts/
// are ignored. Mirrors validate-helm-charts/main.go:292-307 but returns bare
// names (the caller joins paths), copied here because Go forbids importing one
// package main from another.
func chartDirectories(root string) ([]string, error) {
	chartsRoot := filepath.Join(root, "charts")
	entries, err := os.ReadDir(chartsRoot)
	if err != nil {
		return nil, err
	}

	dirs := []string{}
	for _, entry := range entries {
		if entry.IsDir() {
			dirs = append(dirs, entry.Name())
		}
	}
	sort.Strings(dirs)
	return dirs, nil
}
