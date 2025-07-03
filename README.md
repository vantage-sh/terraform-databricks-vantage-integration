# terraform-databricks-vantage-integration

This module provisions all resources and permissions required to integrate your Databricks account with Vantage.

At a high level, the module will:
1. Create a Service Principal at the account level
2. Create OAuth credentials for the Service Principal
3. Create a SQL Warehouse
4. Assign the Service Principal permissions to use the SQL Warehouse
5. Assign the Service Principal permissions to use the `system` tables `billing`, `access`, and `compute`

After applying this module, the outputs (e.g., client ID, secret, SQL warehouse ID) will be used to configure the
[Databricks integration in the Vantage UI](https://console.vantage.sh/settings/databricks?connect=true).

## Databricks Provider Configurations
You will need to define two Databricks providers in your Terraform configuration, one for the account level and one for 
the workspace level.

```hcl
# Workspace-level provider (used for SQL Warehouse and permissions)
provider "databricks" {
  alias = "workspace"
  host  = "your_workspace_url"
  // authenticate to your Databricks workspace...
}

# Account-level provider (used for Service Principal creation)
provider "databricks" {
  alias = "account"
  host = "https://accounts.cloud.databricks.com"
  account_id = "your_account_id"
  // authenticate to your Databricks account...
}

module "databricks_billing" {
  providers = {
    databricks.workspace = databricks.workspace
    databricks.account = databricks.account
  }
  source           = "path_to_your_module"
}
```