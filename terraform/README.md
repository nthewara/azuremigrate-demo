# Terraform

This folder will hold the Azure infrastructure for the Azure Migrate nested Hyper-V demo.

## Planned modules/files
- `providers.tf`
- `main.tf`
- `network.tf`
- `host-vm.tf`
- `bastion.tf`
- `storage.tf`
- `outputs.tf`
- `variables.tf`
- `terraform.tfvars.example`

## Initial scope
- Resource group
- VNet / subnet
- Bastion Standard
- Nested-virtualization-capable Windows host VM
- Premium SSD data disk for nested VHDX storage
- Optional storage account for artifacts
- Optional Log Analytics workspace in supported dependency-analysis region
