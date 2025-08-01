## [plugin-fees-2.0.0-beta.5] - 2025-08-01

This release of Helm focuses on enhancing system usability and performance, offering a more intuitive user interface and faster backend operations.

### ⚡ Performance
- **Improved Data Retrieval**: The fee service selector has been optimized, resulting in more efficient data processing. Users will experience faster response times, enhancing overall system performance.

### 🔄 Changes
- **Fee Template Clarity**: Labels in fee templates have been updated to improve clarity. This change makes fee-related information more intuitive, enhancing user experience by simplifying navigation and understanding.

### 🔧 Maintenance
- **Plugin Management Enhancement**: A new plugins scope has been added to streamline integration and management of additional functionalities. This update allows for more flexible system customization and extension, benefiting developers with easier plugin management.
- **Version Updates**: Released version updates to 2.0.0-beta.5 and 2.0.0-beta.2, ensuring the system remains up-to-date with the latest pre-release improvements. These updates are part of ongoing efforts to maintain system stability and prepare for future enhancements.

Each of these changes is designed to improve the overall user experience, system performance, and maintainability, ensuring a smoother experience for both users and developers.

## [plugin-fees-1.3.0] - 2025-06-20

This release focuses on enhancing the configuration and database components, leading to a more streamlined setup process and improved system performance. Users can expect a more efficient and reliable experience.

### ✨ Improvements
- **Configuration & Database Enhancements**: The latest updates to the configuration and database components simplify setup and boost system performance. These improvements ensure a smoother and more dependable user experience, reducing the time and effort required for configuration.

### 📚 Documentation
- **Changelog Updates**: The changelog files for 'plugin-fees' and 'midaz' have been updated to reflect the latest changes in versions v1.3.0-beta.2 and v2.5.0. This ensures users have the most current information on software updates, aiding in better understanding and utilization.

### 🔧 Maintenance
- **Routine Updates**: Regular maintenance updates for the configuration and database components ensure continued system stability and incorporate minor improvements. These updates help maintain a robust and up-to-date infrastructure, indirectly benefiting users by enhancing overall system reliability.

This changelog provides a user-focused overview of the key changes in version 1.3.0, highlighting improvements that enhance user experience and system performance. The documentation updates ensure users have access to the latest information, supporting better software utilization.

## [plugin-fees-1.3.0-beta.2] - 2025-06-20

This release focuses on enhancing configuration reliability and improving documentation, ensuring a smoother setup and deployment experience for users.

### 🐛 Bug Fixes
- **Config**: Corrected the default value for the Swagger hot environment variable. This fix prevents potential misconfigurations, ensuring consistent behavior across development and testing environments.

### 🔄 Changes
- **Config**: Updated the default value for the Swagger hot environment variable to align with the latest environment settings. This change enhances deployment reliability by ensuring configurations are up-to-date with current standards.

### 📚 Documentation
- **Values Template**: Added a values template file to the documentation. This addition aids users in understanding and customizing configuration options more effectively, streamlining the setup process for both new and existing users.

### 🔧 Maintenance
- **Release Management**: Prepared for the upcoming 1.3.0-beta.2 release with updates to configuration and database components. This groundwork supports future feature rollouts and stability improvements, ensuring a robust platform for users.

This changelog presents the updates in a user-friendly manner, highlighting the benefits and impacts of the changes without delving into technical specifics. It ensures users understand the improvements and how they contribute to a better experience.

##  (2025-05-16)


### Features

