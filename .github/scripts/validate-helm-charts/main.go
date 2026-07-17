package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const chartTypeAnnotation = "lerian.studio/chart-type"

var allowedChartTypes = map[string]bool{
	"single-service":     true,
	"multi-component":    true,
	"dependency-wrapper": true,
	"library":            true,
}

var credentialURLPattern = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*://[^\s/@]+:[^\s/@]+@`)

// templateDefaultPattern captures Helm pipelines of the form
//
//	KEY: {{ .Values.<...>.SOME_KEY | default "literal" ... }}
//
// so the validator can flag non-empty secret defaults that live in templates
// (not values.yaml). Group 1 is the YAML/template key, group 2 is the quoted
// default literal.
//
// Limitation: the `[^}]*` segments cannot span a literal `}` (e.g. a default
// containing a brace, or a pipeline that crosses the closing `}}` onto another
// line). Such forms are not matched and would slip past this check; they are
// rare in practice, so the simple single-line pattern is kept deliberately.
var templateDefaultPattern = regexp.MustCompile(`(?m)^\s*([A-Za-z0-9_.-]+)\s*:\s*\{\{[^}]*\|\s*default\s+"([^"]*)"[^}]*\}\}`)

// dualSecretRequiredPattern matches a Secret data line whose value is gated by a
// Helm `required` on an infra-internal password key, e.g.
//
//	POSTGRES_PASSWORD: {{ required "app.secrets.POSTGRES_PASSWORD is required" ... }}
//
// Such a `required` gate co-existing with the matching bundled Bitnami subchart is
// the dual-secret smell: the app keeps its own copy of a password the subchart
// already owns. After single-sourcing, the infra key is read via secretKeyRef and
// only conditionally written (no `required`), so it no longer matches.
var dualSecretRequiredPattern = regexp.MustCompile(`(?m)^\s*([A-Za-z0-9_]+)\s*:\s*\{\{[^}]*\brequired\b[^}]*\}\}`)

// allowlistedCredentialDefaults exempts intentional, non-empty credential defaults that are
// deliberately kept in published values for backward compatibility — changing them would
// rotate the credential for existing releases on upgrade. Keep this list minimal and
// document the rationale per entry. Key format: "<chartName>:<dotted values path>".
var allowlistedCredentialDefaults = map[string]bool{
	// plugin-access-manager ships a default initUser.adminPassword so existing releases keep
	// their admin login across upgrades; operators are expected to override it in production.
	"plugin-access-manager:auth.initUser.adminPassword": true,
}

type chartYAML struct {
	Type         string            `yaml:"type"`
	Annotations  map[string]string `yaml:"annotations"`
	Dependencies []chartDependency `yaml:"dependencies"`
}

type chartDependency struct {
	Name       string `yaml:"name"`
	Alias      string `yaml:"alias"`
	Repository string `yaml:"repository"`
}

type violation struct {
	Chart  string `yaml:"chart"`
	Rule   string `yaml:"rule"`
	Path   string `yaml:"path"`
	Reason string `yaml:"reason"`
}

type baselineFile struct {
	Violations []violation `yaml:"violations"`
}

type renderRow struct {
	Chart  string
	Status string
	Class  string
	Detail string
}

func main() {
	root := flag.String("root", "../..", "repository root")
	baselinePath := flag.String("baseline", "", "baseline YAML path")
	writeBaseline := flag.Bool("write-baseline", false, "write current static violations to the baseline path")
	strict := flag.Bool("strict", false, "fail on any static violation or baseline entry")
	allowStaleBaseline := flag.Bool("allow-stale-baseline", false, "allow stale baseline entries in baseline mode")
	renderInventory := flag.Bool("render-inventory", false, "generate render inventory instead of static validation")
	renderGate := flag.Bool("render-gate", false, "run blocking helm dependency build and template validation")
	allCharts := flag.Bool("all", false, "select all charts for render gate")
	selectedCharts := flag.String("charts", "", "comma-separated chart names for render gate")
	sampleValuesDir := flag.String("sample-values-dir", "", "directory containing per-chart sample values for render gate")
	outputPath := flag.String("output", "", "output path for render inventory")
	flag.Parse()

	repoRoot, err := filepath.Abs(*root)
	if err != nil {
		fatal(err)
	}

	if *renderInventory {
		if *outputPath == "" {
			fatal(errors.New("--output is required with --render-inventory"))
		}
		rows, err := buildRenderInventory(repoRoot)
		if err != nil {
			fatal(err)
		}
		if err := writeRenderInventory(*outputPath, rows); err != nil {
			fatal(err)
		}
		fmt.Printf("render inventory written to %s (%d charts)\n", *outputPath, len(rows))
		return
	}

	if *renderGate {
		chartSelection, err := parseRenderGateSelection(*allCharts, *selectedCharts)
		if err != nil {
			fatal(err)
		}
		valuesDir := *sampleValuesDir
		if valuesDir == "" {
			valuesDir = filepath.Join(repoRoot, ".github", "configs", "helm-render-values")
		}

		rows, err := buildRenderGate(repoRoot, chartSelection, valuesDir)
		if err != nil {
			fatal(err)
		}
		printRenderRows(rows)
		if renderRowsFailed(rows) {
			os.Exit(1)
		}
		return
	}

	violations, err := collectViolations(repoRoot)
	if err != nil {
		fatal(err)
	}

	if *writeBaseline {
		if *baselinePath == "" {
			fatal(errors.New("--baseline is required with --write-baseline"))
		}
		if err := writeBaselineFile(*baselinePath, violations); err != nil {
			fatal(err)
		}
		fmt.Printf("baseline written to %s (%d violations)\n", *baselinePath, len(violations))
		return
	}

	if *strict {
		baselineFilePath := *baselinePath
		if baselineFilePath == "" {
			baselineFilePath = filepath.Join(repoRoot, ".github", "configs", "helm-chart-standard-baseline.yaml")
		}

		baseline, err := readBaselineViolations(baselineFilePath)
		if err != nil {
			printViolations("current violations", violations)
			fatal(err)
		}

		printStrictSummary(violations, baseline)
		if len(violations) > 0 {
			printViolations("current violations", violations)
		}
		if len(baseline) > 0 {
			printViolations("baseline entries", baseline)
		}
		if len(violations) > 0 || len(baseline) > 0 {
			os.Exit(1)
		}
		return
	}

	if *baselinePath == "" {
		printViolations("unbaselined violations", violations)
		fatal(errors.New("--baseline is required for validation"))
	}

	baselineViolations, err := readBaselineViolations(*baselinePath)
	if err != nil {
		printViolations("current violations", violations)
		fatal(err)
	}

	baseline := violationSet(baselineViolations)
	unbaselined := diffViolations(violations, baseline)
	stale := staleViolations(violations, baselineViolations)
	printSummary(violations, unbaselined, stale)
	printRuleSummary("current violations by rule", violations)
	printRuleSummary("unbaselined violations by rule", unbaselined)
	printRuleSummary("stale baseline entries by rule", stale)
	if len(unbaselined) > 0 {
		printViolations("unbaselined violations", unbaselined)
		os.Exit(1)
	}
	if len(stale) > 0 && !*allowStaleBaseline {
		printViolations("stale baseline entries", stale)
		os.Exit(1)
	}
}

