# -----------------------------------------------------------------------------
# Outputs to enter in Vantage Console
# https://console.vantage.sh/settings/databricks?connect=true
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
  value       = databricks_sql_endpoint.vantage_billing_warehouse.id
}
