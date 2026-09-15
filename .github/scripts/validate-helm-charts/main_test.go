package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

// Every product-console render below runs against a COPY of the chart with its
// dependencies built, never against the working tree. .gitignore excludes
// `**/*.tgz` and `**/charts/*/charts`, so a clean checkout carries no
// lerian-common-helm or mongodb archive and every render would fail on a missing
// dependency rather than on the chart under test. Built once per run, through
// the same steps the render gate itself uses.
var (
	preparedChartOnce sync.Once
	preparedChartDir  string
	preparedChartErr  error
)

func preparedProductConsoleChart(t *testing.T) string {
	t.Helper()
	if _, err := exec.LookPath("helm"); err != nil {
		t.Skip("helm not on PATH")
	}
	preparedChartOnce.Do(func() {
		preparedChartDir, preparedChartErr = buildProductConsoleChart()
	})
	if preparedChartErr != nil {
		// The build fetches lerian-common-helm from ghcr.io and mongodb from
		// charts.bitnami.com. In CI that is a real failure and has to be red; on
		// a developer machine with no network it is not the chart, so name the
		// archives that are missing and skip instead of reporting a red that has
		// nothing to do with the code under test.
		if os.Getenv("CI") != "" {
			t.Fatalf("building charts/product-console dependencies (lerian-common-helm, mongodb): %v", preparedChartErr)
		}
		t.Skipf("charts/product-console dependencies (lerian-common-helm, mongodb) could not be built: %v", preparedChartErr)
	}
	return preparedChartDir
}

func buildProductConsoleChart() (string, error) {
	tmpRoot, err := os.MkdirTemp("", "product-console-render-*")
	if err != nil {
		return "", err
	}
	chartDir := filepath.Join(tmpRoot, "product-console")
	if err := copyDir(filepath.Join("..", "..", "..", "charts", "product-console"), chartDir); err != nil {
		return "", err
	}
	env, err := isolatedHelmEnv(tmpRoot)
	if err != nil {
		return "", err
	}
	if out, err := retryHelm(func() (string, error) {
		return addDependencyRepositories(chartDir, tmpRoot, env)
	}); err != nil {
		return "", fmt.Errorf("helm repo add: %s", oneLine(out))
	}
	if out, err := retryHelm(func() (string, error) {
		return runHelmWithEnv(tmpRoot, env, "dependency", "build", chartDir)
	}); err != nil {
		return "", fmt.Errorf("helm dependency build: %s", oneLine(out))
	}
	return chartDir, nil
}

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
// it renders with the very host the refusal prints.
func TestProductConsoleRefusesAnUnnameableMongoHost(t *testing.T) {
	chart := preparedProductConsoleChart(t)
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

// A ServiceAccount is namespaced, so a Deployment pinned to one namespace with
// its ServiceAccount rendered into another installs cleanly, reports STATUS:
// deployed, and never creates a pod. product-console shipped that: every
// resource carried the chart's pinned namespace except the ServiceAccount,
// which took the release namespace instead.
func TestServiceAccountNamespaceMessage(t *testing.T) {
	const rendered = `---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: %s
%s
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: pinned
spec:
  template:
    spec:
      serviceAccountName: app
`
	cases := []struct {
		name, saName, saNamespace string
		wantHit                   bool
	}{
		{"account left on the release namespace", "app", "", true},
		{"account in another namespace", "app", "  namespace: elsewhere", true},
		{"account alongside its workload", "app", "  namespace: pinned", false},
		{"account this release does not render", "other", "  namespace: pinned", false},
	}
	for _, c := range cases {
		got := serviceAccountNamespaceMessage(fmt.Sprintf(rendered, c.saName, c.saNamespace), "release-ns")
		if (got != "") != c.wantHit {
			t.Errorf("%s: serviceAccountNamespaceMessage = %q, want hit=%v", c.name, got, c.wantHit)
		}
		if c.wantHit && !strings.Contains(got, `ServiceAccount "app"`) {
			t.Errorf("%s: message must name the account, got %q", c.name, got)
		}
	}

	// The reporter chart's shape, and the false positive that made this take a
	// release namespace: the ServiceAccount writes .Release.Namespace while the
	// workload writes nothing, so the two agree in every real install.
	const oneSideExplicit = `---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: release-ns
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      serviceAccountName: app
`
	if got := serviceAccountNamespaceMessage(oneSideExplicit, "release-ns"); got != "" {
		t.Errorf("an account pinned to the release namespace must pass, got %q", got)
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