func collectViolations(root string) ([]violation, error) {
	chartDirs, err := chartDirectories(root)
	if err != nil {
		return nil, err
	}

	var violations []violation
	for _, chartDir := range chartDirs {
		chartName := filepath.Base(chartDir)
		chartPath := filepath.Join(chartDir, "Chart.yaml")
		chartRel := rel(root, chartPath)

		chartData, err := os.ReadFile(chartPath)
		if err != nil {
			violations = append(violations, newViolation(chartName, "missing-chart-yaml", chartRel, "Chart.yaml is required for every chart directory"))
			continue
		}

		var chart chartYAML
		if err := yaml.Unmarshal(chartData, &chart); err != nil {
			violations = append(violations, newViolation(chartName, "invalid-chart-yaml", chartRel, err.Error()))
			continue
		}

		chartType := chart.Annotations[chartTypeAnnotation]
		if !allowedChartTypes[chartType] {
			violations = append(violations, newViolation(chartName, "invalid-chart-type", chartRel, "Chart.yaml must set annotations.lerian.studio/chart-type to single-service, multi-component, dependency-wrapper, or library"))
		}

		isLibrary := chart.Type == "library"
		if chart.Type != "application" && !isLibrary {
			violations = append(violations, newViolation(chartName, "invalid-chart-kind", chartRel, "Chart.yaml type must be application or library"))
		}

		// The library annotation and the Helm chart kind must agree, so an
		// application chart cannot claim chart-type: library to skip requirements.
		if (chartType == "library") != isLibrary {
			violations = append(violations, newViolation(chartName, "chart-type-mismatch", chartRel, "annotations.lerian.studio/chart-type: library requires (and only applies to) Chart.yaml type: library"))
		}

		for _, required := range []string{"README.md", "values.yaml"} {
			path := filepath.Join(chartDir, required)
			if !fileExists(path) {
				violations = append(violations, newViolation(chartName, "missing-"+strings.TrimSuffix(strings.ToLower(required), ".md"), rel(root, path), required+" is required"))
			}
		}
		violations = append(violations, validateReadmeContract(root, chartDir, chartName, chartType)...)

		if chartType != "dependency-wrapper" && !isLibrary {
			valuesTemplate := filepath.Join(chartDir, "values-template.yaml")
			if !fileExists(valuesTemplate) {
				violations = append(violations, newViolation(chartName, "missing-values-template", rel(root, valuesTemplate), "application charts must provide values-template.yaml"))
			}

			helper := filepath.Join(chartDir, "templates", "_helpers.tpl")
			if !fileExists(helper) {
				violations = append(violations, newViolation(chartName, "missing-helpers", rel(root, helper), "application charts must use templates/_helpers.tpl"))
			}
		}

		if len(chart.Dependencies) > 0 {
			lock := filepath.Join(chartDir, "Chart.lock")
			if !fileExists(lock) {
				violations = append(violations, newViolation(chartName, "dependency-lock", rel(root, lock), "charts with dependencies must commit Chart.lock or document a permanent exception"))
			}
		}

		violations = append(violations, findForbiddenTemplateNames(root, chartDir, chartName)...)
		violations = append(violations, scanValues(root, chartDir, chartName)...)
		violations = append(violations, scanTemplateDefaults(root, chartDir, chartName)...)
		violations = append(violations, scanConfigMapTemplates(root, chartDir, chartName)...)
		violations = append(violations, scanValuesTemplate(root, chartDir, chartName)...)
		violations = append(violations, scanDualSecret(root, chartDir, chartName, chart.Dependencies)...)
	}

	sortViolations(violations)
	return violations, nil
}

func chartDirectories(root string) ([]string, error) {
	chartsRoot := filepath.Join(root, "charts")
	entries, err := os.ReadDir(chartsRoot)
	if err != nil {
		return nil, err
	}

	var dirs []string
	for _, entry := range entries {
		if entry.IsDir() {
			dirs = append(dirs, filepath.Join(chartsRoot, entry.Name()))
		}
	}
	sort.Strings(dirs)
	return dirs, nil
}

func findForbiddenTemplateNames(root, chartDir, chartName string) []violation {
	var violations []violation
	templatesDir := filepath.Join(chartDir, "templates")
	if !dirExists(templatesDir) {
		return violations
	}

	_ = filepath.WalkDir(templatesDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}

		switch d.Name() {
		case "helpers.tpl":
			violations = append(violations, newViolation(chartName, "nonstandard-helper-name", rel(root, path), "use _helpers.tpl, not helpers.tpl"))
		case "secret.yaml", "secrets.yml":
			violations = append(violations, newViolation(chartName, "nonstandard-secret-template-name", rel(root, path), "use secrets.yaml for Secret templates"))
		}
		return nil
	})

	return violations
}

func validateReadmeContract(root, chartDir, chartName, chartType string) []violation {
	readmePath := filepath.Join(chartDir, "README.md")
	data, err := os.ReadFile(readmePath)
	if err != nil {
		return nil
	}

	content := strings.ToLower(string(data))
	requiredFragments := []string{
		"## chart contract",
		"chart type: `" + chartType + "`",
		"required secrets:",
		"dependency notes:",
		"production overrides:",
		"source/license:",
	}

	var violations []violation
	for _, fragment := range requiredFragments {
		if !strings.Contains(content, fragment) {
			violations = append(violations, newViolation(chartName, "readme-contract", rel(root, readmePath), "README.md must include Chart Contract fragment: "+fragment))
		}
	}
	return violations
}

func scanValues(root, chartDir, chartName string) []violation {
	valuesPath := filepath.Join(chartDir, "values.yaml")
	data, err := os.ReadFile(valuesPath)
	if err != nil {
		return nil
	}

	var doc yaml.Node
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return []violation{newViolation(chartName, "invalid-values-yaml", rel(root, valuesPath), err.Error())}
	}

	var violations []violation
	if len(doc.Content) > 0 {
		walkValues(root, chartName, valuesPath, doc.Content[0], nil, false, &violations)
	}
	return violations
}

