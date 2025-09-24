# Changelog

All notable changes to this project will be documented in this file.

## [otel-collector-lerian-2.0.0-beta.1] - 2025-09-24

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v1.2.0...otel-collector-lerian-v2.0.0-beta.1)
Contributors: Guilherme Moreira Rodrigues, lerian-studio

### ⚠️ Breaking Changes
- **Major Version Transition**: The move to version 4.0.0 involves critical updates to authentication, backend, and database configurations. Users must consult the upgrade guide for detailed migration instructions to ensure compatibility.
- **RabbitMQ Chart Update**: Transition from Bitnami to groundhog2k chart requires users to update deployment scripts and CI/CD pipelines. Refer to the new chart documentation for configuration adjustments.

### ✨ Features
- **Custom Nginx Configurations**: Users can now specify configmap names and adjust plugin paths, offering greater flexibility in deployment customization.
- **Enhanced Security for Nginx**: Introduction of a security context and service account improves the security posture, aligning with industry best practices.

### 🐛 Bug Fixes
- **RabbitMQ Authentication**: Resolved authentication issues by updating to the latest chart configurations, ensuring smooth integration and operation.

### ⚡ Performance
- **Optimized Resource Management**: ImagePullSecrets and resource limits added to Nginx deployment enhance resource efficiency and security.

### 🔄 Changes
- **Nginx Ingress Configuration**: Updated structure for improved clarity and maintainability, simplifying future configuration tasks.

### 📚 Documentation
- **Upgrade Guide**: Comprehensive guide for version 4.0.0, detailing breaking changes and migration steps to facilitate a smooth transition.

### 🔧 Maintenance
- **Dependency Updates**: Migrated dependencies to the bitnamisecure repository, enhancing security and ensuring the use of supported components.
- **Configuration Streamlining**: Removed redundant Nginx volume mount configurations, reducing complexity and improving chart maintainability.
