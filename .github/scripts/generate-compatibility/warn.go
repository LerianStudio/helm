package main

import (
	"fmt"
	"io"
	"sort"
)

// Severity is the stable, CI-parseable prefix (api-design §II.3).
type Severity string

const (
	SevWarn Severity = "WARN"
	SevInfo Severity = "INFO"
)

// Warning is one diagnostic tied to a chart and a validation rule.
type Warning struct {
	Severity Severity
	Chart    string
	Rule     string // e.g. "V3", "V4", "V6"
	Detail   string
}

// Line renders the stable message contract: "WARN <chart>: <rule> — <detail>".
func (w Warning) Line() string {
	return fmt.Sprintf("%s %s: %s — %s", w.Severity, w.Chart, w.Rule, w.Detail)
}

// emitWarnings writes each warning as one line to stderr, sorted by chart then
// rule for deterministic output. Returns the count of SevWarn (not INFO).
func emitWarnings(stderr io.Writer, ws []Warning) int {
	sorted := make([]Warning, len(ws))
	copy(sorted, ws)
	sort.SliceStable(sorted, func(i, j int) bool {
		if sorted[i].Chart != sorted[j].Chart {
			return sorted[i].Chart < sorted[j].Chart
		}
		return sorted[i].Rule < sorted[j].Rule
	})
	warnCount := 0
	for _, w := range sorted {
		fmt.Fprintln(stderr, w.Line())
		if w.Severity == SevWarn {
			warnCount++
		}
	}
	return warnCount
}