// scanTemplateDefaults walks templates/**/*.yaml looking for secret-like keys
// that fall back to a non-empty literal via `| default "..."`. Empty defaults
// (`| default ""`) and `required` gates are intentionally allowed; a non-empty
// default renders a published credential whenever the operator does not
// override it. This closes the gap where values.yaml is clean but the template
// re-introduces the secret (e.g. matcher's `| default "lerian"`).
func scanTemplateDefaults(root, chartDir, chartName string) []violation {
	templatesDir := filepath.Join(chartDir, "templates")
	if !dirExists(templatesDir) {
		return nil
	}

	var violations []violation
	_ = filepath.WalkDir(templatesDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(d.Name()))
		if ext != ".yaml" && ext != ".yml" && ext != ".tpl" {
			return nil
		}

		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return nil
		}

		for _, match := range templateDefaultPattern.FindAllStringSubmatch(string(data), -1) {
			key := match[1]
			def := strings.TrimSpace(match[2])
			if !isTemplateSecretKey(key) {
				continue
			}
			if !isCredentialLikeDefault(def) {
				continue
			}
			violations = append(violations, newViolation(chartName, "template-default-secret", rel(root, path)+":"+key, fmt.Sprintf("%s falls back to a non-empty default %q; use required or default to empty", key, def)))
		}
		return nil
	})

	return violations
}

// configMapKindPattern matches a `kind: ConfigMap` line in a template file.
var configMapKindPattern = regexp.MustCompile(`(?m)^\s*kind:\s*ConfigMap\s*$`)

// configMapDataKeyPattern captures a data-block key/value in a ConfigMap
// template, e.g.
//
//	  SOME_PASSWORD: {{ .Values.x }}
//
// Group 1 is the key name, group 2 the (template) value text. Pure-template
// lines ({{- if ... }}, comments) do not match because they lack the `KEY:`
// shape.
var configMapDataKeyPattern = regexp.MustCompile(`^\s+([A-Za-z0-9_.-]+)\s*:\s*(\S.*)$`)

// configMapDefaultLiteralPattern extracts the `| default "X"` literal from a
// ConfigMap value, mirroring templateDefaultPattern. Used to skip config flags
// (booleans/numbers) authored on a secret-shaped key, e.g.
// API_KEY_ENABLED: {{ ... | default "false" }}.
var configMapDefaultLiteralPattern = regexp.MustCompile(`\|\s*default\s+"([^"]*)"`)

// scanConfigMapTemplates scans rendered-kind ConfigMap templates (templates/**.yaml
// with `kind: ConfigMap`) for data keys whose names classify as secret-like.
// Unlike scanValues, which only walks values.yaml, this catches a credential key
// authored directly into a ConfigMap template payload — a Secret value that
// would be persisted in plaintext as ConfigMap data. Template control lines and
// non-data sections (metadata, labels) are skipped by tracking the `data:` block.
func scanConfigMapTemplates(root, chartDir, chartName string) []violation {
	templatesDir := filepath.Join(chartDir, "templates")
	if !dirExists(templatesDir) {
		return nil
	}

	var violations []violation
	_ = filepath.WalkDir(templatesDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(d.Name()))
		if ext != ".yaml" && ext != ".yml" {
			return nil
		}

		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return nil
		}
		if !configMapKindPattern.MatchString(string(data)) {
			return nil
		}

		for key, value := range configMapDataKeys(string(data)) {
			if !isTemplateSecretKey(key) {
				continue
			}
			// Skip config flags authored on a secret-shaped key: a value whose
			// `| default "X"` literal is a boolean/number (e.g.
			// API_KEY_ENABLED | default "false", MOCK_TOKEN | default "false")
			// is a toggle, not a credential. Keys without such a default (a
			// reference or hardcoded literal) are flagged.
			if def := configMapDefaultLiteralPattern.FindStringSubmatch(value); def != nil && !isCredentialLikeDefault(def[1]) {
				continue
			}
			violations = append(violations, newViolation(chartName, "secret-in-configmap", rel(root, path)+":"+key,
				fmt.Sprintf("%s is credential-like and lives in a ConfigMap template; move it to a Secret", key)))
		}
		return nil
	})

	return violations
}

// configMapDataKeys extracts the data-block key/value pairs of a ConfigMap
// template. It enters the block at a `data:` line and collects keys indented
// deeper than `data:`, stopping when a sibling (or shallower) section begins.
// This is a source-level scan: it sees the authored keys and their (templated)
// value text, which is sufficient to classify key names and skip flag defaults.
func configMapDataKeys(content string) map[string]string {
	keys := map[string]string{}
	inData := false
	dataIndent := 0
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		indent := len(line) - len(strings.TrimLeft(line, " "))

		if !inData {
			if trimmed == "data:" {
				inData = true
				dataIndent = indent
			}
			continue
		}

		// A non-template line at or below data's indentation ends the block.
		if indent <= dataIndent && !strings.HasPrefix(trimmed, "{{") {
			inData = false
			continue
		}
		if match := configMapDataKeyPattern.FindStringSubmatch(line); match != nil {
			keys[match[1]] = match[2]
		}
	}
	return keys
}

// scanValuesTemplate applies the same credential checks to values-template.yaml.
// Operator-facing placeholders (e.g. <password>, ${...}, CHANGE_ME) are allowed
// because values-template.yaml documents the keys an operator must fill, but a
// concrete credential committed there is still flagged.
func scanValuesTemplate(root, chartDir, chartName string) []violation {
	valuesPath := filepath.Join(chartDir, "values-template.yaml")
	data, err := os.ReadFile(valuesPath)
	if err != nil {
		return nil
	}

	var doc yaml.Node
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return []violation{newViolation(chartName, "invalid-values-template", rel(root, valuesPath), err.Error())}
	}

	var violations []violation
	if len(doc.Content) > 0 {
		walkValues(root, chartName, valuesPath, doc.Content[0], nil, false, &violations)
	}
	return violations
}

// bitnamiInfraSubcharts lists the Bitnami subcharts whose passwords must be
// single-sourced (the app reads the subchart-generated Secret via secretKeyRef
// rather than keeping its own copy). Keyed by subchart name.
var bitnamiInfraSubcharts = map[string]bool{
	"postgresql": true,
	"mongodb":    true,
	"valkey":     true,
}

// infraKeySubchart maps an app Secret data-key to the Bitnami subchart that owns
// its credential, or "" when the key is not an infra-internal password that a
// bundled Bitnami subchart provides. Replica passwords map to postgresql.
func infraKeySubchart(key string) string {
	u := strings.ToUpper(key)
	switch {
	case strings.Contains(u, "MONGO") && strings.Contains(u, "PASSWORD"):
		return "mongodb"
	case u == "REDIS_PASSWORD" || u == "VALKEY_PASSWORD":
		return "valkey"
	case strings.Contains(u, "POSTGRES") && strings.Contains(u, "PASSWORD"):
		return "postgresql"
	case strings.HasPrefix(u, "DB_") && strings.Contains(u, "PASSWORD"):
		// e.g. DB_ONBOARDING_PASSWORD, DB_TRANSACTION_REPLICA_PASSWORD, DB_PASSWORD.
		return "postgresql"
	}
	return ""
}

