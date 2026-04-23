output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "location" {
  value = azurerm_resource_group.main.location
}

output "host_vm_name" {
  value = azurerm_windows_virtual_machine.host.name
}

output "host_private_ip" {
  value = azurerm_network_interface.host.private_ip_address
}

output "host_public_ip" {
  value = var.enable_host_public_ip ? azurerm_public_ip.host[0].ip_address : null
}

output "bastion_name" {
  value = var.deploy_bastion ? azurerm_bastion_host.main[0].name : null
}

output "log_analytics_workspace_name" {
  value = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.main[0].name : null
}

output "nested_guest_template_sources" {
  value = {
    windows = var.windows_template_vhd_url
    sql     = var.sql_template_vhd_url
    linux   = var.linux_template_vhd_url
    migrate = var.migrate_appliance_vhd_url
  }
}
