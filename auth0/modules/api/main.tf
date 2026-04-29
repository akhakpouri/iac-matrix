resource "auth0_resource_server" "resource_server" {
  name                 = var.name
  identifier           = var.identifier
  signing_alg          = var.signing_alg
  allow_offline_access = var.allow_offline_access
  token_lifetime       = var.token_lifetime
}

resource "auth0_resource_server_scopes" "resource_server_scopes" {
  resource_server_identifier = auth0_resource_server.resource_server.identifier

  dynamic "scopes" {
    for_each = var.scopes
    content {
      name        = scopes.key
      description = scopes.value
    }
  }
}
