terraform {
  cloud {
    organization = "akhakpouri"

    workspaces {
      name = "auth0"
    }
  }
}
