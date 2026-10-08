package main

import (
	"encoding/base64"
	"os/exec"
	"strings"
	"testing"
)

// The plugin-br-pix-jd payment-order signing contract. JD rejects an unsigned
// payment order, so in single-tenant the two PEMs are a render gate; in
// multi-tenant the app reads them from the tenant's secret bundle and the chart
// must render none of the three keys.

const pixJDFixture = "../../configs/helm-render-values/plugin-br-pix-jd.yaml"

// pixJDMultiTenant is the smallest set of values the chart's multi-tenant gates
// accept, with both PEMs cleared.
var pixJDMultiTenant = []string{
	"--set", "api.configmap.MULTI_TENANT_ENABLED=true",
	"--set", "api.configmap.MULTI_TENANT_URL=http://tenant-manager:8080",
	"--set", "api.configmap.MULTI_TENANT_REDIS_HOST=valkey:6379",
	"--set", "api.configmap.AWS_REGION=us-east-1",
	"--set", "api.configmap.M2M_LEDGER_TARGET_SERVICE=ledger",
	"--set", "api.configmap.M2M_CRM_TARGET_SERVICE=plugin-crm",
	"--set", "api.secrets.MULTI_TENANT_SERVICE_API_KEY=ci-only",
	"--set", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=",
	"--set", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=",
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

func TestPixJDSingleTenantCarriesTheSigningPEMs(t *testing.T) {
	data := pixJDAPISecretData(t)
	for key, header := range map[string]string{
		"JD_PAYMENT_SIGNING_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----",
		"JD_PAYMENT_SIGNING_CERTIFICATE": "-----BEGIN CERTIFICATE-----",
	} {
		value := data[key]
		if !strings.HasPrefix(value, header) || strings.Count(value, "\n") < 2 {
			t.Errorf("api Secret %s = %q, want the fixture's multi-line PEM starting %q", key, value, header)
		}
	}

	// An argocd-vault-plugin placeholder is substituted after helm runs, so it has
	// to cross the render byte for byte.
	placeholder := "<path:secret/data/benedita/plugin-br-pix-jd/dev-st#JD_PAYMENT_SIGNING_PRIVATE_KEY>"
	data = pixJDAPISecretData(t, "--set-string", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY="+placeholder)
	if got := data["JD_PAYMENT_SIGNING_PRIVATE_KEY"]; got != placeholder {
		t.Errorf("AVP placeholder rendered as %q, want %q", got, placeholder)
	}
}

func TestPixJDSingleTenantRefusesWithoutUsableSigning(t *testing.T) {
	cases := []struct {
		name, want string
		args       []string
	}{
		{"no private key", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY is required in single-tenant", []string{"--set", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY="}},
		{"no certificate", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE is required in single-tenant", []string{"--set", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE="}},
		{"a private key that is not PEM", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY must be PEM", []string{"--set", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=raw-bytes"}},
		{"a certificate that is not PEM", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE must be PEM", []string{"--set", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=raw-bytes"}},
		{"an algorithm the app does not sign with", "api.configmap.JD_PAYMENT_SIGNING_ALGORITHM must be one of", []string{"--set", "api.configmap.JD_PAYMENT_SIGNING_ALGORITHM=Ed25519"}},
	}
	for _, c := range cases {
		out, err := renderPixJD(t, c.args...)
		if err == nil {
			t.Errorf("%s: rendered, want a refusal", c.name)
		} else if !strings.Contains(out, c.want) {
			t.Errorf("%s: refused without naming %q: %s", c.name, c.want, oneLine(out))
		}
	}

	// The operator's Secret carries the PEMs, so the chart has nothing to check.
	if out, err := renderPixJD(t, "--set", "api.existingSecret.name=operator-secret",
		"--set", "api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=", "--set", "api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE="); err != nil {
		t.Errorf("existingSecret without inline PEMs: refused, want a render: %s", oneLine(out))
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
	if out, err := renderPixJD(t); err != nil || strings.Contains(out, "JD_PAYMENT_SIGNING_ALGORITHM") {
		t.Errorf("an unset algorithm was emitted (err=%v)", err)
	}
}

func TestPixJDMultiTenantRendersNoSigning(t *testing.T) {
	// A wrong algorithm and a set key prove the keys are not merely empty but
	// never rendered: the multi-tenant app ignores them.
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
