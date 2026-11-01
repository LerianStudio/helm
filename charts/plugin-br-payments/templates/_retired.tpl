{{/* Keys this chart used to render that the application renamed or no longer reads.
     Refused with the fix in the message: the ConfigMap is template-owned, so a
     leftover key would otherwise be dropped without a trace. */}}
{{- define "plugin-br-payments.validateRetiredKeys" -}}
{{- $cm := .Values.app.configmap | default dict -}}
{{- $sec := .Values.app.secrets | default dict -}}
{{- if hasKey $cm "MULTI_TENANCY_ENABLED" }}{{- fail "\n\nERROR: app.configmap.MULTI_TENANCY_ENABLED was RENAMED to app.configmap.MULTI_TENANT_ENABLED.\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "MULTI_TENANT_MANAGER_URL" }}{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_MANAGER_URL was RENAMED to app.configmap.MULTI_TENANT_URL.\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "MULTI_TENANT_CLIENT_TIMEOUT_SEC" }}{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_CLIENT_TIMEOUT_SEC was RENAMED to app.configmap.MULTI_TENANT_TIMEOUT.\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "MULTI_TENANT_CACHE_TTL_MINUTES" }}{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_CACHE_TTL_MINUTES was RENAMED to app.configmap.MULTI_TENANT_CACHE_TTL_SEC (in seconds).\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "MULTI_TENANT_CB_THRESHOLD" }}{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_CB_THRESHOLD was RENAMED to app.configmap.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD.\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "MULTI_TENANT_CB_TIMEOUT_SEC" }}{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_CB_TIMEOUT_SEC was RENAMED to app.configmap.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC.\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "MIDAZ_ONBOARDING_URL" }}{{- fail "\n\nERROR: app.configmap.MIDAZ_ONBOARDING_URL was RENAMED to app.configmap.MIDAZ_LEDGER_URL (one URL serves onboarding and transaction).\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "MIDAZ_TRANSACTION_URL" }}{{- fail "\n\nERROR: app.configmap.MIDAZ_TRANSACTION_URL was RENAMED to app.configmap.MIDAZ_LEDGER_URL (one URL serves onboarding and transaction).\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "OUTBOX_ENABLED" }}{{- fail "\n\nERROR: app.configmap.OUTBOX_ENABLED is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "OUTBOX_TABLE_NAME" }}{{- fail "\n\nERROR: app.configmap.OUTBOX_TABLE_NAME is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "CIRCUIT_BREAKER_ENABLED" }}{{- fail "\n\nERROR: app.configmap.CIRCUIT_BREAKER_ENABLED is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "RATE_LIMIT_READ" }}{{- fail "\n\nERROR: app.configmap.RATE_LIMIT_READ is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "RATE_LIMIT_WRITE" }}{{- fail "\n\nERROR: app.configmap.RATE_LIMIT_WRITE is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "RECONCILIATION_LOOKBACK_HOURS" }}{{- fail "\n\nERROR: app.configmap.RECONCILIATION_LOOKBACK_HOURS is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "EXAMPLE_STATUS_PROVIDER_MODE" }}{{- fail "\n\nERROR: app.configmap.EXAMPLE_STATUS_PROVIDER_MODE is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "RECONCILIATION_MAX_PROVIDER_PAGES" }}{{- fail "\n\nERROR: app.configmap.RECONCILIATION_MAX_PROVIDER_PAGES is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $cm "TRUSTED_PROXIES" }}{{- fail "\n\nERROR: app.configmap.TRUSTED_PROXIES is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
{{- if hasKey $sec "BTG_CLIENT_ID" }}{{- fail "\n\nERROR: app.secrets.BTG_CLIENT_ID was RENAMED to app.secrets.PROVIDER_CLIENT_ID.\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $sec "BTG_CLIENT_SECRET" }}{{- fail "\n\nERROR: app.secrets.BTG_CLIENT_SECRET was RENAMED to app.secrets.PROVIDER_CLIENT_SECRET.\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- if hasKey $sec "BTG_WEBHOOK_SECRET" }}{{- fail "\n\nERROR: app.secrets.BTG_WEBHOOK_SECRET was RENAMED to app.secrets.BTG_WEBHOOK_HMAC_SECRET (the bearer mechanism was retired; the HMAC secret authenticates the webhook).\n   Rename the key in your values overlay.\n" }}{{- end }}
{{- end -}}
