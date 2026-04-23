# Scripts

## Bootstrap flow

### `Bootstrap-HyperVHost.ps1`
Runs from the Azure VM Custom Script Extension.
It:
- formats the nested-VM data disk
- installs Hyper-V + DHCP
- installs Azure CLI + azcopy
- saves lab config
- copies continuation scripts
- registers a startup task
- reboots the host

### `Continue-HyperVHostSetup.ps1`
Runs after reboot.
It:
- creates the internal vSwitch + NAT + DHCP scope
- downloads reusable sysprepped base VHD/VHDX files
- downloads the official Azure Migrate appliance package and attempts Hyper-V import
- creates nested VMs
- runs Windows guest configuration

### `New-NestedVm.ps1`
Reusable helper that creates a nested VM from either:
- a differencing disk, or
- a full copied disk

### `Configure-GuestWorkloads.ps1`
Uses **PowerShell Direct** into Windows guests to:
- rename APP01 / WEB01 / SQL01
- enable remoting
- install IIS on APP01 / WEB01
- open SQL firewall on SQL01
- push sample traffic generation for dependency demos
