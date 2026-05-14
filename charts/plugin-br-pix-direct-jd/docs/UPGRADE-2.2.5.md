# Helm Upgrade from v2.2.4 to v2.2.5

## Table of Contents
- [Overview](#overview)
- [Application Version Updates](#application-version-updates)
- [Resource Allocation Changes](#resource-allocation-changes)
- [Autoscaling Configuration Updates](#autoscaling-configuration-updates)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)

## Overview

This patch release updates the plugin-br-pix-direct-jd chart from v2.2.4 to v2.2.5, introducing significant changes to resource allocation and autoscaling behavior. The primary focus is on improving performance and scalability through increased memory limits and more aggressive autoscaling parameters.

**Key changes:**
- Application image updates for pix and job components
- Increased memory allocations for pix and qrcode services
- Enhanced autoscaling configuration with higher replica counts
- Modified autoscaling thresholds for better responsiveness

## Application Version Updates

This release updates the container images for multiple components:

| Component | v2.2.4 | v2.2.5 |
|-----------|--------|--------|
| pix.image.tag | 1.2.1-beta.16 | 1.2.1-beta.18 |
| job.image.tag | 1.2.1-beta.11 | 1.2.1-beta.12 |

> **Note:** The Chart.yaml references appVersion `1.2.1-beta.17`, but the actual pix image tag is `1.2.1-beta.18`. This is intentional as the appVersion represents the overall application version while individual components may have different build numbers.

## Resource Allocation Changes

### PIX Service Memory Increase

The PIX service now requires more memory to handle increased workload demands:

| Setting | v2.2.4 | v2.2.5 |
|---------|--------|--------|
| pix.resources.requests.memory | 128Mi | 256Mi |

**Why this matters:** Doubling the memory request ensures the PIX service has adequate resources to handle transaction processing without being throttled or OOMKilled under load.

**Example configuration:**
pix:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi

### QR Code Service Memory Increase

The QR code generation service memory limit has been doubled:

| Setting | v2.2.4 | v2.2.5 |
|---------|--------|--------|
| qrcode.resources.limits.memory | 256Mi | 512Mi |

**Why this matters:** QR code generation can be memory-intensive, especially when handling multiple concurrent requests. This increase prevents memory-related failures during peak usage.

**Example configuration:**
qrcode:
  resources:
    limits:
      cpu: 200m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

> **Warning:** These memory increases will affect your cluster's resource allocation. Ensure your nodes have sufficient available memory before upgrading, especially if running near capacity.

## Autoscaling Configuration Updates

### Increased Replica Counts

The autoscaling configuration has been adjusted to maintain higher baseline capacity and allow for greater scale:

| Setting | v2.2.4 | v2.2.5 |
|---------|--------|--------|
| pix.autoscaling.minReplicas | 1 | 3 |
| pix.autoscaling.maxReplicas | 3 | 6 |

**Why this matters:** Starting with 3 replicas instead of 1 provides better availability and load distribution from the start. The increased maximum allows the service to handle 2x the previous peak load.

### Modified Autoscaling Thresholds

The CPU and memory utilization targets have been adjusted for more responsive scaling:

| Setting | v2.2.4 | v2.2.5 |
|---------|--------|--------|
| pix.autoscaling.targetCPUUtilizationPercentage | 80 | 70 |
| pix.autoscaling.targetMemoryUtilizationPercentage | 80 | 85 |

**Why this matters:** 
- Lower CPU threshold (70% vs 80%) triggers scaling earlier, preventing CPU saturation
- Higher memory threshold (85% vs 80%) better utilizes the increased memory allocation before scaling

**Complete autoscaling configuration:**
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 6
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85

> **Note:** With minReplicas increased from 1 to 3, you will immediately run 3 pods after upgrade. This triples the baseline resource consumption but significantly improves service reliability and response times.

### Operational Impact

**Before upgrade:**
- Minimum pods: 1
- Maximum pods: 3
- Baseline memory: 128Mi per pod (128Mi total minimum)

**After upgrade:**
- Minimum pods: 3
- Maximum pods: 6
- Baseline memory: 256Mi per pod (768Mi total minimum)

**Resource calculation:**
- Minimum memory requirement increases from 128Mi to 768Mi (6x increase)
- Maximum memory requirement increases from 384Mi to 1536Mi (4x increase)

## Preview changes before upgrading
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.5 -n plugin-br-pix-direct-jd
> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.5 -n plugin-br-pix-direct-jd
