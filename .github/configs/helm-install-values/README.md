# helm-install-values

Per-chart values for `helm-install-test.yml`, layered **on top of**
`../helm-render-values/<chart>.yaml` — never instead of it. A chart that already
has render values does not repeat them here; only the delta belongs in this file.

Verified layering, for the record: given a render file setting `MIDAZ_BASE_URL` and
an install file setting `resources.requests`, the install produces the reduced
requests *and* keeps the configmap value from the render file.

## These are written as charts break, not up front

Nobody can reliably guess what a service needs to reach Ready — that lives in the
application, not in the chart. So this directory starts empty and fills in as the
gate finds real failures:

1. A chart fails the install test.
2. The run prints `kubectl describe` and container logs for every pod that did not
   start, plus a pointer back here.
3. Derive the fix from that output and add `<chart>.yaml`.

Do **not** pre-populate this directory by guessing. A file that looks plausible and
is wrong costs more than no file, because the next failure gets read as "the fixture
is already there, so it must be a chart defect".

One file here did not come from a failing run: `product-console.yaml`, which points
the chart's pinned `namespaceOverride` at the gate's own release namespace. A green
run was the problem. The chart deliberately leaves the MongoDB password unwired when
the console and the bundled database land in different namespaces, which is what
`-n it-<chart>` produced, so the gate installed an arm no default install takes and a
renamed Secret key would have reached an operator with every check green. Choosing
which SUPPORTED topology the gate installs is allowed, and belongs here with the
reason written in the file.

## What belongs here

- env the workload reads at boot but the template does not require
- credentials for a bundled subchart, when the app needs them to connect
- `resources.requests` trimmed to fit a single-node cluster
- `replicaCount: 1`
- optional components switched off — nothing that has no business starting in CI
- the supported topology an operator installs, when the gate's `-n it-<chart>` would
  otherwise install a different one and the difference skips a code path

## What does not

Do not use these files to paper over a chart defect. If a chart cannot install
because the chart itself is wrong, that is the finding: fix the chart, or record it
in `../helm-install-test-allow-failure.txt` with a one-line reason and leave the
gate reporting it as a known failure.

A chart with no file here is installed with its render values alone, or with chart
defaults when it has none, except for runtime credentials described below.

## Access Manager: licensed runtime fixture

`plugin-access-manager` v3.9.0 uses `lib-license-go/v4` v4.1.0. The published
binaries enforce licensing in development too. The render fixture supplies no
`ORGANIZATION_IDS`; the license constructor returns nil and middleware startup
panics with `LicenseClient is nil`. Setting a made-up organization only moves the
failure to the license gateway; it does not provide a license.

Deep installs therefore require these Actions secrets (CI-only licenses, never
production credentials):

| Actions secret | Local script environment | Helm value |
| --- | --- | --- |
| `HELM_IT_AUTH_LICENSE_KEY` | `IT_AUTH_LICENSE_KEY` | `auth.secrets.LICENSE_KEY` |
| `HELM_IT_AUTH_ORGANIZATION_IDS` | `IT_AUTH_ORGANIZATION_IDS` | `auth.secrets.ORGANIZATION_IDS` |
| `HELM_IT_IDENTITY_LICENSE_KEY` | `IT_IDENTITY_LICENSE_KEY` | `identity.secrets.LICENSE_KEY` |
| `HELM_IT_IDENTITY_ORGANIZATION_IDS` | `IT_IDENTITY_ORGANIZATION_IDS` | `identity.secrets.ORGANIZATION_IDS` |

The license issuer must authorize the configured organizations for the
`plugin-access-manager` resource: both auth and identity pass that application
name to the license client. Separate inputs allow distinct credentials, or the
same CI license can be used for both when its scope permits. Use `global` only
if the issued license is actually scoped that way. A non-empty key is a
prerequisite, not proof of validity:
the published binaries still validate against their normal gateway. There is no
mock gateway, `licensetest` build, authorization disable, or readiness exemption.

`install-test.sh` generates a mode-0600 temporary values overlay and applies it
last to all four install/upgrade legs, including the `origin/main` baseline. Only
these runtime credentials are shared; baseline chart fixtures still come from
`origin/main`. The overlay is removed on script exit and never printed. Missing
credentials fail before Helm or Kubernetes work rather than waiting for a crash
loop. Do not enable shell tracing or Helm debug output while handling credentials.
Fork/shallow runs remain manifest-only and do not require or inject licenses.

Run `python3 .github/scripts/install-test-license-values_test.py` for regression
coverage. Its Helm/Kubernetes command doubles check argument flow and cleanup;
they do not claim the application started or that a license is valid.