// scanDualSecret flags the dual-secret hazard: an app-owned infra password that
// is `required` in a Secret template while the matching bundled Bitnami subchart
// is declared as a dependency. That co-existence means the operator must set the
// same password in two places (the app Secret and the subchart). After
// single-sourcing, the app reads the subchart Secret via secretKeyRef and the key
// carries no `required` gate, so it no longer matches this rule.
func scanDualSecret(root, chartDir, chartName string, deps []chartDependency) []violation {
	templatesDir := filepath.Join(chartDir, "templates")
	if !dirExists(templatesDir) {
		return nil
	}

	declared := map[string]bool{}
	for _, dep := range deps {
		name := strings.ToLower(strings.TrimSpace(dep.Name))
		if bitnamiInfraSubcharts[name] {
			declared[name] = true
		}
	}
	if len(declared) == 0 {
		return nil
	}

	var violations []violation
	_ = filepath.WalkDir(templatesDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		base := strings.ToLower(d.Name())
		// Only inspect Secret templates (secrets.yaml, *secret*.yaml).
		if !strings.Contains(base, "secret") {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(d.Name()))
		if ext != ".yaml" && ext != ".yml" {
			return nil
		}

		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return nil
		}

		for _, match := range dualSecretRequiredPattern.FindAllStringSubmatch(string(data), -1) {
			key := match[1]
			sub := infraKeySubchart(key)
			if sub == "" || !declared[sub] {
				continue
			}
			violations = append(violations, newViolation(chartName, "dual-secret-infra-password", rel(root, path)+":"+key,
				fmt.Sprintf("%s is `required` while the bundled %q subchart is declared; single-source it: read the subchart Secret via secretKeyRef and drop the required gate (see docs/helm-chart-standard.md \"Single-Source Infra Secrets\")", key, sub)))
		}
		return nil
	})

	return violations
}

func walkValues(root, chartName, valuesPath string, node *yaml.Node, path []string, inConfigmap bool, violations *[]violation) {
	if node == nil {
		return
	}

	switch node.Kind {
	case yaml.MappingNode:
		for i := 0; i+1 < len(node.Content); i += 2 {
			key := node.Content[i]
			value := node.Content[i+1]
			keyPath := appendPath(path, key.Value)
			keyLower := strings.ToLower(key.Value)
			nextInConfigmap := inConfigmap || keyLower == "configmap"

			if nextInConfigmap && value.Kind == yaml.ScalarNode && isSensitiveConfigKey(key.Value) {
				*violations = append(*violations, newViolation(chartName, "secret-in-configmap", yamlPath(root, valuesPath, keyPath), fmt.Sprintf("%s is credential-like and lives under configmap", strings.Join(keyPath, "."))))
			}

			if value.Kind == yaml.ScalarNode {
				checkScalarValue(root, chartName, valuesPath, key.Value, value, keyPath, nextInConfigmap, violations)
			}

			walkValues(root, chartName, valuesPath, value, keyPath, nextInConfigmap, violations)
		}
	case yaml.SequenceNode:
		for i, item := range node.Content {
			walkValues(root, chartName, valuesPath, item, appendPath(path, fmt.Sprintf("[%d]", i)), inConfigmap, violations)
		}
	}
}

func checkScalarValue(root, chartName, valuesPath, key string, value *yaml.Node, path []string, inConfigmap bool, violations *[]violation) {
	valueText := strings.TrimSpace(value.Value)
	pathText := yamlPath(root, valuesPath, path)

	if inConfigmap && credentialURLPattern.MatchString(valueText) {
		*violations = append(*violations, newViolation(chartName, "secret-in-configmap", pathText, "credential-bearing URL lives under configmap"))
	}

	classifyKey := classificationKey(key, path)

	// Intentional, documented credential defaults kept for backward compatibility are
	// exempted from the default-credential rule (see allowlistedCredentialDefaults).
	credDefaultAllowed := allowlistedCredentialDefaults[chartName+":"+strings.Join(path, ".")]

	if !credDefaultAllowed && isPasswordKey(classifyKey) && strings.EqualFold(valueText, "lerian") {
		*violations = append(*violations, newViolation(chartName, "default-credential", pathText, "published values must not default password-like keys to lerian"))
	}

	if !credDefaultAllowed && isSecretValueKey(classifyKey) && isLiteralSecretDefault(valueText) {
		*violations = append(*violations, newViolation(chartName, "default-credential", pathText, "published values must not contain non-empty defaults for secret-like keys"))
	}

	if !credDefaultAllowed && credentialURLPattern.MatchString(valueText) && strings.Contains(strings.ToLower(valueText), ":lerian@") {
		*violations = append(*violations, newViolation(chartName, "default-credential", pathText, "published values must not embed lerian in credential-bearing URLs"))
	}

	switch key {
	case "readOnlyRootFilesystem":
		if isFalse(value) {
			*violations = append(*violations, newViolation(chartName, "writable-root-filesystem", pathText, "application containers should default readOnlyRootFilesystem to true"))
		}
	case "runAsUser":
		if value.Value == "0" {
			*violations = append(*violations, newViolation(chartName, "root-user", pathText, "application containers should not default to runAsUser 0"))
		}
	case "runAsNonRoot":
		if isFalse(value) {
			*violations = append(*violations, newViolation(chartName, "run-as-root", pathText, "application containers should default runAsNonRoot to true"))
		}
	case "allowPrivilegeEscalation":
		if isTrue(value) {
			*violations = append(*violations, newViolation(chartName, "privilege-escalation", pathText, "application containers should default allowPrivilegeEscalation to false"))
		}
	}
}

// classificationKey returns the key that should drive secret-like classification
// for a scalar value. When the immediate key is a generic literal carrier (the
// groundhog2k convention of nesting the credential under a `value` field, e.g.
// authentication.erlangCookie.value or password.value), the carrier itself
// reveals nothing, so the meaningful parent key (erlangCookie, password) is used
// instead. Otherwise the immediate key is returned unchanged.
//
// Note: `secretKey` is deliberately NOT a carrier. In the single-source pattern
// (authentication.password.secretKey: RABBITMQ_DEFAULT_PASS) its value is the
// NAME of a key inside an existingSecret, never a literal credential, so it must
// keep being treated as a reference and pass classification untouched.
func classificationKey(key string, path []string) string {
	if !isGenericValueCarrier(key) {
		return key
	}
	// path ends with the immediate key; the parent is the entry before it.
	if len(path) >= 2 {
		parent := path[len(path)-2]
		if !isGenericValueCarrier(parent) {
			return parent
		}
	}
	return key
}

