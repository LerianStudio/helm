## [plugin-br-pix-direct-jd-1.1.0] - 2025-10-31

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-pix-direct-jd-v1.1.0-beta.2...plugin-br-pix-direct-jd-v1.1.0)
Contributors: Fellipe Benoni, Guilherme Moreira Rodrigues, lerian-studio

### ✨ Features
- **Enhanced Security with Secrets**: You can now use existing secrets within your Helm charts, providing greater flexibility and security in your deployments.
- **Improved Messaging Integration**: The renaming of "Smart Templates" to "Reporter" and improved RabbitMQ configuration make it easier to integrate with messaging systems, enhancing clarity and usability.

### 🐛 Bug Fixes
- **Build Stability**: Updated the Helm setup action to version 3.5, resolving compatibility issues and ensuring smoother build processes.
- **Consistent Access**: Standardized the MIDAZ console URL configuration, ensuring consistent access across different environments.
- **Seamless Navigation**: Aligned NextAuth URLs with the Reporter UI base URL, fixing navigation issues for a better user experience.

### ⚡ Performance
- **Optimized Console Resources**: Adjustments to resource utilization for the console result in improved performance and efficiency.

### 🔧 Maintenance
- **Reliable Builds**: Pinned GitHub Actions to specific commit hashes, enhancing build reliability by preventing unexpected changes.
- **Code Consistency**: Standardized environment variable naming and updated service URLs, improving code maintainability and reducing configuration errors.
- **Cleaner Code Formatting**: Fixed minor styling issues in configmap templates, ensuring cleaner and more consistent code formatting.


