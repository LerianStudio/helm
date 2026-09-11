# helm-install-values

Overlay values for `helm-install-test.yml`, layered **on top of**
`../helm-render-values/<chart>.yaml` — never instead of it. Add a file here only
when a chart cannot come up on a single-node kind cluster as rendered, and keep it
to the smallest override that fixes that:

- trimming `resources.requests` so the pods actually get scheduled
- lowering `replicaCount` to 1
- turning off an optional component that has no business starting in CI

Do **not** use these files to paper over a chart defect. If a chart cannot install,
that is the finding — either fix the chart or add it to
`../helm-install-test-allow-failure.txt` with a one-line reason.

A chart with no file here is installed with its render values alone.
