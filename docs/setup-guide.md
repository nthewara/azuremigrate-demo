# Setup Guide

## 1. Prepare tfvars
Create a real tfvars file outside the repo.

Suggested file:
- `~/workspace/tfvars/azuremigrate-demo.tfvars`

## 2. Deploy

```bash
cd terraform
terraform init -backend-config=~/workspace/tfvars/backend.hcl
terraform plan -var-file=~/workspace/tfvars/azuremigrate-demo.tfvars -out=tfplan
terraform apply tfplan
```

## 3. Wait for host bootstrap
The host will:
1. install Hyper-V
2. reboot
3. continue host setup on startup
4. download base images
5. create nested VMs
6. configure Windows guests through PowerShell Direct

## 4. Connect to the host
Use Bastion to access the Hyper-V host.

Check:
- Hyper-V Manager
- `C:\AzureMigrateLab\Logs`
- desktop status script

## 5. Complete the Azure Migrate appliance
Inside `MIG-APPL`:
- finish appliance setup
- register it to the Azure Migrate project
- add Hyper-V discovery credentials
- point it at the host

## 6. Discovery and dependency demo
- discover APP01 / WEB01 / SQL01 / LNX01
- use guest credentials for software inventory
- if agent-based dependency analysis is used, install the required agents on APP01 / WEB01 / SQL01
- use the sample traffic from APP01 to show relationships
