# Helm Upgrade from v1.0.0 to v1.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. File-based credentials support for API](#1-file-based-credentials-support-for-api)
  - [2. UI nginx configuration directory fix](#2-ui-nginx-configuration-directory-fix)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.1.0 introduces support for mounting file-based credentials into the API container and fixes a runtime issue with the UI's nginx configuration when `readOnlyRootFilesystem` is enabled.

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| API file-based credentials | Not supported | Supported via `extraVolumes` and `extraVolumeMounts` |
| UI nginx conf.d mount | Not present (crash-loop with read-only root) | Writable emptyDir mount |

> **Note:** This is a minor release with no breaking changes. Existing deployments will continue to work without modification.

## Features

### 1. File-based credentials support for API

The API component now supports mounting file-based credentials (certificates, keys, SASL configuration files) via `api.extraVolumes` and `api.extraVolumeMounts`. This enables the API to read credentials from disk for:

- **Kafka SASL_SSL authentication**: CA certificates and SCRAM credential files referenced by `STREAMING_KAFKA_*_FILE` environment variables
- **ICP-Brasil A1 client certificates**: Client certificate and private key files for Dataprev integration referenced by `DATAPREV_CERT_FILE` and `DATAPREV_KEY_FILE` environment variables

**New configuration fields:**

| Flag | Default | Description |
|------|---------|-------------|
| `api.extraVolumes` | `[]` | Additional volumes to mount in the API pod |
| `api.extraVolumeMounts` | `[]` | Additional volume mounts for the API container |

**Before (v1.0.0):**

The API deployment template did not support custom volumes or volume mounts. Operators could not mount file-based credentials.

```yaml
spec:
  template:
    spec:
      containers:
        - name: api
          # ... container spec
          resources:
            {{- toYaml .Values.api.resources | nindent 12 }}
      {{- with .Values.api.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

**After (v1.1.0):**

The API deployment template now includes conditional `volumeMounts` and `volumes` blocks:

```yaml
spec:
  template:
    spec:
      containers:
        - name: api
          # ... container spec
          resources:
            {{- toYaml .Values.api.resources | nindent 12 }}
          {{- with .Values.api.extraVolumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.api.extraVolumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.api.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

**Operational impact:**

Operators can now mount Secrets containing file-based credentials into the API container. The API reads these files at runtime using environment variables that reference file paths.

**Example: Mounting Kafka SASL credentials**

Create a Secret containing the Kafka CA certificate and SCRAM credentials:

```bash
kubectl create secret generic kafka-sasl-credentials \
  --from-file=ca.crt=/path/to/kafka-ca.crt \
  --from-file=scram-username=/path/to/username.txt \
  --from-file=scram-password=/path/to/password.txt \
  -n br-consignado-gw
```

Configure the API to mount the Secret and reference the files:

```yaml
api:
  enabled: true
  configmap:
    STREAMING_KAFKA_CA_FILE: "/etc/kafka/ca.crt"
    STREAMING_KAFKA_SCRAM_USERNAME_FILE: "/etc/kafka/scram-username"
    STREAMING_KAFKA_SCRAM_PASSWORD_FILE: "/etc/kafka/scram-password"
  extraVolumes:
    - name: kafka-sasl
      secret:
        secretName: kafka-sasl-credentials
  extraVolumeMounts:
    - name: kafka-sasl
      mountPath: /etc/kafka
      readOnly: true
```

**Example: Mounting ICP-Brasil A1 client certificate**

Create a Secret containing the client certificate and private key:

```bash
kubectl create secret generic dataprev-client-cert \
  --from-file=client.crt=/path/to/client.crt \
  --from-file=client.key=/path/to/client.key \
  -n br-consignado-gw
```

Configure the API to mount the Secret and reference the files:

```yaml
api:
  enabled: true
  configmap:
    DATAPREV_CERT_FILE: "/etc/dataprev/client.crt"
    DATAPREV_KEY_FILE: "/etc/dataprev/client.key"
  extraVolumes:
    - name: dataprev-cert
      secret:
        secretName: dataprev-client-cert
  extraVolumeMounts:
    - name: dataprev-cert
      mountPath: /etc/dataprev
      readOnly: true
```

> **Important:** The operator is responsible for creating and managing the Secrets containing file-based credentials. The chart does not generate these Secrets automatically. Use external secret management tools (e.g. ArgoCD Vault Plugin, External Secrets Operator) to provision Secrets from a secure vault.

> **Note:** The `extraVolumes` and `extraVolumeMounts` fields accept raw YAML and are passed directly to the pod and container specs using `toYaml`. Ensure the YAML structure matches Kubernetes volume and volumeMount specifications.

### 2. UI nginx configuration directory fix

The UI deployment now mounts `/etc/nginx/conf.d` as a writable emptyDir to prevent crash-loops when `readOnlyRootFilesystem: true` is enabled.

**Background:**

The UI image uses `nginxinc/nginx-unprivileged`, which renders configuration templates from `/etc/nginx/templates/*` into `/etc/nginx/conf.d` at container startup using `envsubst`. With `readOnlyRootFilesystem: true`, the nginx entrypoint cannot write to `/etc/nginx/conf.d`, causing the container to crash-loop with a permission denied error.

**Before (v1.0.0):**

The UI deployment only mounted `/tmp` as an emptyDir:

```yaml
spec:
  template:
    spec:
      containers:
        - name: ui
          # ... container spec
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

**After (v1.1.0):**

The UI deployment now mounts both `/tmp` and `/etc/nginx/conf.d` as emptyDirs:

```yaml
spec:
  template:
    spec:
      containers:
        - name: ui
          # ... container spec
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            # The nginx-unprivileged entrypoint renders /etc/nginx/templates/*
            # into conf.d at boot (envsubst); with readOnlyRootFilesystem the
            # write fails and the container crash-loops, so conf.d is a
            # writable emptyDir.
            - name: nginx-conf
              mountPath: /etc/nginx/conf.d
      volumes:
        - name: tmp
          emptyDir: {}
        - name: nginx-conf
          emptyDir: {}
```

**Operational impact:**

The UI container will now start successfully with `readOnlyRootFilesystem: true` (the default security context). No operator action is required.

> **Note:** This change is transparent to operators. Existing UI deployments will automatically receive the new volume mount on upgrade.

## Configuration Reference

**New API fields:**

```yaml
api:
  # Extra pod volumes / container mounts for file-shaped credentials the API
  # reads from disk (Kafka SASL_SSL CA + SCRAM files via STREAMING_KAFKA_*_FILE,
  # ICP-Brasil A1 client certificate via DATAPREV_CERT_FILE/DATAPREV_KEY_FILE).
  # The operator supplies the Secret (e.g. an AVP-rendered raw resource).
  extraVolumes: []
  extraVolumeMounts: []
```

**Example with multiple credential types:**

```yaml
api:
  enabled: true
  configmap:
    STREAMING_KAFKA_CA_FILE: "/etc/kafka/ca.crt"
    STREAMING_KAFKA_SCRAM_USERNAME_FILE: "/etc/kafka/scram-username"
    STREAMING_KAFKA_SCRAM_PASSWORD_FILE: "/etc/kafka/scram-password"
    DATAPREV_CERT_FILE: "/etc/dataprev/client.crt"
    DATAPREV_KEY_FILE: "/etc/dataprev/client.key"
  extraVolumes:
    - name: kafka-sasl
      secret:
        secretName: kafka-sasl-credentials
    - name: dataprev-cert
      secret:
        secretName: dataprev-client-cert
  extraVolumeMounts:
    - name: kafka-sasl
      mountPath: /etc/kafka
      readOnly: true
    - name: dataprev-cert
      mountPath: /etc/dataprev
      readOnly: true
```

## Migration Steps

No migration steps are required. This release is backward-compatible with v1.0.0 configurations.

**Optional: Add file-based credentials**

If your deployment requires file-based credentials (Kafka SASL_SSL or ICP-Brasil A1 client certificates), follow these steps:

1. Create a Secret containing the credential files:

```bash
kubectl create secret generic <secret-name> \
  --from-file=<key>=<path-to-file> \
  -n br-consignado-gw
```

2. Update your `values.yaml` to mount the Secret and configure the API environment variables:

```yaml
api:
  configmap:
    <ENV_VAR_FILE>: "/path/to/mounted/file"
  extraVolumes:
    - name: <volume-name>
      secret:
        secretName: <secret-name>
  extraVolumeMounts:
    - name: <volume-name>
      mountPath: /path/to/mount
      readOnly: true
```

3. Upgrade the chart:

```bash
helm upgrade br-consignado-gw oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm \
  --version 1.1.0 \
  -n br-consignado-gw \
  -f values.yaml
```

> **Note:** Replace `<secret-name>`, `<volume-name>`, `<ENV_VAR_FILE>`, and file paths with your actual values.

## Preview changes before upgrading

```bash
helm diff upgrade br-consignado-gw oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm --version 1.1.0 -n br-consignado-gw
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-consignado-gw oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm --version 1.1.0 -n br-consignado-gw
```
