package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"gopkg.in/yaml.v3"
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
		// Gated exactly like the dependency-build failure below, and for the
		// same reason: in CI a missing helm means none of these pins ran, and
		// `go test` without -v reports that as `ok`, with only the duration to
		// tell it apart from a real pass. A Setup Helm step that is reordered,
		// removed or fails soft would leave the refusals unguarded with nobody
		// told. On a developer machine a missing helm is just a missing tool.
		if os.Getenv("CI") != "" {
			t.Fatalf("helm is not on PATH, so the charts/product-console render pins did not run: %v", err)
		}
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
	render := func(values ...string) (string, error) {
		args := append([]string{"template", "product-console", chart, "-n", "product-console"}, values...)
		out, err := exec.Command("helm", args...).CombinedOutput()
		return string(out), err
	}

	if out, err := render(); err != nil {
		t.Fatalf("shipped defaults: render failed, want success: %s", oneLine(out))
	}

	cases := []struct {
		name      string
		values    []string
		wantNamed []string // every reason and hint the refusal has to carry
		wantHost  string   // the FQDN it prints, which must name a Service the repaired render creates
	}{
		{
			name:      "replicaset",
			values:    []string{"--set", "mongodb.architecture=replicaset"},
			wantNamed: []string{"mongodb.architecture is replicaset", "replicaSet=rs0"},
			wantHost:  "product-console-mongodb-headless.product-console.svc.cluster.local",
		},
		{
			name:      "renamed Service",
			values:    []string{"--set", "mongodb.service.nameOverride=svcx"},
			wantNamed: []string{"mongodb.service.nameOverride is svcx"},
			wantHost:  "svcx.product-console.svc.cluster.local",
		},
		{
			// Bitnami resolves the Service name through one helper for BOTH
			// architectures (mongodb-16.4.0 templates/_helpers.tpl
			// "mongodb.service.nameOverride"): the override wins when set, and
			// only without one does a replica set fall back to
			// "<fullname>-headless". Naming the headless Service here would send
			// an operator to a host this release never creates.
			name:      "replicaset and a renamed Service together",
			values:    []string{"--set", "mongodb.architecture=replicaset", "--set", "mongodb.service.nameOverride=svcx"},
			wantNamed: []string{"mongodb.architecture is replicaset", "mongodb.service.nameOverride is svcx", "replicaSet=rs0"},
			wantHost:  "svcx.product-console.svc.cluster.local",
		},
	}
	for _, c := range cases {
		out, err := render(c.values...)
		if err == nil {
			t.Errorf("%s: render succeeded, want a refusal", c.name)
			continue
		}
		for _, want := range c.wantNamed {
			if !strings.Contains(out, want) {
				t.Errorf("%s: refusal must name %q, got: %s", c.name, want, oneLine(out))
			}
		}
		// A refusal that does not say what to set is a dead end for the operator.
		// One that names a host the release does not create is worse: it reads as
		// an answer and lands in the very defect it exists to prevent, with the
		// console Ready and every MongoDB-backed page failing.
		if !strings.Contains(out, "Set configmap.MONGO_HOST to "+c.wantHost) {
			t.Errorf("%s: refusal must name %q as the host to set, got: %s", c.name, c.wantHost, oneLine(out))
			continue
		}
		repaired, err := render(append(append([]string{}, c.values...), "--set", "configmap.MONGO_HOST="+c.wantHost)...)
		if err != nil {
			t.Errorf("%s: render with the host the refusal names failed: %s", c.name, oneLine(repaired))
			continue
		}
		svc := c.wantHost[:strings.Index(c.wantHost, ".")]
		services := renderedNames(t, repaired, "Service")
		if !contains(services, svc) {
			t.Errorf("%s: refusal names host %s, but the repaired render creates no Service %q (it creates %v)",
				c.name, c.wantHost, svc, services)
		}
	}
}

