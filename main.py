from flask import Flask, request, jsonify
import json
import os
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Path to the configuration file
CONFIG_FILE = "config.json"

# Load database configuration from config.json
try:
    with open(CONFIG_FILE, "r") as config_file:
        config = json.load(config_file)
        DB_CONFIG = {
            "host": config.get("db_host"),
            "user": config.get("db_user"),
            "password": config.get("db_password"),
            "database": config.get("db_name"),
        }
except FileNotFoundError:
    print(f"Configuration file {CONFIG_FILE} not found.")
    exit(1)
except json.JSONDecodeError as e:
    print(f"Error parsing {CONFIG_FILE}: {e}")
    exit(1)

# Helper to create a database connection
def get_db_connection():
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        return connection
    except Error as e:
        print(f"Database connection error: {e}")
        return None

# Helper to initialize the database table
def initialize_database():
    connection = get_db_connection()
    if connection:
        cursor = connection.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS license_plates (
                id INT AUTO_INCREMENT PRIMARY KEY,
                plate VARCHAR(50) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        connection.commit()
        cursor.close()
        connection.close()

# Routes
@app.route("/add", methods=["POST"])
def add_license_plate():
    data = request.get_json()
    if not data or "plate" not in data:
        return jsonify({"message": "License plate cannot be empty."}), 400

    plate = data["plate"]
    connection = get_db_connection()
    if connection:
        cursor = connection.cursor()
        try:
            cursor.execute("INSERT INTO license_plates (plate) VALUES (%s)", (plate,))
            connection.commit()
            return jsonify({"message": "License plate added successfully!"}), 201
        except mysql.connector.IntegrityError:
            return jsonify({"message": "License plate already exists."}), 400
        finally:
            cursor.close()
            connection.close()
    return jsonify({"message": "Database connection failed."}), 500

@app.route("/check/<string:plate>", methods=["GET"])
def check_license_plate(plate):
    connection = get_db_connection()
    if connection:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM license_plates WHERE plate = %s", (plate,))
        result = cursor.fetchone()
        cursor.close()
        connection.close()
        if result:
            return jsonify({"message": f"License plate found: {plate}"}), 200
        return jsonify({"message": "License plate not found."}), 404
    return jsonify({"message": "Database connection failed."}), 500

@app.route("/list", methods=["GET"])
def list_license_plates():
    connection = get_db_connection()
    if connection:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM license_plates")
        result = cursor.fetchall()
        cursor.close()
        connection.close()
        return jsonify(result), 200
    return jsonify({"message": "Database connection failed."}), 500

# Run the app with HTTPS on port 8080
if __name__ == "__main__":
    initialize_database()  # Ensure database table is ready
    app.run(ssl_context=('certificate.pem', 'key.pem'), host='0.0.0.0', port=8080)
