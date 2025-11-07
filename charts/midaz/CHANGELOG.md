## [midaz-4.4.0-beta.6] - 2025-11-07

[Compare changes](https://github.com/LerianStudio/helm/compare/midaz-v4.4.0-beta.5...midaz-v4.4.0-beta.6)
Contributors: Guilherme Moreira Rodrigues, lerian-studio

### 🐛 Bug Fixes
- **Improved Deployment Stability**: Removed the RabbitMQ health check from the onboarding deployment. This fix resolves issues with unnecessary deployment failures, enhancing the reliability of the onboarding process.

### 🔧 Maintenance
- **Version Update**: Released version 4.4.0-beta.6, incorporating essential internal updates. This maintenance ensures that the build process remains efficient and aligned with the latest development practices, paving the way for a more refined and stable upcoming release.


## [midaz-2.6.0-beta.4] - 2025-07-22

This release enhances configuration flexibility and integration capabilities, providing users with improved deployment options and resolving key issues in plugin management.

### ✨ Features  
- **Smart Templates**: You can now add valkey to smart templates charts, offering enhanced customization and flexibility for your templates.
- **Midaz Console**: New nginx configuration templates and dependency improve deployment options and performance, making your Midaz console setups more efficient.

### 🐛 Bug Fixes
- **Plugin Access Manager**: Fixed issues with the configuration of extra environment variables in identity and auth configmap templates, ensuring consistent and reliable behavior across deployments.

### 🔄 Changes
- **Configuration Management**: Expanded support for extra environment variables across multiple plugins (smart-templates, crm, fees), allowing for greater customization and integration flexibility.
- **Plugin Fees**: You can now configure extra environment variables in both the configmap template and values YAML, providing more control over your setup.
- **Plugin Access Manager**: Improved configuration flexibility by enabling extra environment variables in identity and auth configmap templates, enhancing integration capabilities.

### 📚 Documentation
- Updated changelogs for plugin-access-manager and Midaz, providing clear insights into recent changes and updates.

### 🔧 Maintenance
- **Release Management**: Multiple updates for beta releases across various components (auth, config, database, deps) ensure the project remains on track with its release schedule.
- **Dependencies**: Added nginx as a dependency for the Midaz console, ensuring compatibility and performance improvements.

This changelog is designed to help users quickly understand the new features, improvements, and fixes in this release, focusing on how these changes can benefit their use of the software.

## [midaz-2.6.0-beta.3] - 2025-07-18

This release introduces significant enhancements to configuration flexibility and security, alongside critical bug fixes to improve deployment reliability.

### ✨ Features
- **User Consumer Configuration for RabbitMQ**: Gain more control over message queue interactions with new user-specific configuration options. This feature allows you to tailor RabbitMQ settings to better fit your operational needs, enhancing both flexibility and efficiency.
- **Support for External Secrets**: Securely manage sensitive information across deployments with the new external secrets feature. By keeping secrets outside the application codebase, this enhancement strengthens security practices and simplifies secret management.

### 🐛 Bug Fixes
- **Transaction Deployment Template**: Resolved a critical issue affecting deployment accuracy. This fix ensures more reliable deployment processes, reducing the risk of errors and improving overall system stability.

### 🔧 Maintenance
- **Version Update**: Upgraded to version 2.6.0-beta.3, incorporating various under-the-hood improvements that enhance system performance and prepare for future stable releases.
- **Continuous Integration Enhancements**: Improved CI processes to boost build reliability and efficiency, resulting in smoother development workflows and faster feedback loops for developers.

This update focuses on empowering users with enhanced configuration options and bolstering security measures, while also ensuring a stable and efficient deployment experience.

## [midaz-2.5.0] - 2025-06-20

This release focuses on maintaining the stability and clarity of the Helm project by updating configuration components and enhancing documentation. Users benefit from improved system reliability and easier access to change history.

### 📚 Documentation
- **CHANGELOG Update**: The CHANGELOG for the `charts/midaz` component has been updated. This enhancement provides users with a clearer and more concise history of changes, making it easier to track updates and understand the evolution of the component.

### 🔧 Maintenance
- **Configuration Updates**: Released version 2.5.0 includes updates to the configuration components. These updates ensure the system aligns with the latest standards, enhancing overall stability and maintainability. Users can continue to rely on a robust and up-to-date system without any required actions.

No breaking changes or new features are included in this release, ensuring a seamless experience for users.

This changelog provides a concise and user-focused summary of the updates, emphasizing the benefits and impact on users without delving into technical specifics.

## [midaz-2.5.0-beta.1] - 2025-06-20

This release focuses on enhancing the configuration and database components, setting the stage for future improvements and ensuring that users have access to the latest documentation updates.

### ✨ Improvements
- **Configuration Enhancements**: The configuration component has been updated to version 2.5.0-beta.1, introducing enhancements that prepare the system for upcoming features. This ensures smoother integration with future releases, offering users a more robust and adaptable configuration experience.
- **Database Optimization**: The database component has been upgraded to version 2.4.0, significantly improving data handling and processing efficiency. Users will benefit from optimized performance, leading to faster and more reliable data storage and retrieval.

### 📚 Documentation
- **Changelog Updates**: The CHANGELOG for the 'charts/midaz' component has been updated to reflect the latest changes and improvements. This ensures users have access to up-to-date information, enhancing transparency and understanding of the project's development.

### 🔧 Maintenance
- **General Maintenance**: Routine updates and code maintenance have been performed to ensure the system remains stable and efficient, laying a solid foundation for future enhancements.

This release does not introduce any breaking changes, new features, or bug fixes, but focuses on preparing the system for future developments and ensuring documentation accuracy.

## [midaz-2.4.0-beta.3] - 2025-06-20

This release focuses on enhancing system reliability and user experience through improved configuration settings and documentation updates.

### ✨ Improvements
- **Configuration Enhancements**: Default environment variable settings for onboarding and transaction processes have been improved. This change simplifies setup and ensures more reliable default behavior, minimizing the need for manual adjustments.

### 🐛 Bug Fixes
- **Chart Metadata Correction**: Fixed the application version in chart metadata, ensuring accurate version tracking and consistency across deployments. This resolves potential discrepancies and enhances deployment reliability.
- **Configuration Adjustments**: Default values for environment variables related to onboarding and transaction components have been corrected. This fix addresses potential misconfigurations, leading to improved system stability and user experience.

### 📚 Documentation
- **Version Details Added**: Documentation now includes detailed application version information, offering users clearer insights into the current state and capabilities of the application.
- **Changelog Updates**: The `charts/midaz` component changelog has been updated, providing users with the latest information on changes and updates, which facilitates better understanding and tracking of modifications.

### 🔧 Maintenance
- **Release Preparation**: Updated to version 2.4.0-beta.3 to prepare the system for upcoming features and improvements, ensuring a smoother transition to future releases.

These updates collectively enhance the reliability and usability of the system, ensuring smoother operation and a better user experience.

## [midaz-2.4.0-beta.2] - 2025-06-16

This release focuses on essential maintenance updates and documentation enhancements, ensuring stability and clarity for users as we prepare for future features.

### 📚 Documentation
- Updated the CHANGELOG for the `charts/midaz` component. This ensures users have access to the latest information about changes, improvements, and bug fixes, facilitating better understanding and usage of the software.

### 🔧 Maintenance
- **Release Management**: Updated the project to version 2.4.0-beta.2 and 2.3.1. These updates include various under-the-hood improvements that enhance system stability and security, ensuring users have access to the latest updates and bug fixes.

In this release cycle, the focus was on maintaining the project with version updates and ensuring that the documentation accurately reflects the current state of the software. Users can expect a stable experience with the latest updates applied.


## [midaz-2.4.0-beta.2] - 2025-06-16

This release focuses on enhancing the organization and clarity of our documentation, ensuring users have access to the latest software versions and information. While there are no new features or bug fixes, this update emphasizes stability and user guidance.

### 📚 Documentation
- **Improved Changelog for `charts/midaz`:** We've updated the CHANGELOG to provide clearer insights into recent changes. This enhancement helps users track the software's evolution and understand any new features or fixes included in the latest releases.

### 🔧 Maintenance
- **Release Version Updates:** We've updated the release versions to 2.4.0-beta.2 and 2.3.1. This ensures users are accessing the most recent features and improvements while maintaining compatibility with existing setups.

These updates are part of our ongoing commitment to providing a stable and user-friendly experience. While this release does not introduce new features or fixes, it lays the groundwork for future enhancements by keeping our documentation and versioning up-to-date.

## [midaz-2.4.0-beta.1] - 2025-06-16

This release introduces enhanced configurability with RabbitMQ protocol settings, improves system reliability with critical bug fixes, and strengthens build security. Users will experience a more adaptable and stable platform.

### ✨ Features  
- **RabbitMQ Configuration Enhancements**: Users can now customize RabbitMQ protocol settings for transaction and onboarding processes. This feature enhances integration flexibility, allowing for more tailored and efficient message handling across various environments.

### 🐛 Bug Fixes
- **Initialization Stability**: Fixed issues with initialization containers for transaction and onboarding components, ensuring smoother deployment and reducing startup failures.
- **RabbitMQ Configuration Application**: Corrected a job responsible for applying RabbitMQ definitions, preventing disruptions in message handling and ensuring configurations are consistently applied.

### 🔧 Maintenance
- **Database Preparation**: Released database version 2.4.0-beta.1, incorporating several under-the-hood improvements to prepare for future features and enhancements.
- **CI Pipeline Security**: Updated the CI pipeline to block triggers from bots, enhancing the security and integrity of the build process by preventing unauthorized executions.
- **Changelog Documentation**: Updated the CHANGELOG for charts/midaz, providing users with a clear and concise record of changes, facilitating easier tracking of updates and modifications.

These updates collectively enhance the platform's configurability, reliability, and security, offering users a more robust and adaptable experience.

## [midaz-2.3.1-beta.4] - 2025-06-10

This release focuses on improving user guidance and streamlining the build process, providing clearer documentation and enhancing CI efficiency.

### 📚 Documentation
- **Improved Configuration Guidance**: The values example for the Midaz chart has been updated to offer clearer instructions on configuration options, helping users customize their deployments more effectively.
- **Up-to-Date CHANGELOG**: The Midaz chart's CHANGELOG has been enhanced to include the latest updates, ensuring users are well-informed about recent changes and improvements.

### 🔧 Maintenance
- **Release Management**: Prepared the versioning update to 2.3.1-beta.4, allowing users to track and test the latest beta features and fixes.
- **CI Pipeline Optimization**: Implemented a block on triggers from automated bots within the CI pipeline. This prevents unnecessary builds, reduces resource usage, and maintains clean build logs, enhancing overall efficiency.

This changelog provides a concise overview of the changes in version 2.3.1, highlighting the benefits to users and ensuring clarity and accessibility.

## [midaz-2.3.1-beta.4] - 2025-06-10

This release focuses on enhancing documentation clarity and improving the build process, ensuring a smoother experience for developers and users interacting with the Helm project.

### 📚 Documentation
- **Improved Configuration Guidance**: Updated the values example in the Midaz documentation to provide clearer guidance on configuration options. This helps users better understand how to set up and customize their deployments effectively.
- **Updated Changelog**: Enhanced the Midaz chart's CHANGELOG to include recent updates, ensuring users have access to the latest information about changes and improvements in the chart.

### 🔧 Maintenance
- **Release Management**: Published version 2.3.1-beta.4, marking the latest beta release. This version includes the latest updates and improvements, preparing for the next stable release.
- **Continuous Integration**: Updated the pipeline configuration to block triggers from bots. This change prevents automated systems from inadvertently initiating builds, ensuring that only intentional changes by developers trigger the CI process. This maintains clean and efficient build processes.

These updates collectively improve the documentation clarity and maintain the integrity of the build process, ensuring a smoother experience for developers and users interacting with the Helm project.


## [vmidaz-2.3.1-beta.3] - 2025-06-10

This release focuses on enhancing the documentation to improve user understanding and ease of use, alongside essential maintenance updates to keep the project versioning current.

### 📚 Documentation
- **Improved Example for 'Values' Template**: A new example has been added to the Midaz documentation, illustrating the use of the 'values' template. This enhancement helps users better understand and implement this feature, making the documentation more accessible and practical. [#242]

### 🔧 Maintenance
- **Version Update**: The project has been updated to version 2.3.1-beta.3. This update ensures accurate version tracking, aiding developers and users in managing releases effectively.

In this release, the key focus is on improving documentation to help users better understand and utilize the software's features, along with routine maintenance to ensure smooth version management. No new features, bug fixes, or breaking changes were introduced.

##  (2025-06-04)


### Bug Fixes

* **chart:** fix set secret ref to console deployment ([34b4885](https://github.com/LerianStudio/helm/commit/34b488597985e744a4108eda086a9e14eddac702))
* **chart:** fix typo in environment variable name ([2f57d53](https://github.com/LerianStudio/helm/commit/2f57d53b1b47b8ef0829729a37d819949efd03c4))

##  (2025-06-03)


### Features

* **values:** update auth version ([b549735](https://github.com/LerianStudio/helm/commit/b54973599235c3f52058e68dcd499c8c21c8dac7))
* **values:** update identity version ([f8ee875](https://github.com/LerianStudio/helm/commit/f8ee875bb51ac52300d683e366f976aa903077b2))


### Bug Fixes

* **console:** bump image tag to 2.2.1 ([9dfde6e](https://github.com/LerianStudio/helm/commit/9dfde6ee7deb61ef67376dd84d3396845f88fe9f))
* **console:** update mongodb default port ([fd58b09](https://github.com/LerianStudio/helm/commit/fd58b09788b9f7ccc03937ac5e950060110cedf3))

##  (2025-06-03)


### Features

* **values:** update auth version ([b549735](https://github.com/LerianStudio/helm/commit/b54973599235c3f52058e68dcd499c8c21c8dac7))
* **values:** update identity version ([f8ee875](https://github.com/LerianStudio/helm/commit/f8ee875bb51ac52300d683e366f976aa903077b2))


### Bug Fixes

* **console:** bump image tag to 2.2.1 ([9dfde6e](https://github.com/LerianStudio/helm/commit/9dfde6ee7deb61ef67376dd84d3396845f88fe9f))
* **console:** update mongodb default port ([fd58b09](https://github.com/LerianStudio/helm/commit/fd58b09788b9f7ccc03937ac5e950060110cedf3))

##  (2025-06-03)


### Features

* **values:** update auth version ([b549735](https://github.com/LerianStudio/helm/commit/b54973599235c3f52058e68dcd499c8c21c8dac7))
* **values:** update identity version ([f8ee875](https://github.com/LerianStudio/helm/commit/f8ee875bb51ac52300d683e366f976aa903077b2))


### Bug Fixes

* **console:** bump image tag to 2.2.1 ([9dfde6e](https://github.com/LerianStudio/helm/commit/9dfde6ee7deb61ef67376dd84d3396845f88fe9f))
* **console:** update mongodb default port ([fd58b09](https://github.com/LerianStudio/helm/commit/fd58b09788b9f7ccc03937ac5e950060110cedf3))

##  (2025-05-30)


### ⚠ BREAKING CHANGES

* **valkey:** Valkey no longer uses StatefulSet. Persistent volume claims from StatefulSet will not be reused automatically.

### Features

* **dependencies:** add job to apply default definitions to external rabbitmq host ([c91db90](https://github.com/LerianStudio/helm/commit/c91db90f8311960f818d7f0b0046bc9eda1a4e6b))
* **console:** add mongodb environments ([256757e](https://github.com/LerianStudio/helm/commit/256757eb38cff41510d114572f4d18d92569fd6f))
* **console:** add mongodb environments ([88db3ba](https://github.com/LerianStudio/helm/commit/88db3bad7e8f2ec4fe5056980cbb7e41cdd02c38))
* **console:** add mongodb environments ([7c86ca0](https://github.com/LerianStudio/helm/commit/7c86ca00a65680a99b642d976ac36578c39c31f9))
* **console:** add mongodb port ([73ec8e2](https://github.com/LerianStudio/helm/commit/73ec8e27a619c333a6f2cfe60fcc0c8d49fd8295))
* **dependencies:** create job to apply migrations in casdoor db ([5a74bcc](https://github.com/LerianStudio/helm/commit/5a74bcc6ca8691159c4a3d11826a5afb34909e49))
* **valkey:** migrate from StatefulSet to Deployment ([3854dfe](https://github.com/LerianStudio/helm/commit/3854dfe3430eaf7f4d99e39d032103eca4ff10fd))
* **helm:** update app version ([fb2f841](https://github.com/LerianStudio/helm/commit/fb2f84162e5951495e2ab12296f6855edb09fce7))
* **docs:** update rabbitmq documentation ([cae5467](https://github.com/LerianStudio/helm/commit/cae54677bcf8a2a26949ed341df9caea50cea762))
* **docs:** update readme file ([314da0e](https://github.com/LerianStudio/helm/commit/314da0e538e7534a79cbea9423d2d6b5c08c3a8e))


### Bug Fixes

* update casdoor backend images ([ea9e82b](https://github.com/LerianStudio/helm/commit/ea9e82bfce3259bf88fb13b0b39b0a2f6280c7a1))
* update casdoor backend images ([8c1741d](https://github.com/LerianStudio/helm/commit/8c1741dcd6e3c7df86ed6f5f59d07309792754ba))

##  (2025-05-30)


### Features

* **docs:** update rabbitmq documentation ([cae5467](https://github.com/LerianStudio/helm/commit/cae54677bcf8a2a26949ed341df9caea50cea762))

##  (2025-05-30)


### Features

* **docs:** update readme file ([314da0e](https://github.com/LerianStudio/helm/commit/314da0e538e7534a79cbea9423d2d6b5c08c3a8e))

##  (2025-05-30)


### ⚠ BREAKING CHANGES

* **valkey:** Valkey no longer uses StatefulSet. Persistent volume claims from StatefulSet will not be reused automatically.

### Features

* **valkey:** migrate from StatefulSet to Deployment ([3854dfe](https://github.com/LerianStudio/helm/commit/3854dfe3430eaf7f4d99e39d032103eca4ff10fd))

##  (2025-05-30)


### Features

* **dependencies:** add job to apply default definitions to external rabbitmq host ([c91db90](https://github.com/LerianStudio/helm/commit/c91db90f8311960f818d7f0b0046bc9eda1a4e6b))

##  (2025-05-30)


### Features

* **console:** add mongodb environments ([256757e](https://github.com/LerianStudio/helm/commit/256757eb38cff41510d114572f4d18d92569fd6f))
* **console:** add mongodb environments ([88db3ba](https://github.com/LerianStudio/helm/commit/88db3bad7e8f2ec4fe5056980cbb7e41cdd02c38))

##  (2025-05-30)


### Features

* **console:** add mongodb environments ([7c86ca0](https://github.com/LerianStudio/helm/commit/7c86ca00a65680a99b642d976ac36578c39c31f9))

##  (2025-05-30)


### Features

* **console:** add mongodb port ([73ec8e2](https://github.com/LerianStudio/helm/commit/73ec8e27a619c333a6f2cfe60fcc0c8d49fd8295))
* **dependencies:** create job to apply migrations in casdoor db ([5a74bcc](https://github.com/LerianStudio/helm/commit/5a74bcc6ca8691159c4a3d11826a5afb34909e49))
* **helm:** update app version ([fb2f841](https://github.com/LerianStudio/helm/commit/fb2f84162e5951495e2ab12296f6855edb09fce7))


### Bug Fixes

* update casdoor backend images ([ea9e82b](https://github.com/LerianStudio/helm/commit/ea9e82bfce3259bf88fb13b0b39b0a2f6280c7a1))
* update casdoor backend images ([8c1741d](https://github.com/LerianStudio/helm/commit/8c1741dcd6e3c7df86ed6f5f59d07309792754ba))

##  (2025-05-16)


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

##  (2025-05-14)


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

##  (2025-05-12)


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))

##  (2025-05-09)


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))

##  (2025-05-09)

##  (2025-05-07)


### Features

* **doc:** update charts documentation ([422e771](https://github.com/LerianStudio/helm/commit/422e7717a8f7c79d96f4cdd110421f0c68857d82))
* **doc:** update charts documentation ([b9618c4](https://github.com/LerianStudio/helm/commit/b9618c462cf3f0ad6b3f237347ffae01fc23cb09))

##  (2025-05-07)


### Features

* **ingress:** add ingress templates ([020369a](https://github.com/LerianStudio/helm/commit/020369a13b9696eb2e6e12c389ed211d2feb95f1))
* **ingress:** add ingress templates ([816fcee](https://github.com/LerianStudio/helm/commit/816fcee9d905744bcd47003fb16b974104c2d2d3))
* **pipe:** add release step for ghcr ([f0e4f3f](https://github.com/LerianStudio/helm/commit/f0e4f3f5221b392bb68b2a5f87aa85facc5cfbee))
* **helm:** create chart file to plugin crm ([69b01c8](https://github.com/LerianStudio/helm/commit/69b01c868752eb91973e2d292eb2e7ffaa57c1e0))
* **helm:** create chart file to plugin-fees ([38a0e81](https://github.com/LerianStudio/helm/commit/38a0e81c29d53bb81bb1895869b058942bc1d116))
* **helm:** create chart templates to plugin crm ([777ea2f](https://github.com/LerianStudio/helm/commit/777ea2fa1582d1530fbc4946c4ef184ae90598e9))
* **chart:** create chart templates to plugin-fees ([adabbaa](https://github.com/LerianStudio/helm/commit/adabbaaf405b471b111abe208408fce9c0772e99))
* **chart:** create chart templates to plugin-fees ([303caf0](https://github.com/LerianStudio/helm/commit/303caf06a48ff63e20fcdd13fd2c5d0629aae33c))
* **helm:** create doc to plugin crm ([4cbaa9d](https://github.com/LerianStudio/helm/commit/4cbaa9d4e8377260508c5687f292cfec8dbeee36))
* **helm:** create values file to plugin crm ([de6b154](https://github.com/LerianStudio/helm/commit/de6b1547947f91d580a9ff5f7fb14c1e5efa4d0d))
* **values:** create values file to plugin-fees ([304f228](https://github.com/LerianStudio/helm/commit/304f22871b76180f4b299daa3ecaac06571ffd92))
* **values:** create values file to plugin-fees ([f383281](https://github.com/LerianStudio/helm/commit/f383281421b709744823d9de1bc053288ab6d747))


### Bug Fixes

* generate multiples CHANGELOG's ([3f60787](https://github.com/LerianStudio/helm/commit/3f607875b618db474e4055c44a2cffd8216f4261))

##  (2025-04-22)


### Bug Fixes

* generate multiples CHANGELOG's ([3f60787](https://github.com/LerianStudio/helm/commit/3f607875b618db474e4055c44a2cffd8216f4261))
