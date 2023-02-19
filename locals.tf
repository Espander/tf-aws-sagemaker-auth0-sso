locals {
  cognito_domain             = "https://${var.aws_cognito_domain_prefix}.auth.${var.aws_region}.amazoncognito.com"
  cognito_saml_provider_name = "SagemakerGroundTruthSAMLProvider"
}