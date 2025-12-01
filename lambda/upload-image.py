import boto3
import base64
import uuid
import json

s3 = boto3.client('s3')
bucket_name = 'flask-note-tools'

def lambda_handler(event, context):
    body = json.loads(event['body'])
    
    # Get file data and optional file name    
    file_data = base64.b64decode(body.get('file', ''))
    original_name = body.get('filename', str(uuid.uuid4()))
    
    # Generate unique name if not provided
    unique_name = f"{uuid.uuid4()}_{original_name}"
    
    # Optional: Get content type (default to application/octet-stream)
    content_type = body.get('content_type', 'application/octet-stream')
    
    # Upload to S3
    s3.put_object(
        Bucket=bucket_name,
        Key=unique_name,
        Body=file_data,
        ContentType=content_type
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'s3_path': f"s3://{bucket_name}/{unique_name}"})
    }
