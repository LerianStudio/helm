# Plugin-bc-correios Changelog

## [4.0.3](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.3)

Fixes:
- Ensure that `bc-correios` pods are rolled on configuration changes to maintain consistency and reliability. (@fredcamaral)

Improvements:
- Remove repeated release sections from the changelogs to enhance clarity and readability. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.2...plugin-bc-correios-v4.0.3)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Fixes:

- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container with only its necessary Postgres settings to enhance security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a connection change to maintain consistency and clarity. (@fredcamaral)
- Schedule the migrations job in a manner similar to the app, ensuring ArgoCD remains clean and organized. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Ensure database migrations run before the app starts to avoid runtime issues. (@fredcamaral)

Improvements:

- Describe the timing of the migrations job in the documentation to provide clearer guidance for users. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.1)

Fixes:

- Tightened guards and updated documentation for `plugin-bc-correios` `1.1.0`. (@fredcamaral)
- Moved `plugin-bc-correios` to app `1.1.0`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.0...plugin-bc-correios-v4.0.1)

---

## [4.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.0)

Features:

Fixes:
- Render both authentication host names for the plugin. (@fredcamaral)
- Read the `LICENSE_KEY` from an existing secret. (@fredcamaral)
- Render broker credentials as strings. (@fredcamaral)
- Run the plugin in production mode by default. (@fredcamaral)
- Keep rendering `ENV_NAME` for the plugin. (@fredcamaral)
- Render the environment names that the application reads. (@fredcamaral)

Improvements:
- Fix RabbitMQ migration steps for an existing secret in the documentation. (@fredcamaral)
- State the RabbitMQ URL condition in the guide. (@fredcamaral)
- Align the upgrade guide with application environment names. (@fredcamaral)
- Correct the `3.0` upgrade guide. (@fredcamaral)
- Add verified upgrade guides for `3.0.1` to `3.0.2`. (@fredcamaral)
- Correct documentation against templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v3.0.2...plugin-bc-correios-v4.0.0)

