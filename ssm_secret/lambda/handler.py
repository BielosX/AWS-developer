import redis
import os


def handle(event, context):
    redis_url = os.environ['REDIS_URL']
    client = redis.Redis(host=redis_url, port=6379, db=0, ssl=True, password="Qwertyuiopasdfghjkl", username="default")
    client.set('foo', 'bar')
    val = client.get('foo')
    return val