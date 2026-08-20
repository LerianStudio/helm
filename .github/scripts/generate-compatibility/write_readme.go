package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/LerianStudio/helm/.github/scripts/tableutil"
)

// sortedProductNames returns the product keys in stable ascending order.
func sortedProductNames(doc CompatDoc) []string {
	names := make([]string, 0, len(doc.Products))
	for name := range doc.Products {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// resolveAppVersions resolves the current (N-row) app version for each app
// column label of a chart, reading charts/<dir>/values.yaml via the shared
// tableutil extractor (the same multi-column {component}.image.tag logic used by
// update-chart-version-readme, with a root image.tag fallback). It returns a
// map keyed by app LABEL (e.g. "Fees" -> "3.3.0") and a WARN per column whose
// tag could not be resolved, mirroring the sister tool's "Could not find" note.
// Only the current version is resolved; historical rows stay "—" (v1 reads the
// current state only — decision, not derived from tags).
func resolveAppVersions(root, dir string, appLabels []string) (map[string]string, []Warning) {
	byLabel := map[string]string{}
	if len(appLabels) == 0 {
		return byLabel, nil
	}

	// tableutil keys on the full "<Label> Version" header; build those headers.
	headers := make([]string, 0, len(appLabels))
	labelOf := map[string]string{} // header -> label
	for _, lbl := range appLabels {
		h := lbl + " Version"
		headers = append(headers, h)
		labelOf[h] = lbl
	}

	valuesPath := filepath.Join(root, "charts", dir, "values.yaml")
	res, err := tableutil.ExtractAppVersionsFromValues(valuesPath, headers)

	var warnings []Warning
	if err != nil {
		warnings = append(warnings, Warning{SevWarn, dir, "APP", fmt.Sprintf("cannot read app versions: %v", err)})
	}
	for header, tag := range res.Found {
		byLabel[labelOf[header]] = tag
	}
	for _, header := range res.Missing {
		lbl := labelOf[header]
		component := strings.ToLower(lbl)
		warnings = append(warnings, Warning{SevWarn, dir, "APP", fmt.Sprintf("could not find %s.image.tag in values.yaml; %q left as —", component, header)})
	}
	return byLabel, warnings
}

// renderReadmeLines applies every product's COMPAT block to the given README
// lines, in sorted product order, returning the resulting lines. It is the
// single source of truth shared by writeReadme (mutates disk) and runCheck
// (compares in memory), so both agree byte-for-byte. WARN/INFO diagnostics
// (e.g. a missing app-version column) go to stderr.
func renderReadmeLines(root string, lines []string, doc CompatDoc, stderr io.Writer) ([]string, error) {
	var err error
	for _, name := range sortedProductNames(doc) {
		p := doc.Products[name]
		// Reuse ALL app labels already present in this chart's README section
		// (e.g. ["Tracer"] or ["Fees", "UI"]) so the enriched table never drops a
		// column. Labels live outside the COMPAT markers, so they survive block
		// replacement and stay stable across runs.
		appLabels := appLabelsFor(lines, name)
		// Resolve the current app version(s) from values.yaml (shared logic).
		appVersions, ws := resolveAppVersions(root, p.Dir, appLabels)
		emitWarnings(stderr, tagChart(name, ws))

		body := renderCompatTable(p, appLabels, appVersions)
		lines, err = ensureCompatBlock(lines, name, body)
		if err != nil {
			return nil, err
		}
	}
	return lines, nil
}

// writeReadme rewrites <root>/README.md so every product's COMPAT block matches
// the document. Only content between (or newly wrapped in) markers changes;
// prose, existing tables and irregular separators are preserved (risk #1
// mitigation). For the pilot the caller passes a doc filtered to a single chart
// (--chart tracer-helm), so only that block is touched.
func writeReadme(root string, doc CompatDoc, stderr io.Writer) error {
	readmePath := filepath.Join(root, "README.md")
	data, err := os.ReadFile(readmePath)
	if err != nil {
		return err
	}
	lines := strings.Split(string(data), "\n")

	lines, err = renderReadmeLines(root, lines, doc, stderr)
	if err != nil {
		return err
	}

	out := strings.Join(lines, "\n")
	return os.WriteFile(readmePath, []byte(out), 0o644)
}
