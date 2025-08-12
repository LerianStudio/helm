# Changelog

All notable changes to this project will be documented in this file.

## [otel-collector-1.0.0] - 2025-08-12

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-v1.0.0-beta.3...otel-collector-v1.0.0)
Contributors: Gabriel Ferreira, Guilherme Moreira Rodrigues, gauchito91, lerian-studio

### ⚠️ Breaking Changes
- **Configuration Update**: The `REDIS_PORT` environment variable has been removed. Users must now integrate its value into the `REDIS_HOST` variable. Update your environment settings to ensure seamless operation.
- **Version Transition**: The upgrade to version 3.0.0 involves several breaking changes in `auth`, `backend`, and other components. Please review the migration guide to maintain compatibility.

### ✨ Features
- **Plugin Enhancements**: Plugins now support external secrets, boosting security and simplifying management. A detailed upgrade guide is available to assist with the transition.
- **Improved Authentication**: The plugin-access-manager has been updated to support the latest authentication standards, enhancing security and compatibility.

### 🐛 Bug Fixes
- **Configuration Reliability**: Fixed an issue with the `midaz` console configmap that previously caused incorrect configurations, ensuring stable and expected behavior.

### ⚡ Performance
- **Backend Optimization**: Updated NGINX configurations to optimize buffer settings, resulting in improved performance and stability under load.

### 🔄 Changes
- **Frontend Customization**: Introduced new environment variables for the fees UI, allowing for a more tailored user interface and enhanced user experience.
- **Configuration Streamlining**: Updated configuration maps for `midaz`, improving deployment efficiency and performance.

### 📚 Documentation
- **New README**: A comprehensive README for version 3.0 has been created, providing updated guidance and insights into the latest features and changes.

### 🔧 Maintenance
- **System Updates**: Multiple version bumps and dependency updates across components ensure the system is up-to-date with the latest security patches and performance enhancements.
- **Build System Improvements**: Revised the release pipeline and updated plugin versions to ensure smooth deployment and integration processes.
