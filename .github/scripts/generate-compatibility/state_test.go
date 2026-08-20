package main

import (
	"os"
	"path/filepath"
	"testing"
)

func writeChart(t *testing.T, root, dir, chartYAML string) {
	t.Helper()
	full := filepath.Join(root, "charts", dir)
	if err := os.MkdirAll(full, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(full, "Chart.yaml"), []byte(chartYAML), 0o644); err != nil {
		t.Fatalf("write Chart.yaml: %v", err)
	}
}

func TestReadChartState(t *testing.T) {
	root := t.TempDir()
	writeChart(t, root, "midaz", `apiVersion: v2
name: midaz-helm
type: application
version: 8.6.0
appVersion: "3.7.8"
`)

	got, err := readChartState(root, "midaz")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Name != "midaz-helm" {
		t.Errorf("Name = %q, want midaz-helm", got.Name)
	}
	if got.Dir != "midaz" {
		t.Errorf("Dir = %q, want midaz", got.Dir)
	}
	if got.Version != "8.6.0" {
		t.Errorf("Version = %q, want 8.6.0", got.Version)
	}
	if got.AppVersion != "3.7.8" {
		t.Errorf("AppVersion = %q, want 3.7.8", got.AppVersion)
	}
}

func TestReadChartState_MissingFile(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "charts", "empty"), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	_, err := readChartState(root, "empty")
	if err == nil {
		t.Fatal("expected error for missing Chart.yaml, got nil")
	}
}

func TestReadChartState_ParsesCompatAnnotation(t *testing.T) {
	root := t.TempDir()
	writeChart(t, root, "plugin-fees", `apiVersion: v2
name: plugin-fees-helm
type: application
version: 7.2.0
appVersion: "3.3.0"
annotations:
  lerian.studio/chart-type: multi-component
  lerian.studio/compatibility: |
    requires:
      midaz-helm: ">=8.4.0 <9.0.0"
    testedWith:
      midaz-helm: "8.6.0"
`)

	got, err := readChartState(root, "plugin-fees")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Compat == nil {
		t.Fatal("Compat is nil, want parsed annotation")
	}
	if got.Compat.Requires["midaz-helm"] != ">=8.4.0 <9.0.0" {
		t.Errorf("Requires[midaz-helm] = %q", got.Compat.Requires["midaz-helm"])
	}
	if got.Compat.TestedWith["midaz-helm"] != "8.6.0" {
		t.Errorf("TestedWith[midaz-helm] = %q", got.Compat.TestedWith["midaz-helm"])
	}
}

func TestReadChartState_NoAnnotationIsNilCompat(t *testing.T) {
	root := t.TempDir()
	writeChart(t, root, "matcher", `apiVersion: v2
name: matcher-helm
type: application
version: 3.0.0
`)
	got, err := readChartState(root, "matcher")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Compat != nil {
		t.Errorf("Compat = %+v, want nil", got.Compat)
	}
}
