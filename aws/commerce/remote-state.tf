# RDS connection info comes from the platform-shared workspace so there's one
# source of truth — endpoint changes there propagate without per-workspace
# variable updates.
data "terraform_remote_state" "platform" {
  backend = "remote"
  config = {
    organization = "akhakpouri"
    workspaces = {
      name = "platform-shared"
    }
  }
}
