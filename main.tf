# -----------------------------------------------------------------------------
# Terraform Configuration for Vantage Billing Integration with Databricks
#
# This script sets up a Databricks Service Principal with access to system
# schemas and a SQL Warehouse for billing-related data collection. It also
# configures necessary permissions and access controls.
#
# Intended for use by customers integrating with Vantage.
# -----------------------------------------------------------------------------

# Workspace-level provider (used for SQL Warehouse and permissions)
provider "databricks" {
  alias = "workspace"
  host  = "$YOUR_WORKSPACE_URL_HERE"
  # authenticate to your Databricks workspace...
  # https://registry.terraform.io/providers/databricks/databricks/latest/docs#authentication
}

# Account-level provider (used for Service Principal creation)
provider "databricks" {
  alias = "account"
  host = "https://accounts.cloud.databricks.com"
  account_id = "$YOUR_ACCOUNT_ID_HERE"
  # authenticate to your Databricks account...
  # https://registry.terraform.io/providers/databricks/databricks/latest/docs#authentication
}

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
      configuration_aliases = [databricks.workspace, databricks.account]
    }
  }
}

# -----------------------------------------------------------------------------
# Create a service principal for Vantage to use within the Databricks workspace.
# -----------------------------------------------------------------------------
resource "databricks_service_principal" "vantage_billing_sp" {
  provider = databricks.workspace

  display_name = "vantage-billing-sp"
  databricks_sql_access = true
  workspace_access = true
  active = true
}

# -----------------------------------------------------------------------------
# Generate a secret (client credentials) for the service principal in the
# account scope.
# -----------------------------------------------------------------------------
resource "databricks_service_principal_secret" "vantage_billing_sp_credentials" {
  provider = databricks.account

  service_principal_id = databricks_service_principal.vantage_billing_sp.id
}

# -----------------------------------------------------------------------------
# Create a serverless SQL Warehouse that Vantage will use to run billing
# queries.
# -----------------------------------------------------------------------------
resource "databricks_sql_endpoint" "vantage_billing_warehouse" {
  provider = databricks.workspace

  name                     = "vantage-billing-warehouse"
  cluster_size             = "2X-Small"
  enable_serverless_compute = true
  max_num_clusters         = 1
  auto_stop_mins           = 5
}

# -----------------------------------------------------------------------------
# Grant the service principal permission to use the SQL Warehouse.
# -----------------------------------------------------------------------------
resource "databricks_permissions" "sp_usage_of_warehouse" {
  provider = databricks.workspace

  sql_endpoint_id = databricks_sql_endpoint.vantage_billing_warehouse.id

  access_control {
    service_principal_name = databricks_service_principal.vantage_billing_sp.application_id
    permission_level = "CAN_USE"
  }
}

# -----------------------------------------------------------------------------
# Reference to the 'system.billing' schema, which contains billing data.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_billing" {
  provider = databricks.workspace

  name = "system.billing"
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.billing' schema so the service principal can query billing data.
# -----------------------------------------------------------------------------
resource "databricks_grant" "system_billing_grants" {
  provider = databricks.workspace

  schema = data.databricks_schema.system_billing.id
  principal  = databricks_service_principal.vantage_billing_sp.application_id
  privileges = ["USE_SCHEMA", "SELECT"]
}

# -----------------------------------------------------------------------------
# Reference to the 'system.compute' schema, which provides compute usage data
# and metadata like SQL Warehouse names.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_compute" {
  provider = databricks.workspace

  name = "system.compute"
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.compute' schema.
# -----------------------------------------------------------------------------
resource "databricks_grant" "system_compute_grants" {
  provider = databricks.workspace

  schema = data.databricks_schema.system_compute.id
  principal  = databricks_service_principal.vantage_billing_sp.application_id
  privileges = ["USE_SCHEMA", "SELECT"]
}

# -----------------------------------------------------------------------------
# Reference to the 'system.access' schema, used for audit and access log insights.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_access" {
  provider = databricks.workspace

  name = "system.access"
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.access' schema for usage and access auditing.
# -----------------------------------------------------------------------------
resource "databricks_grant" "system_access_grants" {
  provider = databricks.workspace

  schema = data.databricks_schema.system_access.id
  principal  = databricks_service_principal.vantage_billing_sp.application_id
  privileges = ["USE_SCHEMA", "SELECT"]
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.access' schema for usage and access auditing.
# -----------------------------------------------------------------------------

output "service_principal_id" {
  description = "Client ID of the Vantage billing service principal"
  value       = databricks_service_principal.vantage_billing_sp.application_id
}

output "service_principal_secret" {
  description = "Secret of the Vantage billing service principal"
  value       = databricks_service_principal_secret.vantage_billing_sp_credentials.secret
  sensitive   = true
}

output "vantage_billing_warehouse_id" {
  description = "ID of SQL Warehouse for Vantage billing"
  value = databricks_sql_endpoint.vantage_billing_warehouse.id
}