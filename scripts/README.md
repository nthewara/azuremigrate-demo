# Scripts

Planned script responsibilities:

- `Bootstrap-HyperVHost.ps1`
  - first-boot setup
  - install Hyper-V role
  - prep disks
  - register scheduled task
  - reboot

- `Continue-HyperVHostSetup.ps1`
  - post-reboot continuation
  - create vSwitch + NAT
  - stage guest media
  - create nested VMs

- `New-NestedVm.ps1`
  - reusable helper for guest creation

- `Install-MigrateAgents.ps1`
  - install MMA + Dependency agent on Windows guests

- `Install-AppWorkload.ps1`
  - install IIS / sample app

- `Install-SqlWorkload.ps1`
  - install SQL Server demo workload
