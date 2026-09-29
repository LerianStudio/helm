package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// The br-jd-courier render contract. The chart has no dependencies, so every
// render runs against the working tree; helm-chart-standard.yml runs this file
// on every pull request that touches charts/br-jd-courier.

const courierChart = "../../../charts/br-jd-courier"

var courierRoles = []string{"admin", "pix-ingress", "spb-consumer", "spb-sender"}

func renderCourier(t *testing.T, args ...string) (string, error) {
	t.Helper()
	if _, err := exec.LookPath("helm"); err != nil {
		if os.Getenv("CI") != "" {
			t.Fatalf("helm is not on PATH, so the br-jd-courier render pins did not run: %v", err)
		}
		t.Skip("helm not on PATH")
	}
	out, err := exec.Command("helm", append([]string{"template", "t", courierChart}, args...)...).CombinedOutput()
	return string(out), err
}

func courierManifests(t *testing.T, args ...string) []map[string]interface{} {
	t.Helper()
	out, err := renderCourier(t, args...)
	if err != nil {
		t.Fatalf("render %v failed: %s", args, oneLine(out))
	}
	docs, err := decodeManifests(out)
	if err != nil {
		t.Fatalf("decoding the render %v: %v", args, err)
	}
	return docs
}

func dig(v interface{}, path ...string) interface{} {
	for _, key := range path {
		m, ok := v.(map[string]interface{})
		if !ok {
			return nil
		}
		v = m[key]
	}
	return v
}

func ofKind(docs []map[string]interface{}, kind string) []map[string]interface{} {
	var out []map[string]interface{}
	for _, d := range docs {
		if d["kind"] == kind {
			out = append(out, d)
		}
	}
	return out
}

func container(obj map[string]interface{}) map[string]interface{} {
	cs, _ := dig(obj, "spec", "template", "spec", "containers").([]interface{})
	if len(cs) != 1 {
		return nil
	}
	c, _ := cs[0].(map[string]interface{})
	return c
}

// env returns the container's env entries by name, and their order.
func env(c map[string]interface{}) (map[string]map[string]interface{}, []string) {
	byName := map[string]map[string]interface{}{}
	var order []string
	list, _ := c["env"].([]interface{})
	for _, e := range list {
		entry, _ := e.(map[string]interface{})
		name, _ := entry["name"].(string)
		byName[name] = entry
		order = append(order, name)
	}
	return byName, order
}

func indexOf(values []string, want string) int {
	for i, v := range values {
		if v == want {
			return i
		}
	}
	return -1
}

func TestCourierRefusesWhatTheContractForbids(t *testing.T) {
	type refusal struct {
		name, want string
		args       []string
	}
	cases := []refusal{
		{"a scaled single writer", "spb-consumer is a SINGLE WRITER", []string{"--set", "roles.spbConsumer.replicas=2"}},
		{"any single-writer count above one", "spb-consumer is a SINGLE WRITER", []string{"--set", "roles.spbConsumer.replicas=5"}},
		{"COURIER_ROLES as a value", "config.COURIER_ROLES is refused", []string{"--set", "config.COURIER_ROLES=admin"}},
		{"auth off in a chart install", "config.ALLOW_AUTH_DISABLED_LOCAL_ONLY is refused", []string{"--set", "config.ALLOW_AUTH_DISABLED_LOCAL_ONLY=true"}},
		{"SERVER_ADDRESS drifting from ports.http", "config.SERVER_ADDRESS is refused", []string{"--set", "config.SERVER_ADDRESS=:1"}},
		{"SOAP_SERVER_ADDRESS drifting from ports.soap", "config.SOAP_SERVER_ADDRESS is refused", []string{"--set", "config.SOAP_SERVER_ADDRESS=:1"}},
		{"the OTLP endpoint shadowed from config", "config.OTEL_EXPORTER_OTLP_ENDPOINT is refused", []string{"--set", "config.OTEL_EXPORTER_OTLP_ENDPOINT=x:4317"}},
		{"a PEM key under any config name", "carries a PEM private key", []string{"--set-string", "config.SOME_KEY=-----BEGIN RSA PRIVATE KEY-----MIIB"}},
		{"a PEM key anywhere in the values", "carries a PEM private key", []string{"--set-string", "podAnnotations.note=-----BEGIN PRIVATE KEY-----MIIB"}},
		{"a long PEM key toYaml may fold", "carries a PEM private key", []string{"--set-string", "podAnnotations.note=" + strings.Repeat("word ", 30) + "-----BEGIN ENCRYPTED PRIVATE KEY-----MIIB"}},
		{"a boolean MULTI_TENANT_ENABLED with the migration Job", "MULTI_TENANT_ENABLED=true", []string{"--set", "config.MULTI_TENANT_ENABLED=true"}},
	}
	for _, key := range []string{"LICENSE_KEY", "DATABASE_URL", "POSTGRES_PASSWORD", "POSTGRES_REPLICA_PASSWORD", "REDIS_PASSWORD", "MULTI_TENANT_REDIS_PASSWORD", "MULTI_TENANT_SERVICE_API_KEY", "JD_PASSWORD", "JD_PRIVATE_KEY_PEM"} {
		cases = append(cases, refusal{key + " as a value", "config." + key + " is refused", []string{"--set", "config." + key + "=sentinel"}})
	}
	// Every spelling strconv.ParseBool reads as true, and one it does not.
	for _, spelling := range []string{"true", "True", "TRUE", "t", "T", "1", " true "} {
		cases = append(cases, refusal{fmt.Sprintf("MULTI_TENANT_ENABLED=%q with the migration Job", spelling), "MULTI_TENANT_ENABLED=true", []string{"--set-string", "config.MULTI_TENANT_ENABLED=" + spelling}})
	}
	for _, c := range cases {
		out, err := renderCourier(t, c.args...)
		if err == nil {
			t.Errorf("%s: rendered, want a refusal", c.name)
		} else if !strings.Contains(out, c.want) {
			t.Errorf("%s: refused without naming %q: %s", c.name, c.want, oneLine(out))
		}
	}

	for _, args := range [][]string{
		{"--set-string", "config.MULTI_TENANT_ENABLED=false"},
		{"--set-string", "config.MULTI_TENANT_ENABLED=0"},
		{"--set-string", "config.MULTI_TENANT_ENABLED=f"},
		{"--set", "migrations.enabled=false", "--set", "config.MULTI_TENANT_ENABLED=true"},
		{"--set-string", "podAnnotations.ca=-----BEGIN CERTIFICATE-----MIIB", "--set-string", "podAnnotations.note=rotate the PRIVATE KEY yearly"},
		{"--set", "roles.spbSender.replicas=5", "--set", "roles.admin.replicas=3", "--set", "roles.pixIngress.replicas=4"},
	} {
		if out, err := renderCourier(t, args...); err != nil {
			t.Errorf("%v: refused, want a render: %s", args, oneLine(out))
		}
	}
}

