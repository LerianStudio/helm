package main

import "testing"

// A key that names which secret manager the app reads (its backend, store or
// provider) carries a selector such as "aws" or "vault", not a credential, so it
// belongs in a ConfigMap. Credential keys keep failing the rule.
func TestIsTemplateSecretKeyNamesOfASecretManager(t *testing.T) {
	cases := map[string]bool{
		"ANTIFRAUD_SECRETS_BACKEND": false,
		"SECRETS_BACKEND":           false,
		"SECRET_STORE_PROVIDER":     false,
		"SECRETS_PROVIDER":          false,
		"VAULT_SECRET_STORE":        false,
		"CLIENT_SECRET":             true,
		"WEBHOOK_SIGNING_SECRET":    true,
		"DB_PASSWORD":               true,
		"API_KEY":                   true,
		"SECRET_KEY":                true,
	}
	for key, want := range cases {
		if got := isTemplateSecretKey(key); got != want {
			t.Errorf("isTemplateSecretKey(%q) = %v, want %v", key, got, want)
		}
	}
}