// Three different installs land the console and its bundled MongoDB in
// different namespaces, and a Secret cannot be read across namespaces, so the
// chart leaves MONGODB_PASS unwired and NOTES.txt tells the operator how to
// repair it. A remedy that works in only some of those installs is worse than
// none: the operator follows it, the split survives, and every MongoDB-backed
// page still fails on an auth error, with nothing on screen saying why. Each
// shape is rendered here, and the remedy the notes print is then applied and
// asserted to actually wire the password.
func TestProductConsoleNamespaceSplitRemedy(t *testing.T) {
	chart := preparedProductConsoleChart(t)
	// values.yaml pins namespaceOverride, so the console always lands here.
	const consoleNs = "product-console"
	const remedy = "--set global.namespaceOverride=" + consoleNs
	// helm upgrade re-renders the release from the arguments it is handed, so a
	// remedy printed as a complete command that carries no values file resets
	// every value the operator installed with: the password gets wired and the
	// authorization gate, the ingress and every secret revert to chart defaults.
	// The printed command has to carry the operator's own file back in.
	const carriesValues = "-f <your-values.yaml>"
	const repeatsFlags = "repeat every other flag from that install"
	// The subchart follows global.namespaceOverride when it is set and -n
	// otherwise, so the two split shapes need different explanations. Printing
	// the override sentence for an -n split tells the operator that the repair
	// their install actually needs cannot work.
	const overrideWins = "reads that value INSTEAD of -n, so changing -n alone does not move it"
	const nFollows = "so a fresh install with -n '" + consoleNs + "' lands it beside the console"
	cases := []struct {
		name        string
		namespace   string
		values      []string
		wantMongoNs string
		wantSaid    string // the sentence this split's shape earns
		wantUnsaid  string // the other shape's sentence, which is false here
	}{
		{"release namespace differs from the console's", "other-ns", nil, "other-ns", nFollows, overrideWins},
		{"global.namespaceOverride set", consoleNs, []string{"--set", "global.namespaceOverride=data"}, "data", overrideWins, nFollows},
		{"both at once", "other-ns", []string{"--set", "global.namespaceOverride=data"}, "data", overrideWins, nFollows},
	}
	for _, c := range cases {
		notes := normalizeSpace(renderNotes(t, chart, c.namespace, c.values...))
		if !strings.Contains(notes, "ACTION REQUIRED") {
			t.Errorf("%s: install notes must flag the split, got: %s", c.name, notes)
			continue
		}
		for _, want := range []string{
			"in namespace '" + c.wantMongoNs + "'",
			"while these pods run in '" + consoleNs + "'",
			remedy,
			carriesValues,
			repeatsFlags,
			c.wantSaid,
		} {
			if !strings.Contains(notes, want) {
				t.Errorf("%s: install notes must say %q, got: %s", c.name, want, notes)
			}
		}
		if strings.Contains(notes, c.wantUnsaid) {
			t.Errorf("%s: install notes must not say %q, which is false for this split: %s", c.name, c.wantUnsaid, notes)
		}

		repaired, err := renderChart(chart, c.namespace,
			append(append([]string{}, c.values...), "--set", "global.namespaceOverride="+consoleNs)...)
		if err != nil {
			t.Errorf("%s: render with the remedy applied failed: %s", c.name, oneLine(repaired))
			continue
		}
		// The whole point of the remedy: the console reads the subchart's
		// generated password instead of the empty one in its own Secret.
		if !strings.Contains(normalizeSpace(repaired), "- name: MONGODB_PASS valueFrom: secretKeyRef:") {
			t.Errorf("%s: the remedy the notes print leaves MONGODB_PASS unwired", c.name)
		}
	}
}

// useExistingSecret switches the console's environment Secret from the one this
// chart creates to one the operator brings, and existingSecretName is the key
// that names it. Setting the switch and leaving the name empty rendered a
// secretRef with no name at all: helm lint, the render gate and every render
// assertion pass, and the API server rejects the Deployment at apply time with
// an error that names neither key, on an upgrade rather than at render.
func TestProductConsoleRefusesAnExistingSecretWithNoName(t *testing.T) {
	chart := preparedProductConsoleChart(t)

	// The empty string and a name that is only whitespace reach the API server
	// the same way: a secretRef with nothing usable in it.
	for _, name := range []string{"", "   "} {
		values := []string{"--set", "useExistingSecret=true"}
		if name != "" {
			values = append(values, "--set", "existingSecretName="+name)
		}
		out, err := renderChart(chart, "product-console", values...)
		if err == nil {
			t.Fatalf("render succeeded with useExistingSecret set and name %q, want a refusal: %s", name, oneLine(out))
		}
		if !strings.Contains(out, "existingSecretName") {
			t.Errorf("the refusal for name %q must name existingSecretName, got: %s", name, oneLine(out))
		}
	}

	named, err := renderChart(chart, "product-console",
		"--set", "useExistingSecret=true", "--set", "existingSecretName=my-own-secret")
	if err != nil {
		t.Fatalf("render with existingSecretName set failed: %s", oneLine(named))
	}
	if !strings.Contains(normalizeSpace(named), "- secretRef: name: my-own-secret") {
		t.Errorf("the Secret the operator named must reach the container, got: %s", oneLine(named))
	}
	if contains(renderedNames(t, named, "Secret"), "product-console") {
		t.Error("with useExistingSecret set, the chart must not also create its own Secret")
	}
}