func TestCourierDefaultRender(t *testing.T) {
	docs := courierManifests(t)

	if secrets := ofKind(docs, "Secret"); len(secrets) != 0 {
		t.Errorf("the chart renders %d Secret(s), want none", len(secrets))
	}
	var services []string
	for _, s := range ofKind(docs, "Service") {
		services = append(services, nestedString(s, "metadata", "name"))
	}
	sort.Strings(services)
	if got := strings.Join(services, " "); got != "t-br-jd-courier-admin t-br-jd-courier-pix-ingress t-br-jd-courier-spb-sender" {
		t.Errorf("services rendered: %s; spb-consumer must expose none", got)
	}
	cm := ofKind(docs, "ConfigMap")
	if len(cm) != 1 || dig(cm[0], "data", "PLUGIN_AUTH_ENABLED") != "true" || dig(cm[0], "data", "OTEL_EXPORTER_OTLP_ENDPOINT") != nil {
		t.Errorf("the one ConfigMap must turn authentication on and carry no OTLP endpoint: %v", cm)
	}

	deployments := ofKind(docs, "Deployment")
	pods := append(append([]map[string]interface{}{}, deployments...), ofKind(docs, "Job")...)
	if len(deployments) != 4 || len(pods) != 5 {
		t.Fatalf("rendered %d Deployments and %d pod templates, want 4 and 5", len(deployments), len(pods))
	}
	images := map[string]bool{}
	for _, p := range pods {
		images[fmt.Sprint(container(p)["image"])] = true
		sc := dig(p, "spec", "template", "spec", "securityContext")
		if dig(sc, "runAsNonRoot") != true || dig(sc, "runAsUser") != 65532 {
			t.Errorf("%s: the pod must pin numeric non-root user 65532, got %v", nestedString(p, "metadata", "name"), sc)
		}
	}
	if len(images) != 1 || !images["lerianstudio/br-jd-courier:1.0.0-rc.1"] {
		t.Errorf("every role and the migration Job must run one image, got %v", images)
	}

	var roles []string
	for _, d := range deployments {
		name := nestedString(d, "metadata", "name")
		byName, order := env(container(d))
		role := fmt.Sprint(dig(byName["COURIER_ROLES"], "value"))
		roles = append(roles, role)
		if name != "t-br-jd-courier-"+role {
			t.Errorf("%s carries role %q", name, role)
		}
		// A rolling update runs two single writers during every rollout.
		strategy := dig(d, "spec", "strategy", "type")
		if role == "spb-consumer" && (dig(d, "spec", "replicas") != 1 || strategy != "Recreate") {
			t.Errorf("%s: replicas %v strategy %v, want 1 Recreate", name, dig(d, "spec", "replicas"), strategy)
		}
		if role != "spb-consumer" && strategy != "RollingUpdate" {
			t.Errorf("%s: strategy %v, want RollingUpdate", name, strategy)
		}
		lk := dig(byName["LICENSE_KEY"], "valueFrom", "secretKeyRef")
		if dig(lk, "name") != "t-br-jd-courier" || dig(lk, "key") != "LICENSE_KEY" || dig(lk, "optional") != nil {
			t.Errorf("%s: LICENSE_KEY must come from a required secretKeyRef on the release Secret, got %v", name, lk)
		}
		// $(NODE_IP) expands only in an env value defined below NODE_IP.
		if dig(byName["NODE_IP"], "valueFrom", "fieldRef", "fieldPath") != "status.hostIP" ||
			indexOf(order, "NODE_IP") > indexOf(order, "OTEL_EXPORTER_OTLP_ENDPOINT") ||
			dig(byName["OTEL_EXPORTER_OTLP_ENDPOINT"], "value") != "$(NODE_IP):4317" ||
			dig(byName["ALLOW_INSECURE_OTEL"], "value") != "node-local collector on the pod's own node" {
			t.Errorf("%s: OTLP must go to the node's collector, exempted from the production gate: %v", name, order)
		}
	}
	sort.Strings(roles)
	if strings.Join(roles, " ") != strings.Join(courierRoles, " ") {
		t.Errorf("roles rendered %v, want %v", roles, courierRoles)
	}
}

