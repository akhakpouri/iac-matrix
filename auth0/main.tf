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

module "commerce_api" {
  source = "./modules/api"
}
