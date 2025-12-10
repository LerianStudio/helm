package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

func main() {
	version := flag.String("version", "", "New chart version from semantic-release")
	chart := flag.String("chart", "", "Chart name to update (e.g., midaz-helm, plugin-fees-helm)")
	flag.Parse()

	if *version == "" {
		fmt.Println("ERROR: --version is required")
		flag.Usage()
		os.Exit(1)
	}

	content, err := os.ReadFile("README.md")
	if err != nil {
		fmt.Printf("ERROR: Could not read README.md: %v\n", err)
		os.Exit(1)
	}

	lines := strings.Split(string(content), "\n")

	var tableStart, tableEnd int
	var headers []string
	var rows []map[string]string

	if *chart != "" {
		// Find the section for this specific chart
		tableStart, tableEnd, headers, rows = parseTableForChart(lines, *chart)
	} else {
		// Backward compatibility: find first table
		tableStart, tableEnd, headers, rows = parseTable(lines)
	}

	if tableStart == -1 {
		fmt.Println("ERROR: Could not find version matrix table in README.md")
		os.Exit(1)
	}

	fmt.Printf("Found table at lines %d-%d\n", tableStart, tableEnd)

	updatedRows := updateChartVersion(rows, *version)

	newTableLines := formatTable(headers, updatedRows)

	var newLines []string
	newLines = append(newLines, lines[:tableStart]...)
	newLines = append(newLines, newTableLines...)
	newLines = append(newLines, lines[tableEnd:]...)

	err = os.WriteFile("README.md", []byte(strings.Join(newLines, "\n")), 0644)
	if err != nil {
		fmt.Printf("ERROR: Could not write README.md: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Successfully updated README.md")
	fmt.Printf("  Chart Version: %s\n", *version)
	if *chart != "" {
		fmt.Printf("  Chart: %s\n", *chart)
	}
}

func parseTableForChart(lines []string, chartName string) (int, int, []string, []map[string]string) {
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

func parseTable(lines []string) (int, int, []string, []map[string]string) {
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

func formatTable(headers []string, rows []map[string]string) []string {
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

func updateChartVersion(rows []map[string]string, version string) []map[string]string {
	if len(rows) == 0 {
		fmt.Println("WARNING: No rows found in table")
		return rows
	}

	rows[0]["Chart Version"] = version
	fmt.Printf("Updated first row: Chart Version = %s\n", version)

	return rows
}
