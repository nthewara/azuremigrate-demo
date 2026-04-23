# Terraform

Terraform deploys the Azure-side infrastructure for the demo:
- resource group
- VNet + subnets
- Hyper-V host VM
- Premium SSD data disk for nested guest images/disks
- Bastion Standard
- Log Analytics workspace
- Custom Script Extension to bootstrap the host

## Files
- `providers.tf`
- `variables.tf`
- `main.tf`
- `bastion.tf`
- `host-vm.tf`
- `outputs.tf`
- `terraform.tfvars.example`

## Defaults
- region: `australiaeast`
- host size: `Standard_D16s_v5`
- nested disk: `512 GB Premium_LRS`
- Bastion: enabled
- host public IP: disabled

## Template sources passed into the host
- Windows template: ArcBox Win2022 VHDX
- SQL template: ArcBox SQL Dev VHDX
- Linux template: ArcBox Ubuntu VHDX
- Azure Migrate appliance: official Hyper-V appliance package URL
