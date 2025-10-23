## [plugin-br-pix-direct-jd-1.1.0-beta.1] - 2025-10-23

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-direct-jd-v1.0.0...plugin-br-pix-direct-jd-v1.1.0-beta.1)
Contributors: Gabriel Ferreira, Guilherme Moreira Rodrigues, lerian-studio

### ⚠️ Breaking Changes
- **Major Component Overhaul**: This release involves extensive changes to the Auth, Backend, Build, Config, and Database components. Users must update custom integrations and scripts to align with new API configurations. Please consult the [migration guide](#) for detailed instructions.
- **Storage Backend Update**: MinIO has been replaced with SeaweedFS, requiring users to migrate their storage configurations. Refer to the [storage migration guide](#) for step-by-step instructions.

### ✨ Features
- **Enhanced Security for Plugins**: Introduced CRM data source secrets and disabled ingress by default, providing improved security and configuration flexibility.
- **RBAC Extensions**: Extended RBAC permissions for the discovery service, allowing access to replicasets and list/watch deployments, which enhances operational efficiency.
- **Service Discovery Improvements**: Added RBAC and nginx restart capabilities to the service discovery job, ensuring smoother service updates and maintenance.

### 🐛 Bug Fixes
- **URL Configuration Corrections**: Resolved issues with trailing slashes in `MIDAZ_ONBOARDING_URL` and standardized URL configurations to prevent routing errors.
- **Deployment Order Fixes**: Adjusted Helm hooks from post-install to pre-install for Postgres and RabbitMQ, ensuring proper initialization order and reducing deployment errors.
- **Shell Compatibility**: Corrected shell usage in alpine kubectl container to ensure compatibility and prevent script execution errors.

### ⚡ Performance
- **Optimized Job Execution**: Improved bootstrap jobs with TTL, parallelism, and user existence checks, leading to more efficient resource usage and faster job completion.

### 🔄 Changes
- **Standardized URL Management**: Adopted `MIDAZ_CONSOLE_BASE_PATH` as the source of truth for base URL configurations, ensuring consistent URL management across services.
- **Frontend Service Renaming**: Updated the frontend service name from `reporter-frontend` to `reporter-ui` to better reflect its role and improve clarity.

### 🗑️ Removed
- **Secret Template Hooks**: Removed pre-install/upgrade Helm hooks from secret templates, simplifying deployment processes and reducing complexity.

### 📚 Documentation
- **Naming Convention Updates**: Renamed `plugin-smart-templates` to `reporter` across all documentation to align with updated service names and improve clarity.

### 🔧 Maintenance
- **Modernized Storage Solutions**: Transitioned from MinIO to SeaweedFS, enhancing storage performance and scalability.
- **Configuration Clean-up**: Streamlined configuration files by removing outdated hooks and aligning naming conventions across the board.


