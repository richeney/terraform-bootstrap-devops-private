# Terraform  Bootstrap

Example bootstrap for Azure DevOps using federated workload identities.

## Create a new repo

1. Go to <https://dev.azure.com/>
1. Select your organization on the left hand side
1. Click on **+ New project**
1. Add a project name and description
1. Set visibility to Private
1. Click on **Create**
1. Click on Repos > Files
1. Click on Initialize main branch with README checked, plus a Terraform .gitignore

## Create a personal access token

This is short-lived and is only needed for the duration of the bootstrap itself. Once the bootstrap is completed then you may revoke the token.

1. You should still be logged into [dev.azure.com](https://dev.azure.com)
1. Click the `User settings` icon in the top right and select `Personal access tokens`.
1. Click `+ New Token`.
1. Populate the `Name` field.
1. Reduce down the `Expiration` with a custom defined expiration or leave at 30d
1. Select Scopes = `Full access`
1. Click `Create`.
1. Copy the token and save it somewhere safe.
1. Click `Close`.

> TODO - Refine this.

## Create a terraform.tfvars

Example file:

```shell
subscription_id = "abcdef01-2345-6789-abcd-314159265359"

azure_devops_organization_name     = "RichardCheney"
azure_devops_project_name          = "terraform-bootstrap-devops-test"
azure_devops_personal_access_token = "redacted"
azure_devops_create_pipeline       = true
azure_devops_create_files          = true
```

Additional variables may be found in variables.tf.

## Known issues

- Destroy will fail for the service endpoint as the federated credential deletion does not propagate in time. Rerun the delete.
- Destroy does not remove the environment, despite indicating that it has. Remove manually.
