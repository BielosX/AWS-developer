from aws_cdk import core as cdk
from aws_cdk import aws_cognito as cognito
from aws_cdk import aws_s3_deployment as s3_deployment

import json
from pathlib import Path
import os
import shutil

class WebDeploymentStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, construct_id: str,
        user_pool=None,
        web_bucket=None,
        api_gateway=None,
        **kwargs) -> None:

        super().__init__(scope, construct_id, **kwargs)

        dirname = os.path.dirname(__file__)
        client = cognito.UserPoolClient(self, "UserPoolClient",
            user_pool=user_pool,
            auth_flows={
                "user_password": True
            },
            o_auth={
                "flows": {
                    "implicit_code_grant": True
                },
                "callback_urls": ["{}/web/token.html".format(api_gateway.url)]
            }
        )
        directory = Path("{}/target".format(dirname))
        directory.mkdir(parents=True, exist_ok=True)
        for child in directory.iterdir():
            os.remove(str(child))
        with open("{}/target/client_id.json".format(dirname), "w") as text_file:
            text_file.write(json.dumps({'clientId': client.user_pool_client_id}))
        src_dir = Path("{}/src".format(dirname))
        for child in src_dir.iterdir():
            shutil.copy(str(child), str(directory))

        s3_deployment.BucketDeployment(self, "WebDeployment",
            destination_bucket=web_bucket,
            sources=[s3_deployment.Source.asset(str(directory))]
        )