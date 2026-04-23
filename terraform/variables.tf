variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Primary Azure region for the lab"
  type        = string
  default     = "australiaeast"
}

variable "prefix" {
  description = "Naming prefix for all resources"
  type        = string
  default     = "azmig"
}

variable "admin_username" {
  description = "Admin username for the Hyper-V host VM"
  type        = string
  default     = "azmigadmin"
}

variable "admin_password" {
  description = "Admin password for the Hyper-V host VM"
  type        = string
  sensitive   = true
}

variable "host_vm_size" {
  description = "VM size for the Hyper-V host (must support nested virtualisation)"
  type        = string
  default     = "Standard_D16s_v5"
}

variable "host_os_disk_size_gb" {
  description = "Host OS disk size in GB"
  type        = number
  default     = 128
}

variable "nested_data_disk_size_gb" {
  description = "Managed data disk size for nested VM base images and child disks"
  type        = number
  default     = 512
}

variable "deploy_bastion" {
  description = "Deploy Azure Bastion Standard"
  type        = bool
  default     = true
}

variable "enable_host_public_ip" {
  description = "Attach a public IP to the Hyper-V host for direct RDP. Prefer false when using Bastion."
  type        = bool
  default     = false
}

variable "home_ip" {
  description = "Optional home/office public IP in CIDR format for direct RDP when enable_host_public_ip=true"
  type        = string
  default     = null
}

variable "create_log_analytics_workspace" {
  description = "Create a Log Analytics workspace in the same region as the lab"
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Auto-shutdown time in HHMM format (UTC)"
  type        = string
  default     = "1100"
}

variable "nested_subnet_cidr" {
  description = "Internal NAT subnet used for nested guests on the Hyper-V host"
  type        = string
  default     = "10.10.1.0/24"
}

variable "nested_gateway_ip" {
  description = "Gateway IP assigned to the internal Hyper-V switch adapter on the host"
  type        = string
  default     = "10.10.1.1"
}

variable "dhcp_start" {
  description = "Start address for the nested guest DHCP scope"
  type        = string
  default     = "10.10.1.100"
}

variable "dhcp_end" {
  description = "End address for the nested guest DHCP scope"
  type        = string
  default     = "10.10.1.200"
}

variable "migrate_appliance_vhd_url" {
  description = "Official Azure Migrate Hyper-V appliance package download URL"
  type        = string
  default     = "https://go.microsoft.com/fwlink/?linkid=2191848"
}

variable "windows_template_vhd_url" {
  description = "Sysprepped Windows Server 2022 template VHDX reused for APP01/WEB01"
  type        = string
  default     = "https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-Win2K22.vhdx"
}

variable "sql_template_vhd_url" {
  description = "Sysprepped SQL Server template VHDX reused for SQL01"
  type        = string
  default     = "https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-SQL-DEV.vhdx"
}

variable "linux_template_vhd_url" {
  description = "Sysprepped Ubuntu template VHDX reused for LNX01"
  type        = string
  default     = "https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-Ubuntu-01.vhdx"
}

variable "windows_guest_admin_password" {
  description = "Password for the sysprepped Windows guest templates"
  type        = string
  sensitive   = true
  default     = "ArcDemo123!!"
}

variable "linux_guest_username" {
  description = "Username for the sysprepped Ubuntu template"
  type        = string
  default     = "jumpstart"
}

variable "linux_guest_password" {
  description = "Password for the sysprepped Ubuntu template"
  type        = string
  sensitive   = true
  default     = "JS123!!"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project     = "azuremigrate-demo"
    environment = "lab"
  }
}
