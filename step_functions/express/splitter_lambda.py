def handle(event, context):
    print(event)
    event_len = len(event)
    half = event_len//2
    if half > 0:
        result = {
            'firstHalf': event[:half],
            'secondHalf': event[half:],
            'count': event_len
        }
    else:
        result = {
            'firstHalf': [event[0]],
            'secondHalf': [],
            'count': event_len
        }
    print(result)
    return result