# Changelog

All notable changes to this project will be documented in this file.

## [otel-collector-1.0.0-beta.3] - 2025-07-25

This release enhances the user experience with new UI capabilities, improves backend stability, and streamlines configuration management, ensuring a more robust and user-friendly platform.

### ✨ Features  
- **Enhanced UI Templates and Functions**: We've introduced comprehensive UI templates and functions for plugin fees and CRM, significantly enhancing user interaction and management capabilities. This update allows for greater customization and extensibility of the user interface, making it easier to tailor the platform to specific needs.
- **Integrated Plugin Management**: The Midaz console now supports plugins UI, providing a more seamless and integrated experience for managing plugins. This feature simplifies plugin interactions and boosts productivity.

### 🐛 Bug Fixes
- **Nginx Server Stability**: Resolved issues with Midaz Nginx server definitions, ensuring proper proxy configuration and improved server stability. Users can expect more reliable performance without the need for previous workarounds.
- **CRM UI Connectivity**: Fixed port issues in the CRM UI, ensuring correct connectivity and functionality. This fix enhances the reliability of the CRM interface, allowing uninterrupted user operations.

### 🔧 Maintenance
- **Configuration Cleanup**: Removed unused environment variables from the worker secret in plugin-smart-templates, reducing clutter and potential confusion in configuration management.
- **Service Template Updates**: Updated console, onboarding, and transaction services templates to receive annotations from values.yaml, improving maintainability and clarity of service configurations.
- **Standardized Naming Conventions**: Renamed plugin smart templates frontend to UI, enhancing codebase consistency and ease of navigation.

These updates collectively enhance the platform's user interface, improve backend stability, and streamline configuration management, providing a more robust and user-friendly experience.
