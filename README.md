# terraform-databricks-vantage-integration

The resources will be used for V2 of Vantage's Databricks integration. See our [official documentation](https://docs.vantage.sh/connecting_databricks/) for more details.

This module provisions all resources and permissions required to integrate your Databricks account with Vantage.

At a high level, the module will:

1. Create a Service Principal at the account level
2. Create OAuth credentials for the Service Principal
3. Create a SQL Warehouse
4. Assign the Service Principal permissions to use the SQL Warehouse
5. Assign the Service Principal permissions to use the `system` tables `billing`, `access`, and `compute`

After applying this module, the outputs (e.g., client ID, secret, SQL warehouse ID) will be used to configure the
[Databricks integration in the Vantage UI](https://console.vantage.sh/settings/databricks?connect=true).

Optionally, you can use `enable_ip_allowlist = true` to restrict access to workspace to Vantage's static IP addresses.

## Databricks Provider Configurations

You will need to define a Databricks providers in your Terraform configuration, specifically a workspace level provider.

```hcl
# Workspace-level provider
provider "databricks" {
  host  = "$YOUR_WORKSPACE_URL"
  # authenticate to your Databricks workspace...
  # https://registry.terraform.io/providers/databricks/databricks/latest/docs#authentication
}

module "databricks_vantage_integration" {
  source = "github.com/vantage.sh/terraform-databricks-vantage-integration"
  
  # if you use ssh based git auth
  # source = "git::https://github.com/vantage-sh/terraform-databricks-vantage-integration.git"
}
```
