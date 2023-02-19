data "http" "saml_file" {
  url = "https://${var.auth0_domain}/samlp/metadata/${auth0_client.auth0_app.id}"

  request_headers = {
    Accept = "application/xml"
  }
}