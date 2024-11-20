import os
from flask import Flask, jsonify

app = Flask(__name__)
data_file = '/app/data/storage_data.txt'

@app.route('/')
def home():
    if not os.path.exists(data_file):
        with open(data_file, 'w') as file:
            file.write('Welcome to Azure Storage!\n')
    with open(data_file, 'r') as file:
        content = file.read()
    return f'<pre>{content}</pre>'

@app.route('/write/<data>')
def write(data):
    with open(data_file, 'a') as file:
        file.write(f'{data}\n')
    return jsonify({"message": "Data written to storage!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
