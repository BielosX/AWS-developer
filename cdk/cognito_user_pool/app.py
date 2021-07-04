#!/usr/bin/env python3
import os

from aws_cdk import core as cdk

# For consistency with TypeScript code, `cdk` is the preferred import name for
# the CDK's core module.  The following line also imports it as `core` for use
# with examples from the CDK Developer's Guide, which are in the process of
# being updated to use `cdk`.  You may delete this import if you don't need it.
from aws_cdk import core

from cognito_user_pool.cognito_user_pool_stack import CognitoUserPoolStack


app = core.App()
account = os.getenv('AWS_ACCOUNT')
region = os.getenv('AWS_REGION')
CognitoUserPoolStack(app, "CognitoUserPoolStack",
    env=core.Environment(account=account, region=region))
app.synth()
