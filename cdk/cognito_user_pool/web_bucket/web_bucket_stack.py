from aws_cdk import core as cdk

from aws_cdk import aws_s3 as s3

class WebBucketStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        web_bucket = s3.Bucket(self, "WebsiteBucket",
            public_read_access=True,
            website_index_document="index.html")
        self.web_bucket = web_bucket