## [plugin-br-pix-direct-jd-1.2.0-beta.1] - 2025-11-10

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-direct-jd-v1.1.0...plugin-br-pix-direct-jd-v1.2.0-beta.1)
Contributors: Guilherme Moreira Rodrigues, lerian-studio

### ⚠️ Breaking Changes
- **Core System Overhaul**: This update includes major changes to authentication, backend, build, configuration, and frontend components. Users must update their configurations and dependencies to maintain compatibility. Migration steps include reviewing API changes and adjusting system behavior settings. Please refer to the updated migration guide for detailed instructions.

### ✨ Features
- **gRPC Configuration for Backend Services**: We've introduced gRPC configuration for transaction services, allowing for more efficient communication protocols and enhanced service interoperability. This feature supports a gRPC port configuration, offering greater flexibility and scalability in backend operations.

### 🐛 Bug Fixes
- **Corrected DNS Configuration**: Fixed the DNS name for the transaction service in the onboarding configuration, ensuring reliable service discovery and connectivity.
- **Deployment Stability**: Removed RabbitMQ health check from the onboarding deployment to prevent unnecessary deployment failures, enhancing overall system stability.
- **RabbitMQ Configuration Path**: Resolved issues with the configuration path for RabbitMQ in the transaction service, improving message queue integration.

### 🔄 Changes
- **Environment Variable Management**: Refactored the handling of extra environment variables in the onboarding configmap, simplifying configuration management and reducing potential errors.

### 📚 Documentation
- **Updated Component Versions**: The README file now reflects the latest component versions, providing users with up-to-date information on system dependencies and configurations.

### 🔧 Maintenance
- **Release Management Enhancements**: Multiple updates to the backend, build, and configuration components have been made to streamline the deployment process and ensure consistency across environments.


