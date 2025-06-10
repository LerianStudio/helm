## [vmidaz-2.3.1-beta.3] - 2025-06-10

This release focuses on enhancing the clarity and accessibility of our documentation, ensuring users can seamlessly integrate the latest updates into their workflows.

### 📚 Documentation
- Improved the CHANGELOG to provide a clearer and more comprehensive overview of recent updates. This enhancement helps users quickly understand changes, facilitating easier adoption and integration into their workflows.

### 🔧 Maintenance
- Updated the project to version 2.3.1-beta.3 as part of our ongoing commitment to maintaining software stability and reliability. This ensures users have access to the latest features and improvements without disruption.


This changelog captures the essence of the release, focusing on documentation improvements and maintenance updates that enhance user experience and ensure continued software reliability.

## [vmidaz-2.3.1-beta.3] - 2025-06-10

This release focuses on enhancing the reliability of the software and ensuring users have access to the most up-to-date information through improved documentation. No new features or bug fixes are included in this update.

### 📚 Documentation
- The changelog has been updated to reflect recent changes and improvements, ensuring users can easily track the software's evolution and stay informed about updates.

### 🔧 Maintenance
- The software version has been updated to 2.3.1-beta.3. This update is part of our ongoing commitment to maintaining the stability and reliability of the software, ensuring that the latest improvements and fixes are available for testing.


## [3.0.0] - 2025-06-10

This release of Helm introduces significant architectural changes and new features aimed at enhancing scalability, security, and user experience. Users are encouraged to review the breaking changes and new features to fully leverage the improvements.

### ⚠️ Breaking Changes
- **Authentication & Deployment**: Migrated from StatefulSet to Deployment. This change improves scalability and resource management. Users need to update deployment configurations and scripts. Refer to the migration guide for detailed steps.
- **Auth & Build**: Major version update to 2.0.0 across several components. Significant architectural changes require users to adapt to new configurations. Review the provided migration guides for assistance.
- **Build & Config**: Removed outdated dependencies and scripts related to Casdoor. Update your configurations to align with the new setup.
- **Auth & Config**: Refactored sensitive environment variable names for plugins. Update deployment scripts and environment configurations accordingly.
- **Database & Config**: Replaced Redis with Valkey, affecting data handling and caching strategies. Ensure compatibility with the new setup.

### ✨ Features
- **Plugin Management**: New chart templates and values files for plugin-fees and plugin-crm enhance modularity and ease of integration.
- **Console & Database**: Added MongoDB environment configurations, offering more flexible database setups and improved data handling.
- **Deployment Strategy**: Introduced deployment strategy definitions, providing better control over application deployment and scaling.
- **Security & Access**: Enhanced security context configurations for plugins, improving compliance and security posture.

### 🐛 Bug Fixes
- **Console & Database**: Corrected default MongoDB port settings and image tags, resolving connectivity issues and ensuring proper deployment.
- **Auth & Config**: Fixed environment variable typos and secret references, enhancing reliability and reducing configuration errors.
- **Transaction & Onboarding**: Addressed misconfigured ports and removed deprecated secrets, improving system stability and security.

### ⚡ Performance
- **Resource Optimization**: Optimized resource limits and deployment strategies, resulting in improved performance and resource utilization.

### 📚 Documentation
- **Comprehensive Updates**: Updated documentation, including new readme files and charts documentation, to improve user guidance and onboarding.

### 🔧 Maintenance
- **Dependencies**: Regular updates and removal of outdated dependencies ensure the system remains secure and up-to-date.
- **Code Quality**: Refactored codebase to remove redundant components, improving maintainability and facilitating future updates.
- **CI/CD**: Enhanced CI pipelines with semantic release integration, streamlining development and deployment processes.

---

This changelog provides a comprehensive overview of recent updates to the Helm project, focusing on user impact and system improvements. Users are encouraged to review the breaking changes and major features to ensure smooth transitions and leverage new capabilities.

## [3.0.0] - 2025-06-10

This major release of Helm introduces significant enhancements and improvements across multiple components, focusing on modularity, configurability, and database support.

### ⚠️ Breaking Changes
- **Authentication Overhaul**: Major updates to authentication processes require users to review and update their configurations. Please refer to the migration guide for detailed steps.
- **Deployment Strategy Update**: Transition from StatefulSet to Deployment for Valkey. Users must adjust their deployment configurations to align with the new strategy.
- **Auth Backend Changes**: Removal of the auth backend from plugin auth templates necessitates updates to custom templates. Follow the provided migration documentation for guidance.

### ✨ Features
- **Plugin Access Manager Templates**: Introduces enhanced modularity for managing access controls, allowing for easier customization and scalability.
- **Pre-configured Chart Templates**: New templates for plugin CRM and Fees streamline deployment and integration, reducing setup time.
- **MongoDB Support**: Console now supports MongoDB environments, expanding database compatibility and offering more flexibility in database management.

### 🐛 Bug Fixes
- **Configuration Corrections**: Fixed environment variable typo and default MongoDB port settings, ensuring proper deployment and connectivity.
- **Documentation Accuracy**: Resolved rabbitmq misspelling, enhancing clarity for RabbitMQ setup instructions.

### ⚡ Performance
- **PostgreSQL Replication Enhancements**: Updated configurations improve database reliability and performance, particularly in high-availability setups.

### 📚 Documentation
- **Comprehensive Updates**: New and updated readme files and charts documentation provide clearer guidance and support, ensuring users have the information they need to leverage new features effectively.

### 🔧 Maintenance
- **Dependency Cleanup**: Removal of outdated dependencies and scripts reduces potential security vulnerabilities and streamlines the codebase.
- **Semantic Release Improvements**: Enhanced workflows ensure smoother release processes and better version management.

This release focuses on delivering a more robust and flexible platform, with particular attention to improving user experience and expanding capabilities. Users are encouraged to review the breaking changes and new features sections to fully leverage the improvements in this version.

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
