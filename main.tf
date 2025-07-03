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
# Grant access to the 'system.billing' schema so the service principal can
# query billing data.
# -----------------------------------------------------------------------------
resource "databricks_grants" "system_billing_grants" {
  provider = databricks.workspace

  schema = data.databricks_schema.system_billing.id
  grant {
    principal  = databricks_service_principal.vantage_billing_sp.application_id
    privileges = ["USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT"]
  }
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
resource "databricks_grants" "system_compute_grants" {
  provider = databricks.workspace

  schema = data.databricks_schema.system_compute.id
  grant {
    principal  = databricks_service_principal.vantage_billing_sp.application_id
    privileges = ["USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT"]
  }
}

# -----------------------------------------------------------------------------
# Reference to the 'system.access' schema, used for getting metadata about
# workspace metadata and naming.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_access" {
  provider = databricks.workspace

  name = "system.access"
}

# -----------------------------------------------------------------------------
# Grant access to the 'system.access' schema for usage and access.
# -----------------------------------------------------------------------------
resource "databricks_grants" "system_access_grants" {
  provider = databricks.workspace

  schema = data.databricks_schema.system_access.id
  grant {
    principal  = databricks_service_principal.vantage_billing_sp.application_id
    privileges = ["USE_SCHEMA", "EXECUTE", "READ_VOLUME", "SELECT"]
  }
}