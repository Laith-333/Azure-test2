# Use an official Python image
FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Copy all project files into the container
COPY . /app

# Install necessary Python dependencies
RUN pip install --no-cache-dir flask flask-cors mysql-connector-python

# Expose the port Flask will use
EXPOSE 8080

# Command to run the Flask application
CMD ["python", "secure_api.py"]
