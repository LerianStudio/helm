# Helm Upgrade from v4.0.5 to v4.0.6

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Improved validation for useExistingSecret](#1-improved-validation-for-useexistingsecret)
  - [2. Enhanced MongoDB Service name resolution](#2-enhanced-mongodb-service-name-resolution)
  - [3. Clearer cross-namespace Secret guidance](#3-clearer-cross-namespace-secret-guidance)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that improves validation, error messages, and documentation for operators. No breaking changes are introduced. The application version remains unchanged.

| Field | v4.0.5 | v4.0.6 |
|-------|--------|--------|
| Chart version | `4.0.5` | `4.0.6` |
| App version | `1.12.0` | `1.12.0` |

## Fixes

### 1. Improved validation for useExistingSecret

The chart now validates that `existingSecretName` is set when `useExistingSecret` is `true`, preventing a deployment failure at apply time with a clear error message at render time.

**Before (v4.0.5):**

The Deployment template used an inline conditional that allowed an empty `secretRef.name` to pass through `helm lint` and `helm template`, but the API server rejected it at apply time with a generic error that did not name the misconfigured keys.

```yaml
- secretRef:
    name: {{ if .Values.useExistingSecret }}{{ .Values.existingSecretName }}{{ else }}{{ include "product-console.fullname" . }}{{ end }}
```

**After (v4.0.6):**

A new helper template `product-console.secretName` validates the configuration and fails at render time with a clear message:

```yaml
- secretRef:
    name: {{ include "product-console.secretName" . }}
```

The helper enforces that when `useExistingSecret` is `true`, `existingSecretName` must be set to a non-empty, non-whitespace value. If the validation fails, the chart renders this error:

```
product-console: useExistingSecret is true, so existingSecretName must name the Secret holding the console's environment. Set existingSecretName, or set useExistingSecret to false to use the Secret this chart creates.
```

**Impact:**

- Operators who set `useExistingSecret: true` without setting `existingSecretName` will now see a clear error during `helm upgrade` or `helm install`, before the release reaches the API server
- Existing valid configurations (where both keys are set correctly, or `useExistingSecret` is `false`) are unaffected

### 2. Enhanced MongoDB Service name resolution

The chart now correctly resolves the MongoDB Service name when both `mongodb.architecture` is set to a replica set **and** `mongodb.service.nameOverride` is set, matching the Bitnami subchart's actual behavior.

**Before (v4.0.5):**

The chart had two separate validation blocks that each refused to render when one condition was met, but did not handle the case where both were set simultaneously. The error messages also did not reflect that `mongodb.service.nameOverride` takes precedence over the `<fullname>-headless` fallback in replica set mode.

```yaml
{{- if and (not $named) (ne $arch "standalone") -}}
{{- fail (printf "... the bundled MongoDB publishes the headless Service %s-headless.%s.svc.cluster.local ..." (include "product-console.mongodb.fullname" .) $ns) -}}
{{- end -}}
{{- if and (not $named) $svcName -}}
{{- fail (printf "... the bundled MongoDB's Service is named %s ..." $svcName) -}}
{{- end -}}
```

**After (v4.0.6):**

The chart now resolves the Service name using the same precedence logic as the Bitnami subchart: `mongodb.service.nameOverride` wins when set, and only without it does a replica set fall back to `<fullname>-headless`. A single validation block handles all three cases (replica set, nameOverride, or both) and names the actual Service the release creates:

```yaml
{{- $svc := $svcName | default (ternary (printf "%s-headless" (include "product-console.mongodb.fullname" .)) (include "product-console.mongodb.fullname" .) $replicaSet) -}}
{{- $why := list -}}
{{- if $replicaSet -}}
{{- $why = append $why (printf "mongodb.architecture is %s" $arch) -}}
{{- end -}}
{{- if $svcName -}}
{{- $why = append $why (printf "mongodb.service.nameOverride is %s" $svcName) -}}
{{- end -}}
{{- $msg := printf "product-console: %s, so the bundled MongoDB's Service is named %s and configmap.MONGO_HOST has no correct default. Set configmap.MONGO_HOST to %s.%s.svc.cluster.local." (join " and " $why) $svc $svc $ns -}}
```

**Impact:**

- Operators who set `mongodb.service.nameOverride` (with or without a replica set architecture) will now see an error message that names the correct Service to use in `configmap.MONGO_HOST`
- Operators who set both `mongodb.architecture` to a replica set **and** `mongodb.service.nameOverride` will now see a single error message that reflects the override taking precedence, instead of the chart refusing to render with a message pointing to a Service that does not exist
- Existing configurations where `configmap.MONGO_HOST` is already set are unaffected

### 3. Clearer cross-namespace Secret guidance

The NOTES.txt output now provides clearer, more actionable guidance when the console and MongoDB subchart land in different namespaces, including a concrete `helm upgrade` command and a warning about data loss.

**Before (v4.0.5):**

The NOTES.txt suggested clearing `global.namespaceOverride` or installing with `-n` set to the console's namespace, but did not explain that `helm upgrade` cannot move a release to another namespace, and did not warn that moving the subchart re-creates the database with an empty volume.

**After (v4.0.6):**

The NOTES.txt now:

- Explains that the subchart reads `global.namespaceOverride` **instead of** `-n`, so changing `-n` alone does not move it
- Provides a concrete `helm upgrade` command with `--set global.namespaceOverride=<console-namespace>` to move the subchart beside the console
- Warns that moving the subchart re-creates the database with an empty volume, and instructs operators to back up and restore data manually
- Reminds operators to repeat every other flag from the original install, because `helm upgrade` re-renders the release from the arguments provided and drops every override left out

**Example output (v4.0.6):**

```yaml
- move the subchart to 'product-console', beside the console, by naming
  that namespace in global.namespaceOverride. The subchart lands in
  global.namespaceOverride whenever that is set, and it is set here. It
  reads that value INSTEAD of -n, so changing -n alone does not move it:

    helm upgrade --install product-console \
      oci://registry-1.docker.io/lerianstudio/product-console-helm \
      --version 4.0.6 -n default \
      -f <your-values.yaml> \
      --set global.namespaceOverride=product-console

  Replace <your-values.yaml> with the values file you installed with, and
  repeat every other flag from that install: helm upgrade re-renders the
  release from the arguments you hand it and drops every override you leave
  out. The password is then wired for you.

  Moving the subchart re-creates the database. With the shipped values
  (a standalone MongoDB Deployment over one volume claim with no keep
  policy) it comes up in 'product-console' with an EMPTY volume, and
  helm deletes the volume in 'default'. Back up whatever that
  database holds before you run this, and restore it afterwards; nothing
  carries the data across for you; or
```

**Impact:**

- Operators who encounter the cross-namespace Secret issue will now see a step-by-step command to resolve it, instead of a brief suggestion
- Operators are now warned that moving the subchart destroys the existing database volume and must back up data before running the command

## Configuration Changes

No values keys were added, removed, or renamed. All changes are internal to templates and documentation.

| Setting | v4.0.5 | v4.0.6 | Notes |
|---------|--------|--------|-------|
| `useExistingSecret` | optional, defaults to `false` | optional, defaults to `false` | Now validated: when `true`, `existingSecretName` must be set |
| `existingSecretName` | optional, no validation | optional, validated when `useExistingSecret` is `true` | Must be non-empty and non-whitespace |
| `configmap.MONGO_HOST` | optional, validated for replica sets and nameOverride | optional, validated for replica sets and nameOverride | Error messages now reflect correct Service name precedence |

## Migration Steps

This upgrade requires no mandatory configuration changes. The validation improvements only affect misconfigured installations, which would have failed at apply time in v4.0.5.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. If you have set `useExistingSecret: true`, verify that `existingSecretName` is also set:

```bash
helm get values product-console -n product-console | grep -A1 useExistingSecret
```

If `existingSecretName` is empty or missing, set it before upgrading:

```yaml
useExistingSecret: true
existingSecretName: "product-console-env"
```

3. If you have set `mongodb.architecture` to a replica set or `mongodb.service.nameOverride`, verify that `configmap.MONGO_HOST` is set:

```bash
helm get values product-console -n product-console | grep -E "mongodb.architecture|mongodb.service.nameOverride|MONGO_HOST"
```

If `MONGO_HOST` is not set, the upgrade will fail with a clear error message naming the correct Service. Set it before upgrading:

```yaml
configmap:
  MONGO_HOST: "<service-name>.<namespace>.svc.cluster.local"
```

4. Run the upgrade command.

5. Verify the deployment is healthy:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Note:** This upgrade does not trigger a rolling restart unless you change values. The only changes are to validation logic, helper templates, and NOTES.txt output.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.6 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.6 -n product-console
```
