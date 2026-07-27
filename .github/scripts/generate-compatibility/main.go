package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

// run parses flags and executes the requested mode, returning the process exit
// code (api-design §II.2): 0 success (incl. WARN), 1 environment/usage error
// (unreadable root), 2 conflicting flags. stdout carries the operation result;
// stderr carries diagnostics.
func run(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("generate-compatibility", flag.ContinueOnError)
	fs.SetOutput(stderr)
	write := fs.Bool("write", false, "Write mode (default when no mode given)")
	check := fs.Bool("check", false, "Check mode: detect drift without writing")
	root := fs.String("root", "../..", "Repository root containing charts/")
	chart := fs.String("chart", "", "Restrict README update to a single chart (JSON always full)")
	output := fs.String("output", "docs/compatibility.json", "JSON destination, relative to --root")
	if err := fs.Parse(args); err != nil {
		fmt.Fprintf(stderr, "ERROR invalid flags: %v\n", err)
		return 2
	}

	// Mode selection + conflict check.
	if *write && *check {
		fmt.Fprintln(stderr, "ERROR --write and --check are mutually exclusive")
		return 2
	}

	// Environment check: root must be a readable directory with charts/.
	if info, err := os.Stat(filepath.Join(*root, "charts")); err != nil || !info.IsDir() {
		fmt.Fprintf(stderr, "ERROR --root %q has no readable charts/ directory\n", *root)
		return 1
	}

	doc, err := buildDoc(*root, gitTagLister{root: *root}, stderr)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR %v\n", err)
		return 1
	}

	if *check {
		return runCheck(*root, *output, doc, stdout, stderr)
	}
	return runWrite(*root, *output, *chart, doc, stdout, stderr)
}

// runWrite writes the JSON and README (chart filter applies to README only; the
// JSON is always regenerated in full for determinism — api-design §II.1).
func runWrite(root, output, chart string, doc CompatDoc, stdout, stderr io.Writer) int {
	data, err := renderJSON(doc)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR marshal compatibility.json: %v\n", err)
		return 1
	}
	if err := os.WriteFile(filepath.Join(root, output), data, 0o644); err != nil {
		fmt.Fprintf(stderr, "ERROR write %s: %v\n", output, err)
		return 1
	}

	readmeDoc := doc
	if chart != "" {
		readmeDoc = filterProduct(doc, chart)
	}
	if err := writeReadme(root, readmeDoc, stderr); err != nil {
		fmt.Fprintf(stderr, "ERROR write README.md: %v\n", err)
		return 1
	}
	fmt.Fprintf(stdout, "wrote %s and README.md (%d products)\n", output, len(doc.Products))
	return 0
}

// filterProduct returns a copy of doc containing only the named product, so a
// --chart run touches just that README block.
func filterProduct(doc CompatDoc, chart string) CompatDoc {
	filtered := CompatDoc{SchemaVersion: doc.SchemaVersion, GeneratedFrom: doc.GeneratedFrom, Products: map[string]Product{}}
	if p, ok := doc.Products[chart]; ok {
		filtered.Products[chart] = p
	}
	return filtered
}

// runCheck compares the expected JSON + README against what is on disk without
// writing. Drift is reported as WARN on stderr but never fails the build in v1
// (ADR-4): exit stays 0. A clean repo prints "ok".
func runCheck(root, output string, doc CompatDoc, stdout, stderr io.Writer) int {
	drift := false

	// JSON drift.
	expectedJSON, err := renderJSON(doc)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR marshal compatibility.json: %v\n", err)
		return 1
	}
	actualJSON, err := os.ReadFile(filepath.Join(root, output))
	if err != nil || string(actualJSON) != string(expectedJSON) {
		fmt.Fprintf(stderr, "WARN %s: compatibility JSON is stale\n", output)
		drift = true
	}

	// README drift: render expected README from the current one and compare.
	readmePath := filepath.Join(root, "README.md")
	current, err := os.ReadFile(readmePath)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR read README.md: %v\n", err)
		return 1
	}
	// Render with a discarded stderr: check only reports drift, not the
	// app-version WARNs (those surface during --write).
	expectedLines, err := renderReadmeLines(root, strings.Split(string(current), "\n"), doc, io.Discard)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR render README: %v\n", err)
		return 1
	}
	if strings.Join(expectedLines, "\n") != string(current) {
		fmt.Fprintln(stderr, "WARN README.md: compatibility block is stale")
		drift = true
	}

	if drift {
		fmt.Fprintln(stdout, "drift detected (non-blocking v1)")
	} else {
		fmt.Fprintln(stdout, "ok")
	}
	return 0
}

