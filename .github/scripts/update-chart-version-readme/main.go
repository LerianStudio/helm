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

	// Update chart version
	updatedRows := updateChartVersion(rows, *version)

	// Also update app versions from values.yaml (generic approach)
	if *chart != "" {
		chartDir := getChartDirectory(*chart)
		valuesPath := fmt.Sprintf("charts/%s/values.yaml", chartDir)
		appVersions := extractAppVersionsFromValues(valuesPath, headers)
		updatedRows = updateAppVersions(updatedRows, appVersions)
	}

	newTableLines := tableutil.FormatTable(headers, updatedRows)

	var newLines []string
	newLines = append(newLines, lines[:tableStart]...)
	newLines = append(newLines, newTableLines...)
	newLines = append(newLines, lines[tableEnd:]...)

	err = os.WriteFile("README.md", []byte(strings.Join(newLines, "\n")), 0o644)
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

// getChartDirectory derives the chart directory from the chart name
// e.g., "plugin-access-manager-helm" -> "plugin-access-manager"
func getChartDirectory(chartName string) string {
	return strings.TrimSuffix(chartName, "-helm")
}

// extractAppVersionsFromValues reads values.yaml and extracts app versions
// based on the table headers, delegating to the shared tableutil implementation
// (kept as a thin wrapper so this tool preserves its stdout logging contract).
// For each "X Version" header it resolves {x}.image.tag (root image.tag fallback).
func extractAppVersionsFromValues(valuesPath string, headers []string) map[string]string {
	res, err := tableutil.ExtractAppVersionsFromValues(valuesPath, headers)
	if err != nil {
		fmt.Printf("WARNING: %v\n", err)
	}
	for header, tag := range res.Found {
		fmt.Printf("Found %s = %s\n", header, tag)
	}
	for _, header := range res.Missing {
		component := strings.ToLower(strings.TrimSuffix(header, " Version"))
		fmt.Printf("WARNING: Could not find %s.image.tag in values.yaml\n", component)
	}
	return res.Found
}

// updateAppVersions updates the rows with app versions extracted from values.yaml
func updateAppVersions(rows []map[string]string, appVersions map[string]string) []map[string]string {
	if len(rows) == 0 || len(appVersions) == 0 {
		return rows
	}

	for header, version := range appVersions {
		rows[0][header] = version
		fmt.Printf("Updated first row: %s = %s\n", header, version)
	}

	return rows
}
