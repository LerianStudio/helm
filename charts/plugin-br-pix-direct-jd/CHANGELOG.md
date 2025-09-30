## [plugin-br-pix-direct-jd-1.0.0-beta.1] - 2025-09-30

[Compare changes](https://github.com/LerianStudio/helm/compare/425775a5297a03a3a14e03cf9fac02924798098c...plugin-br-pix-direct-jd-v1.0.0-beta.1)
Contributors: Cayo Hollanda, Gabriel Ferreira, Guilherme Moreira, Guilherme Moreira Rodrigues, Henrique, Henrique Melo, Henrique melo, LF Barrile, fellipe26, gauchito91

### ⚠️ Breaking Changes
- **Configuration Update**: The `REDIS_PORT` environment variable has been removed. Users must now include the port value directly in the `REDIS_HOST` variable. Update your configurations to prevent service disruptions.
- **Deployment Change**: Valkey has transitioned from StatefulSet to Deployment. Review and adjust your deployment scripts accordingly to accommodate this change.
- **Chart Migration**: RabbitMQ has migrated from the Bitnami chart to the groundhog2k chart. Update your chart configurations to align with the new dependencies.

### ✨ Features
- **BR PIX Direct JD Plugin**: A new Helm chart is now available for the BR PIX Direct JD plugin, featuring an integrated PostgreSQL dependency. This simplifies deployment and enhances integration within Kubernetes environments.
- **Enhanced Nginx Security**: Security context, service account, imagePullSecrets, and resource limits have been added to Nginx deployments, boosting security and resource management.

### 🐛 Bug Fixes
- **RabbitMQ Authentication**: Resolved authentication format and username field issues in the Helm chart, ensuring seamless compatibility and preventing authentication errors.
- **Midaz Console Configuration**: Fixed configuration issues in the Midaz console configmap and Nginx proxy settings, resolving deployment and access problems.

### ⚡ Performance
- **Database Connections**: Upgraded to app version 3.3.0 with added SSL mode configurations, enhancing security and reliability for database connections.

### 🔄 Changes
- **Plugin Access Manager**: Updated auth version and UI environment variables, improving authentication capabilities and user interface consistency.
- **Midaz Configmaps**: Updated transaction and onboarding configmaps with new environment variables, enhancing configuration management.

### 🔧 Maintenance
- **Dependency Management**: Migrated dependencies from Bitnami to alternative solutions and updated images to the bitnamisecure repository, ensuring secure and up-to-date dependency management.
- **Automated Versioning**: Integrated semantic-release for automated versioning and changelog generation, streamlining release processes and improving consistency.


