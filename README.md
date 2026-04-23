# Azure Migrate Demo

Nested Hyper-V lab environment in Azure for demonstrating **Azure Migrate discovery, software inventory, SQL discovery, and dependency analysis**.

> [!WARNING]
> This is a **demo / lab pattern**, not an officially supported production pattern. The goal is to create a realistic on-prem-style estate inside a nested Hyper-V host so Azure Migrate can be demonstrated end-to-end.

## Goal

Build a single Azure-hosted lab that looks and behaves like a small on-prem environment:
- **One Azure VM** acts as the **Hyper-V host**
- Multiple **nested VMs** act as on-prem servers
- One nested VM runs the **Azure Migrate appliance**
- Dependency analysis is done in the **supported way for Hyper-V: agent-based**

## Why this approach

This gives us a clean demo story:
- Azure Migrate appliance discovers a Hyper-V environment
- Servers appear as on-prem / Hyper-V workloads, not native Azure VMs
- We can show:
  - Discovery and assessment
  - Software inventory
  - SQL Server discovery
  - Dependency analysis
  - Grouping and assessment

## Key design decisions

### 1. Use nested Hyper-V, not plain Azure VMs
For a demo, native Azure VMs weaken the Azure Migrate story. Nested guests look much closer to a real customer Hyper-V estate.

### 2. Use **agent-based dependency analysis**
For Hyper-V, the safe demo path is **agent-based dependency visualization** using:
- Microsoft Monitoring Agent (MMA)
- Dependency agent

That avoids betting the demo on agentless dependency behavior.

### 3. Use a **two-phase Hyper-V bootstrap**
Installing the Hyper-V role requires a reboot. Custom Script Extension cannot survive that reboot cleanly.

So the host setup should be:
1. CSE / bootstrap script installs Hyper-V + prereqs + scheduled task
2. Host reboots
3. Scheduled task completes vSwitch, NAT, disk prep, ISO/VHD staging, nested VM creation

### 4. Use Premium SSD + enough RAM
Visual Studio / nested virtualization taught us the obvious lesson already: do **not** under-size demo VMs.

Recommended host baseline:
- **Standard_D16s_v5** minimum
- **Premium SSD OS disk**
- **Premium SSD data disk** for nested VHDX files

## Proposed lab architecture

```text
Azure RG
│
├─ Bastion Standard
├─ Hyper-V Host VM (Windows Server 2025/2022, nested virt enabled)
│  ├─ Internal vSwitch + NAT
│  ├─ MIG-APPL       (Azure Migrate appliance)
│  ├─ ADDS01         (optional DC / DNS for domain demo)
│  ├─ APP01          (Windows app server / IIS)
│  ├─ SQL01          (Windows + SQL Server)
│  ├─ WEB01          (second app tier or client workload)
│  └─ LNX01          (Ubuntu / mixed estate demo, optional)
│
└─ Supporting Azure resources
   ├─ Storage account (scripts / ISOs / artifacts if needed)
   ├─ Log Analytics workspace (for dependency analysis)
   └─ Azure Migrate project
```

## Demo scenarios

### Scenario A — Discovery
- Add Hyper-V host to appliance
- Discover nested VMs
- Show machine inventory in Azure Migrate

### Scenario B — Software inventory
- Enable guest credentials in appliance
- Show discovered apps / roles / features
- Highlight IIS / SQL Server / Windows features

### Scenario C — SQL discovery
- Discover SQL instance on `SQL01`
- Show SQL readiness / inventory

### Scenario D — Dependency analysis
- Install MMA + Dependency agent on `APP01`, `SQL01`, `WEB01`
- Associate supported Log Analytics workspace
- Show server dependency map
- Group servers for assessment

### Scenario E — Assessment story
- Create Azure VM / Azure SQL assessment group
- Talk through right-sizing, readiness, and migration options

## Important gotchas

### Log Analytics region constraint
Dependency visualization requires a Log Analytics workspace in a supported region such as:
- **Southeast Asia**
- **East US**
- **West Europe**

So even if the lab runs in **Australia East**, the dependency workspace may need to live in **Southeast Asia**.

### Hyper-V host requirements for appliance
The appliance expects:
- Hyper-V host reachable via WinRM / PowerShell remoting
- Admin or equivalent delegated permissions on host
- Hyper-V Integration Services running in guests

### Network model
The nested appliance and guests must have:
- outbound internet access to Azure Migrate endpoints
- line of sight to the Hyper-V host
- line of sight to guest OS ports for inventory / analysis

## Repository plan

- `docs/implementation-plan.md` — detailed build plan and phases
- `docs/demo-flow.md` — presenter runbook
- `terraform/` — Azure infrastructure for host + bastion + disks + storage
- `scripts/` — host bootstrap + nested VM creation + guest prep

## References

- Azure Arc reference inspiration:
  - <https://github.com/microsoft/azure_arc/tree/main/azure_arc_sqlsrv_jumpstart/azure/windows/defender_sql>
- Prior repo pattern:
  - <https://github.com/nthewara/arc-connectivity-demo>
- Azure Migrate Hyper-V support matrix:
  - <https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v>
- Azure Migrate appliance:
  - <https://learn.microsoft.com/en-us/azure/migrate/migrate-appliance>
- Dependency analysis:
  - <https://learn.microsoft.com/en-us/azure/migrate/how-to-create-group-machine-dependencies>
