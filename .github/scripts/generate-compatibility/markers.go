package main

import (
	"fmt"
	"strings"
)

// beginMarker / endMarker build the HTML-comment sentinels for a chart's block.
// Only content strictly between them is ever rewritten (terraform-docs pattern),
// which keeps hand-written prose and irregular separators intact.
func beginMarker(chart string) string { return "<!-- BEGIN COMPAT:" + chart + " -->" }
func endMarker(chart string) string   { return "<!-- END COMPAT:" + chart + " -->" }

// replaceCompatBlock replaces the lines between the BEGIN/END markers for the
// given chart with blockBody, preserving everything outside the markers exactly.
// Returns found=false (and the document unchanged) when the BEGIN marker is
// absent, so the caller can decide to create a section instead. Returns an error
// for a malformed document (END without BEGIN, or BEGIN without END).
func replaceCompatBlock(lines []string, chart string, blockBody []string) ([]string, bool, error) {
	begin, end := beginMarker(chart), endMarker(chart)

	beginIdx, endIdx := -1, -1
	beginCount, endCount := 0, 0
	for i, line := range lines {
		switch strings.TrimSpace(line) {
		case begin:
			beginIdx = i
			beginCount++
		case end:
			endIdx = i
			endCount++
		}
	}

	if beginIdx == -1 && endIdx == -1 {
		return lines, false, nil
	}
	// Duplicate markers leave an orphan block on rewrite (last-wins overwrites),
	// silently corrupting the section. Require exactly one pair; anything else is
	// malformed and must be surfaced as an error, not papered over.
	if beginCount > 1 || endCount > 1 {
		return nil, false, fmt.Errorf("duplicate COMPAT markers for %q (begin=%d end=%d)", chart, beginCount, endCount)
	}
	if beginIdx == -1 || endIdx == -1 || endIdx < beginIdx {
		return nil, false, fmt.Errorf("malformed COMPAT markers for %q (begin=%d end=%d)", chart, beginIdx, endIdx)
	}

	out := make([]string, 0, len(lines)-(endIdx-beginIdx)+len(blockBody)+2)
	out = append(out, lines[:beginIdx+1]...) // keep everything up to & including BEGIN
	out = append(out, blockBody...)          // fresh body
	out = append(out, lines[endIdx:]...)     // END marker onward, unchanged
	return out, true, nil
}

// sectionHeaderIndex returns the line index of the "### <Name>" header for a
// chart, or -1 if the chart has no section (e.g. br-spi — ADR-5). It reuses the
// exact name-normalization contract of tableutil.ParseTableForChart so section
// matching stays consistent with the sibling README tooling: strip -helm,
// hyphens -> spaces, lowercase.
func sectionHeaderIndex(lines []string, chart string) int {
	normalized := strings.ToLower(strings.TrimSuffix(chart, "-helm"))
	normalized = strings.ReplaceAll(normalized, "-", " ")

	for i, line := range lines {
		lower := strings.ToLower(line)
		if strings.HasPrefix(lower, "### ") && strings.Contains(lower, normalized) {
			return i
		}
	}
	return -1
}

// appLabelsFor extracts ALL app-version column labels used in a chart's section
// mapping table, i.e. every "<X>" of a header "| Chart Version | <X> Version |
// [<Y> Version...] | ... |" (e.g. ["Tracer"] or ["Fees", "UI"]). Preserving
// every column means the enriched COMPAT block never drops an existing app
// column (multi-app charts like plugin-fees).
//
// It scans only within the chart's section (its "### " header to the next
// "### "/"---" boundary). Crucially it reads the FIRST "| Chart Version |"
// header it finds — which, after the first run, is the header INSIDE the COMPAT
// block (the original table was replaced in place). To stay idempotent it stops
// collecting labels at the generated "Support" column (and never treats
// "Support"/"Requer ..." as app columns), so run 1 (original table) and run 2+
// (generated block) yield the identical label set. Returns the fallback
// (title-cased chart name) when no mapping header exists.
func appLabelsFor(lines []string, chart string) []string {
	fallback := []string{sectionTitle(chart)}

	start := sectionHeaderIndex(lines, chart)
	if start == -1 {
		return fallback
	}
	for i := start + 1; i < len(lines); i++ {
		trimmed := strings.TrimSpace(lines[i])
		// Stop at the next section boundary.
		if strings.HasPrefix(trimmed, "### ") || strings.HasPrefix(trimmed, "---") {
			break
		}
		// Match a header row of the form "| Chart Version | <X> Version | ... |".
		if strings.HasPrefix(trimmed, "| Chart Version |") {
			if labels := appLabelsFromHeader(trimmed); len(labels) > 0 {
				return labels
			}
		}
	}
	return fallback
}

// appLabelsFromHeader pulls the app-version labels out of a "| Chart Version |
// ... |" header row. It reads every column after "Chart Version" and stops at
// the first generated column ("Released" or "Support", whichever comes first),
// so a previously generated block header (which appends Released, Support and
// optional "Requer <target>" columns) yields exactly the same labels as the
// original mapping table — the key to idempotency.
func appLabelsFromHeader(headerRow string) []string {
	cells := splitTableCells(headerRow)
	var labels []string
	for _, cell := range cells[1:] { // skip "Chart Version"
		cell = strings.TrimSpace(cell)
		if cell == "" {
			continue
		}
		if cell == releasedHeader || cell == "Support" || strings.HasPrefix(cell, requiresHeaderPrefix+" ") {
			break // generated columns are not app labels
		}
		// Prefer the "<X> Version" convention; keep verbatim otherwise so we
		// never silently drop a column we don't recognize.
		if label := strings.TrimSpace(strings.TrimSuffix(cell, " Version")); label != "" && label != cell {
			labels = append(labels, label)
		} else {
			labels = append(labels, cell)
		}
	}
	return labels
}

