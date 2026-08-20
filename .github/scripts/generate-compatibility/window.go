package main

import (
	"fmt"

	"github.com/Masterminds/semver/v3"
)

// segregateStable drops every pre-release version (e.g. -beta.N, -HELM-N,
// -rc.N). Per TRD §2, pre-releases never become their own support cycle; they
// are removed before minors are computed. Input order is preserved for the
// survivors.
func segregateStable(vs []*semver.Version) []*semver.Version {
	out := make([]*semver.Version, 0, len(vs))
	for _, v := range vs {
		if v.Prerelease() != "" {
			continue
		}
		out = append(out, v)
	}
	return out
}

// minorKey renders the "MAJOR.MINOR" cycle key for a version.
func minorKey(v *semver.Version) string {
	return fmt.Sprintf("%d.%d", v.Major(), v.Minor())
}

// groupByMinor buckets stable versions by their MAJOR.MINOR cycle, keeping the
// highest patch in each bucket. The result is deterministic regardless of input
// order because the winner is chosen by semver comparison, not by position.
func groupByMinor(vs []*semver.Version) map[string]*semver.Version {
	latest := map[string]*semver.Version{}
	for _, v := range vs {
		key := minorKey(v)
		if cur, ok := latest[key]; !ok || v.GreaterThan(cur) {
			latest[key] = v
		}
	}
	return latest
}

// supportedWindowSize is the number of most-recent minor cycles that are marked
// supported (N..N-3). Cycles below that are supported=false.
const supportedWindowSize = 4

// resolveWindow builds the ordered support-window cycles for one chart.
//
// N = chartVersion (from Chart.yaml) is authoritative: its cycle is always
// present and supported, even when no matching tag exists (ADR-3, NFR-3). Tag
// history supplies N-1..N-3. Cycles strictly above N are discarded (a stray
// higher tag must never exceed the declared current version). The top
// supportedWindowSize distinct minors are supported=true; the rest false.
//
// Degradation (FR-7): 0 tags => only the N cycle (+ an INFO); <4 minors => only
// those that exist.
//
// releaseDates maps a version's semver .String() to its ISO release date
// (YYYY-MM-DD, from the tag). Each cycle's Released is set from the date of its
// latest version; a version with no known date leaves Released empty ("").
func resolveWindow(chartVersion string, tagVersions []*semver.Version, releaseDates map[string]string) ([]Cycle, []Warning) {
	var warnings []Warning

	nVer, err := semver.NewVersion(chartVersion)
	if err != nil {
		// Chart.yaml version is unparseable: emit WARN, produce no cycles.
		warnings = append(warnings, Warning{SevWarn, chartVersion, "N", fmt.Sprintf("Chart.yaml version %q is not valid semver", chartVersion)})
		return nil, warnings
	}
	nKey := minorKey(nVer)

	// Group stable tag versions by minor cycle.
	byMinor := groupByMinor(segregateStable(tagVersions))

	// The N cycle is ALWAYS sourced from Chart.yaml (authority): N wins its own
	// minor slot unconditionally. This is deliberate — if a stray tag with a
	// patch ABOVE N in the same minor exists (e.g. N=8.6.0 with a tag 8.6.1),
	// letting that tag occupy the 8.6 slot would then get it dropped by the
	// "never exceed N" filter below, deleting the N cycle entirely. Overwriting
	// with nVer keeps the N cycle present and correct (latest = the declared N).
	byMinor[nKey] = nVer

	// Collect the "latest" version of each minor, drop any cycle above N, then
	// sort descending by that latest version.
	latests := make([]*semver.Version, 0, len(byMinor))
	for _, v := range byMinor {
		if v.GreaterThan(nVer) {
			continue // never exceed N
		}
		latests = append(latests, v)
	}
	sortSemverDesc(latests)

	cycles := make([]Cycle, 0, len(latests))
	for i, v := range latests {
		cycles = append(cycles, Cycle{
			Cycle:     minorKey(v),
			Latest:    v.String(),
			Released:  releaseDates[v.String()], // "" when the tag date is unknown
			Supported: i < supportedWindowSize,
		})
	}

	// Degraded window: count the cycles that ACTUALLY entered the window besides
	// the always-forced N cycle. This must be measured AFTER the "never exceed N"
	// filter — counting byMinor earlier would miss the case where every stable
	// tag is a cycle above N (all dropped by the filter), leaving only N but a
	// non-zero pre-filter count (same class as bug #8: counting at the wrong
	// moment). When nothing but N survived, the window is degraded → emit INFO.
	nonNCycles := 0
	for _, v := range latests {
		if minorKey(v) != nKey {
			nonNCycles++
		}
	}
	if nonNCycles == 0 {
		if len(tagVersions) == 0 {
			warnings = append(warnings, Warning{SevInfo, chartVersion, "N", "no published tags; window = only N (Chart.yaml)"})
		} else {
			// Tags exist but none produced a usable cycle at or below N (all
			// pre-release, or all above N). More precise than "only pre-release".
			warnings = append(warnings, Warning{SevInfo, chartVersion, "N", "no usable tags below N; window = only N (Chart.yaml)"})
		}
	}

	return cycles, warnings
}

// sortSemverDesc performs a stable descending sort of semver versions in place.
func sortSemverDesc(vs []*semver.Version) {
	for i := 1; i < len(vs); i++ {
		for j := i; j > 0 && vs[j].GreaterThan(vs[j-1]); j-- {
			vs[j], vs[j-1] = vs[j-1], vs[j]
		}
	}
}
