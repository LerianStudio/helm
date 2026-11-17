package main

import (
	"fmt"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

var healthPathRe = regexp.MustCompile(`(^|/)(readyz|metrics)(/|$)`)

// healthPortExposureMessage lists rendered resources that expose the internal
// health port (8099: /readyz, /metrics). The only way to reach it is a ClusterIP
// Service port named health; no Ingress backend may target it and no Ingress
// path may carry a readyz or metrics segment.
func healthPortExposureMessage(rendered string) string {
	type backendPort struct {
		Name   string `yaml:"name"`
		Number int    `yaml:"number"`
	}
	type resource struct {
		Kind     string `yaml:"kind"`
		Metadata struct {
			Name string `yaml:"name"`
		} `yaml:"metadata"`
		Spec struct {
			Type  string `yaml:"type"`
			Ports []struct {
				Name       string `yaml:"name"`
				Port       int    `yaml:"port"`
				TargetPort string `yaml:"targetPort"`
			} `yaml:"ports"`
			Rules []struct {
				HTTP struct {
					Paths []struct {
						Path    string `yaml:"path"`
						Backend struct {
							Service struct {
								Name string      `yaml:"name"`
								Port backendPort `yaml:"port"`
							} `yaml:"service"`
						} `yaml:"backend"`
					} `yaml:"paths"`
				} `yaml:"http"`
			} `yaml:"rules"`
		} `yaml:"spec"`
	}

	var hits []string
	dec := yaml.NewDecoder(strings.NewReader(stripNonManifest(rendered)))
	for {
		var doc yaml.Node
		if err := dec.Decode(&doc); err != nil {
			break
		}
		var r resource
		if err := doc.Decode(&r); err != nil {
			continue
		}
		id := r.Kind + "/" + r.Metadata.Name
		for _, p := range r.Spec.Ports {
			reaches := p.Port == 8099 || p.TargetPort == "8099" || p.TargetPort == "health" || p.Name == "health"
			if r.Kind == "Service" && reaches && !((r.Spec.Type == "" || r.Spec.Type == "ClusterIP") && p.Name == "health") {
				hits = append(hits, fmt.Sprintf("%s (%s) port %s:%d", id, r.Spec.Type, p.Name, p.Port))
			}
		}
		for _, rule := range r.Spec.Rules {
			for _, p := range rule.HTTP.Paths {
				svc := p.Backend.Service
				if svc.Port.Number == 8099 || svc.Port.Name == "health" {
					hits = append(hits, fmt.Sprintf("%s backend %s:%s", id, svc.Name, cmpPort(svc.Port.Name, svc.Port.Number)))
				}
				if healthPathRe.MatchString(p.Path) {
					hits = append(hits, fmt.Sprintf("%s path %s", id, p.Path))
				}
			}
		}
	}
	if len(hits) == 0 {
		return ""
	}
	sort.Strings(hits)
	return "health port exposed outside a ClusterIP Service port named health: " + strings.Join(hits, ", ")
}

func cmpPort(name string, number int) string {
	if name != "" {
		return name
	}
	return fmt.Sprint(number)
}
