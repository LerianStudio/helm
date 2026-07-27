package main

import (
	"fmt"
	"strings"

	"github.com/Masterminds/semver/v3"
	"gopkg.in/yaml.v3"
)

// compatAnnotationKey is the reverse-DNS annotation carrying compatibility data.
// It follows the precedent of lerian.studio/chart-type
// (validate-helm-charts/main.go:21).
const compatAnnotationKey = "lerian.studio/compatibility"

// chartTypeAnnotationKey is the pre-existing annotation every chart carries.
// It decides whether a missing cross-compatibility declaration is worth an INFO
// reminder: single-service charts are standalone and are NOT expected to declare
// compatibility, so their absence is silent.
const chartTypeAnnotationKey = "lerian.studio/chart-type"

const (
	chartTypeSingleService     = "single-service"
	chartTypeMultiComponent    = "multi-component"
	chartTypeDependencyWrapper = "dependency-wrapper"
)

// CompatAnnotation is the parsed representation of the embedded YAML in the
// lerian.studio/compatibility annotation (data-model §A.1). Both maps are
// optional in v1; a wholly absent annotation is represented by a nil pointer.
type CompatAnnotation struct {
	Requires   map[string]string `yaml:"requires"`
	TestedWith map[string]string `yaml:"testedWith"`
}

// parseCompatAnnotation is the SECOND step of the two-step unmarshal: the caller
// has already pulled the annotation string out of Chart.yaml.annotations; here
// we unmarshal that embedded YAML document. An empty/whitespace-only string
// means "no annotation declared" and returns (nil, nil). Broken YAML returns an
// error so the caller can emit a V1 WARN and continue (never aborts).
func parseCompatAnnotation(raw string) (*CompatAnnotation, error) {
	if strings.TrimSpace(raw) == "" {
		return nil, nil
	}
	var ann CompatAnnotation
	if err := yaml.Unmarshal([]byte(raw), &ann); err != nil {
		return nil, err
	}
	return &ann, nil
}

// validateCompat applies rules V3–V6 (api-design §I.3) without ever failing.
// V1 (valid YAML) and V2 (unknown keys) are handled by parseCompatAnnotation
// and the typed struct respectively. knownProducts is the set of chart names
// present in the repo, used for the V3 existence check.
//
// chartType (lerian.studio/chart-type) gates the V6 reminder for a MISSING
// cross-compatibility declaration:
//   - single-service        → standalone; no reminder (cross-compat N/A).
//   - multi-component /
//     dependency-wrapper     → INFO reminder when nothing is declared.
//   - "" (missing)           → treated as multi-component (conservative) PLUS a
//     WARN that the chart-type annotation is absent.
//
// A DECLARED compatibility is always validated (V3/V4/V5) regardless of type.
func validateCompat(chart, chartType string, ann *CompatAnnotation, knownProducts map[string]bool) []Warning {
	var out []Warning

	if chartType == "" {
		// chart-type should always be present; flag its absence and fall through
		// as if multi-component (the stricter branch that still reminds on V6).
		out = append(out, Warning{SevWarn, chart, "CT", "lerian.studio/chart-type annotation is missing; treating as multi-component"})
		chartType = chartTypeMultiComponent
	}

	if ann == nil || (len(ann.Requires) == 0 && len(ann.TestedWith) == 0) {
		// Nothing declared. Single-service charts are standalone and are not
		// expected to declare cross-compatibility, so stay silent for them.
		if chartType == chartTypeSingleService {
			return out
		}
		// multi-component / dependency-wrapper: soft, non-blocking reminder.
		out = append(out, Warning{
			Severity: SevInfo,
			Chart:    chart,
			Rule:     "V6",
			Detail:   "no compatibility declared (testedWith expected in v1)",
		})
		return out
	}

	// V3 + V4: requires.
	for product, rng := range ann.Requires {
		if !knownProducts[product] {
			out = append(out, Warning{SevWarn, chart, "V3", fmt.Sprintf("requires[%s] — unknown chart", product)})
		}
		if _, err := semver.NewConstraint(rng); err != nil {
			out = append(out, Warning{SevWarn, chart, "V4", fmt.Sprintf("requires[%s] — invalid semver range %q", product, rng)})
		}
	}

	// V3 + V5: testedWith.
	for product, ver := range ann.TestedWith {
		if !knownProducts[product] {
			out = append(out, Warning{SevWarn, chart, "V3", fmt.Sprintf("testedWith[%s] — unknown chart", product)})
		}
		if _, err := semver.NewVersion(ver); err != nil {
			out = append(out, Warning{SevWarn, chart, "V5", fmt.Sprintf("testedWith[%s] — not an exact version %q", product, ver)})
		}
	}

	return out
}