// mappingTableRange locates the existing app-mapping markdown table inside a
// chart's section and returns [tableStart, tableEnd) line indices (tableEnd is
// exclusive), or (-1,-1) when the section or table is absent. The table is the
// run of lines starting at the "| Chart Version |" header and continuing while
// lines are table rows ("| ... |") — i.e. header + alignment separator + data
// rows. Scanning is confined to the chart's section (its "### " header to the
// next "### "/"---" boundary) so we never touch another chart's table. This is
// the in-place replacement target: the enriched COMPAT block takes the table's
// place, leaving the "#### Application Version Mapping" heading, prose, links and
// trailing "-----------------" separator untouched.
func mappingTableRange(lines []string, chart string) (int, int) {
	start := sectionHeaderIndex(lines, chart)
	if start == -1 {
		return -1, -1
	}
	for i := start + 1; i < len(lines); i++ {
		trimmed := strings.TrimSpace(lines[i])
		if strings.HasPrefix(trimmed, "### ") || strings.HasPrefix(trimmed, "---") {
			return -1, -1 // left the section without finding a table
		}
		if strings.HasPrefix(trimmed, "| Chart Version |") {
			tableStart := i
			end := i + 1
			for end < len(lines) {
				t := strings.TrimSpace(lines[end])
				if strings.HasPrefix(t, "|") && strings.Count(t, "|") > 1 {
					end++
					continue
				}
				break
			}
			return tableStart, end
		}
	}
	return -1, -1
}

// splitTableCells splits a markdown table row "| a | b | c |" into ["a","b","c"].
func splitTableCells(row string) []string {
	trimmed := strings.Trim(strings.TrimSpace(row), "|")
	parts := strings.Split(trimmed, "|")
	cells := make([]string, 0, len(parts))
	for _, p := range parts {
		cells = append(cells, strings.TrimSpace(p))
	}
	return cells
}

// sectionTitle renders the human title used when a chart has no README section
// (ADR-5): strip -helm, hyphens -> spaces, Title Case. e.g. "br-spi-helm" ->
// "Br Spi". Mirrors the tableutil normalization, then title-cases for display.
func sectionTitle(chart string) string {
	base := strings.TrimSuffix(chart, "-helm")
	words := strings.Split(strings.ReplaceAll(base, "-", " "), " ")
	for i, w := range words {
		if w == "" {
			continue
		}
		words[i] = strings.ToUpper(w[:1]) + w[1:]
	}
	return strings.Join(words, " ")
}

// ensureCompatBlock guarantees the chart's COMPAT block reflects blockBody,
// choosing one of four paths (all idempotent):
//  1. markers already present -> replace their contents (replaceCompatBlock);
//  2. an app-mapping table exists in the section -> replace THAT table in place
//     with markers+body, so the "#### Application Version Mapping" heading, prose
//     and trailing separator stay put and no duplicate table is created;
//  3. section header present but no table -> inject markers+body just after the
//     "### ..." header (rare: a section that never had a mapping table);
//  4. no section (ADR-5) -> append a minimal section (title + block) at the end.
func ensureCompatBlock(lines []string, chart string, blockBody []string) ([]string, error) {
	// Path 1: markers exist -> replace their contents.
	replaced, found, err := replaceCompatBlock(lines, chart, blockBody)
	if err != nil {
		return nil, err
	}
	if found {
		return replaced, nil
	}

	block := wrapBlock(chart, blockBody)

	// Path 2: an existing app-mapping table -> replace it in place. This is the
	// common first-run path and the fix for the duplicate-table bug: the markers
	// wrap the location the original table occupied.
	if ts, te := mappingTableRange(lines, chart); ts != -1 {
		out := make([]string, 0, len(lines)-(te-ts)+len(block))
		out = append(out, lines[:ts]...) // up to (not including) the old table
		out = append(out, block...)      // markers + enriched table
		out = append(out, lines[te:]...) // everything after the old table
		return out, nil
	}

	// Path 3: section exists but has no mapping table -> inject after the header.
	if idx := sectionHeaderIndex(lines, chart); idx != -1 {
		out := make([]string, 0, len(lines)+len(block)+1)
		out = append(out, lines[:idx+1]...) // through the "### ..." header
		out = append(out, "")               // blank line after header
		out = append(out, block...)
		out = append(out, lines[idx+1:]...)
		return out, nil
	}

	// Path 4: no section -> minimal section at end (ADR-5).
	out := make([]string, 0, len(lines)+len(block)+3)
	out = append(out, lines...)
	out = append(out, "", "### "+sectionTitle(chart), "")
	out = append(out, block...)
	return out, nil
}

// wrapBlock frames blockBody with the BEGIN/END markers for a chart.
func wrapBlock(chart string, blockBody []string) []string {
	out := make([]string, 0, len(blockBody)+2)
	out = append(out, beginMarker(chart))
	out = append(out, blockBody...)
	out = append(out, endMarker(chart))
	return out
}
