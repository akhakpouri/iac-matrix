output "audience" {
  description = "Audience identifier for the resource server. Consumers use this as the JWT 'aud' claim and as the `audience` parameter when requesting access tokens."
  value       = auth0_resource_server.commerce_api.identifier
}

output "name" {
  description = "Display name of the resource server (as shown in the Auth0 dashboard)."
  value       = auth0_resource_server.commerce_api.name
}

output "scope_names" {
  description = "List of scope names registered on the resource server."
  value       = [for s in auth0_resource_server_scopes.commerce_api_scope.scopes : s.name]
}
