resource "azurerm_public_ip" "host" {
  count               = var.enable_host_public_ip ? 1 : 0
  name                = "${var.prefix}-host-pip-${local.name_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "host" {
  name                = "${var.prefix}-host-nic-${local.name_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.host.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_host_public_ip ? azurerm_public_ip.host[0].id : null
  }
}

resource "azurerm_windows_virtual_machine" "host" {
  name                  = "${var.prefix}-host-${local.name_suffix}"
  computer_name         = "azmig-${local.name_suffix}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.host_vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.host.id]
  tags                  = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.host_os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }

  additional_capabilities {
    ultra_ssd_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  provision_vm_agent         = true
  allow_extension_operations = true
}

resource "azurerm_managed_disk" "nested_data" {
  name                 = "${var.prefix}-nested-disk-${local.name_suffix}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.nested_data_disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "nested_data" {
  managed_disk_id    = azurerm_managed_disk.nested_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.host.id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "host" {
  virtual_machine_id    = azurerm_windows_virtual_machine.host.id
  location              = azurerm_resource_group.main.location
  enabled               = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "bootstrap" {
  name                 = "bootstrap-hyperv"
  virtual_machine_id   = azurerm_windows_virtual_machine.host.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = var.tags

  settings = jsonencode({
    fileUris = [
      "https://raw.githubusercontent.com/nthewara/azuremigrate-demo/main/scripts/Bootstrap-HyperVHost.ps1",
      "https://raw.githubusercontent.com/nthewara/azuremigrate-demo/main/scripts/Continue-HyperVHostSetup.ps1",
      "https://raw.githubusercontent.com/nthewara/azuremigrate-demo/main/scripts/New-NestedVm.ps1",
      "https://raw.githubusercontent.com/nthewara/azuremigrate-demo/main/scripts/Configure-GuestWorkloads.ps1"
    ]
  })

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -File Bootstrap-HyperVHost.ps1 -NestedSubnetCidr '${var.nested_subnet_cidr}' -NestedGatewayIp '${var.nested_gateway_ip}' -DhcpStart '${var.dhcp_start}' -DhcpEnd '${var.dhcp_end}' -WindowsTemplateVhdUrl '${var.windows_template_vhd_url}' -SqlTemplateVhdUrl '${var.sql_template_vhd_url}' -LinuxTemplateVhdUrl '${var.linux_template_vhd_url}' -MigrateApplianceVhdUrl '${var.migrate_appliance_vhd_url}' -WindowsGuestAdminPassword '${var.windows_guest_admin_password}' -LinuxGuestUsername '${var.linux_guest_username}' -LinuxGuestPassword '${var.linux_guest_password}'"
  })

  depends_on = [azurerm_virtual_machine_data_disk_attachment.nested_data]
}
