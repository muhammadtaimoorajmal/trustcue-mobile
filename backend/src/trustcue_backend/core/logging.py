"""Privacy-safe structured logging and correlation ID middleware."""

import json
import logging
import sys
import time
import uuid
from typing import Any

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response
from starlette.routing import Match

logger = logging.getLogger("trustcue.access")


class StructuredJsonFormatter(logging.Formatter):
    """Formats log records as minimal structured JSON without sensitive metadata."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry: dict[str, Any] = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "request_id"):
            log_entry["request_id"] = record.request_id
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)


def configure_logging(level: str = "INFO") -> None:
    """Configure system loggers with privacy-safe formatting."""
    log_level = getattr(logging, level.upper(), logging.INFO)

    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)

    # Only replace standard stdout StreamHandlers, preserving test log capture handlers
    for h in list(root_logger.handlers):
        if type(h) is logging.StreamHandler:
            root_logger.removeHandler(h)

    handler = logging.StreamHandler(sys.stdout)
    formatter = StructuredJsonFormatter(datefmt="%Y-%m-%dT%H:%M:%SZ")
    handler.setFormatter(formatter)
    root_logger.addHandler(handler)

    # Disable default Uvicorn access logger to prevent raw query strings leaking
    uvicorn_access = logging.getLogger("uvicorn.access")
    uvicorn_access.handlers.clear()
    uvicorn_access.propagate = False

    # Quiet HTTP client logger so test clients do not log full query URLs
    logging.getLogger("httpx").setLevel(logging.WARNING)


def extract_route_template(request: Request) -> str:
    """
    Extract matching route template or return safe placeholder for unknown routes.

    Prevents user-controlled query strings and arbitrary probe paths from entering logs.
    """
    app = request.app
    if hasattr(app, "router"):
        for route in app.router.routes:
            match, _ = route.matches(request.scope)
            if match == Match.FULL and hasattr(route, "path"):
                return str(route.path)

    # For unknown/unmatched routes, return a fixed placeholder to avoid echoing arbitrary input
    return "<unmatched_route>"


class PrivacySafeAccessMiddleware(BaseHTTPMiddleware):
    """
    Middleware that assigns a random server-generated request ID and records
    minimal, content-free operational telemetry.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        start_time = time.perf_counter()

        # Always generate a fresh, server-controlled random UUID4
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id

        response: Response | None = None
        status_code = 500

        try:
            response = await call_next(request)
            status_code = response.status_code
        finally:
            duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
            path_template = extract_route_template(request)

            # Minimal operational logging: strictly NO body, queries, tokens, or content hashes
            logger.info(
                "Request processed: method=%s path_template=%s status=%d duration_ms=%.2f",
                request.method,
                path_template,
                status_code,
                duration_ms,
                extra={"request_id": request_id},
            )

        response.headers["X-Request-ID"] = request_id
        return response
