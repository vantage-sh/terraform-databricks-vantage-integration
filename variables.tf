variable "enable_ip_allowlist" {
  type = bool
  default = false
  # https://docs.vantage.sh/security/#:~:text=Does%20Vantage%20use%20fixed%20IP%20addresses%20when%20connecting%20to%20external%20providers%2C%20such%20as%20AWS%20or%20Azure%3F
  description = "Enable IP allowlist for Vantage IP Addresses"
}