# Root Dockerfile for TrustCue Backend Repository
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=8000 \
    ENVIRONMENT=production \
    DEBUG=false \
    DOCS_ENABLED=false

RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/sh -m appuser

WORKDIR /app

COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY backend/pyproject.toml backend/README.md ./
COPY backend/src/ ./src/
COPY backend/contracts/ ./contracts/

RUN pip install --no-cache-dir --no-deps .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; port = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health')" || exit 1

CMD ["sh", "-c", "exec uvicorn trustcue_backend.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
