from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import os

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Database Configuration using Environment Variables
DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME")

# Connect to the database
def get_db_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )

# Middleware to check API key
def require_api_key(func):
    def wrapper(*args, **kwargs):
        key = request.headers.get("X-API-KEY")
        if key != os.getenv("API_KEY"):
            return jsonify({"message": "Invalid or missing API key"}), 403
        return func(*args, **kwargs)
    wrapper.__name__ = func.__name__
    return wrapper

# Routes
@app.route("/add", methods=["POST"])
@require_api_key
def add_license_plate():
    data = request.get_json()
    if not data or "plate" not in data:
        return jsonify({"message": "License plate cannot be empty."}), 400

    plate = data["plate"]

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT plate FROM license_plates WHERE plate = %s", (plate,))
        if cursor.fetchone():
            return jsonify({"message": "License plate already exists."}), 400

        cursor.execute("INSERT INTO license_plates (plate) VALUES (%s)", (plate,))
        conn.commit()
        return jsonify({"message": "License plate added successfully!"}), 201
    finally:
        cursor.close()
        conn.close()

@app.route("/check/<string:plate>", methods=["GET"])
@require_api_key
def check_license_plate(plate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT plate FROM license_plates WHERE plate = %s", (plate,))
        result = cursor.fetchone()
        if result:
            return jsonify({"message": f"License plate found: {plate}"}), 200
        return jsonify({"message": "License plate not found."}), 404
    finally:
        cursor.close()
        conn.close()

@app.route("/list", methods=["GET"])
@require_api_key
def list_license_plates():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT plate FROM license_plates")
        result = cursor.fetchall()
        plates = [row[0] for row in result]
        return jsonify(plates), 200
    finally:
        cursor.close()
        conn.close()

# Run the app
if __name__ == "__main__":
    app.run(ssl_context=('certificate.pem', 'key.pem'), host='0.0.0.0', port=8080)
