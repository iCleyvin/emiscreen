FROM python:3.11-slim

LABEL maintainer="iCleyvin"
LABEL description="Emiscreen - Remote Display via WebRTC"

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    xdotool \
    x11-utils \
    xvfb \
    adb \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Generate SSL certificates
RUN mkdir -p certs && \
    openssl req -new -x509 -keyout certs/key.pem -out certs/cert.pem \
    -days 3650 -nodes -subj "/CN=emiscreen.local" \
    -addext "subjectAltName=DNS:emiscreen.local,DNS:localhost,IP:127.0.0.1"

# Expose ports
EXPOSE 8443

# Default command
CMD ["python", "-m", "emiscreen.server", "--source", "ubuntu-desktop"]
