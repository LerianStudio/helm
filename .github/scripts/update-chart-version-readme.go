package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/LerianStudio/helm/.github/scripts/tableutil"
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
		tableStart, tableEnd, headers, rows = tableutil.ParseTableForChart(lines, *chart)
	} else {
		// Backward compatibility: find first table
		tableStart, tableEnd, headers, rows = tableutil.ParseTable(lines)
	}

	if tableStart == -1 {
		fmt.Println("ERROR: Could not find version matrix table in README.md")
		os.Exit(1)
	}

	fmt.Printf("Found table at lines %d-%d\n", tableStart, tableEnd)

	updatedRows := updateChartVersion(rows, *version)

	newTableLines := tableutil.FormatTable(headers, updatedRows)

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

func updateChartVersion(rows []map[string]string, version string) []map[string]string {
	if len(rows) == 0 {
		fmt.Println("WARNING: No rows found in table")
		return rows
	}

	// Add backticks to match existing format in README
	formattedVersion := "`" + version + "`"
	rows[0]["Chart Version"] = formattedVersion
	fmt.Printf("Updated first row: Chart Version = %s\n", formattedVersion)

	return rows
}
