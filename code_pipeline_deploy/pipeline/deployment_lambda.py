import boto3
import json
import time

pipeline = boto3.client('codepipeline')
deploy = boto3.client('codedeploy')

def get_user_params(job_data):
    try:
        user_params = job_data['actionConfiguration']['configuration']['UserParameters'] 
        print("User params: {}".format(user_params))
        decoded_parameters = json.loads(user_params)
    except Exception as e:
        raise Exception('UserParameters could not be decoded as JSON')
    if 'first_asg' not in decoded_parameters:
        raise Exception('Your UserParameters JSON must include first_asg')
    if 'second_asg' not in decoded_parameters:
        raise Exception('Your UserParameters JSON must include second_asg')
    if 'application_name' not in decoded_parameters:
        raise Exception('Your UserParameters JSON must include application_name')
    if 'deployment_group' not in decoded_parameters:
        raise Exception('Your UserParameters JSON must include deployment_group')
    return decoded_parameters

def continue_later(job, deployment_id):
    continuation_token = json.dumps({'previous_job_id': job, 'deployment_id': deployment_id})
    pipeline.put_job_success_result(jobId=job, continuationToken=continuation_token)

def get_previous_asg(params):
    group = deploy.get_deployment_group(applicationName=params['application_name'], deploymentGroupName=params['deployment_group'])
    group_info = group['deploymentGroupInfo']
    if 'lastSuccessfulDeployment' in group_info:
        deployment_id = group_info['lastSuccessfulDeployment']['deploymentId']
        deployment =  deploy.get_deployment(deploymentId=deployment_id)
        return deployment['deploymentInfo']['targetInstances']['autoScalingGroups'][0]
    else:
        return None

def choose_asg(params):
    prev = get_previous_asg(params)
    print("prev asg: {}".format(prev))
    if prev is None:
        return params['second_asg']
    elif prev == params['first_asg']:
        return params['second_asg']
    elif prev == params['second_asg']:
        return params['first_asg']
    else:
        return None

def get_deployment_status(deployment_id):
    return deploy.get_deployment(deploymentId=deployment_id)['deploymentInfo']['status']

def wait_for_deployment(job_id, deployment_id):
    time.sleep(20)
    status = get_deployment_status(deployment_id)
    print("Deployment status: {}".format(status))
    if status == 'Failed':
        raise Exception('Deployment failed')
    if status == 'Succeeded':
        pipeline.put_job_success_result(jobId=job_id)
    else:
        continue_later(job_id, deployment_id)

def deploy_version(job_id, params, bucket, key):
    asg = choose_asg(params)
    resp = deploy.create_deployment(
        applicationName=params['application_name'],
        deploymentGroupName=params['deployment_group'],
        revision={
            'revisionType': 'S3',
            's3Location': {
                'bucket': bucket,
                'key': key,
                'bundleType': 'zip'
            }
        },
        targetInstances={
            'autoScalingGroups': [asg]
        }
    )
    deployment_id = resp['deploymentId']
    print("New deployment id: {}".format(deployment_id))
    wait_for_deployment(job_id, deployment_id)

def handle(event, context):
    job_id = event['CodePipeline.job']['id']
    job_data = event['CodePipeline.job']['data']
    try:
        if 'continuationToken' in job_data:
            token = json.loads(job_data['continuationToken'])
            deployment_id = token['deployment_id']
            wait_for_deployment(job_id, deployment_id)
        else:
            params = get_user_params(job_data)
            input_artifacts = job_data['inputArtifacts'][0]
            s3_location = input_artifacts['location']['s3Location']
            bucket_name = s3_location['bucketName']
            object_key = s3_location['objectKey']
            print("Artifact: bucket: {}, name: {}".format(bucket_name, object_key))
            deploy_version(job_id, params, bucket_name, object_key)
    except Exception as e:
        print("Job failed: {}".format(e))
        pipeline.put_job_failure_result(jobId=job_id, failureDetails={
            'type': 'JobFailed',
            'message': 'An Error occured'
        })
    return "Complete."