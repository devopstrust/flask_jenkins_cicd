from flask import Flask, jsonify

app = Flask(__name__)

secret = "AKIA1234567890ABCDEF"  # 20 символів, відповідає
secret = "AKIA3234567890ABCDEF"  # 20 символів, відповідає
SECRET_KEY='AKIA1234567890ABCDEF'

@app.route('/api', methods=['GET'])
def get_status():
    return jsonify({'status': 'OK', 'message': 'Hello from Warsaw!'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=False)