from aws_cdk import core as cdk

# For consistency with other languages, `cdk` is the preferred import name for
# the CDK's core module.  The following line also imports it as `core` for use
# with examples from the CDK Developer's Guide, which are in the process of
# being updated to use `cdk`.  You may delete this import if you don't need it.
from aws_cdk import core
from aws_cdk import aws_lambda
import aws_cdk.aws_iam as iam
import os


class HelloLambdaStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        dirname = os.path.dirname(__file__)
        hello_lambda = aws_lambda.Function(
            self,
            "api-gateway-demo-lambda",
            handler = "handle.handle",
            runtime = aws_lambda.Runtime("python3.8"),
            code = aws_lambda.Code.from_asset(path = (dirname + "/src"))
        )
        principal = iam.ServicePrincipal("apigateway.amazonaws.com")
        hello_lambda.grant_invoke(principal)
        self.hello_lambda = hello_lambda