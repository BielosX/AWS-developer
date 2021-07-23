provider "aws" {
  region = "eu-west-1"
}

resource "aws_cognito_user_pool" "demo-user-pool" {
  name = "demo-user-pool"
}

resource "aws_cognito_resource_server" "demo-resource-server" {
  identifier = "demo"
  name = "demo-resource-server"
  user_pool_id = aws_cognito_user_pool.demo-user-pool.id
  scope {
    scope_description = "test scope"
    scope_name = "test"
  }
}

resource "aws_cognito_user_pool_client" "demo-client" {
  name = "demo-client"
  user_pool_id = aws_cognito_user_pool.demo-user-pool.id
  generate_secret = true
  allowed_oauth_flows = ["client_credentials"]
  allowed_oauth_scopes = aws_cognito_resource_server.demo-resource-server.scope_identifiers
  allowed_oauth_flows_user_pool_client = true
}

resource "aws_cognito_user_pool_domain" "demo-domain" {
  domain = "demo-domain"
  user_pool_id = aws_cognito_user_pool.demo-user-pool.id
}

resource "aws_ssm_parameter" "demo-client-id" {
  name = "/cognito/demo-client/client-id"
  type = "String"
  value = aws_cognito_user_pool_client.demo-client.id
}

resource "aws_ssm_parameter" "demo-client-secret" {
  name = "/cognito/demo-client/client-secret"
  type = "String"
  value = aws_cognito_user_pool_client.demo-client.client_secret
}

resource "aws_ssm_parameter" "demo-domain-url" {
  name = "/cognito/demo-user-pool/domain"
  type = "String"
  value = "https://${aws_cognito_user_pool_domain.demo-domain.domain}.auth.eu-west-1.amazoncognito.com"
}

resource "aws_cognito_identity_pool" "demo-identity-pool" {
  identity_pool_name = "demo-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id = aws_cognito_user_pool_client.demo-client.id
    provider_name = aws_cognito_user_pool.demo-user-pool.endpoint
    server_side_token_check = false
  }
}