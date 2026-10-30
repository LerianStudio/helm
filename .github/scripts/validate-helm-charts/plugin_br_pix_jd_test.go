package main

import (
	"encoding/base64"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// The plugin-br-pix-jd payment-order signing contract. Signing is optional, as in
// the app: with neither PEM the chart renders no signing key and the app sends
// unsigned orders; with both it renders both; with exactly one the render refuses,
// since the app would refuse every order. With MULTI_TENANT_ENABLED=true the app
// does not read the three variables and the chart must render none of them.

const pixJDFixture = "../../configs/helm-render-values/plugin-br-pix-jd.yaml"

const (
	pixJDKeyPEM  = "-----BEGIN PRIVATE KEY-----\nci-only-not-a-real-key\n-----END PRIVATE KEY-----\n"
	pixJDCertPEM = "-----BEGIN CERTIFICATE-----\nci-only-not-a-real-certificate\n-----END CERTIFICATE-----\n"
)

// pixJDMultiTenant is the smallest set of values the chart's multi-tenant gates
// accept.
var pixJDMultiTenant = []string{
	"--set", "api.configmap.MULTI_TENANT_ENABLED=true",
	"--set", "api.configmap.MULTI_TENANT_URL=http://tenant-manager:8080",
	"--set", "api.configmap.MULTI_TENANT_REDIS_HOST=valkey:6379",
	"--set", "api.configmap.AWS_REGION=us-east-1",
	"--set", "api.configmap.M2M_LEDGER_TARGET_SERVICE=ledger",
	"--set", "api.configmap.M2M_CRM_TARGET_SERVICE=plugin-crm",
	"--set", "api.secrets.MULTI_TENANT_SERVICE_API_KEY=ci-only",
}

// pixJDSetFile passes a multi-line value the way the README tells operators to:
// --set-file, which --set cannot do.
func pixJDSetFile(t *testing.T, key, content string) []string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "value.pem")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return []string{"--set-file", "api.secrets." + key + "=" + path}
}

func pixJDKey(t *testing.T) []string {
	return pixJDSetFile(t, "JD_PAYMENT_SIGNING_PRIVATE_KEY", pixJDKeyPEM)
}
func pixJDCert(t *testing.T) []string {
	return pixJDSetFile(t, "JD_PAYMENT_SIGNING_CERTIFICATE", pixJDCertPEM)
}

func renderPixJD(t *testing.T, args ...string) (string, error) {
	t.Helper()
	chart := preparedChart(t, "plugin-br-pix-jd")
	full := append([]string{"template", "t", chart, "-f", pixJDFixture}, args...)
	out, err := exec.Command("helm", full...).CombinedOutput()
	return string(out), err
}

func pixJDAPISecretData(t *testing.T, args ...string) map[string]string {
	t.Helper()
	out, err := renderPixJD(t, args...)
	if err != nil {
		t.Fatalf("render %v failed: %s", args, oneLine(out))
	}
	docs, err := decodeManifests(out)
	if err != nil {
		t.Fatalf("decoding the render %v: %v", args, err)
	}
	for _, doc := range docs {
		if doc["kind"] != "Secret" || dig(doc, "metadata", "name") != "plugin-br-pix-jd-api" {
			continue
		}
		data := map[string]string{}
		raw, _ := doc["data"].(map[string]interface{})
		for key, value := range raw {
			decoded, err := base64.StdEncoding.DecodeString(value.(string))
			if err != nil {
				t.Fatalf("api Secret key %s is not base64: %v", key, err)
			}
			data[key] = string(decoded)
		}
		return data
	}
	t.Fatalf("render %v has no api Secret", args)
	return nil
}

func TestPixJDSingleTenantRendersWithoutSigning(t *testing.T) {
	// Signing is opt-in: a JD that does not enforce HashAtivo takes unsigned orders,
	// and an install that never set the PEMs must keep rendering as before.
	out, err := renderPixJD(t)
	if err != nil {
		t.Fatalf("render without signing values refused, want a render: %s", oneLine(out))
	}
	if strings.Contains(out, "JD_PAYMENT_SIGNING") {
		t.Errorf("render without signing values emitted a JD_PAYMENT_SIGNING key")
	}
}

