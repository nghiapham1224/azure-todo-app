# 1. VIRTUAL NETWORK
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# 2. SUBNETS
# Outbound Subnet (Delegated to Flex Consumption)
resource "azurerm_subnet" "snet_outbound" {
  name                            = "snet-outbound"
  resource_group_name             = azurerm_resource_group.rg.name
  virtual_network_name            = azurerm_virtual_network.vnet.name
  address_prefixes                = ["10.0.0.0/24"]
  default_outbound_access_enabled = false
  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private Endpoint Subnet
resource "azurerm_subnet" "snet_private" {
  name                            = "snet-private"
  resource_group_name             = azurerm_resource_group.rg.name
  virtual_network_name            = azurerm_virtual_network.vnet.name
  address_prefixes                = ["10.0.1.0/24"]
  default_outbound_access_enabled = false
}

# 3. PRIVATE DNS ZONES (Required so Private Endpoints resolve to Private IPs)
# DNS for Storage (Blob)
resource "azurerm_private_dns_zone" "dns_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_dns_link" {
  name                  = "link-blob-to-vnet"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# DNS for SQL
resource "azurerm_private_dns_zone" "dns_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "link-sql-to-vnet"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_sql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}
