provider "aws" {
  region = "eu-west-1"
}

resource "aws_cognito_user_pool" "demo-user-pool" {
  name = "demo-user-pool"
}

resource "aws_cognito_user_pool_client" "demo-client" {
  name = "demo-client"
  user_pool_id = aws_cognito_user_pool.demo-user-pool.id
  generate_secret = false
  allowed_oauth_flows = ["implicit"]
  allowed_oauth_scopes = ["email", "profile", "openid"]
  callback_urls = ["http://localhost"]
  explicit_auth_flows = ["USER_PASSWORD_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = ["COGNITO"]
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

resource "aws_sqs_queue" "demo-queue" {
  visibility_timeout_seconds = 60
}

data "aws_iam_policy_document" "assume-role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["cognito-identity.amazonaws.com"]
      type = "Federated"
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test = "StringEquals"
      values = [aws_cognito_identity_pool.demo-identity-pool.id]
      variable = "cognito-identity.amazonaws.com:aud"
    }
    condition {
      test = "ForAnyValue:StringLike"
      values = ["authenticated"]
      variable = "cognito-identity.amazonaws.com:amr"
    }
  }
}

data "aws_iam_policy_document" "demo-queue-full-access" {
  statement {
    effect = "Allow"
    actions = ["sqs:*"]
    resources = [aws_sqs_queue.demo-queue.arn]
  }
}

resource "aws_iam_role" "sqs-access-role" {
  assume_role_policy = data.aws_iam_policy_document.assume-role.json
}

resource "aws_iam_role_policy" "demo-queue-full-access" {
  policy = data.aws_iam_policy_document.demo-queue-full-access.json
  role = aws_iam_role.sqs-access-role.id
}

resource "aws_cognito_identity_pool_roles_attachment" "role-attachment" {
  identity_pool_id = aws_cognito_identity_pool.demo-identity-pool.id
  role_mapping {
    identity_provider = "${aws_cognito_user_pool.demo-user-pool.endpoint}:${aws_cognito_user_pool_client.demo-client.id}"
    ambiguous_role_resolution = "AuthenticatedRole"
    type = "Rules"
    mapping_rule {
      claim = "isAdmin"
      match_type = "Equals"
      role_arn = aws_iam_role.sqs-access-role.arn
      value = "paid"
    }
  }
  roles = {
    "authenticated" = aws_iam_role.sqs-access-role.arn
  }
}
