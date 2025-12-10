package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

func main() {
	chart := flag.String("chart", "", "Chart name (e.g., test-app)")
	component := flag.String("component", "", "Component that was updated (e.g., backend, frontend)")
	version := flag.String("version", "", "New version of the component")
	appVersion := flag.String("app-version", "", "Current appVersion (ignored - Chart Version managed by semantic-release)")
	flag.Parse()

	_ = appVersion // Unused, kept for backward compatibility

	if *chart == "" || *component == "" || *version == "" {
		fmt.Println("ERROR: --chart, --component, and --version are required")
		flag.Usage()
		os.Exit(1)
	}

	content, err := os.ReadFile("README.md")
	if err != nil {
		fmt.Printf("ERROR: Could not read README.md: %v\n", err)
		os.Exit(1)
	}

	lines := strings.Split(string(content), "\n")

	tableStart, tableEnd, headers, rows := parseTable(lines)
	if tableStart == -1 {
		fmt.Println("ERROR: Could not find version matrix table in README.md")
		os.Exit(1)
	}

	fmt.Printf("Found table at lines %d-%d\n", tableStart, tableEnd)
	fmt.Printf("Headers: %v\n", headers)

	updatedRows := updateMatrix(headers, rows, *component, *version)

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
	fmt.Printf("  Component: %s\n", *component)
	fmt.Printf("  Version: %s\n", *version)
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

func updateMatrix(headers []string, rows []map[string]string, component, version string) []map[string]string {
	// Normalize component name to match header format (e.g., "backend" -> "Backend Version")
	componentHeader := strings.Title(component) + " Version"

	// Check if component header exists
	found := false
	for _, h := range headers {
		if h == componentHeader {
			found = true
			break
		}
	}

	if !found {
		fmt.Printf("WARNING: Component header '%s' not found\n", componentHeader)
		fmt.Printf("Available headers: %v\n", headers)
		return rows
	}

	if len(rows) == 0 {
		fmt.Println("WARNING: No rows found in table")
		return rows
	}

	// Update only the first row (most recent)
	rows[0][componentHeader] = version
	fmt.Printf("Updated first row: %s = %s\n", componentHeader, version)

	return rows
}
