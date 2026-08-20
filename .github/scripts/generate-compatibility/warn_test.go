package main

import (
	"testing"
)

func rulesOf(ws []Warning) []string {
	out := make([]string, 0, len(ws))
	for _, w := range ws {
		out = append(out, w.Rule)
	}
	return out
}

func containsRule(ws []Warning, rule string) bool {
	for _, r := range rulesOf(ws) {
		if r == rule {
			return true
		}
	}
	return false
}

func TestValidateCompat(t *testing.T) {
	known := map[string]bool{"midaz-helm": true, "plugin-fees-helm": true}

	tests := []struct {
		name      string
		chartType string
		ann       *CompatAnnotation
		wantRules []string // rules that MUST be present
		absent    []string // rules that must NOT be present
	}{
		{
			name:      "single-service without compat => NO warnings (standalone)",
			chartType: chartTypeSingleService,
			ann:       nil,
			absent:    []string{"V3", "V4", "V5", "V6", "CT"},
		},
		{
			name:      "multi-component without compat => V6 INFO reminder",
			chartType: chartTypeMultiComponent,
			ann:       nil,
			wantRules: []string{"V6"},
		},
		{
			name:      "dependency-wrapper without compat => V6 INFO reminder",
			chartType: chartTypeDependencyWrapper,
			ann:       nil,
			wantRules: []string{"V6"},
		},
		{
			name:      "missing chart-type without compat => CT WARN + V6 INFO (conservative)",
			chartType: "",
			ann:       nil,
			wantRules: []string{"CT", "V6"},
		},
		{
			name:      "single-service WITH requires => still validates V3/V4, no V6",
			chartType: chartTypeSingleService,
			ann: &CompatAnnotation{
				Requires: map[string]string{"midaz-ledger": "maior que 8"},
			},
			wantRules: []string{"V3", "V4"},
			absent:    []string{"V6"},
		},
		{
			name:      "valid complete (multi-component) => no warnings",
			chartType: chartTypeMultiComponent,
			ann: &CompatAnnotation{
				Requires:   map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"},
				TestedWith: map[string]string{"midaz-helm": "8.6.0"},
			},
			absent: []string{"V3", "V4", "V5", "V6", "CT"},
		},
		{
			name:      "V3 unknown product in requires",
			chartType: chartTypeMultiComponent,
			ann: &CompatAnnotation{
				Requires: map[string]string{"midaz-ledger": ">=8.0.0"},
			},
			wantRules: []string{"V3"},
		},
		{
			name:      "V4 unparseable range",
			chartType: chartTypeMultiComponent,
			ann: &CompatAnnotation{
				Requires: map[string]string{"midaz-helm": "maior que 8"},
			},
			wantRules: []string{"V4"},
		},
		{
			name:      "V5 testedWith not an exact version",
			chartType: chartTypeMultiComponent,
			ann: &CompatAnnotation{
				TestedWith: map[string]string{"midaz-helm": ">=8.6.0"},
			},
			wantRules: []string{"V5"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := validateCompat("plugin-fees-helm", tt.chartType, tt.ann, known)
			for _, r := range tt.wantRules {
				if !containsRule(got, r) {
					t.Errorf("expected rule %s in %v", r, rulesOf(got))
				}
			}
			for _, r := range tt.absent {
				if containsRule(got, r) {
					t.Errorf("did not expect rule %s in %v", r, rulesOf(got))
				}
			}
		})
	}
}
