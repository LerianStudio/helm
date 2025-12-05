# Changelog

All notable changes to this project will be documented in this file.

## [otel-collector-lerian-2.1.0-beta.1] - 2025-12-05

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v2.0.0...otel-collector-lerian-v2.1.0-beta.1)
Contributors: Fellipe Benoni, Gabriel Ferreira, Guilherme Moreira Rodrigues, lerian-studio

### ⚠️ Breaking Changes
- **Configuration and Backend Overhaul**: This update requires users to review and potentially modify their authentication, backend, and database configurations. Key changes include the renaming of plugins and adjustments to service URLs and environment variables. Please refer to the migration guide for detailed steps to ensure compatibility.
- **Service URL and Plugin Renaming**: Users must update their configurations to align with new service URLs and plugin names for continued functionality.

### ✨ Features
- **gRPC Port Configuration**: The backend now supports gRPC port configuration for transaction services, enhancing service communication and integration options.
- **Kubernetes Deployment Support**: New Kubernetes manifests for deploying the PIX QR code service and BR PIX direct JD plugin are available, facilitating seamless service deployment with PostgreSQL dependencies.
- **Enhanced Security with External Secrets**: RabbitMQ and PostgreSQL configurations now support external secrets, offering improved security and flexibility for managing sensitive data.

### 🐛 Bug Fixes
- **RabbitMQ Configuration Path**: Fixed the configuration path for RabbitMQ in the transaction service, resolving previous connectivity issues.
- **Navigation Bug**: Corrected a frontend navigation issue that prevented access to account settings, enhancing user accessibility.
- **Standardized MIDAZ Console URL**: Ensures consistent access across environments by standardizing the MIDAZ console URL configuration.

### ⚡ Performance
- **Database Enhancements**: Introduction of logical replication slots and improved SQL formatting boosts database performance and maintainability.

### 🔧 Maintenance
- **CI/CD Stability**: GitHub Actions are now pinned to specific commit hashes, enhancing build stability and security.
- **Documentation Updates**: All component versions in the documentation have been updated, ensuring users have the latest setup guidance.
- **Database Job Efficiency**: Refactored bootstrap jobs to include TTL, parallelism, and user existence checks, improving job efficiency and reliability.
