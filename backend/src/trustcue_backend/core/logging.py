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

from trustcue_backend.core.telemetry import (
    CORRELATION_ID_PATTERN,
    OutcomeCategory,
    current_correlation_id,
    record_stage_duration,
)

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
        if hasattr(record, "correlation_id"):
            log_entry["correlation_id"] = record.correlation_id
        elif current_correlation_id.get():
            log_entry["correlation_id"] = current_correlation_id.get()

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
    Middleware that validates or assigns a server-controlled correlation ID and records
    minimal, content-free operational telemetry using monotonic clock.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        start_time = time.perf_counter()

        # Validate incoming correlation ID or generate a fresh server-controlled UUID4
        incoming_id = request.headers.get("X-Correlation-ID") or request.headers.get("X-Request-ID")
        if incoming_id and CORRELATION_ID_PATTERN.match(incoming_id.strip()):
            correlation_id = incoming_id.strip()
        else:
            correlation_id = str(uuid.uuid4())

        token = current_correlation_id.set(correlation_id)
        request.state.correlation_id = correlation_id
        request.state.request_id = correlation_id

        response: Response | None = None
        status_code = 500

        try:
            response = await call_next(request)
            status_code = response.status_code
        finally:
            duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
            path_template = extract_route_template(request)

            # Map status code to bounded outcome category
            outcome: OutcomeCategory
            if status_code < 400:
                outcome = "success"
            elif status_code in (401, 403):
                outcome = "auth_error"
            elif status_code == 429:
                outcome = "rate_limited"
            elif 400 <= status_code < 500:
                outcome = "client_error"
            else:
                outcome = "internal_error"

            record_stage_duration(
                stage="request_total",
                duration_ms=duration_ms,
                outcome=outcome,
                extra_log_fields={"status_code": status_code},
            )

            # Minimal operational logging: strictly NO body, queries, tokens, or content hashes
            logger.info(
                "Request processed: method=%s path_template=%s status=%d duration_ms=%.2f",
                request.method,
                path_template,
                status_code,
                duration_ms,
                extra={
                    "request_id": correlation_id,
                    "correlation_id": correlation_id,
                },
            )
            current_correlation_id.reset(token)

        response.headers["X-Request-ID"] = correlation_id
        response.headers["X-Correlation-ID"] = correlation_id
        return response
