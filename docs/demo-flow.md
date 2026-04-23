# Demo Flow

## Opening
"This lab uses a nested Hyper-V host in Azure to simulate an on-prem Hyper-V estate so we can demo Azure Migrate discovery and dependency analysis end-to-end."

## Part 1 — Show the lab
- Connect to host through Bastion
- Open Hyper-V Manager
- Show nested VMs:
  - MIG-APPL
  - APP01
  - SQL01
  - WEB01
  - optional LNX01

## Part 2 — Show Azure Migrate discovery
- Open Azure Migrate project
- Show Hyper-V host added to appliance
- Show discovered machines inventory
- Highlight OS, cores, memory, disks

## Part 3 — Show software inventory
- Show IIS / SQL / installed software
- Call out this is collected by the appliance

## Part 4 — Show SQL discovery
- Open SQL discovery view
- Show SQL01 instance and discovered DBs

## Part 5 — Show dependency analysis
- Open dependency map
- Show APP01 talking to SQL01
- Show WEB01 relationship if included
- Explain this uses MMA + Dependency agent for Hyper-V demo reliability

## Part 6 — Show assessment story
- Group APP01 + SQL01 + WEB01
- Create assessment
- Talk through migration targets and readiness

## Closing message
"This isn't a production-supported nested Hyper-V migration pattern. It's a compact lab that lets us demonstrate Azure Migrate workflows, discovery, and dependency analysis using a realistic Hyper-V estate."