* **doc:** update charts documentation ([422e771](https://github.com/LerianStudio/helm/commit/422e7717a8f7c79d96f4cdd110421f0c68857d82))
* **doc:** update charts documentation ([b9618c4](https://github.com/LerianStudio/helm/commit/b9618c462cf3f0ad6b3f237347ffae01fc23cb09))


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

##  (2025-05-16)


### Features

* **doc:** update charts documentation ([422e771](https://github.com/LerianStudio/helm/commit/422e7717a8f7c79d96f4cdd110421f0c68857d82))
* **doc:** update charts documentation ([b9618c4](https://github.com/LerianStudio/helm/commit/b9618c462cf3f0ad6b3f237347ffae01fc23cb09))


### Bug Fixes

* **chart:** resources limits in onboarding and transaction values ([9d788f5](https://github.com/LerianStudio/helm/commit/9d788f5dc9639cb97bf285332c31033fedb0545a))


### Performance Improvements

* Update resources ([b5f07f0](https://github.com/LerianStudio/helm/commit/b5f07f0fd2319f2bbe3155fd075c1ae7874cf59c))
* Update resources ([9ffc743](https://github.com/LerianStudio/helm/commit/9ffc7430951db115934fb10223f0d9287adfcf60))

##  (2025-05-07)


### Features

* **values:** add app new version and reference default config ([b972952](https://github.com/LerianStudio/helm/commit/b97295261b87645884b197bbbf8aeea8dd78e452))
* **values:** add app new version and reference default secret ([ef8069c](https://github.com/LerianStudio/helm/commit/ef8069c403b3e7878571ddb3b92ee6f8be2f251f))
* **chart:** add auth backend helpers functions ([7248963](https://github.com/LerianStudio/helm/commit/72489636dfd8d57191e4d61da0369d6267b277df))
* **chart:** add auth backend templates ([57fb163](https://github.com/LerianStudio/helm/commit/57fb163b2c7cca15b1006ef493e3ee43b7cc616c))
* **onboarding:** add auth config ([8a055cb](https://github.com/LerianStudio/helm/commit/8a055cb83b9f6a9d9c76ca3343ab6a61c1d1c00c))
* **transaction:** add auth config ([a7ede5b](https://github.com/LerianStudio/helm/commit/a7ede5b29f6c69752cffad6970d5d73bd21062cb))
* **pipe:** add branch develop to generate beta release ([2990c0e](https://github.com/LerianStudio/helm/commit/2990c0e71d5b6773321b67c986b0a5a32b970cd3))
* add dependencies to midaz helm ([e1e4095](https://github.com/LerianStudio/helm/commit/e1e4095c7e9fc48c69738c0610ee7ad4bd56c12a))
* **values:** add deployment strategy definitions ([dd93837](https://github.com/LerianStudio/helm/commit/dd9383729db20e4f88265edde5900d35c7dbbafa))
* **console:** add deployment strategy ([0000ab0](https://github.com/LerianStudio/helm/commit/0000ab0a6c088e2eca167f396bff859638b478e4))
* **onboarding:** add deployment strategy ([220274b](https://github.com/LerianStudio/helm/commit/220274beb453eb54ec6e9c3a6020016cf8a7be91))
* **transaction:** add deployment strategy ([65076f4](https://github.com/LerianStudio/helm/commit/65076f421904b98f46329ff40cb31f7cf409476b))
* add doc ([5593a96](https://github.com/LerianStudio/helm/commit/5593a96ff02c3b968c4a703a5a7ccc2afa53be04))
* add doc ([97daf1e](https://github.com/LerianStudio/helm/commit/97daf1ecb4c2a51415c58cf0bc815a36d1e52cc3))
* add doc ([2f02d2e](https://github.com/LerianStudio/helm/commit/2f02d2ef0fad7ad80fe131253a8e232b66499430))
* add doc ([6e20f92](https://github.com/LerianStudio/helm/commit/6e20f92c1c31fa26560edfa77fec348783564de2))
* **doc:** add general readme and moving midaz readme ([41f11fe](https://github.com/LerianStudio/helm/commit/41f11fe167c213be99413d4b0b82a9becbe482f6))
* add gpg key and clean file ([81630ce](https://github.com/LerianStudio/helm/commit/81630ce857b0e00600b63d602c3dec4df45eab61))
* add helm-compose config and karpenter node ([9a52467](https://github.com/LerianStudio/helm/commit/9a52467339718fd820e76355e97113cb6104fc2c))
* add index to semantic-release versioning ([4c98cf1](https://github.com/LerianStudio/helm/commit/4c98cf120e280bcdb252fed83aab285f1fa0f5e8))
* add index to semantic-release versioning ([af4c306](https://github.com/LerianStudio/helm/commit/af4c306d8e6ece405b451407c941eb1bf4eff5bd))
* **ingress:** add ingress templates ([020369a](https://github.com/LerianStudio/helm/commit/020369a13b9696eb2e6e12c389ed211d2feb95f1))
* **ingress:** add ingress templates ([816fcee](https://github.com/LerianStudio/helm/commit/816fcee9d905744bcd47003fb16b974104c2d2d3))
* add init container in casdoor to check if the database is ready ([#48](https://github.com/LerianStudio/helm/issues/48)) ([8337771](https://github.com/LerianStudio/helm/commit/833777165ff6ed1d4183cc48757acd2d8b7ddd83))
* **doc:** add lerian banner ([35b904a](https://github.com/LerianStudio/helm/commit/35b904afb9d910e51b1508693aa7c3ce06ea9a75))
* **console:** add new console env vars ([cf974b8](https://github.com/LerianStudio/helm/commit/cf974b8d696f9eb89e951fd144632d0e5817291f))
* **console:** add new env vars ([a228e39](https://github.com/LerianStudio/helm/commit/a228e39c856f9f4b561d55949edcaa051d5b9af9))
* **console:** add new env vars ([8b8d76f](https://github.com/LerianStudio/helm/commit/8b8d76f525a96f36c1d694c65db51ed7280a68a5))
* **dependencies:** add new parameters to chart file ([#44](https://github.com/LerianStudio/helm/issues/44)) ([4796070](https://github.com/LerianStudio/helm/commit/4796070cb5ad4c32d28bbb7ffc085b5fb3aeb495))
* **doc:** add new version ([39c0a71](https://github.com/LerianStudio/helm/commit/39c0a71dacbe9c80aa095a580c5d42d153b0947b))
* **doc:** add new version ([f864ad2](https://github.com/LerianStudio/helm/commit/f864ad20353a26f7dbe525332ef3b54f6af6fb74))
* add plugin to semantic-release ([4ec01d8](https://github.com/LerianStudio/helm/commit/4ec01d8aceef35145239ae5b513977531798b329))
* add plugin to semantic-release ([d102c52](https://github.com/LerianStudio/helm/commit/d102c52039f5c1262f9dc00eb07728d226e656ef))
* add plugin to semantic-release ([a26017e](https://github.com/LerianStudio/helm/commit/a26017e363c87530e30e96e9b5fdc2581c19bb49))
* add plugin to semantic-release ([b001de0](https://github.com/LerianStudio/helm/commit/b001de0f2fad2b2b1cf05b5c0db9f48aa1af5265))
* add plugin to semantic-release ([f786586](https://github.com/LerianStudio/helm/commit/f7865866e41aad38bdf343e45fce351fa2af2a9b))
* add plugin to semantic-release ([13f0af3](https://github.com/LerianStudio/helm/commit/13f0af38e59cf9fb7a3596293a83dd3e6b9757a0))
* **pipe:** add release step for ghcr ([f0e4f3f](https://github.com/LerianStudio/helm/commit/f0e4f3f5221b392bb68b2a5f87aa85facc5cfbee))
* **console:** add secrets ([ad89e3b](https://github.com/LerianStudio/helm/commit/ad89e3ba7bd1713686bc0546be1e6b11341b10da))
* **chart:** add security context to plugin identity ([47b48fc](https://github.com/LerianStudio/helm/commit/47b48fc9ec49f706519fceb4a7007c0179f62317))
* **pipe:** Add semantic changelog ([8c65e59](https://github.com/LerianStudio/helm/commit/8c65e5970101edc9ac621ec30b783bbc4fc3225c))
* **pipe:** Add semantic changelog ([452b6e7](https://github.com/LerianStudio/helm/commit/452b6e78b97a10aa4cd94daf5c95cd1545dc8222))
* **pipe:** Add semantic changelog ([c54115e](https://github.com/LerianStudio/helm/commit/c54115ebf8bd43a0dc8d41233d1100ac136ba8c3))
* **pipe:** Add semantic changelog ([d9befbb](https://github.com/LerianStudio/helm/commit/d9befbb65561716987a9825587f5ac0c9b63be3b))
* **ci:** Add Semantic Release changelog ([6537310](https://github.com/LerianStudio/helm/commit/6537310682b459b7f9fd48ed3c18dd739a816b0f))
* add step to update gh-pages ([bd762c7](https://github.com/LerianStudio/helm/commit/bd762c72ead853758a349d52913a63b45ed40a5c))
* add step to update gh-pages ([ddffd1b](https://github.com/LerianStudio/helm/commit/ddffd1b3dfbd179e26958361965f93a62273af07))
* **console:** adds new env vars ([473cf5a](https://github.com/LerianStudio/helm/commit/473cf5a8d681e42c9ad8318b42b08dbea1e3e045))
* **chart:** configure pdb to auth backend ([112bc47](https://github.com/LerianStudio/helm/commit/112bc47d72db94b57e81138297d973cb31d4ddf6))
* **helm:** create chart file to plugin crm ([69b01c8](https://github.com/LerianStudio/helm/commit/69b01c868752eb91973e2d292eb2e7ffaa57c1e0))
* **helm:** create chart file to plugin-fees ([38a0e81](https://github.com/LerianStudio/helm/commit/38a0e81c29d53bb81bb1895869b058942bc1d116))
* create chart midaz opensource ([afeadcf](https://github.com/LerianStudio/helm/commit/afeadcf46aef60af8b74055695a55fc00131f029))
* **helm:** create chart templates to plugin crm ([777ea2f](https://github.com/LerianStudio/helm/commit/777ea2fa1582d1530fbc4946c4ef184ae90598e9))
* **chart:** create chart templates to plugin-fees ([adabbaa](https://github.com/LerianStudio/helm/commit/adabbaaf405b471b111abe208408fce9c0772e99))
* **chart:** create chart templates to plugin-fees ([303caf0](https://github.com/LerianStudio/helm/commit/303caf06a48ff63e20fcdd13fd2c5d0629aae33c))
* **helm:** create doc to plugin crm ([4cbaa9d](https://github.com/LerianStudio/helm/commit/4cbaa9d4e8377260508c5687f292cfec8dbeee36))
* **dependencies:** create init config file ([bddd6f0](https://github.com/LerianStudio/helm/commit/bddd6f025782740e3fc021ae4d7e64c0e78fd580))
* **dependencies:** create init sql file ([dcca103](https://github.com/LerianStudio/helm/commit/dcca103dcf229a307833685ad04711f662099219))
* **values:** create pdb definitions ([fe34974](https://github.com/LerianStudio/helm/commit/fe34974aaa497979e0d13b610b77b4d1d7895f2f))
* **console:** create pdb template ([102c56a](https://github.com/LerianStudio/helm/commit/102c56a6e697623317585b8808f09f3cb7458882))
* **onboarding:** create pdb template ([8bc0d48](https://github.com/LerianStudio/helm/commit/8bc0d489407c8c5181a20f2c731e5abc7946b8b6))
* **transaction:** create pdb template ([738f5d3](https://github.com/LerianStudio/helm/commit/738f5d3ff33cc62f155186af1514340fa3133503))
* **chart:** create plugin access manager auth templates ([2fdd9ac](https://github.com/LerianStudio/helm/commit/2fdd9ac466966c5557757afae07a52f9894240fd))
* **chart:** create plugin access manager chart file ([094eecc](https://github.com/LerianStudio/helm/commit/094eeccff09029260104c7428a254c25260d20d6))
* **chart:** create plugin access manager identity templates ([c52068d](https://github.com/LerianStudio/helm/commit/c52068d228e3a79bbf4904e9823fb29407694add))
* **chart:** create plugin access manager templates ([c4221ad](https://github.com/LerianStudio/helm/commit/c4221adf91b52acc3c590d9d7b1f8db314f01d88))
* **values:** create plugin access manager values file ([b1727d0](https://github.com/LerianStudio/helm/commit/b1727d0f162fb1c464b35559f5684740a5af819e))
* **helm:** create values file to plugin crm ([de6b154](https://github.com/LerianStudio/helm/commit/de6b1547947f91d580a9ff5f7fb14c1e5efa4d0d))
* **values:** create values file to plugin-fees ([304f228](https://github.com/LerianStudio/helm/commit/304f22871b76180f4b299daa3ecaac06571ffd92))
* **values:** create values file to plugin-fees ([f383281](https://github.com/LerianStudio/helm/commit/f383281421b709744823d9de1bc053288ab6d747))
* dependency update ([18bd991](https://github.com/LerianStudio/helm/commit/18bd9910348f05785a975b38d8b11068f1069407))
* dependency update ([b56d142](https://github.com/LerianStudio/helm/commit/b56d1421e7251dc932d4b025cc6be4be31ee3c42))
* dependency update ([55eb548](https://github.com/LerianStudio/helm/commit/55eb5489f192d16508b7ecfd93bddcf71aa42feb))
* **grafana:** disable grafana ([423a6f5](https://github.com/LerianStudio/helm/commit/423a6f5495c50c4ccae86c5391cb52841af300e8))
* enable karpenter node ([02b029d](https://github.com/LerianStudio/helm/commit/02b029d1a18e462be5c5c11c5d0c5f0cceee6122))
* **console:** enforce absolute DNS resolution ([8e519fe](https://github.com/LerianStudio/helm/commit/8e519fe25255119d50ecfef91ca8ab5a01df5f78))
* **onboarding:** enforce absolute DNS resolution ([c471521](https://github.com/LerianStudio/helm/commit/c471521eb53ce2e100f080247c2ff25bc1255650))
* **transaction:** enforce absolute DNS resolution ([1759a5b](https://github.com/LerianStudio/helm/commit/1759a5b1ce44339302482bd5ccabed5056c33a2f))
* helm doc ([#26](https://github.com/LerianStudio/helm/issues/26)) ([ccb3021](https://github.com/LerianStudio/helm/commit/ccb30211fbd9ab5b1ff5e3151f1f9361d25e3cff))
* midaz helm chart ([8768a8e](https://github.com/LerianStudio/helm/commit/8768a8e1f97dbe82d0cb96b899c3865e7b9c95c3))
* midaz helm chart ([94b2a6e](https://github.com/LerianStudio/helm/commit/94b2a6eab897bb6c1cd6f336fc9cf12f642ad697))
* **pipe:** new pipe to deploy all charts ([20629f5](https://github.com/LerianStudio/helm/commit/20629f50ce386463a83ac0ebc0fce367430f04a0))
* **pipe:** new releaserc template ([24dc653](https://github.com/LerianStudio/helm/commit/24dc653adae4f036f7d5b9da044f42c43e9acd09))
* postgres replication ([fa57f99](https://github.com/LerianStudio/helm/commit/fa57f99ed9d8dc8a157b776c65a02beb6f3453b4))
* **doc:** remove old components ([954dd09](https://github.com/LerianStudio/helm/commit/954dd097b1be74841efa6022a94d807e228c6ec4))
* **github:** remove pgbouncer reference ([49924e8](https://github.com/LerianStudio/helm/commit/49924e811d918e8ed136e878bb480da51096d98a))
* **pipe:** remove step commit history ([b0fd599](https://github.com/LerianStudio/helm/commit/b0fd5993ef1eecb84d34759552871d9f1447b7a3))
* **pipe:** remove step commit history ([e42b665](https://github.com/LerianStudio/helm/commit/e42b665d1bda4e9461e08b855e120fcb596c6521))
* **pipe:** remove step commit history ([ed1ec98](https://github.com/LerianStudio/helm/commit/ed1ec98c8132bd84ee4c344cd70ac9da355bf9af))
* **pipe:** remove step commit history ([b8b256d](https://github.com/LerianStudio/helm/commit/b8b256d997e838caea71ced0ed190e24aa73896a))
* **pipe:** remove step commit history ([a56f7c6](https://github.com/LerianStudio/helm/commit/a56f7c6027fe4e5c90f08231b2cab83e1dc4cc30))
* **pipe:** remove step commit history ([323b43a](https://github.com/LerianStudio/helm/commit/323b43aa1b8b73d103cdaba3b692d2bde73ff772))
* **chart:** update app version ([348b0cc](https://github.com/LerianStudio/helm/commit/348b0ccb5fea5042fe08da2af81cbd0b323a7aca))
* **chart:** update app version ([6f40285](https://github.com/LerianStudio/helm/commit/6f402851add6d9898c04e263d5706644645cacb2))
* **values:** update app version ([598ed6d](https://github.com/LerianStudio/helm/commit/598ed6d478240d26ee9baa9560d73db1912ba05d))
* **values:** update apps version and add backend config ([7cb17c2](https://github.com/LerianStudio/helm/commit/7cb17c2225d0863ee655b6ea5fc5532421ffa93d))
* **dependencies:** update auth backend init file ([be72215](https://github.com/LerianStudio/helm/commit/be72215937655d4adb136ae9802d68ade6a279b9))
* **chart:** update auth backend templates ([8659b67](https://github.com/LerianStudio/helm/commit/8659b6758e533c9a0922d481107ba59656d3f0a5))
* **chart:** update auth templates ([a6221e4](https://github.com/LerianStudio/helm/commit/a6221e4b89edec63f40b80bd31574588d9204a5b))
* **chart:** update auth templates ([c5bcb23](https://github.com/LerianStudio/helm/commit/c5bcb23959466580106b98f7e3312195f7f42f35))
* **console:** update console image ([0cf1135](https://github.com/LerianStudio/helm/commit/0cf11350d345410c751d99cf8c5347793219b469))
* **console:** update console image ([4da311d](https://github.com/LerianStudio/helm/commit/4da311d8968411a29d129ef02e133b3ddd0bb25e))
* **console:** update console version ([d789c7d](https://github.com/LerianStudio/helm/commit/d789c7dc7596e65c90c0e18072687b2ea828b295))
* **values:** update console version ([778eea0](https://github.com/LerianStudio/helm/commit/778eea0d86f62b9257f4f94892ef2b340df945da))
* **values:** update extra env vars for postgres ([9852143](https://github.com/LerianStudio/helm/commit/9852143eff1ca1bbc3e6c33660d80ec4bb337d6d))
* **pipe:** update gitignore ([6ae09d6](https://github.com/LerianStudio/helm/commit/6ae09d68f21e21e5b93834017c0525511baaf94a))
* **chart:** update identity templates ([f8def52](https://github.com/LerianStudio/helm/commit/f8def529a453cf4c2db448df07ba167ff14d6c83))
* **values:** update midaz version ([#36](https://github.com/LerianStudio/helm/issues/36)) ([af4b898](https://github.com/LerianStudio/helm/commit/af4b898e7ed4e431ab853320a3275b9d219630f7))
* **chart:** update plugin access manager values ([e4221eb](https://github.com/LerianStudio/helm/commit/e4221ebc5da46a51c5d71ef0755bba35e3313584))
* **values:** update resources limits ([04ccb18](https://github.com/LerianStudio/helm/commit/04ccb184cd7393e5c1f60fa5945fd89d0b5289d2))
* **values:** update values file ([db9b3db](https://github.com/LerianStudio/helm/commit/db9b3db3961bea039663a7dba0f548601e3c146b))
* **values:** update values file ([cc698a0](https://github.com/LerianStudio/helm/commit/cc698a0a76b24e97b4ff890605535e9ad128e886))
* **chart:** update version ([40d723d](https://github.com/LerianStudio/helm/commit/40d723d6159d78f2a198cdfa9c7c969d07219289))
* **chart:** update version ([22e2930](https://github.com/LerianStudio/helm/commit/22e2930ce80b8e33926bb6db7a5f70ca6faa4fa5))
* **chart:** update version ([8031ceb](https://github.com/LerianStudio/helm/commit/8031cebf57f599fda19f74224cd17a746bfe1e21))
* **chart:** update version ([a8af389](https://github.com/LerianStudio/helm/commit/a8af389aa9135313e2e534e4fd0af358a3b8fcf2))
* **chart:** update version ([412e782](https://github.com/LerianStudio/helm/commit/412e782cff316594cb5b6ea0410a7c5d66ebf6a1))
* **chart:** update version ([4a42b13](https://github.com/LerianStudio/helm/commit/4a42b1367e2ac41654210610641c44fcb7f8b463))


### Bug Fixes

* **values:** add comments in values ([#43](https://github.com/LerianStudio/helm/issues/43)) ([03a5842](https://github.com/LerianStudio/helm/commit/03a5842787db8dc1b4d954038b36a343ad7180c1))
* **chart:** add new env var to enable auth plugin ([53b8ffb](https://github.com/LerianStudio/helm/commit/53b8ffb5ef5beaf77756b45e815b946b106c9320))
* **onboarding:** auth endpoint and remove old env var ([de370da](https://github.com/LerianStudio/helm/commit/de370daa57563a194d5273888587f0aa95262a0b))
* **transaction:** auth endpoint ([12d8f6d](https://github.com/LerianStudio/helm/commit/12d8f6d3c9d52bff108f220f297d0d4f1db6ca78))
* **values:** auth env vars ([23b34a1](https://github.com/LerianStudio/helm/commit/23b34a13ea547a1587d71689b30adfe02f580dc0))
* chart ([81f1126](https://github.com/LerianStudio/helm/commit/81f112612a3327fffc69da8720b2222122df44a4))
* chart ([f6e6446](https://github.com/LerianStudio/helm/commit/f6e644662db2f641b0e71e3cccd518fa4fe715dc))
* chart name ([6db8350](https://github.com/LerianStudio/helm/commit/6db83502f0f75b59a5345c27eeade292b31078a9))
* chart name ([1f78da5](https://github.com/LerianStudio/helm/commit/1f78da504538d1a518f503e69b21b1696a893313))
* codeowners groups ([#23](https://github.com/LerianStudio/helm/issues/23)) ([b51ff0c](https://github.com/LerianStudio/helm/commit/b51ff0ce5f7d838c2f01565340d91a79cd9c772f))
* **auth:** disable auth ingress ([4e08d7a](https://github.com/LerianStudio/helm/commit/4e08d7af33f67b9500b459a40ad93473cf82007f))
* fix ([8e3d5ad](https://github.com/LerianStudio/helm/commit/8e3d5ad6deff4dc6a84d7f0c343d5e605428686f))
* fix ([3ff9f64](https://github.com/LerianStudio/helm/commit/3ff9f645ed8119d28a4dc256848d27206a4d80ce))
* **audit:** fix audit configmap ([#41](https://github.com/LerianStudio/helm/issues/41)) ([429fdef](https://github.com/LerianStudio/helm/commit/429fdef691c87dc5b4a7e44c236b2550f548c20d))
* **values:** fix autoscaling parameters ([69585b6](https://github.com/LerianStudio/helm/commit/69585b6743736edad8d393c5e50eddc9e4ff114d))
* **transaction:** fix default value of rabbitmq secret ([71afd7a](https://github.com/LerianStudio/helm/commit/71afd7a7067ee4b1cf429669e4a44c58479af037))
* **doc:** fix midaz transaction container port ([bab48e6](https://github.com/LerianStudio/helm/commit/bab48e600b179abf07bbc207982803102ea1d704))
* **pipe:** fix pr title workflow ([#34](https://github.com/LerianStudio/helm/issues/34)) ([5134118](https://github.com/LerianStudio/helm/commit/51341186dfd7f643e3be1d598c51d3909748a3dd))
* **transaction:** fix transaction container port ([cb4ec59](https://github.com/LerianStudio/helm/commit/cb4ec592c2c47036bee2b519d795ca08336904dc))
* generate multiples CHANGELOG's ([3f60787](https://github.com/LerianStudio/helm/commit/3f607875b618db474e4055c44a2cffd8216f4261))
* helm chart ([9b6552f](https://github.com/LerianStudio/helm/commit/9b6552f37d039bb5187c92319bcc3787d1c4ddcc))
* **components:** init file for auth app ([4939e82](https://github.com/LerianStudio/helm/commit/4939e823f60cdbc0965281f496b058178bf70a00))
* **components:** load definitions for rabbitmq ([167c80a](https://github.com/LerianStudio/helm/commit/167c80a8e156fb653e2e365f155c4c35e2785fca))
* **docs:** rabbitmq mispelling name ([cefee91](https://github.com/LerianStudio/helm/commit/cefee916b39020938945ce97f442dbdbf3ba6d63))
* **onboarding:** rabbitmq mispelling name ([bf8de0c](https://github.com/LerianStudio/helm/commit/bf8de0cf79e4a40a3fa0bb7581a7f11b9458de76))
* **transaction:** rabbitmq mispelling name ([8e05032](https://github.com/LerianStudio/helm/commit/8e050329da399b563d2ce6f5fa70edcf2291cccd))
* **onboarding:** remove grpc port from container ([3bd9621](https://github.com/LerianStudio/helm/commit/3bd96218a95decae1c58cc29078c8bbfd71736a9))
* remove hook ([aa92d78](https://github.com/LerianStudio/helm/commit/aa92d78f74000f6f4f2c7fc22db35cc0010916ca))
* **onboarding:** remove old secrets ([0c7966f](https://github.com/LerianStudio/helm/commit/0c7966f91207c688b0e014bab463dac40846f56e))
* **trasaction:** remove old secrets ([1a2a10c](https://github.com/LerianStudio/helm/commit/1a2a10c9a165c0767f45b7909276c287d5c4d3a3))
* **audit:** rename env vars and update container port ([9796046](https://github.com/LerianStudio/helm/commit/979604649c30ce6b8788acb3c1f67dff1a765f63))
* **transaction:** rename env vars and update container port ([4052bc5](https://github.com/LerianStudio/helm/commit/4052bc51634b989fba34c2245319db767aa02275))
* **chart:** rename ledger component to onboarding ([47dd9d0](https://github.com/LerianStudio/helm/commit/47dd9d01c491f30669c3f4ec6271bae1c8d0de75))
* **chart:** rename ledger component to onboarding ([e04404b](https://github.com/LerianStudio/helm/commit/e04404b79c78396a6cb1227cafa5bad10b51d3ee))
* **doc:** rename ledger component to onboarding ([0aa6e34](https://github.com/LerianStudio/helm/commit/0aa6e34ed38d68308cec31b5280b17c017c3d277))
* **components:** rename ledger db for onboarding ([40e49b8](https://github.com/LerianStudio/helm/commit/40e49b8cb2dcf6b169ea4a9c32b5c516f0d06b57))
* **pipe:** rename ledger to onboarding ([448ce90](https://github.com/LerianStudio/helm/commit/448ce9015baee8d553a81f6253d77d76bb96c3ba))
* **dependencies:** rename otel to grafana ([#57](https://github.com/LerianStudio/helm/issues/57)) ([974c47f](https://github.com/LerianStudio/helm/commit/974c47f6974d42804e5210d530829efa0394d734))
* setup otel in template ([#24](https://github.com/LerianStudio/helm/issues/24)) ([837fd03](https://github.com/LerianStudio/helm/commit/837fd03c642b14387299b9b4a50fe00dc22e2f29))
* **components:** sql init for auth app ([9824943](https://github.com/LerianStudio/helm/commit/9824943ab8a6d2e038cd55448259c27149c50546))
* templates ([bc18fc3](https://github.com/LerianStudio/helm/commit/bc18fc3fddd8736d8694f3be401d1a85fc781039))
* update mongodb ([858c934](https://github.com/LerianStudio/helm/commit/858c93496a5e45fcb84389614536d63ca6b84a02))
* **doc:** update nginx ingress config ([#35](https://github.com/LerianStudio/helm/issues/35)) ([d9763ea](https://github.com/LerianStudio/helm/commit/d9763ea4c2139c7d5f020d71422a634f37e15172))
* values ([b1dc8f7](https://github.com/LerianStudio/helm/commit/b1dc8f7105ab3aa0bbed2549525f013875087b7d))

##  (2025-04-25)


### Features

* **values:** add app new version and reference default config ([b972952](https://github.com/LerianStudio/helm/commit/b97295261b87645884b197bbbf8aeea8dd78e452))
* **values:** add app new version and reference default secret ([ef8069c](https://github.com/LerianStudio/helm/commit/ef8069c403b3e7878571ddb3b92ee6f8be2f251f))
* **chart:** add auth backend helpers functions ([7248963](https://github.com/LerianStudio/helm/commit/72489636dfd8d57191e4d61da0369d6267b277df))
* **chart:** add auth backend templates ([57fb163](https://github.com/LerianStudio/helm/commit/57fb163b2c7cca15b1006ef493e3ee43b7cc616c))
* **onboarding:** add auth config ([8a055cb](https://github.com/LerianStudio/helm/commit/8a055cb83b9f6a9d9c76ca3343ab6a61c1d1c00c))
* **transaction:** add auth config ([a7ede5b](https://github.com/LerianStudio/helm/commit/a7ede5b29f6c69752cffad6970d5d73bd21062cb))
* **pipe:** add branch develop to generate beta release ([2990c0e](https://github.com/LerianStudio/helm/commit/2990c0e71d5b6773321b67c986b0a5a32b970cd3))
* add dependencies to midaz helm ([e1e4095](https://github.com/LerianStudio/helm/commit/e1e4095c7e9fc48c69738c0610ee7ad4bd56c12a))
* **values:** add deployment strategy definitions ([dd93837](https://github.com/LerianStudio/helm/commit/dd9383729db20e4f88265edde5900d35c7dbbafa))
* **console:** add deployment strategy ([0000ab0](https://github.com/LerianStudio/helm/commit/0000ab0a6c088e2eca167f396bff859638b478e4))
* **onboarding:** add deployment strategy ([220274b](https://github.com/LerianStudio/helm/commit/220274beb453eb54ec6e9c3a6020016cf8a7be91))
* **transaction:** add deployment strategy ([65076f4](https://github.com/LerianStudio/helm/commit/65076f421904b98f46329ff40cb31f7cf409476b))
* add doc ([5593a96](https://github.com/LerianStudio/helm/commit/5593a96ff02c3b968c4a703a5a7ccc2afa53be04))
* add doc ([97daf1e](https://github.com/LerianStudio/helm/commit/97daf1ecb4c2a51415c58cf0bc815a36d1e52cc3))
* add doc ([2f02d2e](https://github.com/LerianStudio/helm/commit/2f02d2ef0fad7ad80fe131253a8e232b66499430))
* add doc ([6e20f92](https://github.com/LerianStudio/helm/commit/6e20f92c1c31fa26560edfa77fec348783564de2))
* **doc:** add general readme and moving midaz readme ([41f11fe](https://github.com/LerianStudio/helm/commit/41f11fe167c213be99413d4b0b82a9becbe482f6))
* add gpg key and clean file ([81630ce](https://github.com/LerianStudio/helm/commit/81630ce857b0e00600b63d602c3dec4df45eab61))
* add helm-compose config and karpenter node ([9a52467](https://github.com/LerianStudio/helm/commit/9a52467339718fd820e76355e97113cb6104fc2c))
* add index to semantic-release versioning ([4c98cf1](https://github.com/LerianStudio/helm/commit/4c98cf120e280bcdb252fed83aab285f1fa0f5e8))
* add index to semantic-release versioning ([af4c306](https://github.com/LerianStudio/helm/commit/af4c306d8e6ece405b451407c941eb1bf4eff5bd))
* add init container in casdoor to check if the database is ready ([#48](https://github.com/LerianStudio/helm/issues/48)) ([8337771](https://github.com/LerianStudio/helm/commit/833777165ff6ed1d4183cc48757acd2d8b7ddd83))
* **doc:** add lerian banner ([35b904a](https://github.com/LerianStudio/helm/commit/35b904afb9d910e51b1508693aa7c3ce06ea9a75))
* **console:** add new console env vars ([cf974b8](https://github.com/LerianStudio/helm/commit/cf974b8d696f9eb89e951fd144632d0e5817291f))
* **console:** add new env vars ([a228e39](https://github.com/LerianStudio/helm/commit/a228e39c856f9f4b561d55949edcaa051d5b9af9))
* **console:** add new env vars ([8b8d76f](https://github.com/LerianStudio/helm/commit/8b8d76f525a96f36c1d694c65db51ed7280a68a5))
* **dependencies:** add new parameters to chart file ([#44](https://github.com/LerianStudio/helm/issues/44)) ([4796070](https://github.com/LerianStudio/helm/commit/4796070cb5ad4c32d28bbb7ffc085b5fb3aeb495))
* **doc:** add new version ([39c0a71](https://github.com/LerianStudio/helm/commit/39c0a71dacbe9c80aa095a580c5d42d153b0947b))
* **doc:** add new version ([f864ad2](https://github.com/LerianStudio/helm/commit/f864ad20353a26f7dbe525332ef3b54f6af6fb74))
* add plugin to semantic-release ([4ec01d8](https://github.com/LerianStudio/helm/commit/4ec01d8aceef35145239ae5b513977531798b329))
* add plugin to semantic-release ([d102c52](https://github.com/LerianStudio/helm/commit/d102c52039f5c1262f9dc00eb07728d226e656ef))
* add plugin to semantic-release ([a26017e](https://github.com/LerianStudio/helm/commit/a26017e363c87530e30e96e9b5fdc2581c19bb49))
* add plugin to semantic-release ([b001de0](https://github.com/LerianStudio/helm/commit/b001de0f2fad2b2b1cf05b5c0db9f48aa1af5265))
* add plugin to semantic-release ([f786586](https://github.com/LerianStudio/helm/commit/f7865866e41aad38bdf343e45fce351fa2af2a9b))
* add plugin to semantic-release ([13f0af3](https://github.com/LerianStudio/helm/commit/13f0af38e59cf9fb7a3596293a83dd3e6b9757a0))
* **pipe:** add release step for ghcr ([f0e4f3f](https://github.com/LerianStudio/helm/commit/f0e4f3f5221b392bb68b2a5f87aa85facc5cfbee))
* **console:** add secrets ([ad89e3b](https://github.com/LerianStudio/helm/commit/ad89e3ba7bd1713686bc0546be1e6b11341b10da))
* **chart:** add security context to plugin identity ([47b48fc](https://github.com/LerianStudio/helm/commit/47b48fc9ec49f706519fceb4a7007c0179f62317))
* **pipe:** Add semantic changelog ([8c65e59](https://github.com/LerianStudio/helm/commit/8c65e5970101edc9ac621ec30b783bbc4fc3225c))
* **pipe:** Add semantic changelog ([452b6e7](https://github.com/LerianStudio/helm/commit/452b6e78b97a10aa4cd94daf5c95cd1545dc8222))
* **pipe:** Add semantic changelog ([c54115e](https://github.com/LerianStudio/helm/commit/c54115ebf8bd43a0dc8d41233d1100ac136ba8c3))
* **pipe:** Add semantic changelog ([d9befbb](https://github.com/LerianStudio/helm/commit/d9befbb65561716987a9825587f5ac0c9b63be3b))
* **ci:** Add Semantic Release changelog ([6537310](https://github.com/LerianStudio/helm/commit/6537310682b459b7f9fd48ed3c18dd739a816b0f))
* add step to update gh-pages ([bd762c7](https://github.com/LerianStudio/helm/commit/bd762c72ead853758a349d52913a63b45ed40a5c))
* add step to update gh-pages ([ddffd1b](https://github.com/LerianStudio/helm/commit/ddffd1b3dfbd179e26958361965f93a62273af07))
* **console:** adds new env vars ([473cf5a](https://github.com/LerianStudio/helm/commit/473cf5a8d681e42c9ad8318b42b08dbea1e3e045))
* **chart:** configure pdb to auth backend ([112bc47](https://github.com/LerianStudio/helm/commit/112bc47d72db94b57e81138297d973cb31d4ddf6))
* **helm:** create chart file to plugin crm ([69b01c8](https://github.com/LerianStudio/helm/commit/69b01c868752eb91973e2d292eb2e7ffaa57c1e0))
* **helm:** create chart file to plugin-fees ([38a0e81](https://github.com/LerianStudio/helm/commit/38a0e81c29d53bb81bb1895869b058942bc1d116))
* create chart midaz opensource ([afeadcf](https://github.com/LerianStudio/helm/commit/afeadcf46aef60af8b74055695a55fc00131f029))
* **helm:** create chart templates to plugin crm ([777ea2f](https://github.com/LerianStudio/helm/commit/777ea2fa1582d1530fbc4946c4ef184ae90598e9))
* **chart:** create chart templates to plugin-fees ([adabbaa](https://github.com/LerianStudio/helm/commit/adabbaaf405b471b111abe208408fce9c0772e99))
* **chart:** create chart templates to plugin-fees ([303caf0](https://github.com/LerianStudio/helm/commit/303caf06a48ff63e20fcdd13fd2c5d0629aae33c))
* **helm:** create doc to plugin crm ([4cbaa9d](https://github.com/LerianStudio/helm/commit/4cbaa9d4e8377260508c5687f292cfec8dbeee36))
* **dependencies:** create init config file ([bddd6f0](https://github.com/LerianStudio/helm/commit/bddd6f025782740e3fc021ae4d7e64c0e78fd580))
* **dependencies:** create init sql file ([dcca103](https://github.com/LerianStudio/helm/commit/dcca103dcf229a307833685ad04711f662099219))
* **values:** create pdb definitions ([fe34974](https://github.com/LerianStudio/helm/commit/fe34974aaa497979e0d13b610b77b4d1d7895f2f))
* **console:** create pdb template ([102c56a](https://github.com/LerianStudio/helm/commit/102c56a6e697623317585b8808f09f3cb7458882))
* **onboarding:** create pdb template ([8bc0d48](https://github.com/LerianStudio/helm/commit/8bc0d489407c8c5181a20f2c731e5abc7946b8b6))
* **transaction:** create pdb template ([738f5d3](https://github.com/LerianStudio/helm/commit/738f5d3ff33cc62f155186af1514340fa3133503))
* **chart:** create plugin access manager auth templates ([2fdd9ac](https://github.com/LerianStudio/helm/commit/2fdd9ac466966c5557757afae07a52f9894240fd))
* **chart:** create plugin access manager chart file ([094eecc](https://github.com/LerianStudio/helm/commit/094eeccff09029260104c7428a254c25260d20d6))
* **chart:** create plugin access manager identity templates ([c52068d](https://github.com/LerianStudio/helm/commit/c52068d228e3a79bbf4904e9823fb29407694add))
* **chart:** create plugin access manager templates ([c4221ad](https://github.com/LerianStudio/helm/commit/c4221adf91b52acc3c590d9d7b1f8db314f01d88))
* **values:** create plugin access manager values file ([b1727d0](https://github.com/LerianStudio/helm/commit/b1727d0f162fb1c464b35559f5684740a5af819e))
* **helm:** create values file to plugin crm ([de6b154](https://github.com/LerianStudio/helm/commit/de6b1547947f91d580a9ff5f7fb14c1e5efa4d0d))
* **values:** create values file to plugin-fees ([304f228](https://github.com/LerianStudio/helm/commit/304f22871b76180f4b299daa3ecaac06571ffd92))
* **values:** create values file to plugin-fees ([f383281](https://github.com/LerianStudio/helm/commit/f383281421b709744823d9de1bc053288ab6d747))
* dependency update ([18bd991](https://github.com/LerianStudio/helm/commit/18bd9910348f05785a975b38d8b11068f1069407))
* dependency update ([b56d142](https://github.com/LerianStudio/helm/commit/b56d1421e7251dc932d4b025cc6be4be31ee3c42))
* dependency update ([55eb548](https://github.com/LerianStudio/helm/commit/55eb5489f192d16508b7ecfd93bddcf71aa42feb))
* **grafana:** disable grafana ([423a6f5](https://github.com/LerianStudio/helm/commit/423a6f5495c50c4ccae86c5391cb52841af300e8))
* enable karpenter node ([02b029d](https://github.com/LerianStudio/helm/commit/02b029d1a18e462be5c5c11c5d0c5f0cceee6122))
* **console:** enforce absolute DNS resolution ([8e519fe](https://github.com/LerianStudio/helm/commit/8e519fe25255119d50ecfef91ca8ab5a01df5f78))
* **onboarding:** enforce absolute DNS resolution ([c471521](https://github.com/LerianStudio/helm/commit/c471521eb53ce2e100f080247c2ff25bc1255650))
* **transaction:** enforce absolute DNS resolution ([1759a5b](https://github.com/LerianStudio/helm/commit/1759a5b1ce44339302482bd5ccabed5056c33a2f))
* helm doc ([#26](https://github.com/LerianStudio/helm/issues/26)) ([ccb3021](https://github.com/LerianStudio/helm/commit/ccb30211fbd9ab5b1ff5e3151f1f9361d25e3cff))
* midaz helm chart ([8768a8e](https://github.com/LerianStudio/helm/commit/8768a8e1f97dbe82d0cb96b899c3865e7b9c95c3))
* midaz helm chart ([94b2a6e](https://github.com/LerianStudio/helm/commit/94b2a6eab897bb6c1cd6f336fc9cf12f642ad697))
* **pipe:** new pipe to deploy all charts ([20629f5](https://github.com/LerianStudio/helm/commit/20629f50ce386463a83ac0ebc0fce367430f04a0))
* **pipe:** new releaserc template ([24dc653](https://github.com/LerianStudio/helm/commit/24dc653adae4f036f7d5b9da044f42c43e9acd09))
* postgres replication ([fa57f99](https://github.com/LerianStudio/helm/commit/fa57f99ed9d8dc8a157b776c65a02beb6f3453b4))
* **doc:** remove old components ([954dd09](https://github.com/LerianStudio/helm/commit/954dd097b1be74841efa6022a94d807e228c6ec4))
* **github:** remove pgbouncer reference ([49924e8](https://github.com/LerianStudio/helm/commit/49924e811d918e8ed136e878bb480da51096d98a))
* **pipe:** remove step commit history ([b0fd599](https://github.com/LerianStudio/helm/commit/b0fd5993ef1eecb84d34759552871d9f1447b7a3))
* **pipe:** remove step commit history ([e42b665](https://github.com/LerianStudio/helm/commit/e42b665d1bda4e9461e08b855e120fcb596c6521))
* **pipe:** remove step commit history ([ed1ec98](https://github.com/LerianStudio/helm/commit/ed1ec98c8132bd84ee4c344cd70ac9da355bf9af))
* **pipe:** remove step commit history ([b8b256d](https://github.com/LerianStudio/helm/commit/b8b256d997e838caea71ced0ed190e24aa73896a))
* **pipe:** remove step commit history ([a56f7c6](https://github.com/LerianStudio/helm/commit/a56f7c6027fe4e5c90f08231b2cab83e1dc4cc30))
* **pipe:** remove step commit history ([323b43a](https://github.com/LerianStudio/helm/commit/323b43aa1b8b73d103cdaba3b692d2bde73ff772))
* **chart:** update app version ([348b0cc](https://github.com/LerianStudio/helm/commit/348b0ccb5fea5042fe08da2af81cbd0b323a7aca))
* **chart:** update app version ([6f40285](https://github.com/LerianStudio/helm/commit/6f402851add6d9898c04e263d5706644645cacb2))
* **values:** update app version ([598ed6d](https://github.com/LerianStudio/helm/commit/598ed6d478240d26ee9baa9560d73db1912ba05d))
* **values:** update apps version and add backend config ([7cb17c2](https://github.com/LerianStudio/helm/commit/7cb17c2225d0863ee655b6ea5fc5532421ffa93d))
* **dependencies:** update auth backend init file ([be72215](https://github.com/LerianStudio/helm/commit/be72215937655d4adb136ae9802d68ade6a279b9))
* **chart:** update auth backend templates ([8659b67](https://github.com/LerianStudio/helm/commit/8659b6758e533c9a0922d481107ba59656d3f0a5))
* **chart:** update auth templates ([a6221e4](https://github.com/LerianStudio/helm/commit/a6221e4b89edec63f40b80bd31574588d9204a5b))
* **chart:** update auth templates ([c5bcb23](https://github.com/LerianStudio/helm/commit/c5bcb23959466580106b98f7e3312195f7f42f35))
* **console:** update console image ([0cf1135](https://github.com/LerianStudio/helm/commit/0cf11350d345410c751d99cf8c5347793219b469))
* **console:** update console image ([4da311d](https://github.com/LerianStudio/helm/commit/4da311d8968411a29d129ef02e133b3ddd0bb25e))
* **console:** update console version ([d789c7d](https://github.com/LerianStudio/helm/commit/d789c7dc7596e65c90c0e18072687b2ea828b295))
* **values:** update console version ([778eea0](https://github.com/LerianStudio/helm/commit/778eea0d86f62b9257f4f94892ef2b340df945da))
* **values:** update extra env vars for postgres ([9852143](https://github.com/LerianStudio/helm/commit/9852143eff1ca1bbc3e6c33660d80ec4bb337d6d))
* **pipe:** update gitignore ([6ae09d6](https://github.com/LerianStudio/helm/commit/6ae09d68f21e21e5b93834017c0525511baaf94a))
* **chart:** update identity templates ([f8def52](https://github.com/LerianStudio/helm/commit/f8def529a453cf4c2db448df07ba167ff14d6c83))
* **values:** update midaz version ([#36](https://github.com/LerianStudio/helm/issues/36)) ([af4b898](https://github.com/LerianStudio/helm/commit/af4b898e7ed4e431ab853320a3275b9d219630f7))
* **chart:** update plugin access manager values ([e4221eb](https://github.com/LerianStudio/helm/commit/e4221ebc5da46a51c5d71ef0755bba35e3313584))
* **values:** update resources limits ([04ccb18](https://github.com/LerianStudio/helm/commit/04ccb184cd7393e5c1f60fa5945fd89d0b5289d2))
* **values:** update values file ([db9b3db](https://github.com/LerianStudio/helm/commit/db9b3db3961bea039663a7dba0f548601e3c146b))
* **values:** update values file ([cc698a0](https://github.com/LerianStudio/helm/commit/cc698a0a76b24e97b4ff890605535e9ad128e886))
* **chart:** update version ([40d723d](https://github.com/LerianStudio/helm/commit/40d723d6159d78f2a198cdfa9c7c969d07219289))
* **chart:** update version ([22e2930](https://github.com/LerianStudio/helm/commit/22e2930ce80b8e33926bb6db7a5f70ca6faa4fa5))
* **chart:** update version ([8031ceb](https://github.com/LerianStudio/helm/commit/8031cebf57f599fda19f74224cd17a746bfe1e21))
* **chart:** update version ([a8af389](https://github.com/LerianStudio/helm/commit/a8af389aa9135313e2e534e4fd0af358a3b8fcf2))
* **chart:** update version ([412e782](https://github.com/LerianStudio/helm/commit/412e782cff316594cb5b6ea0410a7c5d66ebf6a1))
* **chart:** update version ([4a42b13](https://github.com/LerianStudio/helm/commit/4a42b1367e2ac41654210610641c44fcb7f8b463))


### Bug Fixes

* **values:** add comments in values ([#43](https://github.com/LerianStudio/helm/issues/43)) ([03a5842](https://github.com/LerianStudio/helm/commit/03a5842787db8dc1b4d954038b36a343ad7180c1))
* **chart:** add new env var to enable auth plugin ([53b8ffb](https://github.com/LerianStudio/helm/commit/53b8ffb5ef5beaf77756b45e815b946b106c9320))
* **onboarding:** auth endpoint and remove old env var ([de370da](https://github.com/LerianStudio/helm/commit/de370daa57563a194d5273888587f0aa95262a0b))
* **transaction:** auth endpoint ([12d8f6d](https://github.com/LerianStudio/helm/commit/12d8f6d3c9d52bff108f220f297d0d4f1db6ca78))
* **values:** auth env vars ([23b34a1](https://github.com/LerianStudio/helm/commit/23b34a13ea547a1587d71689b30adfe02f580dc0))
* chart ([81f1126](https://github.com/LerianStudio/helm/commit/81f112612a3327fffc69da8720b2222122df44a4))
* chart ([f6e6446](https://github.com/LerianStudio/helm/commit/f6e644662db2f641b0e71e3cccd518fa4fe715dc))
* chart name ([6db8350](https://github.com/LerianStudio/helm/commit/6db83502f0f75b59a5345c27eeade292b31078a9))
* chart name ([1f78da5](https://github.com/LerianStudio/helm/commit/1f78da504538d1a518f503e69b21b1696a893313))
* codeowners groups ([#23](https://github.com/LerianStudio/helm/issues/23)) ([b51ff0c](https://github.com/LerianStudio/helm/commit/b51ff0ce5f7d838c2f01565340d91a79cd9c772f))
* **auth:** disable auth ingress ([4e08d7a](https://github.com/LerianStudio/helm/commit/4e08d7af33f67b9500b459a40ad93473cf82007f))
* fix ([8e3d5ad](https://github.com/LerianStudio/helm/commit/8e3d5ad6deff4dc6a84d7f0c343d5e605428686f))
* fix ([3ff9f64](https://github.com/LerianStudio/helm/commit/3ff9f645ed8119d28a4dc256848d27206a4d80ce))
* **audit:** fix audit configmap ([#41](https://github.com/LerianStudio/helm/issues/41)) ([429fdef](https://github.com/LerianStudio/helm/commit/429fdef691c87dc5b4a7e44c236b2550f548c20d))
* **values:** fix autoscaling parameters ([69585b6](https://github.com/LerianStudio/helm/commit/69585b6743736edad8d393c5e50eddc9e4ff114d))
* **transaction:** fix default value of rabbitmq secret ([71afd7a](https://github.com/LerianStudio/helm/commit/71afd7a7067ee4b1cf429669e4a44c58479af037))
* **doc:** fix midaz transaction container port ([bab48e6](https://github.com/LerianStudio/helm/commit/bab48e600b179abf07bbc207982803102ea1d704))
* **pipe:** fix pr title workflow ([#34](https://github.com/LerianStudio/helm/issues/34)) ([5134118](https://github.com/LerianStudio/helm/commit/51341186dfd7f643e3be1d598c51d3909748a3dd))
* **transaction:** fix transaction container port ([cb4ec59](https://github.com/LerianStudio/helm/commit/cb4ec592c2c47036bee2b519d795ca08336904dc))
* generate multiples CHANGELOG's ([3f60787](https://github.com/LerianStudio/helm/commit/3f607875b618db474e4055c44a2cffd8216f4261))
* helm chart ([9b6552f](https://github.com/LerianStudio/helm/commit/9b6552f37d039bb5187c92319bcc3787d1c4ddcc))
* **components:** init file for auth app ([4939e82](https://github.com/LerianStudio/helm/commit/4939e823f60cdbc0965281f496b058178bf70a00))
* **components:** load definitions for rabbitmq ([167c80a](https://github.com/LerianStudio/helm/commit/167c80a8e156fb653e2e365f155c4c35e2785fca))
* **docs:** rabbitmq mispelling name ([cefee91](https://github.com/LerianStudio/helm/commit/cefee916b39020938945ce97f442dbdbf3ba6d63))
* **onboarding:** rabbitmq mispelling name ([bf8de0c](https://github.com/LerianStudio/helm/commit/bf8de0cf79e4a40a3fa0bb7581a7f11b9458de76))
* **transaction:** rabbitmq mispelling name ([8e05032](https://github.com/LerianStudio/helm/commit/8e050329da399b563d2ce6f5fa70edcf2291cccd))
* **onboarding:** remove grpc port from container ([3bd9621](https://github.com/LerianStudio/helm/commit/3bd96218a95decae1c58cc29078c8bbfd71736a9))
* remove hook ([aa92d78](https://github.com/LerianStudio/helm/commit/aa92d78f74000f6f4f2c7fc22db35cc0010916ca))
* **onboarding:** remove old secrets ([0c7966f](https://github.com/LerianStudio/helm/commit/0c7966f91207c688b0e014bab463dac40846f56e))
* **trasaction:** remove old secrets ([1a2a10c](https://github.com/LerianStudio/helm/commit/1a2a10c9a165c0767f45b7909276c287d5c4d3a3))
* **audit:** rename env vars and update container port ([9796046](https://github.com/LerianStudio/helm/commit/979604649c30ce6b8788acb3c1f67dff1a765f63))
* **transaction:** rename env vars and update container port ([4052bc5](https://github.com/LerianStudio/helm/commit/4052bc51634b989fba34c2245319db767aa02275))
* **chart:** rename ledger component to onboarding ([47dd9d0](https://github.com/LerianStudio/helm/commit/47dd9d01c491f30669c3f4ec6271bae1c8d0de75))
* **chart:** rename ledger component to onboarding ([e04404b](https://github.com/LerianStudio/helm/commit/e04404b79c78396a6cb1227cafa5bad10b51d3ee))
* **doc:** rename ledger component to onboarding ([0aa6e34](https://github.com/LerianStudio/helm/commit/0aa6e34ed38d68308cec31b5280b17c017c3d277))
* **components:** rename ledger db for onboarding ([40e49b8](https://github.com/LerianStudio/helm/commit/40e49b8cb2dcf6b169ea4a9c32b5c516f0d06b57))
* **pipe:** rename ledger to onboarding ([448ce90](https://github.com/LerianStudio/helm/commit/448ce9015baee8d553a81f6253d77d76bb96c3ba))
* **dependencies:** rename otel to grafana ([#57](https://github.com/LerianStudio/helm/issues/57)) ([974c47f](https://github.com/LerianStudio/helm/commit/974c47f6974d42804e5210d530829efa0394d734))
* setup otel in template ([#24](https://github.com/LerianStudio/helm/issues/24)) ([837fd03](https://github.com/LerianStudio/helm/commit/837fd03c642b14387299b9b4a50fe00dc22e2f29))
* **components:** sql init for auth app ([9824943](https://github.com/LerianStudio/helm/commit/9824943ab8a6d2e038cd55448259c27149c50546))
* templates ([bc18fc3](https://github.com/LerianStudio/helm/commit/bc18fc3fddd8736d8694f3be401d1a85fc781039))
* update mongodb ([858c934](https://github.com/LerianStudio/helm/commit/858c93496a5e45fcb84389614536d63ca6b84a02))
* **doc:** update nginx ingress config ([#35](https://github.com/LerianStudio/helm/issues/35)) ([d9763ea](https://github.com/LerianStudio/helm/commit/d9763ea4c2139c7d5f020d71422a634f37e15172))
* values ([b1dc8f7](https://github.com/LerianStudio/helm/commit/b1dc8f7105ab3aa0bbed2549525f013875087b7d))
