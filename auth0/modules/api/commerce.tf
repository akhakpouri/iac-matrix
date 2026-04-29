resource "auth0_resource_server" "commerce_api" {
  name                 = "Commerce Api Server"
  identifier           = "commerce-api-server"
  signing_alg          = "RS256"
  allow_offline_access = true
  token_lifetime       = 84600
}

resource "auth0_resource_server_scopes" "commerce_api_scope" {
  resource_server_identifier = auth0_resource_server.commerce_api.identifier
  scopes {
    description = "read orders"
    name        = "orders:read"
  }
  scopes {
    description = "write orders"
    name        = "orders:write"
  }
  scopes {
    description = "delete orders"
    name        = "orders:delete"
  }
  scopes {
    description = "read products"
    name        = "products:read"
  }
  scopes {
    description = "write products"
    name        = "products:write"
  }
  scopes {
    description = "delete products"
    name        = "products:delete"
  }
  scopes {
    description = "read users"
    name        = "users:read"
  }
  scopes {
    description = "write users"
    name        = "users:write"
  }
  scopes {
    description = "delete users"
    name        = "users:delete"
  }
}

resource "auth0_branding" "commerce_api_branding" {
  logo_url = "https://cdn.auth0.com/marketplace/v1/commerce-api-server.png"
  colors {
    primary         = "#0059ff"
    page_background = "#f4f4f4"
  }
}

resource "auth0_prompt" "commerce_api_prompt" {
  universal_login_experience = "new"
  identifier_first           = true
}
