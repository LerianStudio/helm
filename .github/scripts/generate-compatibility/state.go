package main

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// ChartState is the normalized state read from one chart's Chart.yaml.
// Version is N, the absolute authority for the support window (ADR-3):
// it is NEVER derived from git tags.
type ChartState struct {
	Name       string // published chart name, e.g. "midaz-helm"
	Dir        string // directory under charts/, e.g. "midaz" (tag prefix)
	Version    string // N — from Chart.yaml.version
	AppVersion string // informational (fills the N row's app-version cell)
	ChartType  string // lerian.studio/chart-type: single-service | multi-component | dependency-wrapper
	Compat     *CompatAnnotation
}

// chartYAML is the minimal shape we parse out of Chart.yaml.
// Dependencies are not needed for the pilot; annotations carry compatibility.
type chartYAML struct {
	Name        string            `yaml:"name"`
	Version     string            `yaml:"version"`
	AppVersion  string            `yaml:"appVersion"`
	Annotations map[string]string `yaml:"annotations"`
}

// readChartState reads <root>/charts/<dir>/Chart.yaml and returns its
// normalized state. Returns an error if the file is missing or unparseable.
// A broken compatibility annotation is surfaced as a *badAnnotationError while
// still returning a usable state (name/version), so buildDoc downgrades it to a
// WARN and continues (ADR-4).
func readChartState(root, dir string) (ChartState, error) {
	path := filepath.Join(root, "charts", dir, "Chart.yaml")
	data, err := os.ReadFile(path)
	if err != nil {
		return ChartState{}, err
	}

	var c chartYAML
	if err := yaml.Unmarshal(data, &c); err != nil {
		return ChartState{}, err
	}

	chartType := c.Annotations[chartTypeAnnotationKey]

	compat, err := parseCompatAnnotation(c.Annotations[compatAnnotationKey])
	if err != nil {
		// Broken embedded YAML (V1): surface as a tagged error so buildDoc can
		// emit a WARN and continue. State is still usable (name/version known).
		return ChartState{
			Name:       c.Name,
			Dir:        dir,
			Version:    c.Version,
			AppVersion: c.AppVersion,
			ChartType:  chartType,
		}, &badAnnotationError{chart: c.Name, err: err}
	}

	return ChartState{
		Name:       c.Name,
		Dir:        dir,
		Version:    c.Version,
		AppVersion: c.AppVersion,
		ChartType:  chartType,
		Compat:     compat,
	}, nil
}

// badAnnotationError marks a Chart.yaml whose compatibility annotation is
// unparseable (V1). The chart state is still returned; the caller downgrades
// this to a WARN rather than aborting (ADR-4).
type badAnnotationError struct {
	chart string
	err   error
}

func (e *badAnnotationError) Error() string {
	return fmt.Sprintf("compatibility annotation is invalid YAML: %v", e.err)
}
