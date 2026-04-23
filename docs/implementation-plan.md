# Implementation Plan

## Outcome we want
A repeatable demo repo that deploys:
- Azure infrastructure for a nested Hyper-V host
- A staged bootstrap process for Hyper-V + nested guests
- An Azure Migrate appliance VM inside the nested lab
- Demo guest workloads suitable for discovery and dependency analysis
- A presenter-friendly runbook

## Phase 1 — Define the lab shape

### Host sizing
**Recommended starting point**
- VM size: `Standard_D16s_v5`
- OS disk: `Premium_LRS`
- Data disk: `Premium_LRS` 512 GB minimum for VHDX files
- Bastion: Standard

### Nested VMs
Suggested first cut:
1. `MIG-APPL` — Azure Migrate appliance
2. `APP01` — Windows Server + IIS sample app
3. `SQL01` — Windows Server + SQL Server Developer / Evaluation
4. `WEB01` — Windows Server or client VM to create app chatter
5. `LNX01` — Ubuntu server (optional but useful)
6. `ADDS01` — optional domain controller if we want a domain-joined story

**Recommendation:** start without ADDS unless it becomes necessary for the demo. Keep the first version lighter.

## Phase 2 — Azure infrastructure repo scaffold

Create these folders:

```text
terraform/
  main.tf
  network.tf
  host-vm.tf
  bastion.tf
  storage.tf
  variables.tf
  outputs.tf
  providers.tf
  terraform.tfvars.example
scripts/
  Bootstrap-HyperVHost.ps1
  Continue-HyperVHostSetup.ps1
  New-NestedVm.ps1
  Install-MigrateAgents.ps1
  Install-AppWorkload.ps1
  Install-SqlWorkload.ps1
  Configure-NatSwitch.ps1
  unattended/
docs/
  implementation-plan.md
  demo-flow.md
  architecture.drawio
```

## Phase 3 — Host bootstrap design

### Step 3.1 — First boot bootstrap
Use Custom Script Extension only for:
- enabling Hyper-V
- enabling management tools
- preparing data disk / folder structure
- registering a scheduled task for phase 2
- rebooting the host

### Step 3.2 — Second boot continuation
Scheduled task does the real work:
- create internal vSwitch
- configure host NAT
- assign host-side gateway IP
- download / attach source media
- create nested VMs
- attach VHDX files
- configure VM startup order

### Step 3.3 — Guest provisioning
For each nested VM:
- set static IP
- rename computer
- enable WinRM or SSH
- install sample workloads
- optionally domain join

## Phase 4 — Azure Migrate appliance strategy

## Option A — Nested appliance VM inside Hyper-V (**recommended**)
Pros:
- cleaner on-prem story
- closer to real customer design
- appliance discovers the Hyper-V estate from inside the nested environment

Cons:
- more resource pressure on host
- appliance import/setup takes time

## Option B — Appliance on the Hyper-V host OS
Pros:
- lighter and simpler
- faster to bring up

Cons:
- weaker demo story
- less realistic separation of roles

**Recommendation:** Start with **Option A** unless host capacity becomes a problem.

## Phase 5 — Dependency analysis design

For Hyper-V, build the demo around **agent-based dependency analysis**.

### Required components on analyzed guests
- MMA agent
- Dependency agent

### Workspace design
Create the Log Analytics workspace in **Australia East** by default.

Do not assume a forced cross-region dependency-analysis workspace. If a specific Azure Migrate dependency-analysis workflow rejects Australia East at deployment time, verify the current platform behavior live and adjust then — not in the baseline repo design.

### Demo group
Install dependency agents on only 2-3 machines initially:
- `APP01`
- `SQL01`
- `WEB01`

That is enough to show inbound / outbound relationships clearly.

## Phase 6 — Workload design

### APP01
- Windows Server 2022
- IIS
- simple web app or static site
- scheduled outbound calls to SQL01 / WEB01 / LNX01 to generate traffic

### SQL01
- SQL Server 2022 Developer or Evaluation
- sample DB
- lightweight app connection from APP01

### WEB01
- second IIS node or utility node
- can host a helper API or SMB share

### LNX01
- optional Ubuntu box
- useful to show mixed OS estate discovery

## Phase 7 — Demo flow

1. Connect to Hyper-V host over Bastion
2. Open Hyper-V Manager and show nested VMs
3. Open Azure Migrate project
4. Show discovered Hyper-V VMs
5. Show software inventory / SQL discovery
6. Show dependency map for APP01 ↔ SQL01 ↔ WEB01
7. Build assessment group
8. Discuss migration paths:
   - APP01 / WEB01 → Azure VM / App Service / Container Apps (story only)
   - SQL01 → Azure SQL Managed Instance / SQL on Azure VM

## Phase 8 — Risks and mitigations

### Risk: host too slow
Mitigation:
- D16s_v5 minimum
- Premium SSD everywhere
- keep guest count small in v1

### Risk: Hyper-V reboot breaks bootstrap
Mitigation:
- strict two-phase setup using scheduled task after reboot

### Risk: dependency analysis not available / flaky
Mitigation:
- use the documented agent-based path
- preinstall agents in image prep scripts if needed

### Risk: appliance networking issues
Mitigation:
- keep one flat internal subnet first
- use host NAT for internet
- avoid overcomplicated routing in v1

## Phase 9 — Build order

### Milestone 1
Repo + docs + Terraform skeleton

### Milestone 2
Azure host deployment working

### Milestone 3
Two-phase Hyper-V bootstrap working

### Milestone 4
Nested guest creation working

### Milestone 5
Azure Migrate appliance operational

### Milestone 6
Dependency analysis demo polished

## Recommended first implementation cut

If we want the fastest path to a working demo, build **v1** like this:
- Bastion + one Hyper-V host in Azure
- 4 nested VMs: `MIG-APPL`, `APP01`, `SQL01`, `WEB01`
- no ADDS initially
- agent-based dependency analysis on APP01 / SQL01 / WEB01
- documentation first, then automation second

That gets us to a credible demo fastest.
