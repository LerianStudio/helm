package tableutil

import (
	"fmt"
	"strings"
)

// ParseTable finds and parses a markdown table from the given lines.
// Returns tableStart, tableEnd, headers, and rows.
// tableStart is -1 if no table is found.
func ParseTable(lines []string) (int, int, []string, []map[string]string) {
	tableStart := -1
	tableEnd := -1
	var headers []string
	var rows []map[string]string

	for i, line := range lines {
		if strings.Contains(line, "| Chart Version |") {
			tableStart = i
			parts := strings.Split(strings.Trim(line, "|"), "|")
			for _, p := range parts {
				p = strings.TrimSpace(p)
				if p != "" {
					headers = append(headers, p)
				}
			}
			continue
		}

		if tableStart != -1 && tableEnd == -1 {
			trimmed := strings.TrimSpace(line)
			if strings.HasPrefix(trimmed, "| :") {
				continue
			}

			if strings.HasPrefix(trimmed, "|") && strings.Count(trimmed, "|") > 1 {
				parts := strings.Split(strings.Trim(trimmed, "|"), "|")
				var values []string
				for _, p := range parts {
					values = append(values, strings.TrimSpace(p))
				}

				if len(values) >= len(headers) {
					row := make(map[string]string)
					for j, header := range headers {
						if j < len(values) {
							row[header] = values[j]
						} else {
							row[header] = "-"
						}
					}
					rows = append(rows, row)
				}
			} else {
				tableEnd = i
				break
			}
		}
	}

	if tableEnd == -1 && tableStart != -1 {
		tableEnd = len(lines)
	}

	return tableStart, tableEnd, headers, rows
}

// ParseTableForChart finds and parses a markdown table for a specific chart section.
// It normalizes the chart name (removes -helm suffix, converts hyphens to spaces)
// and looks for the corresponding section header.
func ParseTableForChart(lines []string, chartName string) (int, int, []string, []map[string]string) {
	// Normalize chart name: remove -helm suffix and convert to lowercase for matching
	// e.g., "midaz-helm" -> "midaz", "plugin-fees-helm" -> "plugin fees"
	normalizedChart := strings.ToLower(strings.TrimSuffix(chartName, "-helm"))
	normalizedChart = strings.ReplaceAll(normalizedChart, "-", " ")

	// Find the section header for this chart (e.g., "### Midaz Helm Chart" or "### Plugin Fees Helm Chart")
	sectionStart := -1
	for i, line := range lines {
		lowerLine := strings.ToLower(line)
		if strings.HasPrefix(lowerLine, "### ") && strings.Contains(lowerLine, normalizedChart) {
			sectionStart = i
			fmt.Printf("Found section for chart '%s' at line %d: %s\n", chartName, i, line)
			break
		}
	}

	if sectionStart == -1 {
		fmt.Printf("WARNING: Could not find section for chart '%s'\n", chartName)
		return -1, -1, nil, nil
	}

	// Now find the table within this section (before the next section or separator)
	tableStart := -1
	tableEnd := -1
	var headers []string
	var rows []map[string]string

	for i := sectionStart; i < len(lines); i++ {
		line := lines[i]

		// Stop if we hit the next section separator (---)
		if i > sectionStart && strings.HasPrefix(strings.TrimSpace(line), "---") {
			if tableStart != -1 && tableEnd == -1 {
				tableEnd = i
			}
			break
		}

		// Stop if we hit another section header
		if i > sectionStart && strings.HasPrefix(line, "### ") {
			if tableStart != -1 && tableEnd == -1 {
				tableEnd = i
			}
			break
		}

		if strings.Contains(line, "| Chart Version |") {
			tableStart = i
			parts := strings.Split(strings.Trim(line, "|"), "|")
			for _, p := range parts {
				p = strings.TrimSpace(p)
				if p != "" {
					headers = append(headers, p)
				}
			}
			continue
		}

		if tableStart != -1 && tableEnd == -1 {
			trimmed := strings.TrimSpace(line)
			if strings.HasPrefix(trimmed, "| :") {
				continue
			}

			if strings.HasPrefix(trimmed, "|") && strings.Count(trimmed, "|") > 1 {
				parts := strings.Split(strings.Trim(trimmed, "|"), "|")
				var values []string
				for _, p := range parts {
					values = append(values, strings.TrimSpace(p))
				}

				if len(values) >= len(headers) {
					row := make(map[string]string)
					for j, header := range headers {
						if j < len(values) {
							row[header] = values[j]
						} else {
							row[header] = "-"
						}
					}
					rows = append(rows, row)
				}
			} else {
				tableEnd = i
				break
			}
		}
	}

	if tableEnd == -1 && tableStart != -1 {
		tableEnd = len(lines)
	}

	return tableStart, tableEnd, headers, rows
}

// FormatTable formats headers and rows back into markdown table lines.
func FormatTable(headers []string, rows []map[string]string) []string {
	var lines []string

	// Header line
	lines = append(lines, "| "+strings.Join(headers, " | ")+" |")

	// Separator line
	var seps []string
	for range headers {
		seps = append(seps, ":---:")
	}
	lines = append(lines, "| "+strings.Join(seps, " | ")+" |")

	// Data rows
	for _, row := range rows {
		var values []string
		for _, h := range headers {
			if v, ok := row[h]; ok {
				values = append(values, v)
			} else {
				values = append(values, "-")
			}
		}
		lines = append(lines, "| "+strings.Join(values, " | ")+" |")
	}

	return lines
}
