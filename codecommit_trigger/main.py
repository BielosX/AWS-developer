
def handler(event, context):
    print(event)
    for record in event['Records']:
        repository = record['eventSourceARN']
        for reference in record['codecommit']['references']:
            commit_hash = reference['commit']
            print("Hash: {}, repository: {}".format(commit_hash, repository))
    return "OK"