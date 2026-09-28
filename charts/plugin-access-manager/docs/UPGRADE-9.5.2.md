# Helm Upgrade from v9.5.1 to v9.5.2

# Topics

- **[Fixes](#fixes)**
  - [1. Database Password Secret Management](#1-database-password-secret-management)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Database Password Secret Management

This release fixes how the auth database password Secret is managed across Helm releases, particularly during uninstall and reinstall scenarios.

**What changed:**

The chart now creates and manages its own Secret for the `auth-database` subchart password (`<release>-auth-database`) with a `helm.sh/resource-policy: keep` annotation. This Secret persists across uninstalls, matching the lifecycle of the database's PersistentVolume.

| Component | v9.5.1 | v9.5.2 |
|-----------|--------|--------|
| Secret ownership | Subchart creates ephemeral Secret | Parent chart creates kept Secret |
| Secret lifecycle | Deleted on `helm uninstall` | Kept on `helm uninstall` |
| Reinstall behavior | New password generated, old data inaccessible | Same password reused, old data accessible |
| Template location | (subchart internal) | `templates/auth-database/secrets.yaml` |

**Why this matters:**

In v9.5.1, if you uninstalled the chart and reinstalled it with the same release name, a new random password was generated, but the kept PersistentVolume still held data initialized with the previous password. The database started, but caradhras and the identity service failed with `password authentication failed for user "auth"`.

In v9.5.2, the password Secret is kept across uninstalls (just like the PVC), so a reinstall with the same name will reuse the existing password and successfully connect to the existing data.

**Default behavior:**

The chart now sets a default value for `auth-database.auth.existingSecret` that evaluates to the Secret name only when rendering inside the subchart:

```yaml
auth-database:
  auth:
    existingSecret: '{{ if eq .Chart.Name "auth-database" }}{{ include "common.names.fullname" . }}{{ end }}'
```

This template expression:
- Renders to `<release>-auth-database` when the subchart processes it
- Renders to an empty string when the parent chart's templates process it
- Allows the parent chart to create the Secret while the subchart consumes it

**Before (v9.5.1):**

```yaml
# values.yaml
auth-database:
  auth:
    username: "auth"
    password: ""
    database: "casdoor"
    # No existingSecret — subchart creates its own ephemeral Secret
```

**After (v9.5.2):**

```yaml
# values.yaml
auth-database:
  auth:
    username: "auth"
    password: ""
    database: "casdoor"
    # Default points subchart at the Secret this chart keeps
    existingSecret: '{{ if eq .Chart.Name "auth-database" }}{{ include "common.names.fullname" . }}{{ end }}'
```

**Operational impact:**

- **New installations:** No action required. The Secret will be created with `resource-policy: keep` automatically.
- **Upgrades from v9.5.1:** The upgrade will create the new kept Secret. If you later uninstall and reinstall, your database data will remain accessible.
- **External database users:** With `auth-database.enabled=false` the chart renders no `<release>-auth-database` Secret and nothing changes. With `auth-database.external=true` while `auth-database.enabled` stays `true`, the bundled subchart is still rendered, so the chart also renders the kept `<release>-auth-database` Secret (see Scenario 2).

> **Important:** If you have already set `auth-database.auth.existingSecret` to your own Secret name in v9.5.1, you must continue to manage that Secret yourself. The chart will respect your existing configuration and will not create its own Secret.

**Limitations:**

The kept Secret only supports the default password keys (`postgres-password`, `password`, `replication-password`). If you need custom `secretKeys` or LDAP bind passwords, you must provide your own `existingSecret`:

```yaml
auth-database:
  auth:
    existingSecret: my-custom-db-secret
    secretKeys:
      adminPasswordKey: custom-admin-key
      userPasswordKey: custom-user-key
```

> **Note:** If you set `auth-database.auth.existingSecret` to an empty string (`""`), the chart will fail with an error. Leave it unset to use the default kept Secret, or provide your own Secret name.

**Template changes:**

The helper function `plugin-auth.dbPasswordEnv` now uses a new helper `plugin-access-manager.operatorDbSecret` to determine if an operator has provided their own Secret:

**Before (v9.5.1):**

```yaml
{{- define "plugin-auth.dbPasswordEnv" -}}
{{- $dbAuth := default dict $db.auth -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
    {{- if $dbAuth.existingSecret }}
      name: {{ $dbAuth.existingSecret }}
      key: password
    {{- else if $internal }}
      name: {{ include "common.names.dependency.fullname" ... }}
      key: password
    {{- else }}
      name: {{ include "plugin-access-manager.fullname" $ctx }}-auth
      key: DB_PASSWORD
    {{- end }}
{{- end }}
```

**After (v9.5.2):**

```yaml
{{- define "plugin-auth.dbPasswordEnv" -}}
{{- $opSecret := include "plugin-access-manager.operatorDbSecret" $ctx -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
    {{- if $opSecret }}
      name: {{ $opSecret }}
      key: password
    {{- else if $internal }}
      name: {{ include "common.names.dependency.fullname" ... }}
      key: password
    {{- else }}
      name: {{ include "plugin-access-manager.fullname" $ctx }}-auth
      key: DB_PASSWORD
    {{- end }}
{{- end }}

{{- define "plugin-access-manager.operatorDbSecret" -}}
{{- tpl (dig "auth" "existingSecret" "" (index .Values "auth-database" | default dict) | toString) . -}}
{{- end }}
```

The new helper properly evaluates the templated `existingSecret` value to determine if it resolves to a Secret name in the parent chart's context (empty string = use the chart's kept Secret).

**Migration scenarios:**

#### Scenario 1: Standard installation (bundled database)

No action required. The upgrade will create the kept Secret automatically.

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.2 -n plugin-access-manager
```

#### Scenario 2: Using an external database

No action required, but the result depends on `auth-database.enabled`:

- `auth-database.enabled: false`: no `<release>-auth-database` Secret is rendered. The applications read `DB_PASSWORD` from the chart's auth Secret (`auth.secrets.DB_PASSWORD`) or from your `existingSecret`, as in v9.5.1.
- `auth-database.external: true` with `auth-database.enabled` left `true`: the kept Secret template checks only `enabled`, not `external`, so `<release>-auth-database` is still rendered with `helm.sh/resource-policy: keep`. The applications still read the external password as in v9.5.1. The kept Secret is unused and stays after `helm uninstall`; delete it manually if you don't need it. Set `auth-database.enabled: false` to render neither the subchart nor the Secret.

```yaml
auth-database:
  enabled: false
  external: true
  # ... external connection details
```

#### Scenario 3: Already using a custom existingSecret

No action required. The chart will continue to use your Secret.

```yaml
auth-database:
  auth:
    existingSecret: my-company-db-secret
```

> **Warning:** Do not set `auth-database.auth.existingSecret` to an empty string or `null`. The render fails with `auth-database.auth.existingSecret is empty: leave it unset to use the Secret this chart keeps, or name your own Secret`. Either leave it unset (to use the default) or provide a Secret name.

#### Scenario 4: Upgrading with `--reuse-values` or with a full values dump

**Action required.** `helm upgrade --reuse-values` rebuilds the values from the previous release's chart, including the bundled PostgreSQL subchart's defaults, and uses them instead of the new chart's `values.yaml`. The subchart's default is `auth.existingSecret: ""`, so an upgrade from v9.5.1 or earlier with `--reuse-values` renders an explicitly empty `auth-database.auth.existingSecret` and fails with the error above. The same happens with a values file generated by `helm get values --all`, or one copied from the subchart's defaults.

Before upgrading, either:

- drop `--reuse-values` and pass your values files explicitly (`-f values.yaml`), or
- remove `existingSecret: ""` from `auth-database.auth` in your values file, or set it to your own Secret name.

The render fails before anything is applied, so a failed attempt changes nothing in the cluster.

#### Scenario 5: Argo CD or other `helm template` based deployments

Argo CD renders the chart with `helm template`, where the chart cannot read the existing Secret. With the bundled database and no `auth-database.auth.password` (and no `existingSecret`), every render generates a new random password. That was already true of the subchart's Secret in v9.5.1. From v9.5.5 on, caradhras also carries a `checksum/auth-database-secret` pod annotation, so each new render also restarts caradhras with a password the database does not know. Argo CD installs must set `auth-database.auth.password` or `auth-database.auth.existingSecret`.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.2 -n plugin-access-manager
```
