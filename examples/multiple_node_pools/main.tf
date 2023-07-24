resource "random_id" "prefix" {
  byte_length = 8
}

resource "azurerm_resource_group" "main" {
  count = var.create_resource_group ? 1 : 0

  location = var.location
  name     = coalesce(var.resource_group_name, "${random_id.prefix.hex}-rg")
}

locals {
  resource_group = {
    name     = var.create_resource_group ? azurerm_resource_group.main[0].name : var.resource_group_name
    location = var.location
  }
}

resource "azurerm_virtual_network" "test" {
  address_space       = ["10.52.0.0/16"]
  location            = local.resource_group.location
  name                = "${random_id.prefix.hex}-vn"
  resource_group_name = local.resource_group.name
}

resource "azurerm_subnet" "test" {
  address_prefixes                               = ["10.52.0.0/24"]
  name                                           = "${random_id.prefix.hex}-sn"
  resource_group_name                            = local.resource_group.name
  virtual_network_name                           = azurerm_virtual_network.test.name
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_network_security_group" "eladSG_1" {
  name                = "elad-nsg"
  location            = var.location
  resource_group_name = coalesce(var.resource_group_name, "${random_id.prefix.hex}-rg")

  security_rule {
    name                       = "AllowAll"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowPort8080"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowPort10250"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_subnet_network_security_group_association" "eladSub" {
  subnet_id                 = azurerm_subnet.test.id
  network_security_group_id = azurerm_network_security_group.eladSG_1.id
}

locals {
  nodes = {
    for i in range(3) : "worker${i}" => {
      name           = substr("worker${i}${random_id.prefix.hex}", 0, 8)
      vm_size        = "Standard_D2s_v3"
      node_count     = 1
      vnet_subnet_id = azurerm_subnet.test.id
    }
  }
}

module "aks_example_multiple_node_pools" {
  source  = "Azure/aks/azurerm//examples/multiple_node_pools"
  version = "7.2.0"

#  prefix                        = "prefix-${random_id.prefix.hex}"
#  resource_group_name           = local.resource_group.name
#  os_disk_size_gb               = 60
#  public_network_access_enabled = false
#  sku_tier                      = "Standard"
#  rbac_aad                      = false
#  vnet_subnet_id                = azurerm_subnet.test.id
#  node_pools                    = local.nodes
}
