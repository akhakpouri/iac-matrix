resource "auth0_branding" "default_branding" {
  logo_url = "https://cdn.auth0.com/marketplace/v1/commerce-api-server.png"
  colors {
    primary         = "#0059ff"
    page_background = "#f4f4f4"
  }
}

resource "auth0_prompt" "default_prompt" {
  universal_login_experience = "new"
  identifier_first           = true
}

module "commerce_api" {
  source = "./modules/api"

  name       = "Commerce Api Server"
  identifier = "commerce-api-server"
  scopes = {
    "orders:read"     = "read orders"
    "orders:write"    = "write orders"
    "orders:delete"   = "delete orders"
    "products:read"   = "read products"
    "products:write"  = "write products"
    "products:delete" = "delete products"
    "users:read"      = "read users"
    "users:write"     = "write users"
    "users:delete"    = "delete users"
  }
}
