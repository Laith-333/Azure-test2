# Use an official Python image
FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Copy only necessary files first to leverage Docker layer caching
COPY requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the project files into the container
COPY . /app

# Expose the port Flask will use
EXPOSE 8080

# Set environment variables for Flask (optional)
ENV FLASK_APP=secure_api.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=8080

# Command to run the Flask application
CMD ["flask", "run", "--cert=certificate.pem", "--key=key.pem"]
