import io
import pytest
from unittest.mock import patch
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_contact_get(client):
    response = client.get('/store-contactUs')
    assert response.status_code == 200
    assert b'contact' in response.data

@patch('requests.post')
def test_contact_post_success(mock_post, client):
    mock_post.side_effect = [
        type('Response', (), {'json': lambda: {'s3_path': 's3://bucket/image.jpg'}})(),
        type('Response', (), {'json': lambda: {'status': 'success'}})()
    ]
    data = {
        'name': 'John Doe',
        'email': 'john@example.com',
        'message': 'Hello!',
        'image': (io.BytesIO(b"fake image data"), 'test.jpg')
    }
    response = client.post('/store-contactUs', data=data, content_type='multipart/form-data')
    assert response.status_code == 200
    assert b'Your contact request has been sent!' in response.data

@patch('requests.post')
def test_notes_get(mock_post, client):
    mock_post.return_value.json = lambda: [{'id': '1', 'note': 'Test Note'}]
    mock_post.return_value.raise_for_status = lambda: None
    response = client.get('/note')
    assert response.status_code == 200
    assert b'notes' in response.data

@patch('requests.post')
def test_notes_add(mock_post, client):
    mock_post.side_effect = [
        type('Response', (), {'json': lambda: {'status': 'added'}, 'raise_for_status': lambda: None})(),
        type('Response', (), {'json': lambda: [{'id': '1', 'note': 'New Note'}], 'raise_for_status': lambda: None})()
    ]
    response = client.post('/note', data={'event': 'add', 'note': 'New Note'})
    assert response.status_code == 200
    assert b'Note added to DynamoDB!' in response.data