// buildDoc reads every chart under <root>/charts and assembles the document,
// emitting WARN/INFO diagnostics to stderr. It never aborts on data problems
// (ADR-4); only environment errors (unreadable charts/ dir) propagate.
func buildDoc(root string, lister tagLister, stderr io.Writer) (CompatDoc, error) {
	dirs, err := chartDirectories(root)
	if err != nil {
		return CompatDoc{}, fmt.Errorf("list charts: %w", err)
	}

	// First pass: read all states so we know the full set of known products
	// before running the V3 existence check.
	states := make([]ChartState, 0, len(dirs))
	knownProducts := map[string]bool{}
	for _, dir := range dirs {
		state, err := readChartState(root, dir)
		var badAnn *badAnnotationError
		switch {
		case errors.As(err, &badAnn):
			fmt.Fprintln(stderr, Warning{SevWarn, badAnn.chart, "V1", err.Error()}.Line())
		case err != nil:
			fmt.Fprintf(stderr, "WARN %s: cannot read Chart.yaml — %v\n", dir, err)
			continue
		}
		if state.Name == "" {
			fmt.Fprintf(stderr, "WARN %s: Chart.yaml has no name; skipping\n", dir)
			continue
		}
		states = append(states, state)
		knownProducts[state.Name] = true
	}

	// Second pass: validate annotations, resolve windows, and build the document.
	doc := CompatDoc{
		SchemaVersion: 1,
		GeneratedFrom: "local",
		Products:      map[string]Product{},
	}
	for _, state := range states {
		emitWarnings(stderr, validateCompat(state.Name, state.ChartType, state.Compat, knownProducts))

		rawTags, err := lister.listTags(state.Dir)
		if err != nil {
			// A tag-listing failure degrades to "no tags" (window = only N),
			// never an abort (ADR-3): N is authoritative.
			fmt.Fprintf(stderr, "WARN %s: cannot list tags — %v\n", state.Dir, err)
			rawTags = nil
		}
		tagVers := parseTags(state.Dir, rawTags)

		// Release dates come from the same tags (creatordate). A failure here is
		// non-fatal: cycles simply carry no Released (ADR-3, additive field).
		tagDates, err := lister.listTagDates(state.Dir)
		if err != nil {
			fmt.Fprintf(stderr, "WARN %s: cannot read tag dates — %v\n", state.Dir, err)
			tagDates = nil
		}
		releaseDates := releaseDatesByVersion(state.Dir, tagDates)

		cycles, ws := resolveWindow(state.Version, tagVers, releaseDates)
		emitWarnings(stderr, tagChart(state.Name, ws))

		// Attach declared requires/testedWith to the N cycle (index 0), the only
		// cycle whose cross-compatibility we know from the current Chart.yaml.
		if len(cycles) > 0 && state.Compat != nil {
			if len(state.Compat.Requires) > 0 {
				cycles[0].Requires = state.Compat.Requires
			}
			if len(state.Compat.TestedWith) > 0 {
				cycles[0].TestedWith = state.Compat.TestedWith
			}
		}

		doc.Products[state.Name] = Product{
			Dir:        state.Dir,
			Current:    state.Version,
			AppVersion: state.AppVersion,
			Cycles:     cycles,
		}
	}

	return doc, nil
}

// tagChart rewrites the Chart field of window warnings (which carry the raw
// version string) to the product name, for a consistent WARN/INFO contract.
func tagChart(name string, ws []Warning) []Warning {
	for i := range ws {
		ws[i].Chart = name
	}
	return ws
}
