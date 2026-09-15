package main

import (
	"fmt"
	"os/exec"
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

// A chart writes a host into a ConfigMap or straight into a container env, and
// the waived plugin-br-bank-transfer entries do both: templates/configmap.yaml
// and the migration Job in templates/migrations.yaml build the same hand-rolled
// "<release>-postgresql-primary". A scan that read only ConfigMap data would
// report the class closed the moment the ConfigMap half was fixed, while the
// Job still blocked forever on a host that resolves in no namespace.
func TestDanglingCollapseHostMessageReadsContainerEnv(t *testing.T) {
	const rendered = `---
apiVersion: v1
kind: Service
metadata:
  name: postgresql-primary
  namespace: data
---
apiVersion: batch/v1
kind: Job
metadata:
  name: migrations
  namespace: data
spec:
  template:
    spec:
      initContainers:
        - name: wait-for-db
          env:
            - name: POSTGRES_HOST
              value: "%s.data.svc.cluster.local"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql
                  key: password
`
	bad := fmt.Sprintf(rendered, "postgresql-postgresql-primary")
	got := danglingCollapseHostMessage(bad, "postgresql", "some-chart")
	if !strings.Contains(got, "POSTGRES_HOST") {
		t.Errorf("a Job env host that misses the collapse must be named, got %q", got)
	}
	good := fmt.Sprintf(rendered, "postgresql-primary")
	if got := danglingCollapseHostMessage(good, "postgresql", "some-chart"); got != "" {
		t.Errorf("a Job env host that honours the collapse must pass, got %q", got)
	}
	// The waiver keys on the env name exactly as it keys on a ConfigMap key.
	knownCollapseHostDrift["some-chart:POSTGRES_HOST"] = true
	defer delete(knownCollapseHostDrift, "some-chart:POSTGRES_HOST")
	if got := danglingCollapseHostMessage(bad, "postgresql", "some-chart"); got != "" {
		t.Errorf("waived chart and env name must pass, got %q", got)
	}
}

// The render gate renders every chart with its default values, so a default
// that is only wrong under a non-default subchart topology is invisible to it.
// product-console resolves configmap.MONGO_HOST from the bundled subchart's
// fullname, which is the Service name for a STANDALONE MongoDB and for nothing
// else: Bitnami renames that Service through mongodb.service.nameOverride, and
// in replicaset architecture publishes "<fullname>-headless" plus one DNS name
// per replica. The chart refuses to render for those two unless the operator
// names a host, and this pins both halves of that: it refuses without one, and
// it renders with the very host the refusal prints. The chart vendors its
// dependencies as .tgz, so no dependency build or network access is needed.
func TestProductConsoleRefusesAnUnnameableMongoHost(t *testing.T) {
	if _, err := exec.LookPath("helm"); err != nil {
		t.Skip("helm not on PATH")
	}
	const chart = "../../../charts/product-console"
	const headless = "product-console-mongodb-headless.product-console.svc.cluster.local"
	cases := []struct {
		name     string
		values   []string
		wantFail string // substring the refusal must name; empty means it must render
	}{
		{"shipped defaults", nil, ""},
		{
			"replicaset with no host named",
			[]string{"--set", "mongodb.architecture=replicaset"},
			"mongodb.architecture is replicaset",
		},
		{
			"replicaset with the host the refusal names",
			[]string{"--set", "mongodb.architecture=replicaset", "--set", "configmap.MONGO_HOST=" + headless},
			"",
		},
		{
			"renamed Service with no host named",
			[]string{"--set", "mongodb.service.nameOverride=svcx"},
			"mongodb.service.nameOverride is svcx",
		},
		{
			"renamed Service with the host the refusal names",
			[]string{"--set", "mongodb.service.nameOverride=svcx", "--set", "configmap.MONGO_HOST=svcx.product-console.svc.cluster.local"},
			"",
		},
	}
	for _, c := range cases {
		args := append([]string{"template", "product-console", chart, "-n", "product-console"}, c.values...)
		out, err := exec.Command("helm", args...).CombinedOutput()
		switch {
		case c.wantFail == "" && err != nil:
			t.Errorf("%s: render failed, want success: %s", c.name, oneLine(string(out)))
		case c.wantFail != "" && err == nil:
			t.Errorf("%s: render succeeded, want a refusal naming %q", c.name, c.wantFail)
		case c.wantFail != "" && !strings.Contains(string(out), c.wantFail):
			t.Errorf("%s: refusal must name %q, got: %s", c.name, c.wantFail, oneLine(string(out)))
		}
		// A refusal that does not say what to set is a dead end for the operator.
		if c.wantFail != "" && !strings.Contains(string(out), "Set configmap.MONGO_HOST to ") {
			t.Errorf("%s: refusal must name the value to set, got: %s", c.name, oneLine(string(out)))
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
