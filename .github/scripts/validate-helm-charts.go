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
}

var credentialURLPattern = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*://[^\s/@]+:[^\s/@]+@`)

// templateDefaultPattern captures Helm pipelines of the form
//
//	KEY: {{ .Values.<...>.SOME_KEY | default "literal" ... }}
//
// so the validator can flag non-empty secret defaults that live in templates
// (not values.yaml). Group 1 is the YAML/template key, group 2 is the quoted
// default literal.
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

type chartYAML struct {
	Type         string            `yaml:"type"`
	Annotations  map[string]string `yaml:"annotations"`
	Dependencies []chartDependency `yaml:"dependencies"`
}

type chartDependency struct {
	Name       string `yaml:"name"`
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
	Chart      string
	Status     string
	Class      string
	PhaseOwner string
	Detail     string
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
			violations = append(violations, newViolation(chartName, "invalid-chart-type", chartRel, "Chart.yaml must set annotations.lerian.studio/chart-type to single-service, multi-component, or dependency-wrapper"))
		}

		if chart.Type != "application" {
			violations = append(violations, newViolation(chartName, "invalid-chart-kind", chartRel, "Chart.yaml type must be application"))
		}

		for _, required := range []string{"README.md", "values.yaml"} {
			path := filepath.Join(chartDir, required)
			if !fileExists(path) {
				violations = append(violations, newViolation(chartName, "missing-"+strings.TrimSuffix(strings.ToLower(required), ".md"), rel(root, path), required+" is required"))
			}
		}
		violations = append(violations, validateReadmeContract(root, chartDir, chartName, chartType)...)

		if chartType != "dependency-wrapper" {
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

	if isPasswordKey(key) && strings.EqualFold(valueText, "lerian") {
		*violations = append(*violations, newViolation(chartName, "default-credential", pathText, "published values must not default password-like keys to lerian"))
	}

	if isSecretValueKey(key) && isLiteralSecretDefault(valueText) {
		*violations = append(*violations, newViolation(chartName, "default-credential", pathText, "published values must not contain non-empty defaults for secret-like keys"))
	}

	if credentialURLPattern.MatchString(valueText) && strings.Contains(strings.ToLower(valueText), ":lerian@") {
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
	return strings.Contains(lower, "password") || strings.HasSuffix(lower, "_pass") || strings.HasSuffix(lower, "pass")
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
		strings.Contains(normalized, "accesskey") {
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
		row := renderRow{Chart: chartName, PhaseOwner: phaseOwner(chartName)}

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

		if out, err := runHelmWithEnv(tmpRoot, helmEnv, templateArgs...); err != nil {
			row.Status = "fail"
			row.Class = classifyTemplateFailure(out)
			detail := oneLine(out)
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

		row.Status = "ok"
		row.Class = "render-ok"
		if row.Detail == "" {
			row.Detail = "helm dependency build and helm template succeeded"
		} else {
			row.Detail += "; helm dependency build and helm template succeeded"
		}
		rows = append(rows, row)
		_ = os.RemoveAll(tmpRoot)
	}

	return rows, nil
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
	builder.WriteString("Generated by `.github/scripts/validate-helm-charts.go --render-inventory`.\n\n")
	builder.WriteString("| Chart | Status | Class | Phase Owner | Detail |\n")
	builder.WriteString("|-------|--------|-------|-------------|--------|\n")
	for _, row := range rows {
		builder.WriteString(fmt.Sprintf("| `%s` | %s | `%s` | %s | %s |\n", row.Chart, row.Status, row.Class, row.PhaseOwner, escapeTable(row.Detail)))
	}

	builder.WriteString("\n## Migration Queue\n\n")
	builder.WriteString("The queue should be re-generated after each phase so it reflects the repository that actually exists.\n\n")
	writePhaseQueue(&builder, rows, "Phase 2", "standard single-service application charts")
	writePhaseQueue(&builder, rows, "Phase 3", "multi-component, PIX, dependency-wrapper, and mock/stub charts")

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(builder.String()), 0o644)
}

func writePhaseQueue(builder *strings.Builder, rows []renderRow, phase, description string) {
	builder.WriteString(fmt.Sprintf("### %s: %s\n\n", phase, description))
	for _, row := range rows {
		if row.PhaseOwner != phase {
			continue
		}
		builder.WriteString(fmt.Sprintf("- `%s` - `%s` (%s)\n", row.Chart, row.Class, row.Status))
	}
	builder.WriteString("\n")
}

func phaseOwner(chart string) string {
	switch chart {
	case "tracer", "underwriter", "flowker", "matcher", "product-console", "go-boilerplate-ddd", "plugin-bc-correios", "plugin-br-bank-transfer", "plugin-br-payments":
		return "Phase 2"
	default:
		return "Phase 3"
	}
}

func copyDir(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
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
