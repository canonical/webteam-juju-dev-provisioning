# Local Juju Environment Provisioning

A toolkit for provisioning local Juju development environments on Multipass VMs. This enables web team members to replicate production/staging Juju environments locally for testing Terraform plans and charm deployments.

## Overview

This toolkit provisions a Multipass VM with:

- **Juju 3.6** - Charm orchestration
- **MicroK8s** - Local Kubernetes cluster with registry, ingress, and storage
- **LXD** - Container/VM substrate for machine charms
- **Charmcraft & Rockcraft** - Charm and rock development tools
- **Terraform** - Infrastructure as code
- **Vault** (optional) - Secrets management
- **DBaaS** (optional) - PostgreSQL with cross-model offers

## Prerequisites

- [Multipass](https://multipass.run/) installed on your machine
- At least 6 CPUs, 6GB RAM, and 50GB disk space available

## Quick Start

### 1. Create your environment configuration

Create a `juju_local.yaml` file in your project root:

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

### 2. Download and run the launcher

```bash
# Set version tag (check releases for latest)
VERSION="v1.0.0"
BASE_URL="https://raw.githubusercontent.com/pedoch/local-juju-env-provisioning/${VERSION}"

# Download the cloud-init and launcher scripts
curl -sLO "${BASE_URL}/cloud-init-juju.yaml"
curl -sLO "${BASE_URL}/launch_instance.sh"
chmod +x launch_instance.sh

# Launch the environment
./launch_instance.sh myproject
```

### 3. Access the VM

```bash
multipass shell myproject
```

## Remote File URLs

Reference files directly in your scripts using GitHub raw URLs. Pin to a specific version tag for stability:

```
https://raw.githubusercontent.com/pedoch/local-juju-env-provisioning/<VERSION>/<FILE>
```

| File                      | Description                                           |
| ------------------------- | ----------------------------------------------------- |
| `cloud-init-juju.yaml`    | Cloud-init configuration that provisions the VM       |
| `launch_instance.sh`      | Main script to launch the Multipass VM                |
| `utils.sh`                | Utility functions for Terraform and Vault integration |
| `juju_local.yaml.example` | Example environment configuration                     |

## Integration with Your Project

### Using with Taskfile

Add these tasks to your project's Taskfile to fetch and run the provisioning scripts:

```yaml
version: "3"

vars:
  INSTANCE_NAME: myproject
  VERSION: v1.0.0
  BASE_URL: "https://raw.githubusercontent.com/pedoch/local-juju-env-provisioning/{{.VERSION}}"

tasks:
  fetch-juju-scripts:
    desc: Download Juju provisioning scripts
    cmds:
      - curl -sLO "{{.BASE_URL}}/cloud-init-juju.yaml"
      - curl -sLO "{{.BASE_URL}}/launch_instance.sh"
      - curl -sLO "{{.BASE_URL}}/utils.sh"
      - chmod +x launch_instance.sh utils.sh
    status:
      - test -f cloud-init-juju.yaml
      - test -f launch_instance.sh

  start-juju:
    desc: Create/start the local Juju environment
    deps: [fetch-juju-scripts]
    cmds:
      - ./launch_instance.sh {{.INSTANCE_NAME}}

  deploy-infra:
    desc: Deploy infrastructure with Terraform
    cmds:
      - |
        multipass exec {{.INSTANCE_NAME}} -- bash -c '
          source /home/ubuntu/project/utils.sh
          cd /home/ubuntu/project/terraform
          export_terraform_vars \
            --controller {{.INSTANCE_NAME}} \
            --model "{{.INSTANCE_NAME}}-k8s:k8s" \
            --tfvars-file ./juju.auto.tfvars
          terraform init && terraform apply
        '
```

### Using with Shell Scripts

```bash
#!/bin/bash
# juju_environment.sh - Example integration script

VERSION="v1.0.0"
BASE_URL="https://raw.githubusercontent.com/pedoch/local-juju-env-provisioning/${VERSION}"
INSTANCE_NAME="myproject"

# Download scripts if not present
fetch_scripts() {
    [ -f cloud-init-juju.yaml ] || curl -sLO "${BASE_URL}/cloud-init-juju.yaml"
    [ -f launch_instance.sh ] || curl -sLO "${BASE_URL}/launch_instance.sh" && chmod +x launch_instance.sh
    [ -f utils.sh ] || curl -sLO "${BASE_URL}/utils.sh" && chmod +x utils.sh
}

run_multipass() {
    fetch_scripts
    ./launch_instance.sh "$INSTANCE_NAME"
}

# Source utils for helper functions
source_utils() {
    [ -f utils.sh ] || curl -sLO "${BASE_URL}/utils.sh"
    source ./utils.sh
}
```

### Recommended .gitignore

Add downloaded provisioning files to your `.gitignore`:

```gitignore
# Local Juju provisioning scripts (fetched from remote)
cloud-init-juju.yaml
launch_instance.sh
utils.sh
```

## Configuration Schema

### juju_local.yaml

```yaml
schema_version: "1.0"

juju:
  version: "3.6/candidate" # Juju snap channel

controllers:
  - name: "controller-name" # Controller name (bootstrapped on LXD)

models:
  - name: "model-name" # Model name (also used as username/password)
    controller: "controller" # Parent controller
    cloud: "microk8s" # Cloud: "microk8s" or "localhost"

services: # Optional services to deploy
  - vault # HashiCorp Vault
  - dbaas # PostgreSQL with cross-model offer
```

## Utility Functions

Download and source `utils.sh` to use these functions:

```bash
curl -sLO "https://raw.githubusercontent.com/pedoch/local-juju-env-provisioning/v1.0.0/utils.sh"
source ./utils.sh
```

### Juju Information

```bash
# Get controller API endpoint
get_juju_controller_address "mycontroller"
# Returns: "10.203.10.58:17070"

# Get model UUID
get_juju_model_uuid "mycontroller:mymodel"
# Returns: "abc123-def456-..."

# Get controller CA certificate
get_juju_controller_ca_cert "mycontroller"
```

### Terraform Integration

```bash
# Export Juju info to Terraform variables file
export_terraform_vars \
  --controller myproject \
  --model "myproject-k8s:k8s" \
  --model "myproject-vm:vm" \
  --tfvars-file ./terraform/juju.auto.tfvars

# Set up Vault with Juju credentials for Terraform
setup_vault_for_terraform \
  --controller myproject \
  --model "myproject-k8s:k8s" \
  --model "myproject-vm:vm" \
  --tfvars-file ./terraform/juju.auto.tfvars
```

### DBaaS Integration

```bash
# Integrate applications with PostgreSQL offer
integrate_dbaas_postgres \
  --controller myproject \
  --model myproject-k8s \
  --integration "myapp:database" \
  --integration "otherapp:database"
```

## VM Resource Customization

Override default VM resources with environment variables:

```bash
JUJU_VM_CPUS=8 JUJU_VM_MEMORY=8G JUJU_VM_DISK=100G ./launch_instance.sh myproject
```

| Variable          | Default | Description              |
| ----------------- | ------- | ------------------------ |
| `JUJU_VM_CPUS`    | 6       | Number of CPUs           |
| `JUJU_VM_MEMORY`  | 6G      | Memory allocation        |
| `JUJU_VM_DISK`    | 50G     | Disk size                |
| `JUJU_VM_TIMEOUT` | 3600    | Launch timeout (seconds) |

## Common Commands

```bash
# List instances
multipass list

# SSH into the VM
multipass shell myproject

# Check Juju status
multipass exec myproject -- juju status

# List controllers
multipass exec myproject -- juju controllers

# View cloud-init logs
multipass exec myproject -- tail -f /var/log/cloud-init-output.log

# Stop the instance
multipass stop myproject

# Start the instance
multipass start myproject

# Delete the instance
multipass delete myproject && multipass purge
```

## Credentials

After provisioning, credentials are saved inside the VM:

| Path                              | Description                   |
| --------------------------------- | ----------------------------- |
| `/home/ubuntu/.juju-credentials/` | User credentials (YAML files) |
| `/home/ubuntu/.juju-tokens/`      | Registration tokens           |
| `/home/ubuntu/.kube/config`       | Kubernetes config             |

Each model gets a user with the same name and password as the model name.

## Versioning

This repository uses semantic versioning. Pin to a specific version tag in your scripts:

- **Major versions** (`v1`, `v2`) - Breaking changes to the configuration schema or scripts
- **Minor versions** (`v1.1`, `v1.2`) - New features, backward compatible
- **Patch versions** (`v1.0.1`, `v1.0.2`) - Bug fixes

Check the [releases page](https://github.com/pedoch/local-juju-env-provisioning/releases) for available versions.

## Troubleshooting

### Cloud-init failed or stuck

```bash
# Check cloud-init status
multipass exec myproject -- cloud-init status

# View full logs
multipass exec myproject -- cat /var/log/cloud-init-output.log
```

### MicroK8s not ready

```bash
multipass exec myproject -- microk8s status --wait-ready
```

### Registry not responding

```bash
multipass exec myproject -- curl -sf http://localhost:32000/v2/_catalog
```

### Juju bootstrap failed

```bash
# Check Juju logs
multipass exec myproject -- juju debug-log
```

## Contributing

1. Test changes locally before committing
2. Update the README if adding new features
3. Follow existing code patterns and conventions
4. Tag releases using semantic versioning
