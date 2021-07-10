
from aws_cdk import core as cdk

# For consistency with other languages, `cdk` is the preferred import name for
# the CDK's core module.  The following line also imports it as `core` for use
# with examples from the CDK Developer's Guide, which are in the process of
# being updated to use `cdk`.  You may delete this import if you don't need it.
from aws_cdk import core
from aws_cdk import aws_apigateway as api_gateway
from aws_cdk import aws_iam as iam


class ApiGatewayStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, construct_id: str,
        user_pool=None,
        user_pool_domain=None,
        hello_lambda=None,
        web_bucket=None,
        **kwargs) -> None:

        super().__init__(scope, construct_id, **kwargs)

        api = api_gateway.RestApi(self, "demo-api")

        auth = api_gateway.CognitoUserPoolsAuthorizer(self, "helloAuthorizer",
            cognito_user_pools=[user_pool]
        )
        hello_resource = api.root.add_resource('hello')
        hello_resource.add_method("GET", api_gateway.LambdaIntegration(hello_lambda),
            authorizer=auth,
            authorization_type=api_gateway.AuthorizationType.COGNITO)

        login_resource = api.root.add_resource('login')
        login_resource.add_method("GET", api_gateway.HttpIntegration(user_pool_domain.base_url()))

        web_resource = api.root.add_resource('web')
        file_resource = web_resource.add_resource('{file}')

        s3_access_role = iam.Role(self, "S3AccessRole",
            assumed_by=iam.ServicePrincipal('apigateway.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonS3ReadOnlyAccess')
            ]
        )

        file_resource.add_method("GET", api_gateway.AwsIntegration(
            service="s3",
            integration_http_method='GET',
            path="{}/{{item}}".format(web_bucket.bucket_name),
            options={
                'credentials_role': s3_access_role,
                'request_parameters': {
                        'integration.request.path.item': 'method.request.path.file'
                    }
            }),
            request_parameters={
                'method.request.path.file': True
            }
        )

        self.api_gateway =api