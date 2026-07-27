# ST-3-1 — Listar tags git `<dir>-v*` e parsear em versões semver (RED → GREEN)

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Isolar o acesso ao git atrás de uma interface testável. Criar `tagLister` (interface) + `gitTagLister` (impl real via `git tag --list <dir>-v*`) e a função pura `parseTags(dir string, rawTags []string) []*semver.Version` que filtra pelo prefixo `<dir>-v`, tira o prefixo, e parseia com Masterminds/semver, DESCARTANDO strings não-semver (ex.: `midaz-v1.0.0-HELM-94.1` cujo sufixo não é semver-limpo é MANTIDO como pre-release; strings que o parser rejeita são descartadas). Segregação de pre-release vem em ST-3-2.

## Prerequisites
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ 2>&1 | tail -1
```
Saída esperada: `ok  ...`
(Se falhar, complete T-2.)

## Files
- create: `./.github/scripts/generate-compatibility/tags.go`
- create: `./.github/scripts/generate-compatibility/tags_test.go`

## Steps

### Passo 1 (RED) — Teste table-driven de parseTags
Crie `./.github/scripts/generate-compatibility/tags_test.go`:
```go
package main

import (
	"testing"
)

func versionStrings(vs []interface{ String() string }) []string {
	out := make([]string, 0, len(vs))
	for _, v := range vs {
		out = append(out, v.String())
	}
	return out
}

func TestParseTags(t *testing.T) {
	tests := []struct {
		name string
		dir  string
		raw  []string
		want []string // semver .String() values, order as returned
	}{
		{
			name: "filters by dir prefix and strips it",
			dir:  "midaz",
			raw:  []string{"midaz-v8.6.0", "midaz-v8.5.0", "plugin-fees-v7.2.0"},
			want: []string{"8.6.0", "8.5.0"},
		},
		{
			name: "keeps semver pre-releases",
			dir:  "midaz",
			raw:  []string{"midaz-v8.6.0-beta.11", "midaz-v8.6.0"},
			want: []string{"8.6.0-beta.11", "8.6.0"},
		},
		{
			name: "drops tags whose suffix is not parseable semver",
			dir:  "midaz",
			raw:  []string{"midaz-vLATEST", "midaz-v8.6.0", "midaz-vnightly"},
			want: []string{"8.6.0"},
		},
		{
			name: "does not match a different dir that shares a prefix boundary",
			dir:  "plugin-fees",
			raw:  []string{"plugin-fees-v7.2.0", "plugin-fees-helm-v1.0.0"},
			// "plugin-fees-helm-v1.0.0" has prefix "plugin-fees-v"? No: after
			// "plugin-fees-v" the remainder would be "..." only if the tag is
			// literally plugin-fees-v<semver>. "plugin-fees-helm-v1.0.0" does
			// NOT start with "plugin-fees-v", so it is excluded.
			want: []string{"7.2.0"},
		},
		{
			name: "empty input",
			dir:  "br-spi",
			raw:  []string{},
			want: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseTags(tt.dir, tt.raw)
			gotStr := make([]string, 0, len(got))
			for _, v := range got {
				gotStr = append(gotStr, v.String())
			}
			if len(gotStr) != len(tt.want) {
				t.Fatalf("got %v (len %d), want %v (len %d)", gotStr, len(gotStr), tt.want, len(tt.want))
			}
			for i := range tt.want {
				if gotStr[i] != tt.want[i] {
					t.Fatalf("index %d: got %q, want %q (full got %v)", i, gotStr[i], tt.want[i], gotStr)
				}
			}
		})
	}
}
```

Rode e capture a falha:
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestParseTags 2>&1 | head -8
```
Saída esperada: `undefined: parseTags` e `[build failed]`.

### Passo 2 (GREEN) — Implementar tags.go
Crie `./.github/scripts/generate-compatibility/tags.go`:
```go
package main

import (
	"os/exec"
	"strings"

	"github.com/Masterminds/semver/v3"
)

// tagLister abstracts the git tag lookup so tests can inject fixtures without
// touching a real repo.
type tagLister interface {
	// listTags returns raw tag names matching the <dir>-v* glob for a chart dir.
	listTags(dir string) ([]string, error)
}

// gitTagLister is the real implementation, backed by `git tag --list`.
// It runs against the working tree at root.
type gitTagLister struct {
	root string
}

func (g gitTagLister) listTags(dir string) ([]string, error) {
	cmd := exec.Command("git", "-C", g.root, "tag", "--list", dir+"-v*")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	tags := make([]string, 0, len(lines))
	for _, l := range lines {
		if s := strings.TrimSpace(l); s != "" {
			tags = append(tags, s)
		}
	}
	return tags, nil
}

// parseTags filters raw tags to those of the form "<dir>-v<semver>", strips the
// "<dir>-v" prefix, and parses each remainder with Masterminds/semver. Tags
// whose remainder is not valid semver are dropped. Pre-releases are KEPT here;
// segregation happens later (ST-3-2). Output order mirrors input order.
func parseTags(dir string, rawTags []string) []*semver.Version {
	prefix := dir + "-v"
	out := make([]*semver.Version, 0, len(rawTags))
	for _, tag := range rawTags {
		if !strings.HasPrefix(tag, prefix) {
			continue
		}
		remainder := strings.TrimPrefix(tag, prefix)
		v, err := semver.NewVersion(remainder)
		if err != nil {
			continue
		}
		out = append(out, v)
	}
	return out
}
```

Remova o helper não usado `versionStrings` do teste se `go vet` reclamar — não é referenciado. (Deixe-o de fora: apague as linhas de `versionStrings` em tags_test.go se estiverem sinalizadas como unused. Go só reclama de imports/variáveis locais não usadas, não de funções de nível de pacote, então provavelmente fica OK; confirme com `go vet`.)

### Passo 3 — Rodar o teste
```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go test ./generate-compatibility/ -run TestParseTags 2>&1 | tail -3
```
Saída esperada: `ok  ...`.

## Verification (copiável) — impl real contra o repo
```bash
cd "$(git rev-parse --show-toplevel)" && git tag --list 'midaz-v*' | head -3
```
Saída esperada: tags reais como `midaz-v1.0.0`, `midaz-v1.0.0-HELM-94.1`, etc. (confirma que o glob `<dir>-v*` funciona no repo).

```bash
cd "$(git rev-parse --show-toplevel)/.github/scripts" && go vet ./generate-compatibility/ && go test ./generate-compatibility/ && echo "ST-3-1_OK"
```
Saída esperada: termina com `ST-3-1_OK`.

## Rollback
```bash
rm -f ./.github/scripts/generate-compatibility/tags.go \
      ./.github/scripts/generate-compatibility/tags_test.go
```
