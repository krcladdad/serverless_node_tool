
import json
import boto3
import time

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('NotesTable')

def lambda_handler(event, context):
    try:
        http_method = event.get('httpMethod')
        if http_method == 'GET':
            dynamo_response = table.scan()
            return build_response(200, dynamo_response.get('Items', []))

        body = json.loads(event.get('body', '{}'))
        action = body.get('action')

        if action == 'get_all':
            dynamo_response = table.scan()
            return build_response(200, dynamo_response.get('Items', []))
        elif action == 'add':
            note_text = body.get('note')
            if not note_text:
                return build_response(400, {'error': 'Note text is required'})
            new_id = str(int(time.time()))
            table.put_item(Item={'id': new_id, 'text': note_text})
            return build_response(200, {'message': 'Note added successfully', 'id': new_id})
        elif action == 'edit':
            note_id = body.get('id')
            note_text = body.get('note')
            if not note_id or not note_text:
                return build_response(400, {'error': 'ID and note text are required'})
            table.update_item(
                Key={'id': str(int(note_id))},
                UpdateExpression="SET #t = :text",
                ExpressionAttributeNames={'#t': 'text'},
                ExpressionAttributeValues={':text': note_text}
            )
            return build_response(200, {'message': 'Note updated successfully'})
        elif action == 'delete':
            note_id = body.get('id')
            if not note_id:
                return build_response(400, {'error': 'ID is required'})
            table.delete_item(Key={'id': str(int(note_id))})
            return build_response(200, {'message': 'Note deleted successfully'})
        else:
            return build_response(400, {'error': 'Invalid action'})
    except Exception as e:
        return build_response(500, {'error': str(e)})

def build_response(status, body):
    return {
        'statusCode': status,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(body)
    }
