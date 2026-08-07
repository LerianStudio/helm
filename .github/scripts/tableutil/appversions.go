package tableutil

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// versionSuffix is the trailing token in an app-version column header, e.g.
// the " Version" of "Fees Version". "Chart Version" is excluded (it is the
// chart version, not an app image tag).
const versionSuffix = " Version"

// AppVersionResult reports, per app-version column header, the image tag found
// in a chart's values.yaml. Found maps header -> tag (e.g. "Fees Version" ->
// "3.3.0"); Missing lists the headers whose {component}.image.tag could not be
// resolved (the caller decides how to surface that — stdout log or stderr WARN).
//
// This is the shared, logging-neutral core reused by both
// update-chart-version-readme and generate-compatibility so the multi-column
// app-version extraction lives in exactly one place.
type AppVersionResult struct {
	Found   map[string]string
	Missing []string
}

// ExtractAppVersionsFromValues reads valuesPath (a chart's values.yaml) and, for
// each header ending in " Version" (except "Chart Version"), resolves the
// component's image tag via {component}.image.tag (with a root image.tag
// fallback for charts like product-console). The component key is the header
// with " Version" stripped and lower-cased ("Fees Version" -> "fees").
//
// It never prints; on a read/parse failure it returns every eligible header in
// Missing with a non-nil error, so callers can log consistently. Behaviour is
// identical to the original update-chart-version-readme implementation.
func ExtractAppVersionsFromValues(valuesPath string, headers []string) (AppVersionResult, error) {
	res := AppVersionResult{Found: map[string]string{}}

	eligible := func() []string {
		var out []string
		for _, h := range headers {
			if strings.HasSuffix(h, versionSuffix) && h != "Chart Version" {
				out = append(out, h)
			}
		}
		return out
	}

	content, err := os.ReadFile(valuesPath)
	if err != nil {
		res.Missing = eligible()
		return res, fmt.Errorf("read %s: %w", valuesPath, err)
	}

	var values map[string]interface{}
	if err := yaml.Unmarshal(content, &values); err != nil {
		res.Missing = eligible()
		return res, fmt.Errorf("parse %s: %w", valuesPath, err)
	}

	for _, header := range headers {
		if !strings.HasSuffix(header, versionSuffix) || header == "Chart Version" {
			continue
		}
		componentKey := strings.ToLower(strings.TrimSuffix(header, versionSuffix))
		if tag := GetImageTag(values, componentKey); tag != "" {
			res.Found[header] = tag
		} else {
			res.Missing = append(res.Missing, header)
		}
	}

	return res, nil
}

// GetImageTag extracts a component's image tag from a parsed values map, trying
// {component}.image.tag first and falling back to a root-level image.tag (for
// charts such as product-console whose values.yaml has image.tag at the root).
// Returns "" when no tag is found.
func GetImageTag(values map[string]interface{}, component string) string {
	if componentSection, ok := values[component]; ok {
		if componentMap, ok := componentSection.(map[string]interface{}); ok {
			if tag := extractTagFromImageSection(componentMap); tag != "" {
				return tag
			}
		}
	}
	// Fallback: root-level image.tag.
	if tag := extractTagFromImageSection(values); tag != "" {
		return tag
	}
	return ""
}

// extractTagFromImageSection returns the .tag of a map's "image" section,
// coercing non-string scalars (int/float) to their string form. Returns ""
// when the section, the image key, or the tag key is absent.
func extractTagFromImageSection(section map[string]interface{}) string {
	imageSection, ok := section["image"]
	if !ok {
		return ""
	}
	imageMap, ok := imageSection.(map[string]interface{})
	if !ok {
		return ""
	}
	tag, ok := imageMap["tag"]
	if !ok {
		return ""
	}
	switch v := tag.(type) {
	case string:
		return v
	case int, float64:
		return fmt.Sprintf("%v", v)
	default:
		return fmt.Sprintf("%v", v)
	}
}
