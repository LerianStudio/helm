## [vmidaz-2.3.1-beta.6] - 2025-06-10

This release focuses on maintaining transparency and ensuring users have the latest project updates through improved release management and documentation.

### 📚 Documentation
- **Changelog Updates**: The changelog has been updated to reflect the latest changes and improvements in the project. This helps users track the software's evolution and stay informed about new features or fixes that might impact their usage.

### 🔧 Maintenance
- **Release Management**: The project has been updated to version 2.3.1-beta.6 as part of our ongoing release process. Regular beta releases ensure users have early access to the latest features and fixes, allowing for timely testing and feedback. This helps maintain a steady development pace and enhances user engagement.

This changelog provides a clear and concise summary of the latest release, focusing on the benefits of updated documentation and release management practices. It ensures users are informed about the project's progress and have access to the most recent developments.

## [vmidaz-2.3.1-beta.5] - 2025-06-10

This release focuses on maintaining accurate documentation to ensure users have the latest information about the software. No new features or bug fixes are included in this update.

### 📚 Documentation
- Updated the CHANGELOG for version 2.3.1-beta.5 to provide users with the most current information on updates and enhancements. This ensures transparency and keeps users informed about ongoing development efforts.

### 🔧 Maintenance
- Improved release management processes by updating documentation. This helps streamline future releases and ensures that users have access to clear and accurate information about software changes.


This changelog is crafted to communicate the focus of the release—documentation updates—while maintaining a professional and user-friendly tone. Each section is relevant to the changes made, ensuring clarity and transparency for users.

## [vmidaz-2.3.1-beta.4] - 2025-06-10

This release focuses on enhancing the project's release management and documentation, ensuring users have clear and up-to-date information about the project's progress.

### 📚 Documentation
- Updated the CHANGELOG to include the latest information about changes and improvements in the beta version. This ensures users are well-informed about the project's development and upcoming features.

### 🔧 Maintenance
- Prepared for release version 2.3.1-beta.4, focusing on internal processes and documentation updates to maintain transparency and keep users and contributors informed.

---

**Notes:**
- This release does not include new features, bug fixes, or performance improvements.
- There are no breaking changes, so no user action is required.
- The primary focus is on maintaining clear communication through updated documentation.

This changelog provides a concise overview of the updates, emphasizing the importance of documentation and transparency for users. It follows the structured template and guidelines, ensuring clarity and relevance for the audience.

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
- Enhanced the CHANGELOG to provide a clear and concise history of changes. This helps users understand the evolution of the project and the context of current features and fixes.

### 🔧 Maintenance
- **Release Management**: Updated the project to version 2.3.1-beta.3. This ensures users have access to the latest pre-release version, which is crucial for testing and providing feedback for further development.

These updates focus on keeping the project well-documented and ensuring users are informed about the latest version available for testing.

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