func renderChart(chart, namespace string, values ...string) (string, error) {
	args := append([]string{"template", "product-console", chart, "-n", namespace}, values...)
	out, err := exec.Command("helm", args...).CombinedOutput()
	return string(out), err
}

// renderNotes returns a render of the chart that includes NOTES.txt, which
// `helm template` otherwise never emits. helm renders every file under
// templates/ except NOTES.txt and _*.tpl, so a copy of the chart turns the notes
// into a named template and has a ConfigMap carry their output.
func renderNotes(t *testing.T, chart, namespace string, values ...string) string {
	t.Helper()
	probe := filepath.Join(t.TempDir(), "product-console")
	if err := copyDir(chart, probe); err != nil {
		t.Fatalf("copying the chart: %v", err)
	}
	notes, err := os.ReadFile(filepath.Join(probe, "templates", "NOTES.txt"))
	if err != nil {
		t.Fatalf("reading NOTES.txt: %v", err)
	}
	if err := os.WriteFile(filepath.Join(probe, "templates", "_notes-probe.tpl"),
		[]byte("{{- define \"notes.probe\" -}}\n"+string(notes)+"{{- end -}}\n"), 0o600); err != nil {
		t.Fatalf("writing the notes template: %v", err)
	}
	if err := os.WriteFile(filepath.Join(probe, "templates", "notes-probe.yaml"),
		[]byte("apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: notes-probe\ndata:\n  notes: |\n{{ include \"notes.probe\" . | indent 4 }}\n"), 0o600); err != nil {
		t.Fatalf("writing the notes probe: %v", err)
	}
	out, err := renderChart(probe, namespace, values...)
	if err != nil {
		t.Fatalf("rendering the install notes: %s", oneLine(out))
	}
	return out
}

// normalizeSpace collapses every run of whitespace to one space, so an assertion
// on a phrase does not depend on where the notes wrap it.
func normalizeSpace(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

// decodeManifests returns every object in a rendered manifest stream. A document
// the decoder rejects is reported rather than read as the end of the stream:
// swallowing it truncated the list, and the assertions built on that list then
// passed while asserting nothing.
func decodeManifests(rendered string) ([]map[string]interface{}, error) {
	var docs []map[string]interface{}
	dec := yaml.NewDecoder(strings.NewReader(stripNonManifest(rendered)))
	for {
		var doc yaml.Node
		err := dec.Decode(&doc)
		if errors.Is(err, io.EOF) {
			return docs, nil
		}
		if err != nil {
			return nil, fmt.Errorf("document %d: %w", len(docs)+1, err)
		}
		var m map[string]interface{}
		if err := doc.Decode(&m); err != nil || m == nil {
			continue
		}
		docs = append(docs, m)
	}
}

// A rejected document used to end the walk, so renderedNames came back short
// with no signal at all. The one negative assertion built on it, "with
// useExistingSecret set the chart must not also create its own Secret", then
// passed on a release that did create one.
func TestDecodeManifestsReportsARejectedDocument(t *testing.T) {
	const good = "---\nkind: Secret\nmetadata:\n  name: first\n---\nkind: Secret\nmetadata:\n  name: last\n"
	if got := renderedNames(t, good, "Secret"); len(got) != 2 {
		t.Fatalf("every object in a readable stream must be returned, got %v", got)
	}
	// A leading tab is a YAML syntax error, so the decoder rejects the second
	// document and the third is never reached.
	const truncating = "---\nkind: Secret\nmetadata:\n  name: first\n---\n\tkind: Secret\n---\nkind: Secret\nmetadata:\n  name: last\n"
	if _, err := decodeManifests(truncating); err == nil {
		t.Fatal("a document the decoder rejects must be reported, not read as the end of the stream")
	}
}

// renderedNames returns the metadata.name of every object of one kind in a
// rendered manifest stream.
func renderedNames(t *testing.T, rendered, kind string) []string {
	t.Helper()
	docs, err := decodeManifests(rendered)
	if err != nil {
		t.Fatalf("decoding the rendered manifest: %v", err)
	}
	var names []string
	for _, m := range docs {
		if k, _ := m["kind"].(string); k != kind {
			continue
		}
		if name := nestedString(m, "metadata", "name"); name != "" {
			names = append(names, name)
		}
	}
	return names
}

func contains(values []string, want string) bool {
	for _, v := range values {
		if v == want {
			return true
		}
	}
	return false
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