func TestCourierValuesMoveWhatTheyName(t *testing.T) {
	for _, d := range ofKind(courierManifests(t, "--set", "jd-courier.image.tag=9.9.9"), "Deployment") {
		if got := container(d)["image"]; got != "lerianstudio/br-jd-courier:9.9.9" {
			t.Errorf("the release bump key jd-courier.image.tag did not move %s: %v", nestedString(d, "metadata", "name"), got)
		}
	}

	for _, d := range ofKind(courierManifests(t, "--set", "ports.http=9090", "--set", "ports.soap=9091"), "Deployment") {
		byName, _ := env(container(d))
		ports, _ := container(d)["ports"].([]interface{})
		if dig(byName["SERVER_ADDRESS"], "value") != ":9090" || dig(byName["SOAP_SERVER_ADDRESS"], "value") != ":9091" || len(ports) == 0 || dig(ports[0], "containerPort") != 9090 {
			t.Errorf("%s: listener addresses do not follow ports.*", nestedString(d, "metadata", "name"))
		}
	}

	// Only the default node-local endpoint is exempted from the production gate.
	for _, endpoint := range []string{"https://otel.example:4317", "$(NODE_IP):4318"} {
		for _, d := range ofKind(courierManifests(t, "--set", "telemetry.otlpEndpoint="+endpoint), "Deployment") {
			byName, _ := env(container(d))
			_, exempt := byName["ALLOW_INSECURE_OTEL"]
			if dig(byName["OTEL_EXPORTER_OTLP_ENDPOINT"], "value") != endpoint || exempt {
				t.Errorf("%s: endpoint %q must move the role and get no insecure exemption", nestedString(d, "metadata", "name"), endpoint)
			}
		}
	}

	for _, d := range ofKind(courierManifests(t, "--set", "secrets.existingSecret=courier-secrets"), "Deployment") {
		byName, _ := env(container(d))
		if dig(byName["LICENSE_KEY"], "valueFrom", "secretKeyRef", "name") != "courier-secrets" {
			t.Errorf("%s: secrets.existingSecret does not name the LICENSE_KEY Secret", nestedString(d, "metadata", "name"))
		}
	}
}

// A LICENSE_KEY value offered through every values path the schema admits
// reaches no manifest; the variable's name is allowed, its value never.
func TestCourierRendersNoLicenseKeyValue(t *testing.T) {
	const sentinel = "lk-sentinel-4f1c9e"
	out, err := renderCourier(t, "--set", "secrets.existingSecret=courier-secrets",
		"--set", "secrets.LICENSE_KEY="+sentinel, "--set", "secrets.licenseKey="+sentinel,
		"--set", "jd-courier.licenseKey="+sentinel)
	if err != nil {
		t.Fatalf("render failed: %s", oneLine(out))
	}
	if strings.Contains(out, sentinel) {
		t.Error("a LICENSE_KEY value appears in a rendered manifest")
	}
	if strings.Contains(out, "kind: Secret") {
		t.Error("the chart renders a Secret")
	}
}

func TestCourierRendersWholeNumbersAsDigits(t *testing.T) {
	values := filepath.Join(t.TempDir(), "numbers.yaml")
	if err := os.WriteFile(values, []byte("config:\n  BIG_WHOLE: 10485760\n  FRACTION: 1.5\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	cm := ofKind(courierManifests(t, "-f", values), "ConfigMap")
	if len(cm) != 1 {
		t.Fatalf("rendered %d ConfigMaps, want 1", len(cm))
	}
	if dig(cm[0], "data", "BIG_WHOLE") != "10485760" || dig(cm[0], "data", "FRACTION") != "1.5" {
		t.Errorf("numbers from a values file rendered as %v", dig(cm[0], "data"))
	}
}
