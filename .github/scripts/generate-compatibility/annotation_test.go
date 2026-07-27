package main

import (
	"reflect"
	"testing"
)

func TestParseCompatAnnotation(t *testing.T) {
	tests := []struct {
		name      string
		raw       string
		want      *CompatAnnotation
		wantError bool
	}{
		{
			name: "complete requires + testedWith",
			raw: `requires:
  midaz-helm: ">=8.4.0 <9.0.0"
testedWith:
  midaz-helm: "8.6.0"
`,
			want: &CompatAnnotation{
				Requires:   map[string]string{"midaz-helm": ">=8.4.0 <9.0.0"},
				TestedWith: map[string]string{"midaz-helm": "8.6.0"},
			},
		},
		{
			name: "only testedWith (typical v1 post-backfill)",
			raw: `testedWith:
  midaz-helm: "8.6.0"
`,
			want: &CompatAnnotation{
				TestedWith: map[string]string{"midaz-helm": "8.6.0"},
			},
		},
		{
			name: "empty string => nil (absent)",
			raw:  "",
			want: nil,
		},
		{
			name:      "broken embedded YAML => error (V1)",
			raw:       "requires:\n  midaz-helm \">=8.4.0\"\n", // missing colon
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseCompatAnnotation(tt.raw)
			if (err != nil) != tt.wantError {
				t.Fatalf("err = %v, wantError = %v", err, tt.wantError)
			}
			if tt.wantError {
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}
