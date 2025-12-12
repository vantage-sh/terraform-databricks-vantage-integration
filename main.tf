# -----------------------------------------------------------------------------
# Terraform Configuration for Vantage Billing Integration with Databricks
#
# This script sets up a Databricks Service Principal with access to system
# schemas and a SQL Warehouse for billing-related data collection. It also
# configures necessary permissions and access controls.
#
# Intended for use by customers integrating with Vantage.
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      # https://github.com/databricks/terraform-provider-databricks/releases/tag/v1.86.0
      # this version allows for service principal creation at the workspace level
      version = ">= 1.86.0"
    }
  }
  required_version = ">= 1.0"
}

# -----------------------------------------------------------------------------
# Create a service principal for Vantage to use within the Databricks workspace.
# -----------------------------------------------------------------------------
resource "databricks_service_principal" "vantage_billing_sp" {
  display_name          = "vantage-billing-sp"
  databricks_sql_access = true
  workspace_access      = true
  active                = true
}

# -----------------------------------------------------------------------------
# Generate a secret (client credentials) for the service principal in the
# account scope.
# -----------------------------------------------------------------------------
resource "databricks_service_principal_secret" "vantage_billing_sp_credentials" {
  service_principal_id = databricks_service_principal.vantage_billing_sp.id
}

# -----------------------------------------------------------------------------
# Create a serverless SQL Warehouse that Vantage will use to run billing
# queries.
# -----------------------------------------------------------------------------
resource "databricks_sql_endpoint" "vantage_billing_warehouse" {
  name                      = "vantage-billing-warehouse"
  cluster_size              = "2X-Small"
  enable_serverless_compute = true
  max_num_clusters          = 1
  auto_stop_mins            = 5
}

# -----------------------------------------------------------------------------
# Grant the service principal permission to use the SQL Warehouse.
# -----------------------------------------------------------------------------
resource "databricks_permissions" "sp_usage_of_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.vantage_billing_warehouse.id

  access_control {
    service_principal_name = databricks_service_principal.vantage_billing_sp.application_id
    permission_level       = "CAN_USE"
  }
}

# -----------------------------------------------------------------------------
# Enable IP access lists for Vantage IP Addresses
# -----------------------------------------------------------------------------
resource "databricks_workspace_conf" "enable_ip_access_lists" {
  count = var.enable_ip_allowlist ? 1 : 0

  custom_config = {
    "enableIpAccessLists" = true
  }
}

resource "databricks_ip_access_list" "vantage_static_ips" {
  count = var.enable_ip_allowlist ? 1 : 0

  label     = "allow_in"
  list_type = "ALLOW"
  # https://docs.vantage.sh/security/#:~:text=Does%20Vantage%20use%20fixed%20IP%20addresses%20when%20connecting%20to%20external%20providers%2C%20such%20as%20AWS%20or%20Azure%3F
  ip_addresses = [
    "54.87.66.45",
    "3.95.43.133",
    "54.162.3.72",
    "44.199.143.63",
    "3.218.103.23"
  ]
  depends_on = [databricks_workspace_conf.enable_ip_access_lists]
}

# -----------------------------------------------------------------------------
# Reference to the 'system.billing' schema, which contains billing data.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_billing" {

  name = "system.billing"
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.billing' schema so the service principal can query billing data.
# -----------------------------------------------------------------------------
resource "databricks_grant" "system_billing_grants" {

  schema     = data.databricks_schema.system_billing.id
  principal  = databricks_service_principal.vantage_billing_sp.application_id
  privileges = ["USE_SCHEMA", "SELECT"]
}

# -----------------------------------------------------------------------------
# Reference to the 'system.compute' schema, which provides compute usage data
# and metadata like SQL Warehouse names.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_compute" {
  name = "system.compute"
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.compute' schema.
# -----------------------------------------------------------------------------
resource "databricks_grant" "system_compute_grants" {
  schema     = data.databricks_schema.system_compute.id
  principal  = databricks_service_principal.vantage_billing_sp.application_id
  privileges = ["USE_SCHEMA", "SELECT"]
}

# -----------------------------------------------------------------------------
# Reference to the 'system.access' schema, used for audit and access log insights.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_access" {
  name = "system.access"
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.access' schema for usage and access auditing.
# -----------------------------------------------------------------------------
resource "databricks_grant" "system_access_grants" {
  schema     = data.databricks_schema.system_access.id
  principal  = databricks_service_principal.vantage_billing_sp.application_id
  privileges = ["USE_SCHEMA", "SELECT"]
}
