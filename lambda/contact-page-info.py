import boto3
import json
import uuid
import time

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ContactUs')

def lambda_handler(event, context):
    body = json.loads(event['body'])
    name = body['name']
    email = body['email']
    message = body['message']
    s3_path = body['s3_path']

    table.put_item(Item={
        'id': str(uuid.uuid4()),
        'name': name,
        'email': email,
        'message': message,
        's3_path': s3_path,
        'timestamp': int(time.time())
    })

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Metadata stored successfully'})
    }
