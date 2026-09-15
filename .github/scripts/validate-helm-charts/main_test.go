package main

import (
	"fmt"
	"strings"
	"testing"
)

// A file:///tmp/lib dependency yields an absolute relPath ("/tmp/lib"). Helm
// resolves it verbatim at render time (outside the repo), so it must be rejected
// before the containment check — which filepath.Join would otherwise let pass by
// folding the leading slash into chartDir.
func TestMaterializeLocalDependencies_RejectsAbsolutePath(t *testing.T) {
	deps := []chartDependency{{Name: "lib", Repository: "file:///tmp/lib"}}
	err := materializeLocalDependencies("/repo", "/repo/charts/x", "/tmp/render", "/tmp/render/x", deps)
	if err == nil {
		t.Fatal("expected error for absolute file:// dependency, got nil")
	}
	if !strings.Contains(err.Error(), "absolute path") {
		t.Fatalf("expected absolute-path error, got: %v", err)
	}
}

// H1 has two halves. The Secret half was already asserted; this is the host
// half: under a collapse release name, an app helper that rebuilds
// "<release>-<subchart>" by hand writes a ConfigMap host that resolves in no
// namespace, and the install still reports success because the workload only
// fails when it first opens the connection.
func TestDanglingCollapseHostMessage(t *testing.T) {
	const rendered = `---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: data
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app
  namespace: app
data:
  MONGO_HOST: "%s"
  MIDAZ_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1"
`
	cases := []struct {
		name, host, chart string
		wantHit           bool
	}{
		{"hand-rolled release prefix", "mongodb-mongodb.data.svc.cluster.local", "some-chart", true},
		{"collapse honored", "mongodb.data.svc.cluster.local", "some-chart", false},
		{"right name, wrong namespace", "mongodb.other.svc.cluster.local", "some-chart", true},
		{"unrelated sibling release", "reporter-manager.reporter.svc.cluster.local", "some-chart", false},
		{"waived chart and key", "mongodb-mongodb.data.svc.cluster.local", "waived-chart", false},
	}
	knownCollapseHostDrift["waived-chart:MONGO_HOST"] = true
	defer delete(knownCollapseHostDrift, "waived-chart:MONGO_HOST")
	for _, c := range cases {
		got := danglingCollapseHostMessage(fmt.Sprintf(rendered, c.host), "mongodb", c.chart)
		if (got != "") != c.wantHit {
			t.Errorf("%s: danglingCollapseHostMessage(%q) = %q, want hit=%v", c.name, c.host, got, c.wantHit)
		}
		if c.wantHit && !strings.Contains(got, "MONGO_HOST") {
			t.Errorf("%s: message must name the ConfigMap key, got %q", c.name, got)
		}
	}
}

func TestWithinDir(t *testing.T) {
	cases := []struct {
		name         string
		base, target string
		want         bool
	}{
		{"base itself", "/repo", "/repo", true},
		{"nested", "/repo", "/repo/charts/lib", true},
		{"parent traversal", "/repo", "/repo/../etc", false},
		{"sibling absolute", "/repo", "/etc", false},
	}
	for _, c := range cases {
		if got := withinDir(c.base, c.target); got != c.want {
			t.Errorf("%s: withinDir(%q,%q)=%v want %v", c.name, c.base, c.target, got, c.want)
		}
	}
}
