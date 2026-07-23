# Midaz Pull Request Checklist

## Pull Request Type
[//]: # (Check the appropriate box for the type of pull request.)

- [ ] Midaz
- [ ] Plugin Access Manager
- [ ] Plugin CRM
- [ ] Reporter
- [ ] Plugin Fees
- [ ] Plugin BR PIX Direct JD
- [ ] Plugin BR PIX Indirect BTG
- [ ] Plugin BR PIX Switch
- [ ] Plugin BR Bank Transfer
- [ ] Otel Collector
- [ ] Pipeline
- [ ] Documentation
- [ ] Fetcher
- [ ] BR STA
- [ ] BR CCS
- [ ] BR SLC

## Checklist
Please check each item after it's completed.

- [ ] I have tested these changes locally (or cut an **Alpha Release** from my branch — see below).
- [ ] I have updated the documentation accordingly.
- [ ] I have added necessary comments to the code, especially in complex areas.
- [ ] I have ensured that my changes adhere to the project's coding standards.
- [ ] I have checked for any potential security issues.
- [ ] I have ensured that all tests pass.
- [ ] This PR modifies **only one chart** (or is a single shared `pipe`/`doc` change).
- [ ] I did **not** hand-edit `Chart.yaml` `version`, `CHANGELOG.md`, or the README version matrix (CI owns these).
- [ ] I have confirmed this code is ready for review.

## Additional Notes
[//]: # (Add any additional notes, context, or explanation that could be helpful for reviewers.)

## Contribution rules (trunk-based)

- 🎯 **Target `main`.** The `develop` branch is retired — do **not** target it.
- 📦 **One chart per PR**, on a `feat/<chart>` branch. A change that touches N charts = N PRs. Shared meta (`.github/**`, root `README.md`) is its own `pipe`/`doc` PR.
- 🧪 **Test before merge with an Alpha Release.** Actions → **Helm Alpha Release** → *Run workflow* against **your branch** → set `chart`. Publishes a disposable `ghcr.io/lerianstudio/alpha/<chart>` (TTL ~3 days). Works even for a chart that only exists on your branch.
- 🏷️ **Version, CHANGELOG and README matrix are CI-owned.** semantic-release bumps them on merge based on your commit type (`feat`→minor, `fix`→patch, breaking→major). Never hand-bump.