func TestPixJDSingleTenantCarriesTheSigningPEMs(t *testing.T) {
	data := pixJDAPISecretData(t, append(pixJDKey(t), pixJDCert(t)...)...)
	for key, want := range map[string]string{
		"JD_PAYMENT_SIGNING_PRIVATE_KEY": pixJDKeyPEM,
		"JD_PAYMENT_SIGNING_CERTIFICATE": pixJDCertPEM,
	} {
		if got := data[key]; got != want {
			t.Errorf("api Secret %s = %q, want the multi-line PEM %q", key, got, want)
		}
	}

	// An argocd-vault-plugin placeholder is substituted after helm runs, so it has
	// to cross the render byte for byte.
	placeholder := "<path:secret/data/benedita/plugin-br-pix-jd/dev-st#JD_PAYMENT_SIGNING_PRIVATE_KEY>"
	data = pixJDAPISecretData(t, append(pixJDCert(t), "--set-string", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY="+placeholder)...)
	if got := data["JD_PAYMENT_SIGNING_PRIVATE_KEY"]; got != placeholder {
		t.Errorf("AVP placeholder rendered as %q, want %q", got, placeholder)
	}
}

func TestPixJDSingleTenantRefusesUnusableSigning(t *testing.T) {
	cases := []struct {
		name, want string
		args       []string
	}{
		{"a certificate with no private key", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY is missing", pixJDCert(t)},
		{"a private key with no certificate", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE is missing", pixJDKey(t)},
		{"a private key that is not PEM", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY must be PEM", append(pixJDCert(t), "--set", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=raw-bytes")},
		{"a certificate that is not PEM", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE must be PEM", append(pixJDKey(t), "--set", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=raw-bytes")},
		{"an algorithm the app does not sign with", "api.configmap.JD_PAYMENT_SIGNING_ALGORITHM must be one of", []string{"--set", "api.configmap.JD_PAYMENT_SIGNING_ALGORITHM=Ed25519"}},
	}
	for _, c := range cases {
		out, err := renderPixJD(t, c.args...)
		if err == nil {
			t.Errorf("%s: rendered, want a refusal", c.name)
		} else if !strings.Contains(out, c.want) {
			t.Errorf("%s: refused without naming %q: %s", c.name, c.want, oneLine(out))
		} else if strings.Contains(strings.ToLower(out), "tenant") {
			t.Errorf("%s: refusal speaks of tenancy, which the operator never configures: %s", c.name, oneLine(out))
		}
	}
	for _, half := range [][]string{pixJDCert(t), pixJDKey(t)} {
		if out, _ := renderPixJD(t, half...); !strings.Contains(out, "set both or neither") {
			t.Errorf("a lone signing value %v: refusal does not say to set both or neither: %s", half, oneLine(out))
		}
	}

	// The operator's Secret carries the PEMs, so the chart renders no Secret and
	// has nothing to check, even with a lone inline value.
	if out, err := renderPixJD(t, append(pixJDKey(t), "--set", "api.existingSecret.name=operator-secret")...); err != nil {
		t.Errorf("existingSecret with a lone inline PEM: refused, want a render: %s", oneLine(out))
	}
}

func TestPixJDSingleTenantAlgorithmReachesTheConfigMap(t *testing.T) {
	out, err := renderPixJD(t, "--set", "api.configmap.JD_PAYMENT_SIGNING_ALGORITHM=RSA_PKCS1_SHA256")
	if err != nil {
		t.Fatalf("render failed: %s", oneLine(out))
	}
	if !strings.Contains(out, `JD_PAYMENT_SIGNING_ALGORITHM: "RSA_PKCS1_SHA256"`) {
		t.Errorf("a set algorithm did not reach the ConfigMap")
	}
	// Blank leaves the default to the app: emitting one here would be a second owner.
	if out, err := renderPixJD(t, append(pixJDKey(t), pixJDCert(t)...)...); err != nil || strings.Contains(out, "JD_PAYMENT_SIGNING_ALGORITHM") {
		t.Errorf("an unset algorithm was emitted (err=%v)", err)
	}
}

func TestPixJDMultiTenantRendersNoSigning(t *testing.T) {
	// A wrong algorithm and a lone, non-PEM key prove the keys are not merely empty
	// but never rendered: with MULTI_TENANT_ENABLED=true the app does not read them.
	for _, extra := range [][]string{
		nil,
		{"--set", "api.configmap.JD_PAYMENT_SIGNING_ALGORITHM=Ed25519"},
		{"--set", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=raw-bytes"},
	} {
		out, err := renderPixJD(t, append(append([]string{}, pixJDMultiTenant...), extra...)...)
		if err != nil {
			t.Errorf("multi-tenant %v: refused, want a render: %s", extra, oneLine(out))
			continue
		}
		if strings.Contains(out, "JD_PAYMENT_SIGNING") {
			t.Errorf("multi-tenant %v rendered a JD_PAYMENT_SIGNING key", extra)
		}
	}
}
