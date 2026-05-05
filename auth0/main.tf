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
  identifier = "urn:commerce-api"
  scopes = {
    "category:read"  = "read category"
    "category:write" = "write category"
    "orders:read"    = "read orders"
    "orders:write"   = "write orders"
    "payment:read"   = "read payment"
    "payment:write"  = "write payment"
    "products:read"  = "read products"
    "products:write" = "write products"
    "reviews:read"   = "read reviews"
    "reviews:write"  = "write reviews"
    "users:read"     = "read users"
    "users:write"    = "write users"
    "users:delete"   = "delete users"
  }
}
