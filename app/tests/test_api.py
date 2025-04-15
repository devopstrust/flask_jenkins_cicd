import requests

def test_api_status():
    response = requests.get('http://localhost:5000/api')
    assert response.status_code == 200
    assert response.json()['status'] == 'OK'