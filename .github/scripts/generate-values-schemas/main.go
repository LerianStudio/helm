// Command generate-values-schemas produces a real per-chart values.schema.json
// for every chart under charts/*.
//
// Policy (see the helm-chart-standardization-revamp branch finding M1):
//   - Root schema is a closed object: additionalProperties:false, so operator
//     typos at the top level fail Helm's schema validation at render time.
//   - properties are the chart's ACTUAL top-level keys (parsed from values.yaml),
//     plus "global" which Helm always injects.
//   - Third-party subchart blocks (Chart.yaml dependency names/aliases, plus a
//     known set such as postgresql/mongodb/valkey/rabbitmq/auth-database/
//     otel-collector-lerian) are type:object, additionalProperties:true: their
//     surface belongs to the dependency, so we do not constrain it.
//   - App component / app config blocks are type:object, additionalProperties:true
//     at the nested level (we do not over-constrain nested structure), but we
//     declare "secrets"/"configmap" sub-keys as objects when present.
//   - Top-level scalars are type-checked (string/boolean/integer/number) against
//     the values.yaml default.
//   - required lists the top-level keys that exist in values.yaml. Helm validates
//     COALESCED values, so defaults always satisfy this; it guards against a chart
//     accidentally dropping a block.
//
// Usage (run from .github/scripts):
//
//	go run ./generate-values-schemas/ --root ../..
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// knownSubcharts are third-party chart names whose value surface belongs to the
// dependency, not to us. We treat any top-level block matching one of these as
// opaque (additionalProperties:true, no nested constraints) even when the block
// is present in values.yaml without a matching Chart.yaml dependency (e.g. a
// dead or transitively-resolved block).
var knownSubcharts = map[string]bool{
	"keda":                    true,
	"mongodb":                 true,
	"opentelemetry-collector": true,
	"otel-collector-lerian":   true,
	"postgresql":              true,
	"rabbitmq":                true,
	"seaweedfs":               true,
	"valkey":                  true,
	"grafana":                 true,
	"auth-database":           true, // common alias for a postgresql dependency
}

// orderedObject marshals to a JSON object while preserving insertion order, so
// generated schemas keep the same key order as the source values.yaml and
// produce clean, stable diffs.
type orderedObject struct {
	keys   []string
	values map[string]interface{}
}

func newObject() *orderedObject {
	return &orderedObject{values: map[string]interface{}{}}
}

func (o *orderedObject) set(key string, value interface{}) *orderedObject {
	if _, exists := o.values[key]; !exists {
		o.keys = append(o.keys, key)
	}
	o.values[key] = value
	return o
}

func (o *orderedObject) MarshalJSON() ([]byte, error) {
	var b strings.Builder
	b.WriteByte('{')
	for i, k := range o.keys {
		if i > 0 {
			b.WriteByte(',')
		}
		keyJSON, err := json.Marshal(k)
		if err != nil {
			return nil, err
		}
		b.Write(keyJSON)
		b.WriteByte(':')
		valJSON, err := json.Marshal(o.values[k])
		if err != nil {
			return nil, err
		}
		b.Write(valJSON)
	}
	b.WriteByte('}')
	return []byte(b.String()), nil
}

func main() {
	root := flag.String("root", ".", "Repository root containing the charts/ directory")
	flag.Parse()

	chartsDir := filepath.Join(*root, "charts")
	entries, err := os.ReadDir(chartsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: cannot read %s: %v\n", chartsDir, err)
		os.Exit(1)
	}

	generated := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		chartPath := filepath.Join(chartsDir, entry.Name())
		if err := generateChartSchema(chartPath); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: %s: %v\n", entry.Name(), err)
			os.Exit(1)
		}
		generated++
		fmt.Printf("generated %s/values.schema.json\n", chartPath)
	}
	fmt.Printf("done: %d chart schemas generated\n", generated)
}

// generateChartSchema reads a chart's values.yaml and Chart.yaml and writes its
// values.schema.json. Charts without a values.yaml are skipped silently.
func generateChartSchema(chartPath string) error {
	valuesPath := filepath.Join(chartPath, "values.yaml")
	valuesBytes, err := os.ReadFile(valuesPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("read values.yaml: %w", err)
	}

	// Decode into a yaml.Node mapping so top-level key order is preserved.
	var doc yaml.Node
	if err := yaml.Unmarshal(valuesBytes, &doc); err != nil {
		return fmt.Errorf("parse values.yaml: %w", err)
	}
	topKeys, topValues := topLevel(&doc)

	subcharts, err := dependencyKeys(chartPath)
	if err != nil {
		return fmt.Errorf("parse Chart.yaml: %w", err)
	}

	schema := buildSchema(topKeys, topValues, subcharts)

	out, err := json.MarshalIndent(schema, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal schema: %w", err)
	}
	out = append(out, '\n')

	schemaPath := filepath.Join(chartPath, "values.schema.json")
	if err := os.WriteFile(schemaPath, out, 0o644); err != nil {
		return fmt.Errorf("write values.schema.json: %w", err)
	}
	return nil
}

