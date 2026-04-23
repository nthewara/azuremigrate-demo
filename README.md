# Azure Migrate Demo

Nested Hyper-V lab in Azure for demonstrating:
- Azure Migrate discovery
- software inventory
- SQL discovery
- dependency analysis
- grouped assessment

This repo now includes a working **v1 scaffold**:
- Terraform for the Azure host + Bastion + storage + workspace
- host bootstrap scripts
- nested VM creation from reusable **sysprepped VHD templates**
- PowerShell Direct guest configuration for Windows nested VMs

## Reused guest templates we found from the Arc demo pattern

These are the same public sysprepped guest images used by the older Arc demo / ArcBox-style approach:

- **Windows Server 2022**
  - `https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-Win2K22.vhdx`
- **SQL Server 2022 Developer**
  - `https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-SQL-DEV.vhdx`
- **Ubuntu 22.04**
  - `https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-Ubuntu-01.vhdx`

For the **Azure Migrate appliance**, the repo uses the official Hyper-V appliance package URL:
- `https://go.microsoft.com/fwlink/?linkid=2191848`

The continuation script downloads that package, extracts it, and attempts a Hyper-V import for `MIG-APPL`.

## Lab shape

```text
Azure
│
├─ Bastion Standard
├─ Hyper-V host VM (Windows Server 2025, nested virtualization)
│  ├─ MIG-APPL  -> Azure Migrate appliance
│  ├─ APP01     -> Windows app tier
│  ├─ WEB01     -> Windows helper/web tier
│  ├─ SQL01     -> SQL Server tier
│  └─ LNX01     -> Ubuntu guest
└─ Log Analytics workspace
```

## Important implementation choices

### 1) Sysprepped base images + differencing disks
APP01, WEB01, SQL01, and LNX01 are created from reusable base templates.
That keeps deployment faster and disk usage lower.

### 2) PowerShell Direct for Windows guest config
The host uses **PowerShell Direct** to:
- rename APP01 / WEB01 / SQL01
- enable remoting
- install IIS on APP01 / WEB01
- open SQL firewall on SQL01
- push sample traffic generation for dependency demos

### 3) Azure Migrate appliance stays official
I did **not** fake the appliance image. The repo downloads the official Hyper-V appliance package and tries to import it as `MIG-APPL`.

## Files that matter

### Terraform
- `terraform/main.tf`
- `terraform/bastion.tf`
- `terraform/host-vm.tf`
- `terraform/providers.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/terraform.tfvars.example`

### Scripts
- `scripts/Bootstrap-HyperVHost.ps1`
- `scripts/Continue-HyperVHostSetup.ps1`
- `scripts/New-NestedVm.ps1`
- `scripts/Configure-GuestWorkloads.ps1`

## Quick start

```bash
cd terraform
cp terraform.tfvars.example ~/workspace/tfvars/azuremigrate-demo.tfvars
terraform init -backend-config=~/workspace/tfvars/backend.hcl
terraform plan -var-file=~/workspace/tfvars/azuremigrate-demo.tfvars -out=tfplan
terraform apply tfplan
```

Then:
1. Connect to the host with Bastion
2. Wait for the scheduled continuation script to finish nested guest creation
3. Open Hyper-V Manager
4. Complete Azure Migrate appliance setup inside `MIG-APPL`
5. Add the Hyper-V host into the appliance
6. Install dependency agents on APP01 / WEB01 / SQL01 if needed for the chosen demo path

## Default guest credentials from the reused templates

### Windows guests
- Username: `Administrator`
- Password: `ArcDemo123!!`

### Linux guest
- Username: `jumpstart`
- Password: `JS123!!`

## Notes

- Region default is **Australia East**.
- The Log Analytics workspace is also created in **Australia East** by default.
- If Azure Migrate enforces a different dependency-analysis constraint in practice, validate that live at deploy time instead of baking stale assumptions into the repo.
