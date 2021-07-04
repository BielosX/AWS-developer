from aws_cdk import core as cdk

# For consistency with other languages, `cdk` is the preferred import name for
# the CDK's core module.  The following line also imports it as `core` for use
# with examples from the CDK Developer's Guide, which are in the process of
# being updated to use `cdk`.  You may delete this import if you don't need it.
from aws_cdk import core
from aws_cdk import aws_cognito as cognito


class CognitoUserPoolStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        account = kwargs['env'].account
        region = kwargs['env'].region

        user_pool = cognito.UserPool(self, "DemoUserPool",
            user_pool_name="demo-user-pool",
            self_sign_up_enabled=True,
            enable_sms_role=False,
            password_policy={
                "min_length": 12,
                "require_digits": True,
                "require_lowercase": True,
                "require_symbols": False,
                "require_uppercase": False
            },
            standard_attributes={
                "address": {
                    "required": False,
                    "mutable": True
                },
                "nickname": {
                    "required": False,
                    "mutable": True
                }
            },
            custom_attributes={
                "favorite_fruit": cognito.StringAttribute(min_len=1, max_len=30, mutable=True)
            },
            sign_in_aliases={
                "username": True,
                "email": True
            },
            auto_verify={
                "email": True
            }
        )
        user_pool_domain = cognito.UserPoolDomain(self, "DemoUserPoolDomain",
            user_pool=user_pool,
            cognito_domain={
                "domain_prefix": "demo-user-pool-{}-{}".format(account, region)
            }
        )
        self.user_pool = user_pool
        self.user_pool_domain = user_pool_domain