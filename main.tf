resource "auth0_client" "auth0_app" {
  name                                = "AWS SAML IdP"
  description                         = "SAML IdP for AWS Sagemaker portal"
  app_type                            = "spa"
  custom_login_page_on                = true
  is_first_party                      = true
  is_token_endpoint_ip_header_trusted = false
  token_endpoint_auth_method          = "client_secret_post"
  oidc_conformant                     = false
  callbacks = [
    "${local.cognito_domain}/saml2/idpresponse",
  ]
  allowed_origins     = []
  allowed_logout_urls = []
  web_origins         = []
  grant_types = [
    "authorization_code"
  ]

  addons {
    samlp {
      # Audience the SAML Assertion is intended for - should match the AWS Cognito User Pool to make assertion success
      audience                      = "urn:amazon:cognito:sp:${aws_cognito_user_pool.cognito_user_pool.id}"
      create_upn_claim              = false
      include_attribute_name_format = false
      lifetime_in_seconds           = 0
      logout = {
        "callback"    = "${local.cognito_domain}/saml2/logout"
        "slo_enabled" = true
      }
      map_identities           = false
      map_unknown_claims_as_is = false
      mappings = {
        "email"   = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        "user_id" = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",

        # Uncomment to deliver additional user details via SAML       
        # "name" : "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
        # "given_name" : "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname",
        # "family_name" : "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname",
        # "upn" : "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn",
        # "groups" : "http://schemas.xmlsoap.org/claims/Group"
      }
      name_identifier_format = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
      name_identifier_probes = [
        # Select user email address as a name identifier to be shown on Sagemaker portal
        "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
      ]
      passthrough_claims_with_no_mapping = false
      sign_response                      = false
      typed_attributes                   = false
    }
  }
}



resource "aws_iam_saml_provider" "saml_provider" {
  name                   = local.cognito_saml_provider_name
  saml_metadata_document = data.http.saml_file.response_body
}

resource "aws_cognito_user_pool" "cognito_user_pool" {
  name             = "SagemakerGroundTruth-UserPool"
  alias_attributes = ["email", "preferred_username"]

  # Additional Security settings
  device_configuration {
    challenge_required_on_new_device = "true"
  }

  # Advanced security mechanism allowing custom security actions  and bringing additional metrics - incurs additional AWS charges. 
  # Other options are "ENFORCED" or "AUDIT".
  user_pool_add_ons {
    advanced_security_mode = "OFF"
  }
}


resource "aws_cognito_user_pool_client" "cognito_app_client" {
  name                                 = "SagemakerGroundTruth-AppClient"
  user_pool_id                         = aws_cognito_user_pool.cognito_user_pool.id
  generate_secret                      = true
  callback_urls                        = ["https://${aws_cognito_user_pool_domain.cognito_domain.cloudfront_distribution_arn}"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  supported_identity_providers         = [aws_iam_saml_provider.saml_provider.name]

  #Additional security settings for the client tokens
  access_token_validity  = 10
  id_token_validity      = 10
  refresh_token_validity = 1
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "hours"
  }

  # Workaround cycling issue when we need to reference a SageMaker portal URL in allowed callbacks and logout URL's
  lifecycle {
    ignore_changes = [
      callback_urls,
      logout_urls
    ]
  }
  depends_on = [
    aws_cognito_identity_provider.cognito_user_pool_identity_provider
  ]
}

resource "aws_cognito_user_pool_domain" "cognito_domain" {
  domain       = "sagemakergroundtruth-test-domain"
  user_pool_id = aws_cognito_user_pool.cognito_user_pool.id
}

resource "aws_cognito_identity_provider" "cognito_user_pool_identity_provider" {
  user_pool_id  = aws_cognito_user_pool.cognito_user_pool.id
  provider_name = aws_iam_saml_provider.saml_provider.name
  provider_type = "SAML"
  attribute_mapping = {
    email              = "email"
    preferred_username = "name"
  }

  provider_details = {
    MetadataFile = aws_iam_saml_provider.saml_provider.saml_metadata_document
    IDPSignout   = true
  }
}

#Sagemaker
resource "aws_sagemaker_workforce" "workforce" {
  workforce_name = "default"

  cognito_config {
    client_id = aws_cognito_user_pool_client.cognito_app_client.id
    user_pool = aws_cognito_user_pool_domain.cognito_domain.user_pool_id
  }
}