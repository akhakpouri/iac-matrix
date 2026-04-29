output "commerce_api_audience" {
  description = "Audience identifier for the commerce-api resource server."
  value       = module.commerce_api.audience
}

output "commerce_api_scopes" {
  description = "Scope names registered on the commerce-api resource server."
  value       = module.commerce_api.scope_names
}
