# Helm Upgrade from v2.0.0 to v2.0.1

This is a patch release that updates only the chart version metadata. No configuration changes, template modifications, or operational impacts are introduced.

## Summary

| Aspect | Details |
|--------|---------|
| **Chart version change** | 2.0.0 → 2.0.1 |
| **App version** | 1.0.0 (unchanged) |
| **Breaking changes** | None |
| **Action required** | No |

This release contains no functional changes to templates, values, or application behavior. The version bump is purely administrative.

## Preview changes before upgrading

```bash
helm diff upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.0.1 -n go-boilerplate-ddd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.0.1 -n go-boilerplate-ddd
```
