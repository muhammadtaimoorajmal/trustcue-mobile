# Dockerfile for TrustCue Backend Service
FROM python:3.13-slim

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=8000 \
    ENVIRONMENT=production \
    DEBUG=false \
    DOCS_ENABLED=false

# Create unprivileged application user
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/sh -m appuser

WORKDIR /app

# Install runtime dependencies first for optimal Docker layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy source code and package metadata
COPY pyproject.toml README.md ./
COPY src/ ./src/
COPY contracts/ ./contracts/

# Install the package in non-editable mode without re-resolving dependencies
RUN pip install --no-cache-dir --no-deps .

# Switch to non-root user
USER appuser

EXPOSE 8000

# Container health check querying /health liveness probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; port = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health')" || exit 1

# Launch Uvicorn bound to 0.0.0.0 and dynamically assigned $PORT
CMD ["sh", "-c", "exec uvicorn trustcue_backend.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
