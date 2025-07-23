# Changelog

All notable changes to this project will be documented in this file.

## [otel-collector-1.0.0-beta.1] - 2025-07-23

This major release of Helm introduces significant enhancements to scalability, security, and performance, along with several breaking changes that require user attention.

### ⚠️ Breaking Changes
- **Authentication and Configuration Overhaul**: The authentication flow and configuration management have been updated. Users must review the new documentation and adapt their systems for continued compatibility. [Migration Guide](#)
- **Valkey Deployment Update**: Transition from StatefulSet to Deployment for Valkey improves scalability. Users need to update their deployment configurations to align with this change. [Migration Steps](#)
- **Backend Architecture Revamp**: Major changes in backend architecture require updates to existing integrations and deployment scripts. [Integration Update Guide](#)

### ✨ Features
- **Midaz Collector Helm Chart**: Introduces enhanced data collection capabilities, allowing for more comprehensive system monitoring and analytics.
- **Plugin-Smart-Templates**: Now supports external secrets and configuration map annotations, offering more secure and flexible template management.
- **Console MongoDB Configurations**: Added configurations for MongoDB environments, improving database integration for console applications.
- **Ingress Enhancements**: New ingress templates provide improved routing and load balancing, enhancing application accessibility and performance.

### 🐛 Bug Fixes
- **Plugin-Access-Manager**: Fixed issues with environment variable configurations, ensuring system stability and correct variable application.
- **Midaz Job Definitions**: Corrected transaction deployment templates and RabbitMQ job definitions, enhancing job execution reliability.
- **Console MongoDB Settings**: Resolved MongoDB default port settings and image tag updates, ensuring proper connectivity and version management.

### ⚡ Performance
- **Resource Optimization**: Improved resource allocation and management, resulting in better system performance and reduced operational costs.

### 🔄 Changes
- **Environment Variable Support**: Enhanced support for extra environment variables across several components, providing greater flexibility in configuration management.

### 📚 Documentation
- **Updated Guides**: Comprehensive updates to documentation reflect the latest changes, ensuring users have access to accurate and helpful resources.

### 🔧 Maintenance
- **Dependency Updates**: Regular updates to dependencies, removing outdated references and adding new parameters for improved compatibility and performance.
- **Build Process Refinement**: Refactored build scripts and configurations to streamline the build process and remove deprecated components.
- **Testing Enhancements**: Improved testing frameworks and scripts to ensure robust validation of new features and changes, enhancing overall system reliability.

For a detailed overview of all changes and migration guides, please refer to the [full documentation](#).

This changelog is designed to provide users with a clear and concise overview of the most significant updates in this release, focusing on the impact and benefits of each change. Users are encouraged to review the breaking changes and features sections to ensure their systems remain compatible and take advantage of new capabilities.