// topLevel returns the ordered top-level keys and their value nodes from a
// decoded values.yaml document. Returns empty slices for an empty document.
func topLevel(doc *yaml.Node) ([]string, map[string]*yaml.Node) {
	keys := []string{}
	values := map[string]*yaml.Node{}
	if doc.Kind != yaml.DocumentNode || len(doc.Content) == 0 {
		return keys, values
	}
	root := doc.Content[0]
	if root.Kind != yaml.MappingNode {
		return keys, values
	}
	for i := 0; i+1 < len(root.Content); i += 2 {
		key := root.Content[i].Value
		keys = append(keys, key)
		values[key] = root.Content[i+1]
	}
	return keys, values
}

// dependencyKeys returns the set of values.yaml block names that map to a
// Chart.yaml dependency: the dependency alias when set, otherwise its name.
func dependencyKeys(chartPath string) (map[string]bool, error) {
	chartBytes, err := os.ReadFile(filepath.Join(chartPath, "Chart.yaml"))
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]bool{}, nil
		}
		return nil, err
	}
	var chart struct {
		Dependencies []struct {
			Name  string `yaml:"name"`
			Alias string `yaml:"alias"`
		} `yaml:"dependencies"`
	}
	if err := yaml.Unmarshal(chartBytes, &chart); err != nil {
		return nil, err
	}
	keys := map[string]bool{}
	for _, dep := range chart.Dependencies {
		if dep.Alias != "" {
			keys[dep.Alias] = true
		} else if dep.Name != "" {
			keys[dep.Name] = true
		}
	}
	return keys, nil
}

// buildSchema assembles the JSON Schema (draft-07) for a chart from its ordered
// top-level keys, their value nodes, and the set of dependency block names.
func buildSchema(topKeys []string, topValues map[string]*yaml.Node, subcharts map[string]bool) *orderedObject {
	properties := newObject()
	required := []string{}

	for _, key := range topKeys {
		properties.set(key, propertySchema(key, topValues[key], subcharts))
		required = append(required, key)
	}

	// Helm always injects "global"; declare it as an open object. Only add it to
	// required when the chart actually ships a global block (see required policy).
	if _, hasGlobal := topValues["global"]; !hasGlobal {
		properties.set("global", openObject())
	}

	sort.Strings(required)

	schema := newObject()
	schema.set("$schema", "https://json-schema.org/draft-07/schema#")
	schema.set("type", "object")
	schema.set("additionalProperties", false)
	schema.set("properties", properties)
	if len(required) > 0 {
		schema.set("required", required)
	}
	return schema
}

// propertySchema returns the schema fragment for a single top-level key.
func propertySchema(key string, node *yaml.Node, subcharts map[string]bool) *orderedObject {
	// "global" is Helm-injected and varies widely; keep it open.
	if key == "global" {
		return openObject()
	}

	switch node.Kind {
	case yaml.ScalarNode:
		return scalarSchema(node)
	case yaml.SequenceNode:
		return newObject().set("type", "array")
	case yaml.MappingNode:
		// Third-party subchart block: surface belongs to the dependency.
		if subcharts[key] || knownSubcharts[key] {
			return openObject()
		}
		return componentSchema(node)
	default:
		// Null or unknown (e.g. empty value): leave open rather than guess.
		return newObject().set("type", "object")
	}
}

// scalarSchema type-checks a scalar against its values.yaml default. YAML tags
// give us the inferred type without re-implementing scalar parsing.
func scalarSchema(node *yaml.Node) *orderedObject {
	switch node.Tag {
	case "!!bool":
		return newObject().set("type", "boolean")
	case "!!int":
		return newObject().set("type", "integer")
	case "!!float":
		return newObject().set("type", "number")
	case "!!null":
		// A null default (e.g. "key:") could later hold any type; keep it open.
		return newObject()
	default:
		// !!str and quoted scalars.
		return newObject().set("type", "string")
	}
}

// componentSchema describes an app component / app config block: an open object
// (we do not over-constrain nested structure), but with "secrets"/"configmap"
// sub-keys declared as objects when the block defines them.
func componentSchema(node *yaml.Node) *orderedObject {
	schema := newObject().set("type", "object")

	subProps := newObject()
	for i := 0; i+1 < len(node.Content); i += 2 {
		subKey := node.Content[i].Value
		if subKey == "secrets" || subKey == "configmap" {
			subProps.set(subKey, newObject().set("type", "object"))
		}
	}
	if len(subProps.keys) > 0 {
		schema.set("properties", subProps)
	}
	schema.set("additionalProperties", true)
	return schema
}

// openObject is type:object with additionalProperties:true.
func openObject() *orderedObject {
	return newObject().
		set("type", "object").
		set("additionalProperties", true)
}