// isGenericValueCarrier reports whether a key is a structural wrapper that
// carries a credential literal without naming it (the groundhog2k convention of
// nesting the value under a `value` field). Such keys never classify on their
// own; the parent key holds the meaning.
func isGenericValueCarrier(key string) bool {
	return strings.ToLower(strings.NewReplacer("_", "", "-", "", ".", "").Replace(key)) == "value"
}

func isSensitiveConfigKey(key string) bool {
	lower := strings.ToLower(key)
	if strings.Contains(lower, "password") || strings.Contains(lower, "secret") || strings.Contains(lower, "private_key") || strings.Contains(lower, "client_secret") {
		return true
	}
	if lower == "api_key" || strings.HasSuffix(lower, "_api_key") {
		return true
	}
	if lower == "token" || strings.HasSuffix(lower, "_token") || strings.Contains(lower, "_token_") {
		return !strings.Contains(lower, "refresh_interval")
	}
	return false
}

func isPasswordKey(key string) bool {
	lower := strings.ToLower(key)
	// Word-boundary semantics: a bare HasSuffix "pass" would match compass/bypass.
	// Only the abbreviation "pass" used as a whole word (exact or "_pass" suffix)
	// or a key containing "password" is treated as a password key.
	return strings.Contains(lower, "password") || strings.HasSuffix(lower, "_pass") || lower == "pass"
}

// isTemplateSecretKey classifies a template data-key (e.g. POSTGRES_PASSWORD,
// LCRYPTO_HASH_SECRET_KEY, MIDAZ_CLIENT_SECRET) as credential-bearing. Unlike
// isSecretValueKey (which scans values.yaml and must ignore *references* to
// secret objects), this targets the actual Secret data payload, so it does NOT
// exclude `*_SECRET_KEY` crypto-material keys. It still skips keys that merely
// point at an external secret (existingSecret, secretName, secretKeyRef).
func isTemplateSecretKey(key string) bool {
	normalized := strings.NewReplacer("_", "", "-", "", ".", "").Replace(strings.ToLower(key))

	// References to external secret objects, not the secret value itself.
	if strings.Contains(normalized, "existingsecret") ||
		strings.Contains(normalized, "secretname") ||
		strings.Contains(normalized, "secretkeyref") ||
		strings.HasSuffix(normalized, "secretkeyname") ||
		strings.HasSuffix(normalized, "passwordkey") ||
		normalized == "automountserviceaccounttoken" {
		return false
	}

	if strings.Contains(normalized, "password") ||
		strings.HasSuffix(normalized, "pass") ||
		strings.Contains(normalized, "privatekey") ||
		strings.Contains(normalized, "secret") ||
		strings.Contains(normalized, "apikey") ||
		strings.Contains(normalized, "accesskey") ||
		strings.Contains(normalized, "erlang") ||
		strings.Contains(normalized, "cookie") {
		return true
	}
	if normalized == "token" || strings.HasSuffix(normalized, "token") {
		return !strings.Contains(normalized, "refresh") && !strings.Contains(normalized, "lifetime")
	}
	return false
}

// isCredentialLikeDefault reports whether a `| default "X"` literal looks like a
// real credential rather than a boolean/numeric flag or an operator
// placeholder. Booleans and numbers (e.g. `| default "false"`, `| default "5"`)
// are config toggles that happen to live on a token-shaped key and must not be
// flagged.
func isCredentialLikeDefault(value string) bool {
	value = strings.TrimSpace(value)
	if value == "" {
		return false
	}
	if isOperatorPlaceholder(value) {
		return false
	}
	lower := strings.ToLower(value)
	if lower == "true" || lower == "false" || lower == "null" || lower == "nil" {
		return false
	}
	if _, err := strconv.ParseFloat(value, 64); err == nil {
		return false
	}
	return true
}

func isSecretValueKey(key string) bool {
	normalized := strings.NewReplacer("_", "", "-", "", ".", "").Replace(strings.ToLower(key))
	if normalized == "automountserviceaccounttoken" || strings.Contains(normalized, "secretname") || strings.Contains(normalized, "existingsecret") || strings.HasSuffix(normalized, "secretkey") || strings.HasSuffix(normalized, "passwordkey") {
		return false
	}
	if strings.Contains(normalized, "password") || strings.HasSuffix(normalized, "pass") || strings.Contains(normalized, "privatekey") || strings.Contains(normalized, "clientsecret") {
		return true
	}
	// erlangCookie / *-cookie carry the RabbitMQ clustering secret.
	if strings.Contains(normalized, "erlang") || strings.Contains(normalized, "cookie") {
		return true
	}
	if normalized == "secret" || strings.HasSuffix(normalized, "secret") {
		return true
	}
	if normalized == "token" || strings.HasSuffix(normalized, "token") || strings.Contains(normalized, "token") && !strings.Contains(normalized, "refresh") && !strings.Contains(normalized, "lifetime") {
		return true
	}
	return normalized == "apikey" || strings.HasSuffix(normalized, "apikey")
}

func isLiteralSecretDefault(value string) bool {
	value = strings.TrimSpace(value)
	if value == "" {
		return false
	}
	return !isOperatorPlaceholder(value)
}

// isOperatorPlaceholder reports whether a value is an obvious fill-me-in
// placeholder rather than a concrete credential. These are acceptable in
// values-template.yaml (and harmless in values.yaml) because they cannot
// authenticate against anything.
func isOperatorPlaceholder(value string) bool {
	value = strings.TrimSpace(value)
	if value == "" {
		return true
	}
	// Template/interpolation expressions: ${...}, {{ ... }}.
	if strings.HasPrefix(value, "${") || strings.HasPrefix(value, "{{") {
		return true
	}
	// Angle-bracket placeholders: <password>, <your-token>.
	if strings.HasPrefix(value, "<") && strings.HasSuffix(value, ">") {
		return true
	}
	lower := strings.ToLower(value)
	for _, marker := range []string{"changeme", "change_me", "change-me", "placeholder", "replace_me", "replace-me", "your-", "your_", "<", ">"} {
		if strings.Contains(lower, marker) {
			return true
		}
	}
	return false
}

func isFalse(node *yaml.Node) bool {
	return strings.EqualFold(node.Value, "false")
}

func isTrue(node *yaml.Node) bool {
	return strings.EqualFold(node.Value, "true")
}

func appendPath(path []string, value string) []string {
	next := make([]string, 0, len(path)+1)
	next = append(next, path...)
	next = append(next, value)
	return next
}

func yamlPath(root, filePath string, path []string) string {
	if len(path) == 0 {
		return rel(root, filePath)
	}
	return rel(root, filePath) + ":" + strings.Join(path, ".")
}

func readBaselineViolations(path string) ([]violation, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read baseline: %w", err)
	}

	var baseline baselineFile
	if err := yaml.Unmarshal(data, &baseline); err != nil {
		return nil, fmt.Errorf("parse baseline: %w", err)
	}
	sortViolations(baseline.Violations)
	return baseline.Violations, nil
}

