package main

import (
	"os/exec"
	"strings"

	"github.com/Masterminds/semver/v3"
)

// tagLister abstracts the git tag lookup so tests can inject fixtures without
// touching a real repo.
type tagLister interface {
	// listTags returns raw tag names matching the <dir>-v* glob for a chart dir.
	listTags(dir string) ([]string, error)
	// listTagDates returns a map of raw tag name -> release date (YYYY-MM-DD)
	// for the <dir>-v* glob. The date is the tag's creatordate:short. Tags with
	// no resolvable date are simply absent from the map.
	listTagDates(dir string) (map[string]string, error)
}

// gitTagLister is the real implementation, backed by `git tag --list`.
// It runs against the working tree at root.
type gitTagLister struct {
	root string
}

func (g gitTagLister) listTags(dir string) ([]string, error) {
	cmd := exec.Command("git", "-C", g.root, "tag", "--list", dir+"-v*")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	tags := make([]string, 0, len(lines))
	for _, l := range lines {
		if s := strings.TrimSpace(l); s != "" {
			tags = append(tags, s)
		}
	}
	return tags, nil
}

// listTagDates runs `git tag -l "<dir>-v*" --format='%(refname:short) %(creatordate:short)'`
// and returns tag name -> ISO date (YYYY-MM-DD). creatordate:short is already
// ISO-formatted. Lines without a date part are skipped.
func (g gitTagLister) listTagDates(dir string) (map[string]string, error) {
	cmd := exec.Command("git", "-C", g.root, "tag", "-l", dir+"-v*",
		"--format=%(refname:short) %(creatordate:short)")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	return parseTagDates(string(out)), nil
}

// parseTagDates turns the "<tag> <YYYY-MM-DD>" lines of `git tag --format` output
// into a tag -> date map. Lines missing the date field are ignored. Kept as a
// pure function so it is unit-testable without a git repo.
func parseTagDates(raw string) map[string]string {
	dates := map[string]string{}
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue // tag present but no date field
		}
		dates[fields[0]] = fields[1]
	}
	return dates
}

// parseTags filters raw tags to those of the form "<dir>-v<semver>", strips the
// "<dir>-v" prefix, and parses each remainder with Masterminds/semver. Tags
// whose remainder is not valid semver are dropped. Pre-releases are KEPT here;
// segregation happens later (segregateStable). Output order mirrors input order.
func parseTags(dir string, rawTags []string) []*semver.Version {
	prefix := dir + "-v"
	out := make([]*semver.Version, 0, len(rawTags))
	for _, tag := range rawTags {
		if !strings.HasPrefix(tag, prefix) {
			continue
		}
		remainder := strings.TrimPrefix(tag, prefix)
		v, err := semver.NewVersion(remainder)
		if err != nil {
			continue
		}
		out = append(out, v)
	}
	return out
}

// releaseDatesByVersion maps a chart's tag dates (keyed by raw tag name) to a
// map keyed by semver .String() of the version, so resolveWindow can look up a
// cycle's release date by its latest version. Tags whose remainder is not valid
// semver are ignored. e.g. {"tracer-v2.1.0": "2026-06-18"} -> {"2.1.0": "2026-06-18"}.
func releaseDatesByVersion(dir string, tagDates map[string]string) map[string]string {
	prefix := dir + "-v"
	out := make(map[string]string, len(tagDates))
	for tag, date := range tagDates {
		if !strings.HasPrefix(tag, prefix) {
			continue
		}
		remainder := strings.TrimPrefix(tag, prefix)
		v, err := semver.NewVersion(remainder)
		if err != nil {
			continue
		}
		out[v.String()] = date
	}
	return out
}
