# Changelog

All notable changes to this project will be documented in this file.

## [otel-collector-lerian-2.2.0-beta.1] - 2025-12-19

[Compare changes](https://github.com/LerianStudio/helm/compare/otel-collector-lerian-v2.1.1...otel-collector-lerian-v2.2.0-beta.1)
Contributors: Fellipe Benoni, Guilherme Moreira Rodrigues, lerian-studio

### ✨ Features
- **OpenTelemetry Collector Documentation**: A new comprehensive README has been introduced, providing clear guidance on configuration and usage, making it easier for users to implement and manage OpenTelemetry.
- **Plugin BR Pix Direct JD Update**: The plugin has been updated to versions pix@1.2.1-beta.11 and job@1.2.1-beta.11, offering new environment variables that enhance configuration flexibility and integration capabilities.

### 🐛 Bug Fixes
- **Plugin BR Pix Direct JD Stability**: Fixed an issue in versions pix@1.2.1-beta.7 and job@1.2.1-beta.7, ensuring stable and correct plugin operations, thus improving overall reliability.

### 📚 Documentation
- **Enhanced Error Messaging**: The README matrix script now includes chart names in error messages, aiding in quicker troubleshooting and resolution.
- **Improved Table Parsing**: Documentation updates now include improved table parsing utilities and version formatting, ensuring consistency and ease of updates.
- **Updated Plugin Table Headers**: The Plugin BR Pix Direct JD table header now reflects the latest Pix version, providing users with accurate and up-to-date information.

### 🔧 Maintenance
- **Documentation Readability**: Adjustments to heading levels and the addition of separator lines in README files improve readability and organization.
- **Backend Service Update**: The transaction service has been updated to version 3.4.7, ensuring compatibility and access to the latest features and fixes.
- **Release Workflow Improvements**: Simplified README parsing logic and added debug output in the release notification workflow, enhancing maintainability and debugging capabilities.
