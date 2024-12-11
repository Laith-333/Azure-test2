# Use an official Python image
FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Copy requirements file first to cache dependencies
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy all project files into the container
COPY . /app

# Expose the port Flask will use
EXPOSE 8080

# Command to run the Flask application
CMD ["python", "secure_api.py"]
