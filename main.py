from flask import Flask, request, jsonify
import mysql.connector
import os
from flask_cors import CORS

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Load API key from environment variable
API_KEY = os.getenv("API_KEY")

# Database connection settings (from environment variables)
DB_HOST = os.getenv("DATABASE_ENDPOINT")
DB_USER = os.getenv("DATABASE_USER")
DB_PASSWORD = os.getenv("DATABASE_PASSWORD")
DB_NAME = os.getenv("DATABASE_NAME")

# Middleware to check API key
def require_api_key(func):
    def wrapper(*args, **kwargs):
        key = request.headers.get("X-API-KEY")
        if key != API_KEY:
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
        conn = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        cursor = conn.cursor()
        # Check if plate already exists
        cursor.execute("SELECT COUNT(*) FROM license_plates WHERE plate = %s", (plate,))
        exists = cursor.fetchone()[0]

        if exists:
            return jsonify({"message": "License plate already exists."}), 400

        # Insert new plate
        cursor.execute("INSERT INTO license_plates (plate) VALUES (%s)", (plate,))
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"message": "License plate added successfully!"}), 201
    except mysql.connector.Error as err:
        return jsonify({"message": f"Database error: {str(err)}"}), 500

@app.route("/check/<string:plate>", methods=["GET"])
@require_api_key
def check_license_plate(plate):
    try:
        conn = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        cursor = conn.cursor()
        # Check if plate exists
        cursor.execute("SELECT COUNT(*) FROM license_plates WHERE plate = %s", (plate,))
        exists = cursor.fetchone()[0]
        cursor.close()
        conn.close()

        if exists:
            return jsonify({"message": f"License plate found: {plate}"}), 200
        return jsonify({"message": "License plate not found."}), 404
    except mysql.connector.Error as err:
        return jsonify({"message": f"Database error: {str(err)}"}), 500

@app.route("/list", methods=["GET"])
@require_api_key
def list_license_plates():
    try:
        conn = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        cursor = conn.cursor(dictionary=True)
        # Fetch all plates
        cursor.execute("SELECT * FROM license_plates")
        license_plates = cursor.fetchall()
        cursor.close()
        conn.close()

        return jsonify(license_plates), 200
    except mysql.connector.Error as err:
        return jsonify({"message": f"Database error: {str(err)}"}), 500

# Run the app with HTTPS on port 8080
if __name__ == "__main__":
    app.run(ssl_context=('certificate.pem', 'key.pem'), host='0.0.0.0', port=8080)
