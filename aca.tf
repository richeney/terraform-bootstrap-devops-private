module "azure_devops_agents" {
  // https://registry.terraform.io/modules/Azure/avm-ptn-cicd-agents-and-runners/azurerm/latest?tab=inputs
  source  = "Azure/avm-ptn-cicd-agents-and-runners/azurerm"
  version = "0.1.4"

  postfix                                      = local.uniq
  location                                     = var.location
  version_control_system_type                  = "azuredevops"
  version_control_system_personal_access_token = var.azure_devops_agents_token
  version_control_system_organization          = local.org_service_url
  tags                                         = var.tags

  resource_group_creation_enabled               = false
  resource_group_name                           = var.resource_group_name
  virtual_network_creation_enabled              = false
  virtual_network_id                            = azurerm_virtual_network.private.id
  container_app_subnet_id                       = azurerm_subnet.agent_pool.id
  container_registry_private_endpoint_subnet_id = azurerm_subnet.private_endpoints.id

  container_app_environment_name                   = "my-container-app-environment"
  compute_types                                    = ["azure_container_app"]
  container_app_container_cpu                      = 1
  container_app_container_memory                   = "2Gi"
  container_app_environment_creation_enabled       = true
  container_app_infrastructure_resource_group_name = "agent-infrastructure" // null
  container_app_job_container_name                 = "azp-agent-myjobcontainer"                       // null
  container_app_job_name                           = "azp-agent-myjob"                                // null
  container_app_max_execution_count                = 3                                                // 100
  container_app_min_execution_count                = 0
  container_app_placeholder_container_name         = "azp-agent-myplaceholder" // null

  #   container_registry_creation_enabled                  = false
  #   container_registry_name                              = azurerm_container_registry.acr.name
  #   container_registry_private_dns_zone_creation_enabled = true
  #   custom_container_registry_images                     = null
  #   custom_container_registry_login_server               = azurerm_container_registry.acr.login_server
  #   custom_container_registry_username                   = azurerm_container_registry.acr.admin_username
  #   custom_container_registry_password                   = azurerm_container_registry.acr.admin_password
  #   default_image_name                                   = "${azurerm_container_registry.acr.login_server}/azp-agent:linux"

  #   container_app_placeholder_replica_retry_limit = 0
  #   container_app_placeholder_replica_timeout     = 300
  #   container_app_polling_interval_seconds        = 30
  #   container_app_replica_retry_limit             = 3
  #   container_app_replica_timeout                 = 1800

  version_control_system_pool_name         = azuredevops_agent_pool.aca.name
  version_control_system_agent_name_prefix = "aca-agent"

  depends_on = [azuredevops_pipeline_authorization.queue]
}
