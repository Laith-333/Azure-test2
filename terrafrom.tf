terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.65.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "a4503bef-025f-422e-aec8-247f8b4fd46f"
}

# Fetch Tenant ID
data "azurerm_client_config" "current" {}

# Random String for Unique Naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group with Random Name
resource "azurerm_resource_group" "example" {
  name     = "example-rg-${random_string.suffix.result}"
  location = "North Europe"
}


# Virtual Network
resource "azurerm_virtual_network" "hub_network" {
  name                = "example-vnet"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet for Database
resource "azurerm_subnet" "database_subnet" {
  name                 = "database-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.hub_network.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "mysql-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }

  depends_on = [
    azurerm_virtual_network.hub_network
  ]
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "private_endpoint_subnet" {
  name                 = "private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.hub_network.name
  address_prefixes     = ["10.0.5.0/24"]

  depends_on = [
    azurerm_virtual_network.hub_network
  ]
}


resource "azurerm_subnet" "container_subnet" {
  name                 = "container-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.hub_network.name
  address_prefixes     = ["10.0.16.0/20"]

  delegation {
    name = "container-delegation"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }

  depends_on = [
    azurerm_virtual_network.hub_network
  ]
}




# MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "default" {
  name                   = "example-mysql-server"
  resource_group_name    = azurerm_resource_group.example.name
  location               = azurerm_resource_group.example.location
  administrator_login    = "adminuser"
  administrator_password = "SecurePassw0rd!"
  sku_name               = "B_Standard_B1ms"

  storage {
    size_gb = 32
  }

  backup_retention_days = 7
  zone                  = "1" # Specify a valid availability zone here

  depends_on = [
    azurerm_virtual_network.hub_network
  ]
}


# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "exampleacr123unique"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Basic"
  admin_enabled       = true

  depends_on = [
    azurerm_resource_group.example
  ]
}


# Add Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "example-log-analytics"
  location            = "North Europe"
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  depends_on = [
    azurerm_resource_group.example
  ]
}


# Container App Environment with VNet Integration
resource "azurerm_container_app_environment" "app_env" {
  name                       = "private-container-env"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  # VNet integration for private access
  infrastructure_subnet_id = azurerm_subnet.container_subnet.id

  # Disable public network access
  internal_load_balancer_enabled = true

  # Enable zone redundancy for high availability
  zone_redundancy_enabled = true

  # Workload profile configuration
  workload_profile {
    name                  = "ca-profile"
    workload_profile_type = "D4"
    minimum_count         = 1
    maximum_count         = 2
  }

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics
  ]
}

# Private Endpoint for Container App Environment
resource "azurerm_private_endpoint" "container_env_private_endpoint" {
  name                = "privateendpoint"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "container-env-connection"
    private_connection_resource_id = azurerm_container_app_environment.app_env.id
    subresource_names              = ["managedEnvironments"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_container_app_environment.app_env
  ]
}


# Azure Private DNS Zone for Container App Environment
resource "azurerm_private_dns_zone" "container_env_dns_zone" {
  name                = "privatelink.containerapp.azure.com"
  resource_group_name = azurerm_resource_group.example.name
}

# Link DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "container_env_dns_link" {
  name                  = "container-env-dns-zone-link"
  resource_group_name   = azurerm_resource_group.example.name
  private_dns_zone_name = azurerm_private_dns_zone.container_env_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.hub_network.id
}

# Add A Record for the Private Endpoint
resource "azurerm_private_dns_a_record" "container_env_dns_a_record" {
  name                = azurerm_container_app_environment.app_env.name
  zone_name           = azurerm_private_dns_zone.container_env_dns_zone.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.container_env_private_endpoint.private_service_connection[0].private_ip_address]

  depends_on = [
    azurerm_private_endpoint.container_env_private_endpoint
  ]
}
# Add Container App
resource "azurerm_container_app" "container_app" {
  name                         = "example-container-app"
  container_app_environment_id = azurerm_container_app_environment.app_env.id
  resource_group_name          = azurerm_resource_group.example.name
  revision_mode                = "Single"

  template {
    container {
      name   = "example-container"
      image  = "laith333/test:test"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "REGISTRY_USERNAME"
        value = "exampleacr123unique"
      }

      env {
        name  = "REGISTRY_PASSWORD"
        value = "SuperSecret123!"
      }
    }
  }

  ingress {
    external_enabled = false # Disable public ingress
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_container_app_environment.app_env,
    azurerm_container_registry.acr,
  ]
}

////////////////////////////////////////////////////
# Private Endpoint for MySQL Flexible Server
resource "azurerm_private_endpoint" "mysql_private_endpoint" {
  name                = "mysql-private-endpoint"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "mysql-connection"
    private_connection_resource_id = azurerm_mysql_flexible_server.default.id
    subresource_names              = ["mysqlServer"] # Adjust if necessary
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.private_endpoint_subnet,
    azurerm_mysql_flexible_server.default
  ]
}

# Private DNS Zone for MySQL Flexible Server
resource "azurerm_private_dns_zone" "mysql_dns_zone" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.example.name
}

# Link DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link" {
  name                  = "mysql-dns-zone-link"
  resource_group_name   = azurerm_resource_group.example.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.hub_network.id
}

# Add A Record for the Private Endpoint
resource "azurerm_private_dns_a_record" "mysql_dns_a_record" {
  name                = azurerm_mysql_flexible_server.default.name
  zone_name           = azurerm_private_dns_zone.mysql_dns_zone.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.mysql_private_endpoint.private_service_connection[0].private_ip_address]
}


# Update NSG Rules for Private Endpoint
resource "azurerm_network_security_group" "private_endpoint_nsg" {
  name                = "private-endpoint-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "AllowContainerAppEnvironment"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint_nsg_association" {
  subnet_id                 = azurerm_subnet.private_endpoint_subnet.id
  network_security_group_id = azurerm_network_security_group.private_endpoint_nsg.id
}

