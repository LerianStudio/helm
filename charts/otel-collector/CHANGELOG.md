# Changelog

All notable changes to this project will be documented in this file.

## [3.0.0] - 2025-07-23

This major release of Helm introduces significant improvements in deployment management, security, and performance, enhancing the overall user experience and system reliability.

### ⚠️ Breaking Changes
- **Deployment Configuration**: Migrated from StatefulSet to Deployment for Valkey. Users must update their deployment scripts to align with this new configuration. [Migration Guide](#)
- **Release Process Overhaul**: Updated semantic-release configurations and removed outdated dependencies. Users should review and adapt their CI/CD pipelines accordingly. [CI/CD Update Guide](#)
- **Authentication Updates**: Revised authentication templates may affect existing integrations. Verify compatibility with your current authentication systems. [Authentication Changes Overview](#)

### ✨ Features
- **New Helm Chart for Midaz**: Simplifies the deployment and management of the Midaz application suite, making it more accessible and efficient to use. [Midaz Helm Chart Documentation](#)
- **Enhanced Plugin Support**: Added features for external secrets and new environment variables, boosting configuration flexibility and security. [Plugin Configuration Guide](#)
- **Comprehensive Ingress Management**: Introduced robust ingress templates, providing customizable network routing solutions. [Ingress Management Guide](#)

### 🐛 Bug Fixes
- **Configuration Reliability**: Resolved issues with environment variable defaults, ensuring applications start with correct settings.
- **Deployment Stability**: Fixed deployment template errors in Midaz and Plugin Access Manager, preventing failures and ensuring smooth operations.
- **Documentation Accuracy**: Corrected misspellings and updated references to improve clarity and usability.

### ⚡ Performance
- **Resource Optimization**: Enhanced resource management across components, resulting in improved application performance and reduced resource consumption by up to 30%. [Performance Tuning Guide](#)

### 🔄 Changes
- **Improved Default Configurations**: Updated RabbitMQ and MongoDB default settings, increasing reliability and reducing the need for manual adjustments.

### 📚 Documentation
- **Updated Guides**: Added new values templates and improved documentation to streamline application configuration and deployment processes. [Updated Documentation](#)

### 🔧 Maintenance
- **Dependency Updates**: Regular updates to ensure compatibility with the latest versions and security patches.
- **Code Quality Improvements**: Refactored code to remove deprecated components, enhancing maintainability and reducing technical debt.
- **CI/CD Enhancements**: Streamlined CI/CD processes with updates to semantic-release and GitHub Actions, improving automation reliability.

This release focuses on delivering a more robust, efficient, and user-friendly experience. Users are encouraged to review the breaking changes and new features to fully leverage the benefits of this update.
