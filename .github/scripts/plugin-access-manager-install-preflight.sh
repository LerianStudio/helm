#!/usr/bin/env bash
# CI-only prerequisite gate; never changes chart values or license policy.
# Usage: plugin-access-manager-install-preflight.sh <deep|shallow> [chart ...]
# Presence is not license validation: the real binaries still validate at startup.
set +x
set -euo pipefail

mode="${1:-}"
case "$mode" in
  deep|shallow) shift ;;
  *) printf '%s\n' '::error::License preflight requires mode deep or shallow.' >&2; exit 1 ;;
esac

for chart in "$@"; do
  [[ "$chart" == plugin-access-manager ]] || continue
  if [[ "$mode" == shallow ]]; then
    printf '%s\n' '::notice::[plugin-access-manager] Shallow manifest validation only; licensed startup and upgrade readiness are not tested.'
    exit 0
  fi
  missing=()
  for name in PLUGIN_ACCESS_MANAGER_CI_LICENSE_KEY PLUGIN_ACCESS_MANAGER_CI_ORGANIZATION_IDS; do
    [[ "${!name:-}" =~ [^[:space:]] ]] || missing+=("$name")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '::error::[plugin-access-manager] Missing licensed CI prerequisite: %s. Configure approved CI secrets for auth and identity in PR and origin/main installs; no readiness or upgrade coverage is claimed.\n' "${missing[*]}" >&2
    exit 1
  fi
  exit 0
done