func writeBaselineFile(path string, violations []violation) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	out, err := yaml.Marshal(baselineFile{Violations: violations})
	if err != nil {
		return err
	}

	return os.WriteFile(path, out, 0o644)
}

func diffViolations(violations []violation, baseline map[string]bool) []violation {
	var missing []violation
	for _, item := range violations {
		if !baseline[item.key()] {
			missing = append(missing, item)
		}
	}
	return missing
}

func staleViolations(violations, baseline []violation) []violation {
	current := violationSet(violations)
	var stale []violation
	for _, item := range baseline {
		if !current[item.key()] {
			stale = append(stale, item)
		}
	}
	sortViolations(stale)
	return stale
}

func violationSet(violations []violation) map[string]bool {
	seen := make(map[string]bool, len(violations))
	for _, item := range violations {
		seen[item.key()] = true
	}
	return seen
}

func (v violation) key() string {
	return v.Chart + "|" + v.Rule + "|" + v.Path
}

func newViolation(chart, rule, path, reason string) violation {
	return violation{Chart: chart, Rule: rule, Path: filepath.ToSlash(path), Reason: reason}
}

func sortViolations(violations []violation) {
	sort.Slice(violations, func(i, j int) bool {
		if violations[i].Chart != violations[j].Chart {
			return violations[i].Chart < violations[j].Chart
		}
		if violations[i].Rule != violations[j].Rule {
			return violations[i].Rule < violations[j].Rule
		}
		return violations[i].Path < violations[j].Path
	})
}

func printSummary(violations, unbaselined, stale []violation) {
	fmt.Printf("helm chart standard: %d current violation(s), %d unbaselined, %d stale baseline entries\n", len(violations), len(unbaselined), len(stale))
}

func printStrictSummary(violations, baseline []violation) {
	fmt.Printf("helm chart standard strict: %d current violation(s), %d baseline entries\n", len(violations), len(baseline))
}

func printRuleSummary(title string, violations []violation) {
	if len(violations) == 0 {
		return
	}

	counts := map[string]int{}
	var rules []string
	for _, item := range violations {
		if counts[item.Rule] == 0 {
			rules = append(rules, item.Rule)
		}
		counts[item.Rule]++
	}
	sort.Strings(rules)

	fmt.Println(title + ":")
	for _, rule := range rules {
		fmt.Printf("- %s: %d\n", rule, counts[rule])
	}
}

func printViolations(title string, violations []violation) {
	if len(violations) == 0 {
		return
	}
	fmt.Println(title + ":")
	for _, item := range violations {
		fmt.Printf("- %s %s %s: %s\n", item.Chart, item.Rule, item.Path, item.Reason)
	}
}

func buildRenderInventory(root string) ([]renderRow, error) {
	return buildRenderRows(root, nil, "")
}

func isLibraryChart(chartDir string) bool {
	data, err := os.ReadFile(filepath.Join(chartDir, "Chart.yaml"))
	if err != nil {
		return false
	}
	var c chartYAML
	if err := yaml.Unmarshal(data, &c); err != nil {
		return false
	}
	return c.Type == "library"
}

func buildRenderGate(root string, chartSelection map[string]bool, sampleValuesDir string) ([]renderRow, error) {
	rows, err := buildRenderRows(root, chartSelection, sampleValuesDir)
	if err != nil {
		return nil, err
	}
	if len(chartSelection) > 0 {
		for _, row := range rows {
			delete(chartSelection, row.Chart)
		}
		if len(chartSelection) > 0 {
			var missing []string
			for chart := range chartSelection {
				missing = append(missing, chart)
			}
			sort.Strings(missing)
			return nil, fmt.Errorf("unknown chart(s): %s", strings.Join(missing, ", "))
		}
	}
	return rows, nil
}

func buildRenderRows(root string, chartSelection map[string]bool, sampleValuesDir string) ([]renderRow, error) {
	chartDirs, err := chartDirectories(root)
	if err != nil {
		return nil, err
	}

	var rows []renderRow
	for _, chartDir := range chartDirs {
		chartName := filepath.Base(chartDir)
		if chartSelection != nil && !chartSelection[chartName] {
			continue
		}
		row := renderRow{Chart: chartName}

		// Library charts are not installable (helm template fails); their helpers
		// are exercised through the consumer charts, so skip the render gate.
		if isLibraryChart(chartDir) {
			row.Status = "ok"
			row.Class = "skipped-library"
			row.Detail = "library chart — not installable; helpers validated via consumer charts"
			rows = append(rows, row)
			continue
		}

		deps, err := chartDependencies(chartDir)
		if err != nil {
			return nil, err
		}

		tmpRoot, err := os.MkdirTemp("", "helm-chart-render-*")
		if err != nil {
			return nil, err
		}
		tmpChart := filepath.Join(tmpRoot, chartName)
		if err := copyDir(chartDir, tmpChart); err != nil {
			_ = os.RemoveAll(tmpRoot)
			return nil, err
		}

		helmEnv, err := isolatedHelmEnv(tmpRoot)
		if err != nil {
			_ = os.RemoveAll(tmpRoot)
			return nil, err
		}

		if out, err := addDependencyRepositories(tmpChart, tmpRoot, helmEnv); err != nil {
			row.Status = "fail"
			row.Class = "missing-dependency"
			row.Detail = oneLine(out)
			rows = append(rows, row)
			_ = os.RemoveAll(tmpRoot)
			continue
		}

		if out, err := runHelmWithEnv(tmpRoot, helmEnv, "dependency", "build", tmpChart); err != nil {
			row.Status = "fail"
			row.Class = "missing-dependency"
			row.Detail = oneLine(out)
			rows = append(rows, row)
			_ = os.RemoveAll(tmpRoot)
			continue
		}

		templateArgs := []string{"template", chartName, tmpChart}
		hasFixture := false
		if sampleValuesDir != "" {
			sampleValuesPath := filepath.Join(sampleValuesDir, chartName+".yaml")
			if fileExists(sampleValuesPath) {
				hasFixture = true
				templateArgs = append(templateArgs, "--values", sampleValuesPath)
				row.Detail = "using sample values " + rel(root, sampleValuesPath)
			} else {
				row.Detail = "using default values"
			}
		}

		normalOut, err := runHelmWithEnv(tmpRoot, helmEnv, templateArgs...)
		if err != nil {
			row.Status = "fail"
			row.Class = classifyTemplateFailure(normalOut)
			detail := oneLine(normalOut)
			// M2: make the fixture-coupling explicit. When a chart needs
			// operator-provided values (required/fail gate) but no fixture
			// exists for it, surface that the fixture is missing rather than
			// leaving the maintainer to guess why the render gate is red.
			if sampleValuesDir != "" && !hasFixture && row.Class == "required-value" {
				detail = "missing render fixture .github/configs/helm-render-values/" + chartName + ".yaml; " + detail
			}
			if row.Detail != "" {
				row.Detail += "; " + detail
			} else {
				row.Detail = detail
			}
			rows = append(rows, row)
			_ = os.RemoveAll(tmpRoot)
			continue
		}

		// H1: dangling-secretKeyRef assertion on the normal render.
		if msg := danglingSecretRefMessage(normalOut); msg != "" {
			row.Status = "fail"
			row.Class = "dangling-secret-ref"
			row.Detail = appendDetail(row.Detail, "release "+chartName+": "+msg)
			rows = append(rows, row)
			_ = os.RemoveAll(tmpRoot)
			continue
		}

		// H1: Bitnami release-name collapse. When the release name equals a
		// bundled Bitnami subchart name (or alias), common.names.dependency.fullname
		// collapses <release>-<subchart> to just <subchart>; any app helper that
		// hardcodes <release>-<subchart> instead would then reference a Secret that
		// no longer exists. Render once per Bitnami dependency under that release
		// name and re-run the dangling-ref assertion to catch that whole bug class.
		collapseDetail, collapseFailed := runCollapseRenders(tmpRoot, tmpChart, helmEnv, chartName, bitnamiReleaseNames(chartName, deps), templateArgs)
		if collapseFailed {
			row.Status = "fail"
			row.Class = "dangling-secret-ref"
			row.Detail = appendDetail(row.Detail, collapseDetail)
			rows = append(rows, row)
			_ = os.RemoveAll(tmpRoot)
			continue
		}

		row.Status = "ok"
		row.Class = "render-ok"
		successDetail := "helm dependency build and helm template succeeded"
		if collapseDetail != "" {
			successDetail += "; " + collapseDetail
		}
		row.Detail = appendDetail(row.Detail, successDetail)
		rows = append(rows, row)
		_ = os.RemoveAll(tmpRoot)
	}

	return rows, nil
}

