## [plugin-br-pix-direct-jd-1.0.0-beta.1] - 2025-10-07

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-direct-jd-v1.0.0-beta.3...plugin-br-pix-direct-jd-v1.0.0-beta.1)
Contributors: Guilherme Moreira Rodrigues, lerian-studio

### ⚠️ Breaking Changes
- **Authentication, Backend, Build, Config, Database**: Major version updates require users to adapt their configurations and APIs. Ensure compatibility by following the migration guides provided. Deployment scripts and integrations may need updates to align with the new architecture.
- **Release 1.0.0-beta.1**: Initial beta release with foundational changes across all major components. Substantial integration testing is recommended to ensure smooth transition.

### ✨ Features
- **Database**: Now supports external secrets for RabbitMQ admin credentials, enhancing security by allowing sensitive data to be managed externally.
- **Database, Auth, Build, Config**: Added PostgreSQL definitions and updated security settings for console deployment, improving database management and security posture.
- **Backend, Build, Config, Database**: Deployed Kubernetes manifests for PIX QR code service and BR PIX direct JD plugin, facilitating easier deployment and scalability.

### 🐛 Bug Fixes
- **Backend, Build, Config**: Corrected nginx deployment configuration, resolving previous deployment issues and improving maintainability.
- **Secrets Template**: Renamed PRIVATE_KEY to KEY in the QR code secrets template to align with naming conventions, preventing configuration errors.

### ⚡ Performance
- **Database**: Enhanced SQL formatting and added logical replication slots, improving performance and reliability for high-availability setups.

### 📚 Documentation
- **Documentation**: Updated component and chart versions to reflect the latest releases, ensuring users have access to accurate setup and configuration instructions.

### 🔧 Maintenance
- **Build, Config**: Regular release updates and version bumps, maintaining system stability and incorporating the latest dependency improvements.
- **PR Template**: Added BR PIX Direct JD plugin to PR template and title validation, streamlining the contribution process and ensuring consistency in pull requests.


