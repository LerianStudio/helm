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

const (
	courierChart = "../../../charts/br-jd-courier"
	// The render gate's values: the chart refuses to render without
	// config.ENVIRONMENT_NAME, so every render here starts from them.
	courierFixture = "../../configs/helm-render-values/br-jd-courier.yaml"
)

var courierRoles = []string{"admin", "pix-ingress", "spb-consumer", "spb-sender"}

func helmTemplate(t *testing.T, args ...string) (string, error) {
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

func renderCourier(t *testing.T, args ...string) (string, error) {
	t.Helper()
	return helmTemplate(t, append([]string{"-f", courierFixture}, args...)...)
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
		{"COURIER_ROLES as a value", "config.COURIER_ROLES is refused", []string{"--set", "config.COURIER_ROLES=admin"}},
		{"auth off in a chart install", "config.ALLOW_AUTH_DISABLED_LOCAL_ONLY is refused", []string{"--set", "config.ALLOW_AUTH_DISABLED_LOCAL_ONLY=true"}},
		{"SERVER_ADDRESS drifting from ports.http", "config.SERVER_ADDRESS is refused", []string{"--set", "config.SERVER_ADDRESS=:1"}},
		{"SOAP_SERVER_ADDRESS drifting from ports.soap", "config.SOAP_SERVER_ADDRESS is refused", []string{"--set", "config.SOAP_SERVER_ADDRESS=:1"}},
		{"the OTLP endpoint shadowed from config", "config.OTEL_EXPORTER_OTLP_ENDPOINT is refused", []string{"--set", "config.OTEL_EXPORTER_OTLP_ENDPOINT=x:4317"}},
		{"a PEM key under any config name", "carries a PEM private key", []string{"--set-string", "config.SOME_KEY=-----BEGIN RSA PRIVATE KEY-----MIIB"}},
		{"a PEM key anywhere in the values", "carries a PEM private key", []string{"--set-string", "podAnnotations.note=-----BEGIN PRIVATE KEY-----MIIB"}},
		{"a long PEM key toYaml may fold", "carries a PEM private key", []string{"--set-string", "podAnnotations.note=" + strings.Repeat("word ", 30) + "-----BEGIN ENCRYPTED PRIVATE KEY-----MIIB"}},
		{"a boolean MULTI_TENANT_ENABLED with the migration Job", "MULTI_TENANT_ENABLED=true", []string{"--set", "config.MULTI_TENANT_ENABLED=true"}},
		{"ENV_NAME in place of ENVIRONMENT_NAME", "config.ENV_NAME, the service's deprecated alias, does not satisfy", []string{"--set-string", "config.ENVIRONMENT_NAME=", "--set", "config.ENV_NAME=production"}},
		{"a blank ENVIRONMENT_NAME", "config.ENVIRONMENT_NAME is required", []string{"--set-string", "config.ENVIRONMENT_NAME=  "}},
		{"the Pix transit with no TLS shape", "the Pix engines refuse plain HTTP", []string{"--set", "roles.admin.pixTransit.enabled=true"}},
	}
	for _, key := range []string{"SOAP_TLS_CERT_FILE", "SOAP_TLS_KEY_FILE", "SOAP_TLS_TERMINATED_UPSTREAM", "PIX_TRANSIT_SERVER_ADDRESS", "PIX_TRANSIT_TLS_CERT_FILE", "PIX_TRANSIT_TLS_KEY_FILE", "PIX_TRANSIT_TLS_TERMINATED_UPSTREAM"} {
		cases = append(cases, refusal{key + " as a value", "config." + key + " is refused", []string{"--set", "config." + key + "=x"}})
	}
	for _, key := range []string{"LICENSE_KEY", "DATABASE_URL", "POSTGRES_PASSWORD", "POSTGRES_REPLICA_PASSWORD", "REDIS_PASSWORD", "MULTI_TENANT_REDIS_PASSWORD", "MULTI_TENANT_SERVICE_API_KEY", "JD_PASSWORD", "JD_SPI_CLIENT_SECRET", "JD_PRIVATE_KEY_PEM"} {
		cases = append(cases, refusal{key + " as a value", "config." + key + " is refused", []string{"--set", "config." + key + "=sentinel"}})
	}
	// Every spelling strconv.ParseBool reads as true, and one it does not.
	for _, spelling := range []string{"true", "True", "t", "1", " true "} {
		cases = append(cases, refusal{fmt.Sprintf("MULTI_TENANT_ENABLED=%q with the migration Job", spelling), "MULTI_TENANT_ENABLED=true", []string{"--set-string", "config.MULTI_TENANT_ENABLED=" + spelling}})
	}
	if out, err := helmTemplate(t); err == nil || !strings.Contains(out, "config.ENVIRONMENT_NAME is required") {
		t.Errorf("the chart's own defaults must refuse for want of ENVIRONMENT_NAME: %s", oneLine(out))
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
		// Datastore and SOAP TLS in production are the service's boot checks, not the render's.
		{"--set", "config.ENVIRONMENT_NAME=production"},
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
	// A cluster install is never local, and telemetry names the environment the service runs as.
	if dig(cm[0], "data", "DEPLOYMENT_MODE") != "byoc" || dig(cm[0], "data", "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT") != dig(cm[0], "data", "ENVIRONMENT_NAME") {
		t.Errorf("DEPLOYMENT_MODE must default to byoc and the OTEL environment follow ENVIRONMENT_NAME: %v", dig(cm[0], "data"))
	}
	if ingresses := ofKind(docs, "Ingress"); len(ingresses) != 0 {
		t.Errorf("the default render carries %d Ingress(es), want none", len(ingresses))
	}
	if sas := ofKind(docs, "ServiceAccount"); len(sas) != 0 {
		t.Errorf("the default render carries %d ServiceAccount(s), want none", len(sas))
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
	// No literal tag: the release dispatch rewrites jd-courier.image.tag on every bump.
	if len(images) != 1 {
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
		if spec := dig(d, "spec", "template", "spec"); dig(spec, "serviceAccountName") != "default" || dig(spec, "automountServiceAccountToken") != false {
			t.Errorf("%s: must run as the namespace default with no API token, got %v %v", name, dig(spec, "serviceAccountName"), dig(spec, "automountServiceAccountToken"))
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
		if got := fmt.Sprint(container(d)["image"]); !strings.HasSuffix(got, ":9.9.9") {
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

	cm := ofKind(courierManifests(t, "--set", "config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT=prod-eu", "--set", "config.DEPLOYMENT_MODE=saas"), "ConfigMap")
	if len(cm) != 1 || dig(cm[0], "data", "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT") != "prod-eu" || dig(cm[0], "data", "DEPLOYMENT_MODE") != "saas" {
		t.Errorf("config must override the derived OTEL environment and DEPLOYMENT_MODE: %v", cm)
	}
}

// Each SOAP TLS shape reaches the spb-sender alone: the other roles serve no SOAP.
func TestCourierSOAPTLSShapes(t *testing.T) {
	docs := courierManifests(t,
		"--set", "roles.spbSender.ingress.enabled=true",
		"--set", "roles.spbSender.ingress.className=alb",
		"--set", "roles.spbSender.ingress.hosts[0].host=jd.example",
		"--set", "roles.spbSender.ingress.hosts[0].paths[0].path=/",
		"--set", "roles.spbSender.soapTls.existingSecret=soap-tls-cert")

	ingresses := ofKind(docs, "Ingress")
	if len(ingresses) != 1 {
		t.Fatalf("rendered %d Ingresses, want 1", len(ingresses))
	}
	rule := dig(ingresses[0], "spec", "rules").([]interface{})[0]
	backend := dig(rule, "http", "paths").([]interface{})[0]
	if dig(ingresses[0], "spec", "ingressClassName") != "alb" || dig(rule, "host") != "jd.example" ||
		dig(backend, "backend", "service", "name") != "t-br-jd-courier-spb-sender" || dig(backend, "backend", "service", "port", "name") != "soap" {
		t.Errorf("the Ingress must route its host to the spb-sender's SOAP port: %v", ingresses[0])
	}

	for _, d := range ofKind(docs, "Deployment") {
		name := nestedString(d, "metadata", "name")
		c := container(d)
		byName, _ := env(c)
		volumes, _ := dig(d, "spec", "template", "spec", "volumes").([]interface{})
		if name != "t-br-jd-courier-spb-sender" {
			if _, ok := byName["SOAP_TLS_TERMINATED_UPSTREAM"]; ok || len(volumes) != 0 || byName["SOAP_TLS_CERT_FILE"] != nil {
				t.Errorf("%s serves no SOAP and must carry no SOAP TLS", name)
			}
			continue
		}
		mounts, _ := c["volumeMounts"].([]interface{})
		if dig(byName["SOAP_TLS_TERMINATED_UPSTREAM"], "value") != "true" ||
			dig(byName["SOAP_TLS_CERT_FILE"], "value") != "/etc/jd-courier/soap-tls/tls.crt" ||
			dig(byName["SOAP_TLS_KEY_FILE"], "value") != "/etc/jd-courier/soap-tls/tls.key" ||
			len(volumes) != 1 || dig(volumes[0], "secret", "secretName") != "soap-tls-cert" ||
			len(mounts) != 1 || dig(mounts[0], "mountPath") != "/etc/jd-courier/soap-tls" || dig(mounts[0], "readOnly") != true ||
			dig(c, "securityContext", "readOnlyRootFilesystem") != true {
			t.Errorf("%s: the Ingress and the mounted certificate must both reach the SOAP listener, read-only: %v %v", name, byName, volumes)
		}
	}

	for _, d := range ofKind(courierManifests(t, "--set", "roles.spbSender.soapTls.terminatedUpstream=true"), "Deployment") {
		byName, _ := env(container(d))
		_, upstream := byName["SOAP_TLS_TERMINATED_UPSTREAM"]
		if upstream != (nestedString(d, "metadata", "name") == "t-br-jd-courier-spb-sender") || byName["SOAP_TLS_CERT_FILE"] != nil {
			t.Errorf("%s: soapTls.terminatedUpstream must reach the spb-sender alone, with no certificate", nestedString(d, "metadata", "name"))
		}
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

// Every role runs as the one ServiceAccount the AWS identity hangs on, with no Kubernetes API token.
func TestCourierServiceAccount(t *testing.T) {
	for _, c := range []struct {
		args       []string
		want       string
		rendersOne bool
	}{
		{[]string{"--set", "serviceAccount.create=true", "--set", "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=arn:aws:iam::1:role/courier"}, "t-br-jd-courier", true},
		{[]string{"--set", "serviceAccount.create=true", "--set", "serviceAccount.name=courier"}, "courier", true},
		{[]string{"--set", "serviceAccount.name=existing"}, "existing", false},
	} {
		docs := courierManifests(t, c.args...)
		sas := ofKind(docs, "ServiceAccount")
		if c.rendersOne != (len(sas) == 1) || (c.rendersOne && nestedString(sas[0], "metadata", "name") != c.want) {
			t.Errorf("%v: rendered ServiceAccounts %v, want %q rendered=%v", c.args, sas, c.want, c.rendersOne)
		}
		if len(sas) == 1 && c.want == "t-br-jd-courier" && dig(sas[0], "metadata", "annotations", "eks.amazonaws.com/role-arn") != "arn:aws:iam::1:role/courier" {
			t.Errorf("%v: the IRSA annotation must reach the ServiceAccount: %v", c.args, sas[0])
		}
		for _, d := range ofKind(docs, "Deployment") {
			spec := dig(d, "spec", "template", "spec")
			if dig(spec, "serviceAccountName") != c.want || dig(spec, "automountServiceAccountToken") != false {
				t.Errorf("%v: %s runs as %v (automount %v), want %q with no API token", c.args, nestedString(d, "metadata", "name"), dig(spec, "serviceAccountName"), dig(spec, "automountServiceAccountToken"), c.want)
			}
		}
	}
}

// The Pix transit reaches the admin alone, on ports.pixTransit, with the TLS shape it was given.
func TestCourierPixTransit(t *testing.T) {
	for _, shape := range []struct {
		arg            string
		cert, upstream bool
	}{
		{"roles.admin.pixTransit.tls.existingSecret=pix-transit-cert", true, false},
		{"roles.admin.pixTransit.tls.terminatedUpstream=true", false, true},
	} {
		docs := courierManifests(t, "--set", "roles.admin.pixTransit.enabled=true", "--set", "ports.pixTransit=9443", "--set", shape.arg)
		for _, s := range ofKind(docs, "Service") {
			ports, _ := dig(s, "spec", "ports").([]interface{})
			admin := nestedString(s, "metadata", "name") == "t-br-jd-courier-admin"
			exposed := len(ports) == 2 && dig(ports[1], "name") == "pix-transit" && dig(ports[1], "port") == 9443 && dig(ports[1], "targetPort") == "pix-transit"
			if exposed != admin {
				t.Errorf("%s: %s exposes %v; only the admin Service carries the transit port", shape.arg, nestedString(s, "metadata", "name"), ports)
			}
		}
		for _, d := range ofKind(docs, "Deployment") {
			name := nestedString(d, "metadata", "name")
			c := container(d)
			byName, _ := env(c)
			ports, _ := c["ports"].([]interface{})
			volumes, _ := dig(d, "spec", "template", "spec", "volumes").([]interface{})
			if name != "t-br-jd-courier-admin" {
				if byName["PIX_TRANSIT_SERVER_ADDRESS"] != nil || len(volumes) != 0 {
					t.Errorf("%s: %s serves no transit and must carry none", shape.arg, name)
				}
				continue
			}
			_, upstream := byName["PIX_TRANSIT_TLS_TERMINATED_UPSTREAM"]
			cert := dig(byName["PIX_TRANSIT_TLS_CERT_FILE"], "value") == "/etc/jd-courier/pix-transit-tls/tls.crt" &&
				dig(byName["PIX_TRANSIT_TLS_KEY_FILE"], "value") == "/etc/jd-courier/pix-transit-tls/tls.key" &&
				len(volumes) == 1 && dig(volumes[0], "secret", "secretName") == "pix-transit-cert"
			if dig(byName["PIX_TRANSIT_SERVER_ADDRESS"], "value") != ":9443" || len(ports) != 2 ||
				dig(ports[1], "name") != "pix-transit" || dig(ports[1], "containerPort") != 9443 ||
				cert != shape.cert || upstream != shape.upstream || (!shape.cert && len(volumes) != 0) {
				t.Errorf("%s: the admin must listen on ports.pixTransit with exactly this TLS shape: %v %v %v", shape.arg, byName, ports, volumes)
			}
		}
	}
}
