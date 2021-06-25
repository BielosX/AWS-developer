#!/usr/bin/env python3
import os

from aws_cdk import core as cdk

# For consistency with TypeScript code, `cdk` is the preferred import name for
# the CDK's core module.  The following line also imports it as `core` for use
# with examples from the CDK Developer's Guide, which are in the process of
# being updated to use `cdk`.  You may delete this import if you don't need it.
from aws_cdk import core

from aws_lambda.lambda_stack import LambdaStack
from bucket.bucket_stack import BucketStack


app = core.App()
account = os.getenv('AWS_ACCOUNT')
region = os.getenv('AWS_REGION')
print("Account: {} Region: {}".format(account, region))
bucket_stack = BucketStack(app, "BucketStack", env=core.Environment(account=account, region=region))
lambda_stack = LambdaStack(app,
    "LambdaStack",
    env=core.Environment(account=account, region=region),
    bucket_name = bucket_stack.bucket_name)
lambda_stack.add_dependency(bucket_stack)
app.synth()
