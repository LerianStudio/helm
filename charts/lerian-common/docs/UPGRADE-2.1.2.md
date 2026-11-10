# Helm Upgrade from v2.1.1 to v2.1.2

## Topics ToC

- **[Fixes](#fixes)**
  - [1. AWS IAM Roles Anywhere Sidecar Security Hardening](#1-aws-iam-roles-anywhere-sidecar-security-hardening)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. AWS IAM Roles Anywhere Sidecar Security Hardening

The `lerian-common.rolesAnywhere.sidecar` helper has been updated to include a `seccompProfile` in the container's security context, aligning with Kubernetes security best practices.

#### What changed

The `aws-signing-helper` sidecar container now includes a seccomp profile configuration:

**Before (v2.1.1):**

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
resources:
  # ...
```

**After (v2.1.2):**

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
  # ...
```

#### Why it matters

The `seccompProfile` restricts the system calls that the container can make, reducing the attack surface. Setting `type: RuntimeDefault` applies the container runtime's default seccomp profile, which blocks potentially dangerous system calls while allowing normal application behavior.

This change improves the security posture of workloads using AWS IAM Roles Anywhere integration without requiring any configuration changes from operators.

#### Operational impact

> **Important:** This is a library chart (type: library) that is consumed as a dependency by other charts. It does not deploy resources directly.

**For operators:**

- **No action required.** This change is automatically applied when product charts that consume `lerian-common.rolesAnywhere.sidecar` are upgraded to use `lerian-common` v2.1.2.
- The seccomp profile is applied only to the `aws-signing-helper` sidecar container, not to application containers.
- If your Kubernetes cluster does not support seccomp profiles (Kubernetes < 1.19), the field will be ignored without causing errors.

**For chart maintainers:**

If your product chart uses the `lerian-common.rolesAnywhere.sidecar` helper, update your `Chart.yaml` dependency to v2.1.2:

```yaml
dependencies:
  - name: lerian-common
    version: 2.1.2
    repository: oci://registry-1.docker.io/lerianstudio
```

Then update dependencies:

```bash
helm dependency update
```

The rendered output will automatically include the seccomp profile in the sidecar's security context.

#### Documentation updates

The template file comments have been simplified to remove implementation notes that are no longer relevant. The functional behavior and usage contract remain unchanged.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.1.2 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of this update, run `helm diff` on the **product charts** that consume it after updating their `lerian-common` dependency to v2.1.2.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.1.2 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update it as a dependency in your umbrella or product chart's `Chart.yaml` to version 2.1.2 and run `helm dependency update`.
