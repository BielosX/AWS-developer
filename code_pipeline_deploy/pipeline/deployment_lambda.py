import boto3

pipeline = boto3.client('codepipeline')

def handle(event, context):
    job_id = event['CodePipeline.job']['id']
    print("Hello World jobId: {}".format(job_id))
    pipeline.put_job_success_result(jobId=job_id)
    return "Complete."