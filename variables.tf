variable "auth0_domain" {
  type        = string
  description = "Auth0 Domain"
}
variable "auth0_client_id" {
  type        = string
  description = "Auth0 Machine to Machine client ID"
}

variable "auth0_client_secret" {
  type        = string
  description = "Auth0 client Secret"
}

variable "aws_region" {
  type        = string
  description = "Target AWS region for resource deployment"
}
variable "aws_cognito_domain_prefix" {
  type        = string
  description = "Custom prefix for Cognito domain in format '<aws_cognito_domain_prefix>.auth.<aws_region>.amazoncognito.com'"
}