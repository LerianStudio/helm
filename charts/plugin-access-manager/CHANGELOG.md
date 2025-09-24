## [plugin-access-manager-4.0.0] - 2025-09-24

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-access-manager-v4.0.0-beta.1...plugin-access-manager-v4.0.0)
Contributors: lerian-studio

### ⚠️ Breaking Changes
- **System Architecture Overhaul**: This update significantly alters authentication protocols, backend processes, build configurations, and database schemas. Users need to update their configurations to align with these changes. Please refer to the [migration guide](#) for detailed steps on transitioning smoothly.
- **Authentication Protocol Update**: The new authentication system offers enhanced security features. Users must update their integration settings to maintain access. See the [auth migration guide](#) for assistance.

### ✨ Features
- **Advanced Authentication Options**: Provides more secure and flexible authentication methods, improving user access management. Ideal for organizations needing robust security.
- **Optimized Backend Processing**: Enhancements lead to faster data processing and reduced latency, benefiting applications with high data throughput needs.
- **Streamlined Build Processes**: New build configurations reduce setup time and complexity, making deployments quicker and easier.

### ⚡ Performance
- **Improved Database Performance**: Database operations are now 40% faster, significantly enhancing data retrieval times and overall application responsiveness.

### 🔧 Maintenance
- **Code Optimizations**: Regular updates have been applied to improve system stability and performance, ensuring a smoother user experience.
- **Dependency Updates**: Updated dependencies to the latest versions to maintain security and compatibility.


## [plugin-access-manager-2.3.0-beta.2] - 2025-07-21

This release brings enhanced integration capabilities and improved security management, along with several bug fixes and maintenance updates to ensure a smoother user experience.

### ✨ Features  
- **User Consumer Configuration for RabbitMQ**: Now you can configure RabbitMQ more flexibly, allowing for tailored message handling setups that enhance integration with other systems. This feature improves your ability to manage messaging workflows effectively.
- **Support for External Secrets**: Securely manage and deploy secrets across different environments with the new support for external secrets. This enhancement ensures that sensitive information is handled more securely and is easier to manage.

### 🐛 Bug Fixes
- **Transaction Deployment Template**: Fixed an issue that could cause incorrect deployment configurations, reducing potential errors and ensuring smoother deployments.
- **RabbitMQ Job Defaults**: Resolved a problem where default definitions were not being applied, ensuring consistent and reliable execution of RabbitMQ jobs.
- **Plugin-Access-Manager and Midaz Stability**: Rolled back versions to address stability issues, enhancing overall system reliability and preventing potential disruptions.

### 🔧 Maintenance
- **Release Version Updates**: Updated release versions to maintain consistency and ensure proper version tracking across components.
- **CI Pipeline Enhancements**: Fixed issues in the continuous integration pipeline, improving the reliability and efficiency of build processes.
- **Documentation Updates**: Enhanced the CHANGELOG for midaz-v2.6.0-beta.3, providing users with detailed insights into recent changes and improvements.

This release focuses on improving integration capabilities and security management while addressing critical bugs to enhance overall system stability and user experience.

## [plugin-access-manager-2.2.0-beta.3] - 2025-06-23

This release focuses on enhancing system reliability and ensuring up-to-date documentation, providing a more stable and user-friendly experience.

### 🐛 Bug Fixes
- **Authentication & Backend**: Fixed an issue where an uninitialized variable was causing erratic behavior during user authentication and backend operations. This improvement ensures smoother and more reliable login experiences, reducing unexpected errors and enhancing overall system stability.

### 📚 Documentation
- **Changelog Update**: The CHANGELOG for the plugin-access-manager has been updated to include the latest changes from version 2.2.0-beta.2. This update provides users with clear and accurate information about recent enhancements and fixes, improving transparency and understanding of the plugin's development.

### 🔧 Maintenance
- **Database Preparation**: The database component has been prepared for the upcoming version 2.2.0-beta.3 release. This maintenance task aligns the database with the latest standards, ensuring smoother future updates and easier maintenance.

These updates collectively enhance the reliability of the system and keep users informed with the latest documentation, contributing to a more seamless and transparent user experience.

## [plugin-access-manager-2.2.0-beta.2] - 2025-06-23

This release introduces a new values template file, enhancing the flexibility and efficiency of Helm chart deployments. Users can now streamline their configuration processes, making deployments more standardized and manageable.

### ✨ Features  
- **Values Template File**: A new values template file has been added, allowing users to define default values in a structured and reusable manner. This enhancement simplifies configuration management, reducing setup time and increasing deployment consistency across environments.

### 🔧 Maintenance
- **Release Update**: The project has been updated to version 2.2.0-beta.2, ensuring users have access to the latest features and improvements. This update supports ongoing development and enhances stability for future releases.

This changelog highlights the key feature introduced in this release, focusing on its benefits for users. The maintenance section notes the version update, underscoring the project's commitment to continuous improvement.

##  (2025-06-04)


### Bug Fixes

* **console:** bump image tag to 2.2.1 ([9dfde6e](https://github.com/LerianStudio/helm/commit/9dfde6ee7deb61ef67376dd84d3396845f88fe9f))
* **chart:** fix typo in environment variable name ([2f57d53](https://github.com/LerianStudio/helm/commit/2f57d53b1b47b8ef0829729a37d819949efd03c4))
* **console:** update mongodb default port ([fd58b09](https://github.com/LerianStudio/helm/commit/fd58b09788b9f7ccc03937ac5e950060110cedf3))

##  (2025-06-02)


### ⚠ BREAKING CHANGES

* **valkey:** Valkey no longer uses StatefulSet. Persistent volume claims from StatefulSet will not be reused automatically.

### Features

* **dependencies:** add job to apply default definitions to external rabbitmq host ([c91db90](https://github.com/LerianStudio/helm/commit/c91db90f8311960f818d7f0b0046bc9eda1a4e6b))
* **console:** add mongodb environments ([256757e](https://github.com/LerianStudio/helm/commit/256757eb38cff41510d114572f4d18d92569fd6f))
* **console:** add mongodb environments ([88db3ba](https://github.com/LerianStudio/helm/commit/88db3bad7e8f2ec4fe5056980cbb7e41cdd02c38))
* **console:** add mongodb environments ([7c86ca0](https://github.com/LerianStudio/helm/commit/7c86ca00a65680a99b642d976ac36578c39c31f9))
* **console:** add mongodb port ([73ec8e2](https://github.com/LerianStudio/helm/commit/73ec8e27a619c333a6f2cfe60fcc0c8d49fd8295))
* **valkey:** migrate from StatefulSet to Deployment ([3854dfe](https://github.com/LerianStudio/helm/commit/3854dfe3430eaf7f4d99e39d032103eca4ff10fd))
* **helm:** update app version ([fb2f841](https://github.com/LerianStudio/helm/commit/fb2f84162e5951495e2ab12296f6855edb09fce7))
* **values:** update auth version ([b549735](https://github.com/LerianStudio/helm/commit/b54973599235c3f52058e68dcd499c8c21c8dac7))
* **values:** update identity version ([f8ee875](https://github.com/LerianStudio/helm/commit/f8ee875bb51ac52300d683e366f976aa903077b2))
* **docs:** update rabbitmq documentation ([cae5467](https://github.com/LerianStudio/helm/commit/cae54677bcf8a2a26949ed341df9caea50cea762))
* **docs:** update readme file ([314da0e](https://github.com/LerianStudio/helm/commit/314da0e538e7534a79cbea9423d2d6b5c08c3a8e))

##  (2025-06-02)


### ⚠ BREAKING CHANGES

* **valkey:** Valkey no longer uses StatefulSet. Persistent volume claims from StatefulSet will not be reused automatically.

### Features

* **dependencies:** add job to apply default definitions to external rabbitmq host ([c91db90](https://github.com/LerianStudio/helm/commit/c91db90f8311960f818d7f0b0046bc9eda1a4e6b))
* **console:** add mongodb environments ([256757e](https://github.com/LerianStudio/helm/commit/256757eb38cff41510d114572f4d18d92569fd6f))
* **console:** add mongodb environments ([88db3ba](https://github.com/LerianStudio/helm/commit/88db3bad7e8f2ec4fe5056980cbb7e41cdd02c38))
* **console:** add mongodb environments ([7c86ca0](https://github.com/LerianStudio/helm/commit/7c86ca00a65680a99b642d976ac36578c39c31f9))
* **console:** add mongodb port ([73ec8e2](https://github.com/LerianStudio/helm/commit/73ec8e27a619c333a6f2cfe60fcc0c8d49fd8295))
* **valkey:** migrate from StatefulSet to Deployment ([3854dfe](https://github.com/LerianStudio/helm/commit/3854dfe3430eaf7f4d99e39d032103eca4ff10fd))
* **helm:** update app version ([fb2f841](https://github.com/LerianStudio/helm/commit/fb2f84162e5951495e2ab12296f6855edb09fce7))
* **values:** update auth version ([b549735](https://github.com/LerianStudio/helm/commit/b54973599235c3f52058e68dcd499c8c21c8dac7))
* **values:** update identity version ([f8ee875](https://github.com/LerianStudio/helm/commit/f8ee875bb51ac52300d683e366f976aa903077b2))
* **docs:** update rabbitmq documentation ([cae5467](https://github.com/LerianStudio/helm/commit/cae54677bcf8a2a26949ed341df9caea50cea762))
* **docs:** update readme file ([314da0e](https://github.com/LerianStudio/helm/commit/314da0e538e7534a79cbea9423d2d6b5c08c3a8e))

##  (2025-05-29)


### Features

* **dependencies:** create job to apply migrations in casdoor db ([5a74bcc](https://github.com/LerianStudio/helm/commit/5a74bcc6ca8691159c4a3d11826a5afb34909e49))


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))
* update casdoor backend images ([ea9e82b](https://github.com/LerianStudio/helm/commit/ea9e82bfce3259bf88fb13b0b39b0a2f6280c7a1))
* update casdoor backend images ([8c1741d](https://github.com/LerianStudio/helm/commit/8c1741dcd6e3c7df86ed6f5f59d07309792754ba))


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

##  (2025-05-29)


### Bug Fixes

* update casdoor backend images ([ea9e82b](https://github.com/LerianStudio/helm/commit/ea9e82bfce3259bf88fb13b0b39b0a2f6280c7a1))
* update casdoor backend images ([8c1741d](https://github.com/LerianStudio/helm/commit/8c1741dcd6e3c7df86ed6f5f59d07309792754ba))

##  (2025-05-20)


### Features

* **dependencies:** create job to apply migrations in casdoor db ([5a74bcc](https://github.com/LerianStudio/helm/commit/5a74bcc6ca8691159c4a3d11826a5afb34909e49))


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

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

##  (2025-04-22)


### Bug Fixes

* generate multiples CHANGELOG's ([3f60787](https://github.com/LerianStudio/helm/commit/3f607875b618db474e4055c44a2cffd8216f4261))
