# Helm Upgrade from v2.2.3 to v2.2.4

## Table of Contents
- [Fixes](#fixes)
- [Command to upgrade](#command-to-upgrade)

## Fixes

This patch release updates the application version from `1.2.1-beta.15` to `1.2.1-beta.16` and includes the following improvements:

- **Resource Optimization**: Increased memory limit for the PIX service from `256Mi` to `512Mi` to improve stability and performance under load
- **High Availability**: Updated QR Code service autoscaling configuration with minimum replicas increased from `1` to `3` for better availability and load distribution
- **Configuration Updates**: Updated ConfigMap template for the plugin-br-pix-direct-jd-job component

## Command to upgrade
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.4 -n plugin-br-pix-direct-jd
