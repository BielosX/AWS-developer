import os
from aws_cdk import core as cdk
from aws_cdk import core
from aws_cdk import aws_s3 as s3
from aws_cdk import aws_s3_deployment as s3_deploy

class BucketStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        account = kwargs['env'].account
        region = kwargs['env'].region
        dirname = os.path.dirname(__file__)
        bucket = s3.Bucket(self, "my-test-bucket-{}-{}".format(account, region))
        s3_deploy.BucketDeployment(
            self, "DeployTestFile",
            sources=[s3_deploy.Source.asset("{}/content".format(dirname))],
            destination_bucket=bucket
        )
        self.bucket_name = bucket.bucket_name