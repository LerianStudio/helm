# Plugin-bc-correios Changelog

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

Fixes:
- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container only with its Postgres settings to enhance security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a connection change to maintain consistency. (@fredcamaral)
- Schedule the migrations job in alignment with the app while keeping ArgoCD clean to avoid unnecessary clutter. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Run database migrations before the app starts to ensure the app operates on the latest schema. (@fredcamaral)

Improvements:
- Describe when the migrations job runs to provide better documentation and understanding. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Fixes:
- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container with only its necessary Postgres settings to enhance security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a change in connection to maintain consistency. (@fredcamaral)
- Schedule the migrations job in alignment with the app and ensure ArgoCD remains clean. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Ensure database migrations run before the application starts to avoid potential runtime issues. (@fredcamaral)

Improvements:
- Describe the timing of the migrations job execution in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

Fixes:
- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container with only its necessary Postgres settings for better isolation. (@fredcamaral)
- Rename the migrations job when there is a connection change to maintain consistency. (@fredcamaral)
- Schedule the migrations job in the same manner as the app while keeping ArgoCD clean. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Ensure database migrations run before the application starts to avoid runtime issues. (@fredcamaral)

Improvements:
- Describe the timing of when the migrations job runs in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

- Describe when the migrations Job runs in the documentation. (@fredcamaral)

Fixes:

- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container with only its necessary Postgres settings. (@fredcamaral)
- Rename the migrations Job when there is a connection change to maintain consistency. (@fredcamaral)
- Schedule the migrations Job similarly to the app to keep ArgoCD clean and organized. (@fredcamaral)
- Ensure the migrations pod is not included in the app selectors to avoid conflicts. (@fredcamaral)
- Run database migrations before the application starts to ensure all changes are applied. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

Fixes:
- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container with only its necessary Postgres settings for improved security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a change in connection to maintain consistency. (@fredcamaral)
- Schedule the migrations job in a manner similar to the app, ensuring ArgoCD remains clean and organized. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Execute database migrations before the app starts to ensure all necessary updates are applied. (@fredcamaral)

Improvements:
- Describe the timing of when the migrations job runs in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

Fixes:
- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container only with its necessary Postgres settings to enhance security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a connection change to maintain consistency. (@fredcamaral)
- Schedule the migrations job in alignment with the app while keeping ArgoCD clean to avoid unnecessary clutter. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Ensure database migrations run before the app starts to avoid runtime errors. (@fredcamaral)

Improvements:
- Describe the timing of when the migrations job runs in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

Fixes:
- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container with only its necessary Postgres settings to enhance security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a connection change to maintain consistency. (@fredcamaral)
- Schedule the migrations job like the app to keep ArgoCD clean and organized. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Run database migrations before the app starts to ensure the app operates on the latest schema. (@fredcamaral)

Improvements:
- Describe when the migrations job runs in the documentation to provide clarity for users. (@fredcamaral)
- Drop the chart version label from `seaweedfs` pods to streamline configuration. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

Fixes:
- Run the plugin-bc-correios migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container only with its necessary Postgres settings to enhance security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a connection change to maintain consistency. (@fredcamaral)
- Schedule the migrations job in alignment with the application while keeping ArgoCD clean. (@fredcamaral)
- Exclude the migrations pod from application selectors to prevent unintended interactions. (@fredcamaral)
- Ensure database migrations run before the application starts to avoid runtime issues. (@fredcamaral)

Improvements:
- Describe the timing of the migrations job in the documentation for better understanding. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.2](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.2)

Features:

Fixes:
- Run the `plugin-bc-correios` migrations in a job to ensure proper execution. (@fredcamaral)
- Provide the migrations container only with its specific Postgres settings to enhance security and efficiency. (@fredcamaral)
- Rename the migrations job when there is a connection change to maintain consistency. (@fredcamaral)
- Schedule the migrations job in alignment with the app while keeping ArgoCD clean. (@fredcamaral)
- Exclude the migrations pod from app selectors to prevent unintended interactions. (@fredcamaral)
- Ensure database migrations run before the app starts to avoid startup issues. (@fredcamaral)

Improvements:
- Describe the timing of when the migrations job runs in the documentation for better clarity. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.1...plugin-bc-correios-v4.0.2)

---

## [4.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.1)

Fixes:

- Tightened guards and updated documentation for `plugin-bc-correios` `1.1.0`. (@fredcamaral)
- Moved `plugin-bc-correios` to app `1.1.0`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.0...plugin-bc-correios-v4.0.1)

---

## [4.0.1](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.1)

Fixes:

- Tightened guards and updated documentation for `plugin-bc-correios` `1.1.0`. (@fredcamaral)
- Moved `plugin-bc-correios` to app `1.1.0`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.0...plugin-bc-correios-v4.0.1)

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

---

## [4.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.0)

Fixes:
- Render both authentication host names for the plugin. (@fredcamaral)
- Read the `LICENSE_KEY` from an existing secret. (@fredcamaral)
- Render broker credentials as strings. (@fredcamaral)
- Run the plugin in production mode by default. (@fredcamaral)
- Keep rendering `ENV_NAME` for the plugin. (@fredcamaral)
- Ensure the environment names the app reads are correctly rendered. (@fredcamaral)

Improvements:
- Fix RabbitMQ migration steps for existing secret in the documentation. (@fredcamaral)
- State the RabbitMQ URL condition in the guide. (@fredcamaral)
- Align the upgrade guide with application environment names. (@fredcamaral)
- Correct the `3.0` upgrade guide. (@fredcamaral)
- Add verified upgrade guides for transitioning from `3.0.1` to `3.0.2`. (@fredcamaral)
- Correct chart documentation against templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v3.0.2...plugin-bc-correios-v4.0.0)

---

## [4.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-bc-correios-v4.0.0)

Features:

Fixes:
- Render both authentication host names for the plugin. (@fredcamaral)
- Read the `LICENSE_KEY` from an existing secret. (@fredcamaral)
- Render broker credentials as strings. (@fredcamaral)
- Run the plugin in production mode by default. (@fredcamaral)
- Keep rendering `ENV_NAME` for the plugin. (@fredcamaral)
- Ensure the environment names the app reads are rendered correctly. (@fredcamaral)

Improvements:
- Fix the RabbitMQ migration steps for an existing secret in the documentation. (@fredcamaral)
- State the RabbitMQ URL condition in the guide. (@fredcamaral)
- Align the upgrade guide with application environment names. (@fredcamaral)
- Correct the `3.0` upgrade guide. (@fredcamaral)
- Add verified upgrade guides for transitioning from `3.0.1` to `3.0.2`. (@fredcamaral)
- Correct chart documentation against templates and application code. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v3.0.2...plugin-bc-correios-v4.0.0)

