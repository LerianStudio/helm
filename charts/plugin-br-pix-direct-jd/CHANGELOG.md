## [plugin-br-pix-direct-jd-1.2.4-beta.1] - 2025-12-05

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-direct-jd-v1.2.3...plugin-br-pix-direct-jd-v1.2.4-beta.1)
Contributors: Fellipe Benoni, Guilherme Moreira Rodrigues, lerian-studio

### ✨ Features
- **Enhanced Logging**: Introduced a new masc log feature, providing detailed insights for troubleshooting and monitoring, making it easier to track system behavior and diagnose issues.

### 🐛 Bug Fixes
- **Documentation Accuracy**: Corrected the plugin-fees chart version to 3.4.4, ensuring users have accurate versioning information for deployment, reducing confusion and potential deployment errors.

### 🔄 Changes
- **Telemetry Update**: Enabled telemetry plugins and updated the OpenTelemetry version, improving system monitoring and observability, helping users gain better insights into system performance.
- **UI Improvement**: Renamed the plugin-smart-templates-ui to reporter-ui, enhancing clarity and consistency in the user interface, making it easier for users to navigate and understand.
- **Configuration Update**: Changed the SeaweedFS filer port from 9000 to 8888, aligning with new standards for improved compatibility and reducing potential configuration conflicts.

### 📚 Documentation
- **Version Updates**: Updated version tables in the README to reflect the latest chart and component versions, ensuring users have the most current information for deployment and configuration.

### 🔧 Maintenance
- **Release Management**: Conducted multiple version bumps and beta releases across components such as database, auth, backend, and frontend, ensuring all parts of the system are up-to-date with the latest improvements and fixes.
- **Security and Streamlining**: Removed default regcred from imagePullSecrets configuration, enhancing security and streamlining deployment setups.
- **Build Process Simplification**: Disabled helm plugin signature verification in CI and release workflows, simplifying the build process and reducing potential friction in development pipelines.


