from aws_cdk import core as cdk

# For consistency with other languages, `cdk` is the preferred import name for
# the CDK's core module.  The following line also imports it as `core` for use
# with examples from the CDK Developer's Guide, which are in the process of
# being updated to use `cdk`.  You may delete this import if you don't need it.
from aws_cdk import core
from aws_cdk import aws_lambda as aws_lambda
from aws_cdk import aws_iam as iam
import os


class LambdaStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, construct_id: str, bucket_name=None, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        dirname = os.path.dirname(__file__)
        role = iam.Role(self,
            "s3-full-access-role",
            assumed_by =  iam.ServicePrincipal("lambda.amazonaws.com"),
            managed_policies = [iam.ManagedPolicy.from_aws_managed_policy_name("AmazonS3FullAccess")])
        aws_lambda.Function(
            self,
            "cdk-demo-lambda",
            handler = "handle.handle",
            runtime = aws_lambda.Runtime("python3.8"),
            code = aws_lambda.Code.from_asset(path = (dirname + "/src")),
            role = role,
            environment = {
                "BUCKET_NAME": bucket_name
            }
        )