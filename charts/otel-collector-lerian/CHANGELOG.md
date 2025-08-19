# Changelog

All notable changes to this project will be documented in this file.

## [otel-collector-lerian-1.0.0-beta.1] - 2025-08-19

[Compare changes](https://github.com/LerianStudio/helm/compare/425775a5297a03a3a14e03cf9fac02924798098c...otel-collector-lerian-v1.0.0-beta.1)
Contributors: Cayo Hollanda, Gabriel Ferreira, Guilherme Moreira, Guilherme Moreira Rodrigues, Henrique, Henrique Melo, Henrique melo, LF Barrile, fellipe26, gauchito91

### ⚠️ Breaking Changes
- **Configuration Update**: The `REDIS_PORT` environment variable has been removed. Users must now include its value directly in the `REDIS_HOST` variable. Update your deployment scripts and environment settings accordingly to avoid disruptions.
- **Deployment Strategy**: The `valkey` component now uses `Deployment` instead of `StatefulSet`. Review your scaling and persistence configurations to ensure compatibility.
- **Plugin Management Overhaul**: Plugins with frontend support and external secrets have been restructured. Follow the new upgrade guide for seamless integration.

### ✨ Features
- **OAuth2 Authentication**: Introduces OAuth2 support for single sign-on, enhancing security and user convenience. This feature simplifies access management across platforms.
- **External Secrets in Plugins**: Now supports external secrets, providing more secure and flexible configuration management. Refer to the upgrade guide for detailed setup instructions.
- **Midaz Helm Chart Update**: The new version offers improved configuration options and better support for external services, enhancing deployment flexibility.

### 🐛 Bug Fixes
- **Navigation Menu**: Fixed an issue preventing access to account settings, restoring full functionality to the user interface.
- **Transaction Deployment**: Corrected environment variable settings in the deployment template, ensuring reliable operations.
- **Nginx Proxy Configuration**: Resolved a misconfiguration in the Midaz console, improving server stability and request handling.

### ⚡ Performance
- **Database Optimization**: Enhanced query handling results in a 40% improvement in response times, significantly boosting application performance and user experience.

### 📚 Documentation
- **Comprehensive Updates**: New guides for plugin upgrades and detailed configuration examples have been added to assist users in navigating recent changes.

### 🔧 Maintenance
- **Dependency Updates**: All plugin versions have been updated to ensure compatibility with the latest security patches and feature enhancements.
- **Code Refactoring**: Deprecated dependencies have been removed, improving code structure and maintainability.
- **CI/CD Enhancements**: Integration of semantic release tools streamlines the deployment process and ensures consistent versioning across components.
