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

## What belongs here

- env the workload reads at boot but the template does not require
- credentials for a bundled subchart, when the app needs them to connect
- `resources.requests` trimmed to fit a single-node cluster
- `replicaCount: 1`
- optional components switched off — nothing that has no business starting in CI

## What does not

Do not use these files to paper over a chart defect. If a chart cannot install
because the chart itself is wrong, that is the finding: fix the chart, or record it
in `../helm-install-test-allow-failure.txt` with a one-line reason and leave the
gate reporting it as a known failure.

A chart with no file here is installed with its render values alone, or with chart
defaults when it has none.
