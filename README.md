# Drover

**Drover** is a distributed compute scheduler and work board for coding agents. Orchestrate Claude Code, Codex, pi, and other coding agents across Local, GKE Spot, Boat, Proxmox, and SSH Pools—with one Coordinator, automated checks and second-agent reviews, spot failover, and live compute cost tracking.

> This repository hosts compiled binary releases and the standalone installer for Drover.

## Install

On macOS or Linux:

```sh
curl -fsSL https://drover.sh | sh
```

The installer downloads the SHA-256 verified binary for your platform to `~/.local/bin/drover` and runs `drover init`.

## 2-Minute Distributed Quickstart

```sh
# 1. Add a compute provider
drover providers init boat      # or: gke, proxmox, ssh-pool
drover providers --json

# 2. Split work across local + cloud
drover set placement.mix "local=50, boat=50"
drover add "Ship feature X" --on auto --delegate

# 3. Enable spot failover & track spend
drover set placement.failoverAfter 2m
drover cost
```

Update anytime with `drover update`, and verify your setup with `drover doctor`.
