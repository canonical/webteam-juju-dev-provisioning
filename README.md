# Local Juju Environment Provisioning

Provision local Juju development environments on either a **Multipass VM** or an **LXD container**. Replicate production/staging Juju environments locally for testing Terraform plans and charm deployments.

## What gets installed

- **Juju 3.6** - Charm orchestration
- **MicroK8s** - Local Kubernetes cluster with registry, ingress, and storage
- **LXD** - Container/VM substrate for machine charms
- **Charmcraft & Rockcraft** - Charm and rock development tools
- **Terraform** - Infrastructure as code
- **Vault** (optional) - Secrets management
- **DBaaS** (optional) - PostgreSQL with cross-model offers

## Quick Start

### 1. Fetch the scripts

From your project directory, run the init script with your chosen backend:

```bash
# LXD container (lighter, shared host kernel)
BACKEND=lxd bash <(curl -fsSL https://raw.githubusercontent.com/canonical/webteam-juju-dev-provisioning/main/init.sh)

# Multipass VM (heavier, full isolation)
BACKEND=vm bash <(curl -fsSL https://raw.githubusercontent.com/canonical/webteam-juju-dev-provisioning/main/init.sh)

# Pin to a specific release
BACKEND=lxd VERSION=v1.2.0 bash <(curl -fsSL https://raw.githubusercontent.com/canonical/webteam-juju-dev-provisioning/main/init.sh)
```

| Variable  | Default | Description |
|-----------|---------|-------------|
| `BACKEND` | _(required)_ | `vm` or `lxd` |
| `VERSION` | `main` | Git tag or branch to fetch from |
| `REPO`    | `canonical/webteam-juju-dev-provisioning` | GitHub org/repo override |

### 2. Configure your environment

Copy the example config and edit it:

```bash
cp juju_local.yaml.example juju_local.yaml
```

```yaml
schema_version: "1.0"

juju:
  version: "3.6/candidate"

controllers:
  - name: "myproject"

models:
  - name: "myproject-k8s"
    controller: "myproject"
    cloud: "microk8s"

  - name: "myproject-vm"
    controller: "myproject"
    cloud: "localhost"

services:
  - vault
  - dbaas
```

### 3. Launch

```bash
# LXD
./launch_instance_lxd.sh myproject

# VM
./launch_instance.sh myproject
```

### 4. Access

```bash
# LXD
lxc exec myproject -- sudo --login --user ubuntu

# VM
multipass shell myproject
```

## Resource Customisation

### LXD container

```bash
JUJU_CPUS=4 JUJU_MEMORY=4GB ./launch_instance_lxd.sh myproject
```

| Variable | Default | Fallback | Description |
|----------|---------|----------|-------------|
| `JUJU_BASE_IMAGE` | `ubuntu:24.04` | `JUJU_LXD_IMAGE` | Base image |
| `JUJU_CPUS`       | `2`    | `JUJU_LXD_CPUS`    | Number of CPUs |
| `JUJU_MEMORY`     | `3GB`  | `JUJU_LXD_MEMORY`  | Memory allocation |
| `JUJU_DISK`       | `20GB` | `JUJU_LXD_DISK`    | Root disk size |
| `JUJU_TIMEOUT`    | `3600` | `JUJU_LXD_TIMEOUT` | Cloud-init timeout (seconds) |

### Multipass VM

```bash
JUJU_CPUS=8 JUJU_MEMORY=8G ./launch_instance.sh myproject
```

| Variable | Default | Fallback | Description |
|----------|---------|----------|-------------|
| `JUJU_BASE_IMAGE` | `24.04` | — | Ubuntu image (recommended: `24.04`) |
| `JUJU_CPUS`       | `6`    | `JUJU_VM_CPUS`    | Number of CPUs |
| `JUJU_MEMORY`     | `6G`   | `JUJU_VM_MEMORY`  | Memory allocation |
| `JUJU_DISK`       | `50G`  | `JUJU_VM_DISK`    | Disk size |
| `JUJU_TIMEOUT`    | `3600` | `JUJU_VM_TIMEOUT` | Launch timeout (seconds) |

## Utility Functions

Source `utils.sh` inside the instance for Terraform and Vault integration:

```bash
source /home/ubuntu/project/utils.sh

# Export Juju connection info to a tfvars file
export_terraform_vars \
  --controller myproject \
  --model "myproject-k8s:k8s" \
  --model "myproject-vm:vm" \
  --tfvars-file ./terraform/juju.auto.tfvars

# Integrate an app with the PostgreSQL cross-model offer
integrate_dbaas_postgres \
  --controller myproject \
  --model myproject-k8s \
  --integration "myapp:database"
```

## Common Commands

### LXD

```bash
lxc list                                                  # List containers
lxc exec myproject -- sudo --login --user ubuntu          # Shell in
lxc exec myproject -- juju status                         # Juju status
lxc exec myproject -- tail -f /var/log/cloud-init-output.log  # Cloud-init logs
lxc stop myproject                                        # Stop
lxc start myproject                                       # Start
lxc delete --force myproject                              # Delete
```

### Multipass

```bash
multipass list                                            # List instances
multipass shell myproject                                 # Shell in
multipass exec myproject -- juju status                   # Juju status
multipass exec myproject -- tail -f /var/log/cloud-init-output.log  # Cloud-init logs
multipass stop myproject                                  # Stop
multipass start myproject                                 # Start
multipass delete myproject && multipass purge              # Delete
```

## Credentials

After provisioning, credentials are saved inside the instance:

| Path | Description |
|------|-------------|
| `/home/ubuntu/.juju-credentials/` | User credentials (YAML files) |
| `/home/ubuntu/.juju-tokens/` | Registration tokens |
| `/home/ubuntu/.kube/config` | Kubernetes config |

Each model gets a user with the same name and password as the model name.

## Recommended .gitignore

```gitignore
# Local Juju provisioning scripts (fetched via init.sh)
cloud-init-juju*.yaml
launch_instance*.sh
setup-juju-env.sh
utils.sh
juju_local.yaml
```

## Versioning

This repository uses semantic versioning. Pin to a specific version tag in your scripts.

Check the [releases page](https://github.com/canonical/webteam-juju-dev-provisioning/releases) for available versions.

## UID/GID Remapping (LXD)

When using LXD with privileged containers, the host user's UID/GID must match the container's `ubuntu` user for bind-mounted project files to be accessible. If your host UID/GID differs from the default `1000`, `launch_instance_lxd.sh` automatically remaps the container's `ubuntu` user to match.

This runs automatically — no configuration needed.

## Troubleshooting

```bash
# Check cloud-init status
lxc exec myproject -- cloud-init status          # LXD
multipass exec myproject -- cloud-init status     # VM

# View full cloud-init logs
lxc exec myproject -- cat /var/log/cloud-init-output.log
multipass exec myproject -- cat /var/log/cloud-init-output.log

# MicroK8s not ready
lxc exec myproject -- microk8s status --wait-ready

# Juju logs
lxc exec myproject -- juju debug-log
```