// appendDetail joins a new detail fragment onto an existing row detail with a
// "; " separator, matching the existing render-row detail formatting.
func appendDetail(existing, detail string) string {
	if existing == "" {
		return detail
	}
	return existing + "; " + detail
}

// bitnamiReleaseNames returns the release names that trigger the Bitnami
// release-name collapse for a chart: one per bundled Bitnami subchart, using the
// dependency alias when set (the alias is what common.names.dependency.fullname
// keys on) and the subchart name otherwise. The chart's own name is excluded
// because the normal render already exercises release == chartName.
func bitnamiReleaseNames(chartName string, deps []chartDependency) []string {
	seen := map[string]bool{}
	var names []string
	for _, dep := range deps {
		if !bitnamiInfraSubcharts[strings.ToLower(strings.TrimSpace(dep.Name))] {
			continue
		}
		release := strings.TrimSpace(dep.Alias)
		if release == "" {
			release = strings.TrimSpace(dep.Name)
		}
		if release == "" || release == chartName || seen[release] {
			continue
		}
		seen[release] = true
		names = append(names, release)
	}
	sort.Strings(names)
	return names
}

// runCollapseRenders renders the chart once per collapse release name and runs
// the dangling-ref assertion on each. It returns a one-line detail describing
// the renders performed (or the first failure) and whether any render exposed a
// dangling secret reference.
func runCollapseRenders(tmpRoot, tmpChart string, env []string, chartName string, releaseNames []string, baseArgs []string) (string, bool) {
	if len(releaseNames) == 0 {
		return "", false
	}
	for _, release := range releaseNames {
		args := append([]string{"template", release, tmpChart}, baseArgs[3:]...)
		out, err := runHelmWithEnv(tmpRoot, env, args...)
		if err != nil {
			return fmt.Sprintf("collapse render (release %q) failed: %s", release, oneLine(out)), true
		}
		if msg := danglingSecretRefMessage(out); msg != "" {
			return fmt.Sprintf("collapse render (release %q): %s", release, msg), true
		}
	}
	return fmt.Sprintf("collapse renders passed for release name(s) %s", strings.Join(releaseNames, ", ")), false
}

// chartDependencies reads the dependency list from a chart's Chart.yaml.
func chartDependencies(chartDir string) ([]chartDependency, error) {
	data, err := os.ReadFile(filepath.Join(chartDir, "Chart.yaml"))
	if err != nil {
		return nil, err
	}
	var chart chartYAML
	if err := yaml.Unmarshal(data, &chart); err != nil {
		return nil, err
	}
	return chart.Dependencies, nil
}

// allowedDanglingSecrets lists Secret names that a rendered manifest may
// reference without that Secret being rendered in the same release. Entries are
// for intentionally external/pre-existing secrets the operator (or a subchart's
// own controller) provisions out of band. Each entry MUST carry a justification.
var allowedDanglingSecrets = map[string]bool{
	// otel-collector-lerian references an operator-provisioned API-key Secret;
	// its README instructs `kubectl create secret generic otel-api-key` before
	// install, so the chart intentionally never renders it.
	"otel-api-key": true,
	// reporter bundles the KEDA subchart, whose operator self-manages this TLS
	// cert Secret at runtime via --enable-cert-rotation/--cert-secret-name. KEDA
	// creates it; no Helm chart renders it.
	"kedaorg-certs": true,
}

// danglingSecretRefMessage parses rendered multi-document Helm output, collects
// the names of every rendered Secret and every secret reference (secretKeyRef,
// envFrom.secretRef, volume.secret.secretName), and returns a non-empty message
// when a reference points at a Secret that is neither rendered in the release nor
// in allowedDanglingSecrets. This is the H1 assertion: a release-name collapse
// (or any helper drift) that makes an app point at a Secret the subchart renders
// under a different name shows up here as a dangling reference.
func danglingSecretRefMessage(rendered string) string {
	rendered = stripNonManifest(rendered)
	secretNames := map[string]bool{}
	refs := map[string]bool{}

	dec := yaml.NewDecoder(strings.NewReader(rendered))
	for {
		var doc yaml.Node
		if err := dec.Decode(&doc); err != nil {
			if err == io.EOF {
				break
			}
			// A non-fatal decode error on one document should not mask the rest;
			// stop scanning rather than crash the gate.
			break
		}
		var m map[string]interface{}
		if err := doc.Decode(&m); err != nil || m == nil {
			continue
		}
		if kind, _ := m["kind"].(string); kind == "Secret" {
			if name := nestedString(m, "metadata", "name"); name != "" {
				secretNames[name] = true
			}
		}
		collectSecretRefs(m, refs)
	}

	var missing []string
	for ref := range refs {
		if ref == "" || secretNames[ref] || allowedDanglingSecrets[ref] {
			continue
		}
		missing = append(missing, ref)
	}
	if len(missing) == 0 {
		return ""
	}
	sort.Strings(missing)
	return "secret reference(s) point at non-rendered Secret(s): " + strings.Join(missing, ", ")
}

