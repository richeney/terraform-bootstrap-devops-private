variable "subscription_id" {
  type        = string
  description = "The subscription guid for the terraform workload identity and remote state."

  validation {
    condition     = length(var.subscription_id) == 36 && can(regex("^[a-z0-9-]+$", var.subscription_id))
    error_message = "Subscription ID must be a 36 character GUID."
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group to deploy resources."
  default     = "terraform"
}

variable "location" {
  type        = string
  description = "The Azure region to deploy resources."
  default     = "UK South"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to add to resources."
  default     = null
}

variable "managed_identity_name" {
  type        = string
  description = "The name of the managed identity."
  default     = "terraform"
}

variable "storage_account_name" {
  type        = string
  description = "The name of the storage account. Must be globally unique."
  default     = null

  validation {
    condition     = var.storage_account_name == null ? true : (length(coalesce(var.storage_account_name, "abcefghijklmnopqrstuwxy")) <= 24 && length(coalesce(var.storage_account_name, "ab")) > 3 && can(regex("^[a-z0-9]+$", coalesce(var.storage_account_name, "A%"))))
    error_message = "Storage account name must be null or 3-24 of lowercase alphanumerical characters, and globally unique"
  }
}

//================================================================

variable "azure_devops_organization_name" {
  type        = string
  description = "value of the Azure DevOps organization name"
}

variable "azure_devops_project_name" {
  type        = string
  description = "value of the Azure DevOps project name"
}

variable "azure_devops_personal_access_token" {
  type        = string
  description = "value of the Azure DevOps fine grained personal access token"
}

variable "azure_devops_variable_group_name" {
  type        = string
  description = "value of the Azure DevOps variable group name"
  default     = "Terraform Backend"

  validation {
    condition     = length(var.azure_devops_variable_group_name) > 0
    error_message = "The azure_devops_variable_group_name must be a valid string."
  }
}

variable "azure_devops_service_connection_name" {
  type        = string
  description = "value of the Azure DevOps service connection name"

  default = "Terraform"

  validation {
    condition     = length(var.azure_devops_service_connection_name) > 0
    error_message = "The service_connection_name must be a valid string."
  }
}

variable "azure_devops_create_pipeline" {
  description = "Create a pipeline in Azure DevOps."
  type        = bool
  default     = true
}

variable "azure_devops_create_files" {
  description = "Create a set of Terraform files in Azure DevOps."
  type        = bool
  default     = false
}
