package main

import (
	"bytes"
	"encoding/json"
)

// CompatDoc is the root of docs/compatibility.json (data-model §B.1).
type CompatDoc struct {
	SchemaVersion int                `json:"schemaVersion"`
	GeneratedFrom string             `json:"generatedFrom"`
	Products      map[string]Product `json:"products"`
}

// Product is one chart's projection (data-model §B.2).
//
// AppVersion is the Chart.yaml appVersion, carried in-memory as informational
// context; it is intentionally NOT serialized (json:"-"). Note the README N-row
// app-version cells are resolved from values.yaml {component}.image.tag (shared
// tableutil logic, multi-column), NOT from this single field.
type Product struct {
	Dir        string  `json:"dir"`
	Current    string  `json:"current"`
	AppVersion string  `json:"-"`
	Cycles     []Cycle `json:"cycles,omitempty"`
}

// Cycle is one minor-cycle line (data-model §B.3). There is no tier field:
// the badge/tier is presentation, derived at render time, never persisted.
// Released is the ISO (YYYY-MM-DD) date of the cycle's latest tag; it is an
// additive optional field (schemaVersion stays 1) and is omitted when unknown.
type Cycle struct {
	Cycle      string            `json:"cycle"`
	Latest     string            `json:"latest"`
	Released   string            `json:"released,omitempty"`
	Supported  bool              `json:"supported"`
	Requires   map[string]string `json:"requires,omitempty"`
	TestedWith map[string]string `json:"testedWith,omitempty"`
}

// renderJSON marshals the document deterministically (Go's encoding/json sorts
// map keys) with two-space indent and a trailing newline, matching the sibling
// generate-values-schemas output style.
func renderJSON(doc CompatDoc) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	if err := enc.Encode(doc); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
