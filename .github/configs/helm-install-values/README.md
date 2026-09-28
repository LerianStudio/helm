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
defaults when it has none.

## Access Manager licensed CI

`plugin-access-manager` deep install requires two optional repository/organization
GitHub Actions secrets (optional for other charts, **required for this chart**):

- `PLUGIN_ACCESS_MANAGER_CI_LICENSE_KEY`: an approved CI license valid for the
  Access Manager auth and identity binaries under test, including `origin/main`.
- `PLUGIN_ACCESS_MANAGER_CI_ORGANIZATION_IDS`: the corresponding organization IDs
  in the application's expected comma-separated string format.

Never commit their values to fixtures. The workflow passes these secrets only on
`pull_request` events whose head repository equals the current repository and is
not a fork. Fork PRs receive neither value and retain shallow `--no-hooks`,
no-wait manifest validation, **not** licensed startup/readiness coverage. Dispatch
runs do not receive licensing secrets; dispatching Access Manager therefore fails
its deep preflight. Use an authorized same-repository PR for licensed CI.

The prerequisite check runs before registry login or kind creation. An absent,
empty, or whitespace-only required secret fails with its **name**, never its value.
Presence alone is not license validation: an expired, invalid, mismatched, or
unreachable license still fails real application startup/readiness. This is not
an allow-listed failure, and no TEST/ENV/development switch bypasses enforcement.

For Access Manager deep installs only, `install-test.sh` creates a JSON
(YAML-compatible) overlay under `RUNNER_TEMP`, with an unpredictable name and mode
`0600`. Python reads the environment and preserves strings without shell/YAML
interpolation. The overlay contains only `auth.secrets.LICENSE_KEY`,
`auth.secrets.ORGANIZATION_IDS`, and identical `identity.secrets` entries. It is
last in values precedence for PR render/fresh install, PR-to-PR upgrade, baseline
render/install, and baseline-to-PR upgrade. The baseline still loads **its own**
render/install fixtures from `origin/main`; PR fixtures are never substituted.
Explicit PR values remain supported, with licensing layered last.

The overlay path, not secret values, is passed to Helm. Shell tracing is disabled;
Helm/kubectl output is scrubbed for raw, JSON-escaped, and base64 credential forms,
including workload diagnostics. Helm and kubectl do not inherit the licensing
environment. Other charts and shallow installs never receive the overlay.
An EXIT trap removes it after success or failure; INT/TERM also exit through that
trap. Abrupt runner termination/SIGKILL requires runner teardown, so never retain
or upload runner temporary directories as artifacts. The normal throwaway
cluster cleanup removes the test releases and their Kubernetes Secrets; Helm
release data and chart Secrets contain the license while the test runs.

Offline verification (synthetic canaries; mocked Git, Helm, and kubectl; no
containers, cluster calls, or real credential reads):

```sh
python3 -m unittest discover -s .github/scripts/tests -p 'test_plugin_access_manager_install_preflight.py' -v
```

Provisioning approved secrets, license-gateway connectivity, registry access, and
a real successful install/readiness/upgrade run remain operational prerequisites.
Offline tests do not establish deployment success.
