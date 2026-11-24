package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// A ConfigMap key on allowlistedConfigMapKeys passes for its own chart only; the same
// key in another chart, and a real credential in the allowlisted chart, still fail.
func TestScanConfigMapTemplatesAllowlistIsPerChartAndPerKey(t *testing.T) {
	configMap := "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: probe\ndata:\n" +
		"  ANTIFRAUD_SECRETS_BACKEND: {{ .Values.backend | quote }}\n" +
		"  CLIENT_SECRET: {{ .Values.clientSecret | quote }}\n"

	cases := map[string][]string{
		"plugin-br-bank-transfer":    {"CLIENT_SECRET"},
		"plugin-br-pix-lerian":       {"CLIENT_SECRET"},
		"plugin-br-pix-indirect-btg": {"CLIENT_SECRET"},
		"plugin-br-ted-lerian":       {"CLIENT_SECRET"},
		"plugin-br-pix-jd":           {"ANTIFRAUD_SECRETS_BACKEND", "CLIENT_SECRET"},
	}
	for chartName, want := range cases {
		chartDir := filepath.Join(t.TempDir(), chartName)
		if err := os.MkdirAll(filepath.Join(chartDir, "templates"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(chartDir, "templates", "configmap.yaml"), []byte(configMap), 0o600); err != nil {
			t.Fatal(err)
		}

		flagged := map[string]bool{}
		for _, v := range scanConfigMapTemplates(chartDir, chartDir, chartName) {
			flagged[v.Path[strings.LastIndex(v.Path, ":")+1:]] = true
		}
		if len(flagged) != len(want) {
			t.Errorf("%s: flagged %v, want %v", chartName, flagged, want)
		}
		for _, key := range want {
			if !flagged[key] {
				t.Errorf("%s: %s not flagged", chartName, key)
			}
		}
	}
}
