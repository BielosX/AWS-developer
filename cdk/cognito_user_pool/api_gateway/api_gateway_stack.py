
from aws_cdk import core as cdk

# For consistency with other languages, `cdk` is the preferred import name for
# the CDK's core module.  The following line also imports it as `core` for use
# with examples from the CDK Developer's Guide, which are in the process of
# being updated to use `cdk`.  You may delete this import if you don't need it.
from aws_cdk import core
from aws_cdk import aws_apigateway as api_gateway
from aws_cdk import aws_cognito as cognito


class ApiGatewayStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, construct_id: str, user_pool=None, user_pool_domain=None, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        user_pool_client = cognito.UserPoolClient(
            self,
            "ApiGatewayUserPoolClient",
            user_pool=user_pool,
            auth_flows={
                "user_password": True
            }
        )
        login_url = user_pool_domain.sign_in_url(client=user_pool_client, redirect_uri="https://example.com")
        api = api_gateway.RestApi(self, "demo-api")
        api.root.add_method("GET", api_gateway.HttpIntegration(login_url))