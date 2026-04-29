variable "name" {
  description = "Display name for the resource server (shown in the Auth0 dashboard)."
  type        = string
}

variable "identifier" {
  description = "Audience identifier — used as the JWT 'aud' claim. Should be a URI in production. Auth0 cannot change this in place; renaming requires recreate."
  type        = string
}

variable "scopes" {
  description = "Scopes registered on the resource server, as a map of scope name → description."
  type        = map(string)
}

variable "signing_alg" {
  description = "Algorithm used to sign access tokens."
  type        = string
  default     = "RS256"
}

variable "token_lifetime" {
  description = "Access token lifetime in seconds."
  type        = number
  default     = 86400
}

variable "allow_offline_access" {
  description = "Whether refresh tokens are issued for this audience."
  type        = bool
  default     = true
}
