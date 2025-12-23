package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/LerianStudio/helm/.github/scripts/tableutil"
	"gopkg.in/yaml.v3"
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

// getChartDirectory derives the chart directory from the chart name
// e.g., "plugin-access-manager-helm" -> "plugin-access-manager"
func getChartDirectory(chartName string) string {
	return strings.TrimSuffix(chartName, "-helm")
}

// extractAppVersionsFromValues reads values.yaml and extracts app versions
// based on the table headers. For each "X Version" header, it looks for
// the corresponding {x}.image.tag path in values.yaml
func extractAppVersionsFromValues(valuesPath string, headers []string) map[string]string {
	versions := make(map[string]string)

	content, err := os.ReadFile(valuesPath)
	if err != nil {
		fmt.Printf("WARNING: Could not read %s: %v\n", valuesPath, err)
		return versions
	}

	// Parse YAML into a generic map
	var values map[string]interface{}
	if err := yaml.Unmarshal(content, &values); err != nil {
		fmt.Printf("WARNING: Could not parse %s: %v\n", valuesPath, err)
		return versions
	}

	// For each header that ends with " Version" (except "Chart Version"),
	// derive the component name and look for {component}.image.tag
	versionSuffix := " Version"
	for _, header := range headers {
		if !strings.HasSuffix(header, versionSuffix) || header == "Chart Version" {
			continue
		}

		// Derive component name: "Auth Version" -> "auth"
		componentName := strings.TrimSuffix(header, versionSuffix)
		componentKey := strings.ToLower(componentName)

		// Look for {component}.image.tag in values.yaml
		tag := getImageTag(values, componentKey)
		if tag != "" {
			versions[header] = tag
			fmt.Printf("Found %s = %s (from %s.image.tag)\n", header, tag, componentKey)
		} else {
			fmt.Printf("WARNING: Could not find %s.image.tag in values.yaml\n", componentKey)
		}
	}

	return versions
}

// getImageTag extracts the image tag from a component's configuration
// Looks for {component}.image.tag in the values map
func getImageTag(values map[string]interface{}, component string) string {
	// Get the component section
	componentSection, ok := values[component]
	if !ok {
		return ""
	}

	componentMap, ok := componentSection.(map[string]interface{})
	if !ok {
		return ""
	}

	// Get the image section
	imageSection, ok := componentMap["image"]
	if !ok {
		return ""
	}

	imageMap, ok := imageSection.(map[string]interface{})
	if !ok {
		return ""
	}

	// Get the tag
	tag, ok := imageMap["tag"]
	if !ok {
		return ""
	}

	// Handle different tag types (string, number, etc.)
	switch v := tag.(type) {
	case string:
		return v
	case int, float64:
		return fmt.Sprintf("%v", v)
	default:
		return fmt.Sprintf("%v", v)
	}
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
