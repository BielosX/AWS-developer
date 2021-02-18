import boto3
import json

pipeline = boto3.client('codepipeline')

def get_user_params(job_data):
    try:
        user_params = job_data['actionConfiguration']['configuration']['UserParameters'] 
        print("User params: {}".format(user_params))
        decoded_parameters = json.loads(user_params)
    except Exception as e:
        raise Exception('UserParameters could not be decoded as JSON')
    if 'count' not in decoded_parameters:
        raise Exception('Your UserParameters JSON must include count')
    return decoded_parameters

def continue_later(job, count):
    continuation_token = json.dumps({'previous_job_id': job, 'count': count})
    pipeline.put_job_success_result(jobId=job, continuationToken=continuation_token)

def handle(event, context):
    job_id = event['CodePipeline.job']['id']
    job_data = event['CodePipeline.job']['data']
    try:
        count = get_user_params(job_data)['count']
        if 'continuationToken' in job_data:
            count = json.loads(job_data['continuationToken'])['count']
        print("Hello World jobId: {}, count: {}".format(job_id, count))
        count = count - 1
        if count == 0:
            pipeline.put_job_success_result(jobId=job_id)
        else:
            continue_later(job_id, count)
    except Exception as e:
        print("Job failed: {}".format(e))
        pipeline.put_job_failure_result(jobId=job_id, failureDetails={
            'type': 'JobFailed',
            'message': 'An Error occured'
        })
    return "Complete."