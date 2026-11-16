# Agent Changelog

## [1.0.5](https://github.com/LerianStudio/helm/releases/tag/agent-v1.0.5)

Fixes:
- Remove the chart label from the pod template to ensure proper configuration. (@fredcamaral)
- Address issues with unreachable source in the pod template. (@fredcamaral)

Improvements:
- Add the verified `1.0.4` upgrade guide to the documentation for better upgrade clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/agent-v1.0.4...agent-v1.0.5)

---

## [1.0.4](https://github.com/LerianStudio/helm/releases/tag/agent-v1.0.4)

Improvements:
- Clearly state RBAC grants in chart comments to enhance understanding. (@fredcamaral)
- Correct the cluster-scoped write comment in RBAC for accuracy. (@fredcamaral)
- Update chart documentation to align with templates and application code. (@fredcamaral)

Docs:
- Add verified upgrade guides for `1.0.3`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/agent-v1.0.3...agent-v1.0.4)

---

## [1.0.3](https://github.com/LerianStudio/helm/releases/tag/agent-v1.0.3)

Features:
- Added a Helm upgrade guide for agent `v1.0.2`. (@guimoreirar)

Improvements:
- Relicensed under Elastic License 2.0. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/agent-v1.0.2...agent-v1.0.3)

---

## [1.0.2](https://github.com/LerianStudio/helm/releases/tag/agent-v1.0.2)

Fixes:
- Update `agent@1.0.2` to address bug fixes. (@lerian-studio)

Improvements:
- Add Helm upgrade guide for `agent` `v1.0.1`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/agent-v1.0.1...agent-v1.0.2)

---

## [1.0.1](https://github.com/LerianStudio/helm/releases/tag/agent-v1.0.1)

Fixes:
- Update `agent@1.0.1` to address issues. (@bedatty, @lerian-studio)

Improvements:
- Add Helm upgrade guide for `agent` `v1.0.0`. (@guimoreirar)

[Compare changes](https://github.com/LerianStudio/helm/compare/agent-v1.0.0...agent-v1.0.1)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/agent-v1.0.0)

Features:
- Ship the agent chart with app `1.0.0`. (@bedatty)
- Expose the agent's reliability knobs and pin its image tag. (@bedatty)
- Add the agent chart for app `1.0.0-beta.1`. (@bedatty)

Fixes:
- Name the vanished agent by job and namespace in its alert. (@bedatty)
- Refuse the default ServiceAccount and alert on a vanished agent. (@bedatty)

Improvements:
- Build the agent chart on lerian-common. (@bedatty)
- Drop the agent's infra runner. (@bedatty)
- Bring the agent chart to the repository's values contract. (@bedatty)

[View all changes](https://github.com/LerianStudio/helm/commits/agent-v1.0.0)
