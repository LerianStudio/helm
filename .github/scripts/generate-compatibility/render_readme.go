package main

import (
	"fmt"
	"sort"
	"strings"
)

// supportLabel maps a supported cycle's position (0=N, 1=N-1, ...) to its rich
// Support-column cell: badge + tier label + N-offset (data-model §1). The tier
// is presentation only — it is derived here from position, never persisted in
// the JSON. Positions >=4 are never supported (they collapse into the EOL row).
var supportLabel = []string{
	"🟢 Full (N)",
	"🔵 Security (N-1)",
	"🟡 Extended (N-2)",
	"🟠 Extended (N-3)",
}

// eolSupportLabel is the single summary cell for all end-of-life cycles.
const eolSupportLabel = "🔴 EOL"

// requiresHeaderPrefix labels the optional cross-compat column. English, to
// match the other generated headers (Chart Version, Released, Support).
const requiresHeaderPrefix = "Requires"

// legacyRequiresHeaderPrefix is the pre-i18n-fix Portuguese label. Kept only as
// a sentinel so appLabelsFromHeader ignores a legacy generated header during the
// in-place migration to "Requires".
const legacyRequiresHeaderPrefix = "Requer"

// cellUnknown is the placeholder ("—") used wherever we do not have a confident
// value: historical/EOL app versions, historical/EOL requires cells, and extra
// app columns even on the N row (we only know one app version — the Chart.yaml
// appVersion — so extra columns are never invented).
const cellUnknown = "—"

// renderCompatTable produces the enriched "Application Version Mapping" table
// for one product, wrapped later in COMPAT markers. It reuses ALL app-version
// column labels already present in the chart's README section (e.g. ["Tracer"]
// or ["Fees", "UI"]) so the enriched table never drops an existing column:
//
//	| Chart Version | <App1> Version | [<AppN> Version...] | Support | [Requires <target>...] |
//
// Rows are one per cycle (ordered descending, index 0 = N), Support driven by
// position (Full/Security/Extended), and a single collapsed EOL row that
// references only the ceiling of the dead range as "≤ <highest EOL latest>".
//
// Value policy (no invention):
//   - Only the N row carries real app versions. Each app column is filled from
//     appVersions[label] (resolved from values.yaml {component}.image.tag by the
//     shared tableutil extractor); a column with no resolved tag stays "—".
//   - Historical/EOL app versions are "—".
//   - The Requires column carries the declared range only on the N row; N-1..N-3
//     and EOL are "—" (in v1 the dev declares requires for the current version
//     only; history is filled by E2E in v2).
//
// appVersions maps app LABEL (e.g. "Fees") to its resolved current tag.
func renderCompatTable(p Product, appLabels []string, appVersions map[string]string) []string {
	if len(appLabels) == 0 {
		// Defensive: always render at least one app-version column.
		appLabels = []string{sectionTitle("")}
	}

	// Split supported vs EOL, preserving descending order.
	var supported, eol []Cycle
	for _, c := range p.Cycles {
		if c.Supported {
			supported = append(supported, c)
		} else {
			eol = append(eol, c)
		}
	}

	// Distinct requires targets across supported cycles (sorted for determinism).
	requireTargets := map[string]bool{}
	for _, c := range supported {
		for target := range c.Requires {
			requireTargets[target] = true
		}
	}
	var targets []string
	for target := range requireTargets {
		targets = append(targets, target)
	}
	sort.Strings(targets)

	// Header: Chart Version | <App> Version... | Released | Support | [Requires <target>...]
	headers := []string{"Chart Version"}
	for _, lbl := range appLabels {
		headers = append(headers, lbl+" Version")
	}
	headers = append(headers, releasedHeader, "Support")
	for _, tgt := range targets {
		headers = append(headers, fmt.Sprintf("%s %s", requiresHeaderPrefix, tgt))
	}

	lines := []string{tableRow(headers), separator(len(headers))}

	// appCells builds the app-version cells for a row. Only the N row carries
	// real values, one per app column resolved from values.yaml; a column with
	// no resolved tag (and every historical/EOL cell) stays "—".
	appCells := func(isN bool) []string {
		cells := make([]string, len(appLabels))
		for i, lbl := range appLabels {
			cells[i] = cellUnknown
			if isN {
				if tag, ok := appVersions[lbl]; ok && tag != "" {
					cells[i] = tag
				}
			}
		}
		return cells
	}

	// requiresCells builds the Requires cells for a row. Only the N row carries the
	// declared range; N-1..N-3 (and EOL) are "—".
	requiresCells := func(c *Cycle) []string {
		cells := make([]string, len(targets))
		for i, tgt := range targets {
			if c != nil {
				if rng, ok := c.Requires[tgt]; ok && rng != "" {
					cells[i] = rng
					continue
				}
			}
			cells[i] = cellUnknown
		}
		return cells
	}

	// Supported rows.
	for i := range supported {
		c := supported[i]
		label := eolSupportLabel
		if i < len(supportLabel) {
			label = supportLabel[i]
		}
		isN := i == 0

		row := []string{"`" + c.Latest + "`"}
		row = append(row, appCells(isN)...)
		row = append(row, releasedCell(c.Released), label)
		if isN {
			row = append(row, requiresCells(&c)...)
		} else {
			row = append(row, requiresCells(nil)...)
		}
		lines = append(lines, tableRow(row))
	}

	// Single collapsed EOL summary line: reference only the ceiling of the dead
	// range ("≤ <highest EOL latest>"), never the full cycle list. eol[0] is the
	// highest EOL cycle because cycles arrive ordered descending.
	if len(eol) > 0 {
		row := []string{"`≤ " + eol[0].Latest + "`"}
		row = append(row, appCells(false)...)
		// Released is "—" for the EOL row: it aggregates multiple versions.
		row = append(row, cellUnknown, eolSupportLabel)
		row = append(row, requiresCells(nil)...)
		lines = append(lines, tableRow(row))
	}

	return lines
}

// releasedHeader is the column title for the release date (before Support).
const releasedHeader = "Released"

// releasedCell renders a cycle's release-date cell: the ISO date, or "—" when
// unknown (e.g. a just-created N with no published tag yet).
func releasedCell(date string) string {
	if date == "" {
		return cellUnknown
	}
	return date
}

func tableRow(cells []string) string {
	return "| " + strings.Join(cells, " | ") + " |"
}

func separator(n int) string {
	seps := make([]string, n)
	for i := range seps {
		seps[i] = ":---:"
	}
	return "| " + strings.Join(seps, " | ") + " |"
}
