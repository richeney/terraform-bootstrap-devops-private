data "azurerm_client_config" "current" {}

data "azurerm_subscription" "terraform" {
  subscription_id = var.subscription_id
}

data "http" "source_address" {
  url = "https://ipinfo.io/ip"

  request_headers = {
    Accept = "application/json"
  }
}

locals {
  uniq                    = substr(sha1(azurerm_resource_group.terraform.id), 0, 8)
  storage_account_name    = "terraformsa${local.uniq}"
  container_registry_name = "terraformacr${local.uniq}"
}

resource "azurerm_resource_group" "terraform" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_storage_account" "terraform" {
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location
  tags                = var.tags

  # public_network_access_enabled = false
  # need access to the storage account when running the initial bootstrap
  # will rework this to be more secure in the future

  account_tier             = "Standard"
  account_kind             = "BlobStorage"
  account_replication_type = "GRS"

  default_to_oauth_authentication  = true
  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = false

  network_rules {
    default_action = "Deny"
    ip_rules       = [data.http.source_address.response_body]
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 365
    }
    container_delete_retention_policy {
      days = 90
    }
  }
}

resource "azurerm_storage_container" "terraform" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform.name
  container_access_type = "private"

  depends_on = [
    azurerm_storage_account.terraform
  ]
}

resource "azurerm_user_assigned_identity" "terraform" {
  name                = var.managed_identity_name
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_role_assignment" "contributor" {
  // Make this a default, but allow it to be overridden with an array of objects containing scope and role_definition_name
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id
}

resource "azurerm_role_assignment" "state" {
  scope                = azurerm_storage_account.terraform.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.terraform.principal_id

}

//===================================================================

// Additional resources for host pool

resource "azurerm_public_ip" "private" {
  name                = "terraform-pip"
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "private" {
  name                = "terraform-natgw"
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "private" {
  nat_gateway_id       = azurerm_nat_gateway.private.id
  public_ip_address_id = azurerm_public_ip.private.id
}

resource "azurerm_subnet_nat_gateway_association" "agent_pool" {
  subnet_id      = azurerm_subnet.agent_pool.id
  nat_gateway_id = azurerm_nat_gateway.private.id
}

//===================================================================

resource "azurerm_virtual_network" "private" {
  name                = "terraform-vnet"
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "agent_pool" {
  name                              = "agent_pool"
  resource_group_name               = azurerm_resource_group.terraform.name
  virtual_network_name              = azurerm_virtual_network.private.name
  address_prefixes                  = ["10.0.0.0/26"]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Enabled"

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
    }
  }

}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "private_endpoints"
  resource_group_name               = azurerm_resource_group.terraform.name
  virtual_network_name              = azurerm_virtual_network.private.name
  address_prefixes                  = ["10.0.0.64/26"]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Enabled"
}

//===================================================================





resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.terraform.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "storage_private_dns_zone_link"
  resource_group_name   = azurerm_resource_group.terraform.name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.private.id
}

resource "azurerm_private_endpoint" "storage" {
  name                = "${azurerm_storage_account.terraform.name}-pe"
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  custom_network_interface_name = "${azurerm_storage_account.terraform.name}-pe-nic"

  private_service_connection {
    name                           = "blob_storage_private_service_connection"
    private_connection_resource_id = azurerm_storage_account.terraform.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob_storage"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
  }
}

//===================================================================

resource "azurerm_container_registry" "acr" {
  name                = local.container_registry_name
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_container_registry_task" "acr_task" {
  name                  = "agent-build"
  container_registry_id = azurerm_container_registry.acr.id

  platform {
    os           = "Linux"
    architecture = "amd64"
  }

  docker_step {
    context_access_token = var.azure_devops_personal_access_token
    context_path         = "https://github.com/richeney/azure_devops_agent.git#main:."
    dockerfile_path      = "./dockerfile"
    image_names          = ["azp-agent:linux"]
    push_enabled         = true
    arguments            = null
  }
}

resource "azurerm_container_registry_task_schedule_run_now" "run_now" {
  container_registry_task_id = azurerm_container_registry_task.acr_task.id
}

//===================================================================

/*
resource "azurerm_container_group" "alz" {
  for_each            = toset(["agent-01"])
  name                = each.value
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location
  ip_address_type     = "Private"
  os_type             = "Linux"
  subnet_ids          = [azurerm_subnet.container_instances.id]
  depends_on = [
    azurerm_container_registry_task_schedule_run_now.run_now
  ]

  image_registry_credential {
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
    server   = azurerm_container_registry.acr.login_server
  }

  # Included pipelines uses OIDC for authentication.
  # See <https://github.com/Azure-Samples/azure-devops-terraform-oidc-ci-cd/tree/main/pipelines>
  # for a comparison between OIDC and managed identity authentication.
  # OIDC is more secure and more flexible than managed identity authentication in this case.

  # identity {
  #   type = "UserAssigned"
  #   identity_ids = [
  #     azurerm_user_assigned_identity.terraform.id
  #   ]
  # }

  container {
    name   = each.value
    image  = "${azurerm_container_registry.acr.login_server}/azp-agent:linux"
    cpu    = 1
    memory = 4

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      AZP_AGENT_NAME = each.value
      AZP_URL        = local.org_service_url
      AZP_POOL       = local.agent_pool_name
    }

    secure_environment_variables = {
      AZP_TOKEN = var.azure_devops_agents_token
    }
  }
}
*/
