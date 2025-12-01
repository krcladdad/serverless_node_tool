from flask import Flask, render_template, request
import boto3
import time
import os
from dotenv import load_dotenv
import json
import requests
import logging
import base64
# from secrets_manager import get_secret

# Load .env file
load_dotenv()

app = Flask(__name__)


def get_secret(secret_name, region_name):
    client = boto3.client('secretsmanager', region_name=region_name)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])


# AWS Configuration
secret = get_secret('my-app-secrets', region_name='us-east-1')

app.secret_key = secret['FLASK_SECRET_KEY']


AWS_REGION = secret.get('region', 'us-east-1')
AWS_ACCESS_KEY = secret['AWS_ACCESS_KEY']
AWS_SECRET_KEY = secret['AWS_SECURITY_ACCESS_KEY']
API_BASE = secret['API_BASE']
API_BASE_IMAGE = secret['API_BASE_IMAGE']
API_BASE_CONTACT = secret['API_BASE_CONTACT']

print(f"AWS Region: {AWS_REGION}")  # For debugging

S3_BUCKET = secret['AWS_S3_BUCKET']
DYNAMO_TABLE_NOTES =secret['AWS_DYNAMO_TABLE_NOTES']
DYNAMO_TABLE_CONTACTUS =secret['AWS_DYNAMO_TABLE_CONTACTUS']

 #Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
notes_table = dynamodb.Table(DYNAMO_TABLE_NOTES)
contactus_table = dynamodb.Table(DYNAMO_TABLE_CONTACTUS)
s3 = boto3.client('s3', region_name=AWS_REGION)

@app.route('/')
def home():
    active_tab = 'home'
    return render_template('index.html', active_tab=active_tab)

@app.route('/contact',methods=['GET','POST'])
def contact():
    active_tab = 'contact'
    toasters = []
    toasters_display = False
    
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        email = request.form.get('email', '').strip()
        message = request.form.get('message', '').strip()
        image_file = request.files.get('image')

        if name and email and message and image_file:
            # Convert image to Base64
            image_bytes = image_file.read()
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')

            # Call Lambda 1 via API Gateway to upload image to S3
            upload_response = requests.post(
                f"{API_BASE_IMAGE}/upload-image",                
                json={
                        'file': image_base64,  # ✅ match Lambda expectation
                        'filename': image_file.filename,  # ✅ original name
                        'content_type': image_file.content_type  # ✅ MIME type
                    }                    
            )
            upload_data = upload_response.json()
            s3_path = upload_data.get('s3_path')
            app.logger.debug('file upload in s3 bucket response: %s', upload_data)
            # Call Lambda 2 to store metadata in DynamoDB
            metadata_response = requests.post(
                f"{API_BASE_CONTACT}/store-contactUs",
                json={
                    'id': str(int(time.time())),
                    'name': name,
                    'email': email,
                    'message': message,
                    's3_path': s3_path
                }
            )
            app.logger.debug('contact us page response: %s', metadata_response)
            toasters.append({'type': 'success', 'message': 'Your contact request has been sent!'})
            toasters_display = True
        else:
            toasters.append({'type':'danger','message':'All fields are required!'})
            toasters_display = True
   
    return render_template('contact.html', active_tab=active_tab,toasters=toasters,toasters_display=toasters_display)

@app.route('/notes',methods=['GET','POST'])
def notes():
    active_tab = 'notes'
    # helper to fetch current notes from the upstream API
    
    
    def fetch_notes():
        r = requests.post(
            f"{API_BASE}/note",
            json={'action': 'get_all'},
            timeout=5
        )
        r.raise_for_status()
        data = r.json()  # Could be dict or list

        # If API Gateway response is dict with 'body'
        if isinstance(data, dict) and 'body' in data:
            body = data['body']
            notes = json.loads(body or '[]') if isinstance(body, str) else body
        elif isinstance(data, list):
            # Lambda returned raw list
            notes = data
        else:
            notes = []

        return notes

    app.logger.debug('before notes Fetching initial notes from API...')
    notes = fetch_notes()
    app.logger.debug('initial notes: %s', notes)
    toasters = []
    toasters_display = False
    if request.method == 'POST':
        event = request.form.get('event', '')
        if event =='add':            
            text = request.form.get('note', '').strip()
            if text:
                response = requests.post(f"{API_BASE}/note", json={'action':'add','note': text})
                print(response.json())

            # text = request.form.get('note', '').strip()
            # if text:                
            #     new_id = int(time.time())
            #     notes_table.put_item(Item={'id': new_id, 'text': text})
                toasters.append({'type': 'success', 'message': 'Note added to DynamoDB!'})
                toasters_display = True
                # re-fetch so UI shows the added item
                notes = fetch_notes()

        elif event == 'edit':
            
            edit_id = request.form.get('edit_id', '')
            text = request.form.get('note', '').strip()
          
            try:
                response = requests.post(f"{API_BASE}/note", json={'action':'edit','id': edit_id, 'note': text}, timeout=6)
                response.raise_for_status()
                app.logger.debug('edit response: %s', response.text)
            except Exception:
                app.logger.exception('Failed to post edit to API')

            # if edit_id and text:
            #     notes_table.update_item(
            #         Key={'id': int(edit_id)},
            #         UpdateExpression="SET #t = :text",
            #         ExpressionAttributeNames={'#t': 'text'},
            #         ExpressionAttributeValues={':text': text}
            #     )
            toasters.append({'type': 'success', 'message': 'Note updated in DynamoDB!'})
            toasters_display = True
            # refresh notes after edit
            notes = fetch_notes()
        elif event == 'delete':
            del_id = request.form.get('del_id', '')
            try:
                response = requests.post(f"{API_BASE}/note", json={'action':'delete','id': del_id}, timeout=6)
                response.raise_for_status()
                app.logger.debug('delete response: %s', response.text)
            except Exception:
                app.logger.exception('Failed to post delete to API')

            # if del_id:
            #     notes_table.delete_item(Key={'id': int(del_id)})
            toasters.append({'type': 'success', 'message': 'Note deleted from DynamoDB!'})
            toasters_display = True
            # refresh notes after delete
            notes = fetch_notes()
        else:
            toasters.append({'type':'danger','message':'Invalid action!'})
            toasters_display = True
    else:
        toasters = []
        toasters_display = False 
    return render_template('notes.html', active_tab=active_tab, notes=notes,toasters=toasters,toasters_display=toasters_display)


if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)
