package main

import (
	"strings"
	"testing"
)

func TestSectionHeaderIndex(t *testing.T) {
	doc := strings.Split(`# Charts

### Midaz Helm Chart

prose

### Plugin Fees Helm Chart

prose

### Matcher

prose`, "\n")

	tests := []struct {
		chart string
		want  int // line index of the "### ..." header, -1 if absent
	}{
		{"midaz-helm", 2},
		{"plugin-fees-helm", 6},
		{"matcher-helm", 10}, // normalizes to "matcher", matches "### Matcher"
		{"br-spi-helm", -1},  // no section (ADR-5)
	}
	for _, tt := range tests {
		t.Run(tt.chart, func(t *testing.T) {
			got := sectionHeaderIndex(doc, tt.chart)
			if got != tt.want {
				t.Errorf("chart %q: got index %d, want %d", tt.chart, got, tt.want)
			}
		})
	}
}
