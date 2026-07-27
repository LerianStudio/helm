package main

import (
	"testing"
)

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
