// Tags
locals {
  tags = {
    class      = var.tag_class
    instructor = var.tag_instructor
    semester   = var.tag_semester
  }
}

// Existing Resources

/// Subscription ID

# data "azurerm_subscription" "current" {
# }

// Random Suffix Generator

resource "random_integer" "deployment_id_suffix" {
  min = 100
  max = 999
}

// Resource Group

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.class_name}-${var.student_name}-${var.environment}-${var.location}-${random_integer.deployment_id_suffix.result}"
  location = var.location

  tags = local.tags
}


// Storage Account

resource "azurerm_storage_account" "storage" {
  name                     = "sto${var.class_name}${var.student_name}${var.environment}${random_integer.deployment_id_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}


// Create a virtual network within the resource group

resource "azurerm_virtual_network" "vnetwork" {
  name                = "Lillian-network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

// Create a subnet within the resource group

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-Lillian"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnetwork.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
}


// Storage Account with Network Rules

resource "azurerm_storage_account" "storage_network" {
  name                     = "sto${var.class_name}${var.student_name}${random_integer.deployment_id_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    ip_rules                   = ["100.0.0.1"]
    virtual_network_subnet_ids = [azurerm_subnet.subnet.id]
  }

  tags = local.tags

  # Enable the hierachical namespace
  is_hns_enabled = true
}

// SQL Server

resource "azurerm_mssql_server" "lilliansqlserver" {
  name                         = "lilliansqlserver"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "lillianbowling"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"
}

// SQL Database

resource "azurerm_mssql_database" "sqldatabase" {
  name         = "lillian-db"
  server_id    = azurerm_mssql_server.lilliansqlserver.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  tags = {
    foo = "bar"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

// Virtual Network Rule within resource group

resource "azurerm_mssql_virtual_network_rule" "vnet_rule" {
  name      = "sql-vnet-rule"
  server_id = azurerm_mssql_server.lilliansqlserver.id
  subnet_id = azurerm_subnet.subnet.id
}

