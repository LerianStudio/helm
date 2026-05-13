# Helm Upgrade from v2.2.2 to v2.2.3

## Topics
- [Fixes](#fixes)
- [Command to upgrade](#command-to-upgrade)

## Fixes

This patch release updates the application version with bug fixes and improvements:

- Updated appVersion from `1.2.1-beta.11` to `1.2.1-beta.15`
- Updated default image tag from `1.2.1-beta.14` to `1.2.1-beta.15`

## Command to upgrade
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.3 -n plugin-br-pix-direct-jd
