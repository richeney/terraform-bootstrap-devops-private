data "azurerm_subscription" "terraform" {
  subscription_id = var.subscription_id
}

locals {
  uniq                 = substr(sha1(azurerm_resource_group.terraform.id), 0, 8)
  storage_account_name = "terraform${local.uniq}"
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

  lifecycle {
    ignore_changes = [tags]
  }

  account_tier             = "Standard"
  account_kind             = "BlobStorage"
  account_replication_type = "GRS"

  default_to_oauth_authentication = true
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

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
