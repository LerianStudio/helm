# Helm Upgrade from v8.0.1 to v8.0.2

# Topics

- ***[Security Enhancements](#security-enhancements)***
    - [1. Seccomp Profile for AWS Roles Anywhere Sidecar](#1-seccomp-profile-for-aws-roles-anywhere-sidecar)
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Security Enhancements

### 1. Seccomp Profile for AWS Roles Anywhere Sidecar

The AWS Roles Anywhere sidecar container now includes a seccomp profile configuration, enhancing the security posture by restricting system calls available to the container.

**Template change:**

**Before (v8.0.1):**

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
resources:
  {{- toYaml .Values.aws.rolesAnywhere.sidecar.resources | nindent 12 }}
```

**After (v8.0.2):**

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
resources:
  {{- toYaml .Values.aws.rolesAnywhere.sidecar.resources | nindent 12 }}
```

**Why this matters:**

The `RuntimeDefault` seccomp profile applies the container runtime's default seccomp policy, which blocks potentially dangerous system calls. This reduces the attack surface of the sidecar container by limiting the kernel APIs it can access, aligning with Kubernetes security best practices and pod security standards.

**Migration impact:**

- This change is **automatic** and requires no configuration changes from operators
- The sidecar container will be subject to seccomp restrictions after upgrade
- If your cluster or container runtime does not support seccomp profiles, the pod may fail to start (rare in modern Kubernetes clusters v1.19+)
- This change only affects deployments where `aws.rolesAnywhere.enabled` is set to `true`

> **Note:** This security enhancement is transparent to most operators. If you encounter pod startup failures after upgrade, verify that your Kubernetes cluster and container runtime support seccomp profiles (standard in Kubernetes 1.19+).

> **Important:** This change does not affect the main application container, only the AWS Roles Anywhere sidecar. If you are not using AWS Roles Anywhere integration (`aws.rolesAnywhere.enabled: false`), this change has no impact on your deployment.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.2 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.2 -n plugin-fees
```
