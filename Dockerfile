# Use Python slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the port
EXPOSE 5000

# Start with Gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "main:app"]