// stripNonManifest drops leading non-YAML banner lines (helm warnings, NOTES)
// that helm template can emit on stderr-merged output, keeping only manifest
// documents so the YAML decoder does not choke.
func stripNonManifest(rendered string) string {
	idx := strings.Index(rendered, "---")
	if idx <= 0 {
		return rendered
	}
	// Keep everything from the first document separator; if the output starts
	// with a manifest (no leading separator) we already returned it above.
	return rendered[idx:]
}

// collectSecretRefs recursively walks a decoded manifest, recording the Secret
// names referenced via secretKeyRef.name, envFrom[].secretRef.name,
// volumes[].secret.secretName, and projected.sources[].secret.name.
func collectSecretRefs(node interface{}, refs map[string]bool) {
	switch v := node.(type) {
	case map[string]interface{}:
		if ref, ok := v["secretKeyRef"].(map[string]interface{}); ok {
			if name, _ := ref["name"].(string); name != "" {
				refs[name] = true
			}
		}
		if ref, ok := v["secretRef"].(map[string]interface{}); ok {
			if name, _ := ref["name"].(string); name != "" {
				refs[name] = true
			}
		}
		if ref, ok := v["secret"].(map[string]interface{}); ok {
			if name, _ := ref["secretName"].(string); name != "" { // volume secret
				refs[name] = true
			}
			if name, _ := ref["name"].(string); name != "" { // projected volume source secret
				refs[name] = true
			}
		}
		for _, child := range v {
			collectSecretRefs(child, refs)
		}
	case []interface{}:
		for _, child := range v {
			collectSecretRefs(child, refs)
		}
	}
}

// nestedString returns the string at a nested map path, or "" if any segment is
// missing or not the expected type.
func nestedString(m map[string]interface{}, keys ...string) string {
	cur := interface{}(m)
	for _, k := range keys {
		asMap, ok := cur.(map[string]interface{})
		if !ok {
			return ""
		}
		cur = asMap[k]
	}
	s, _ := cur.(string)
	return s
}

func parseRenderGateSelection(allCharts bool, selectedCharts string) (map[string]bool, error) {
	if allCharts && strings.TrimSpace(selectedCharts) != "" {
		return nil, errors.New("use either --all or --charts, not both")
	}
	if allCharts {
		return nil, nil
	}
	if strings.TrimSpace(selectedCharts) == "" {
		return nil, errors.New("--render-gate requires --all or --charts")
	}

	selection := map[string]bool{}
	for _, chart := range strings.Split(selectedCharts, ",") {
		chart = strings.TrimSpace(chart)
		if chart == "" {
			continue
		}
		selection[chart] = true
	}
	if len(selection) == 0 {
		return nil, errors.New("--charts did not contain any chart names")
	}
	return selection, nil
}

func printRenderRows(rows []renderRow) {
	for _, row := range rows {
		fmt.Printf("%s: %s (%s) - %s\n", row.Chart, row.Status, row.Class, row.Detail)
	}
}

func renderRowsFailed(rows []renderRow) bool {
	for _, row := range rows {
		if row.Status != "ok" {
			return true
		}
	}
	return false
}

func isolatedHelmEnv(root string) ([]string, error) {
	repoCache := filepath.Join(root, "helm-repository-cache")
	if err := os.MkdirAll(repoCache, 0o755); err != nil {
		return nil, err
	}
	return append(os.Environ(),
		"HELM_REPOSITORY_CONFIG="+filepath.Join(root, "repositories.yaml"),
		"HELM_REPOSITORY_CACHE="+repoCache,
	), nil
}

func addDependencyRepositories(chartDir, workDir string, env []string) (string, error) {
	data, err := os.ReadFile(filepath.Join(chartDir, "Chart.yaml"))
	if err != nil {
		return "", err
	}

	var chart chartYAML
	if err := yaml.Unmarshal(data, &chart); err != nil {
		return "", err
	}

	seen := map[string]bool{}
	for _, dependency := range chart.Dependencies {
		repository := strings.TrimSpace(dependency.Repository)
		if repository == "" || strings.HasPrefix(repository, "file://") || strings.HasPrefix(repository, "oci://") || seen[repository] {
			continue
		}
		if !strings.HasPrefix(repository, "http://") && !strings.HasPrefix(repository, "https://") {
			continue
		}

		seen[repository] = true
		name := fmt.Sprintf("chart-dep-%d", len(seen))
		if out, err := runHelmWithEnv(workDir, env, "repo", "add", name, repository); err != nil {
			return out, err
		}
	}

	return "", nil
}

func runHelmWithEnv(workDir string, env []string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	cmd := exec.CommandContext(ctx, "helm", args...)
	cmd.Dir = workDir
	if env != nil {
		cmd.Env = env
	}
	out, err := cmd.CombinedOutput()
	if ctx.Err() == context.DeadlineExceeded {
		return string(out) + "\nhelm command timed out", ctx.Err()
	}
	return string(out), err
}

func classifyTemplateFailure(output string) string {
	lower := strings.ToLower(output)
	if strings.Contains(lower, "required") || strings.Contains(lower, "is required") {
		return "required-value"
	}
	return "template-error"
}

func writeRenderInventory(path string, rows []renderRow) error {
	var builder strings.Builder
	builder.WriteString("# Helm Render Inventory\n\n")
	builder.WriteString("Generated on demand by `.github/scripts/validate-helm-charts --render-inventory`.\n\n")
	builder.WriteString("| Chart | Status | Class | Detail |\n")
	builder.WriteString("|-------|--------|-------|--------|\n")
	for _, row := range rows {
		builder.WriteString(fmt.Sprintf("| `%s` | %s | `%s` | %s |\n", row.Chart, row.Status, row.Class, escapeTable(row.Detail)))
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(builder.String()), 0o644)
}

func copyDir(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("symlink entries are not allowed in chart sources: %s", path)
		}

		relPath, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, relPath)

		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}

		info, err := d.Info()
		if err != nil {
			return err
		}
		return copyFile(path, target, info.Mode())
	})
}

func copyFile(src, dst string, mode os.FileMode) error {
	if info, err := os.Lstat(src); err != nil {
		return err
	} else if info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("refusing to copy symlink target: %s", src)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}

	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func oneLine(value string) string {
	fields := strings.Fields(value)
	if len(fields) == 0 {
		return "no output"
	}
	text := strings.Join(fields, " ")
	if len(text) > 220 {
		return text[:220] + "..."
	}
	return text
}

func escapeTable(value string) string {
	return strings.ReplaceAll(value, "|", "\\|")
}

func rel(root, path string) string {
	relPath, err := filepath.Rel(root, path)
	if err != nil {
		return filepath.ToSlash(path)
	}
	return filepath.ToSlash(relPath)
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "error:", err)
	os.Exit(1)
}
