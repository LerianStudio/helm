package main

import (
	"fmt"
	"strings"
	"testing"
)

// The health port (8099: /readyz, /metrics, probes) is internal only: the one
// way to reach it is a ClusterIP Service port named health, and no Ingress path
// may route to a readyz or metrics segment.
func TestHealthPortExposureMessage(t *testing.T) {
	const svc = `---
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
%s
  ports:
    - name: %s
      port: %s
      targetPort: %s
`
	const ing = `---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
spec:
  rules:
    - http:
        paths:
          - path: %s
            pathType: Prefix
            backend:
              service:
                name: app
                port:
                  %s
`
	service := func(typ, name, port, target string) string {
		if typ != "" {
			typ = "  type: " + typ
		}
		return fmt.Sprintf(svc, typ, name, port, target)
	}
	ingress := func(path, backend string) string { return fmt.Sprintf(ing, path, backend) }

	cases := []struct {
		name     string
		rendered string
		wantHit  bool
		want     string
	}{
		{"ClusterIP health port", service("ClusterIP", "health", "8099", "8099"), false, ""},
		{"untyped Service health port", service("", "health", "8099", "health"), false, ""},
		{"Ingress to the http port", ingress("/", "name: http"), false, ""},
		{"near-miss path", ingress("/readyzz", "number: 80"), false, ""},
		{"NodePort health port", service("NodePort", "health", "8099", "8099"), true, "Service/app (NodePort)"},
		{"LoadBalancer health port", service("LoadBalancer", "health", "8099", "8099"), true, "Service/app (LoadBalancer)"},
		{"http port targeting 8099", service("ClusterIP", "http", "80", "8099"), true, "Service/app"},
		{"http port targeting health", service("ClusterIP", "http", "80", "health"), true, "Service/app"},
		{"Ingress backend number 8099", ingress("/", "number: 8099"), true, "Ingress/app backend app:8099"},
		{"Ingress backend named health", ingress("/", "name: health"), true, "Ingress/app backend app:health"},
		{"Ingress /readyz", ingress("/readyz", "number: 80"), true, "Ingress/app path /readyz"},
		{"Ingress tenant readyz", ingress("/spi/readyz/tenant/x", "number: 80"), true, "Ingress/app path /spi/readyz/tenant/x"},
		{"Ingress /metrics", ingress("/metrics", "number: 80"), true, "Ingress/app path /metrics"},
	}
	for _, c := range cases {
		got := healthPortExposureMessage(c.rendered)
		if (got != "") != c.wantHit {
			t.Errorf("%s: healthPortExposureMessage = %q, want hit=%v", c.name, got, c.wantHit)
		}
		if c.wantHit && !strings.Contains(got, c.want) {
			t.Errorf("%s: message must contain %q, got %q", c.name, c.want, got)
		}
	}
}
