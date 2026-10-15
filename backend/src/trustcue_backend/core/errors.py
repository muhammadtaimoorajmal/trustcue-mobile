"""Standardized, privacy-safe error envelopes and exception handlers."""

import logging
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("trustcue.errors")


class TrustCueError(Exception):
    """Base exception for application-level errors."""

    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details


def get_request_id(request: Request) -> str:
    """Extract or generate a validated server-controlled request ID."""
    req_id = getattr(request.state, "request_id", None)
    if not req_id or not isinstance(req_id, str):
        req_id = str(uuid.uuid4())
        request.state.request_id = req_id
    return req_id


def build_error_envelope(
    code: str,
    message: str,
    request_id: str,
    status_code: int,
    details: dict[str, Any] | None = None,
) -> JSONResponse:
    """Construct a standardized, privacy-safe JSON error response."""
    payload: dict[str, Any] = {
        "error": {
            "code": code,
            "message": message,
            "requestId": request_id,
            "timestamp": datetime.now(UTC).isoformat(),
        }
    }
    if details:
        payload["error"]["details"] = details

    return JSONResponse(
        status_code=status_code,
        content=payload,
        headers={"X-Request-ID": request_id},
    )


async def trustcue_error_handler(request: Request, exc: TrustCueError) -> JSONResponse:
    """Handle domain TrustCueError exceptions."""
    req_id = get_request_id(request)
    return build_error_envelope(
        code=exc.code,
        message=exc.message,
        request_id=req_id,
        status_code=exc.status_code,
        details=exc.details,
    )


async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """
    Handle request validation errors with strict privacy sanitation.

    Crucially: NEVER echoes submitted user input or sensitive field values.
    Only field locations, error types, and safe schema messages are returned.
    """
    req_id = get_request_id(request)
    sanitized_issues: list[dict[str, str]] = []

    for err in exc.errors():
        # Exclude the raw 'input' field which could contain user text or credentials
        loc_elements = [str(elem) for elem in err.get("loc", []) if elem != "body"]
        field_path = " -> ".join(loc_elements) if loc_elements else "payload"
        sanitized_issues.append(
            {
                "field": field_path,
                "issue": str(err.get("msg", "Invalid value")),
                "type": str(err.get("type", "validation_error")),
            }
        )

    return build_error_envelope(
        code="VALIDATION_ERROR",
        message="The submitted request payload failed schema validation.",
        request_id=req_id,
        status_code=422,
        details={"fields": sanitized_issues},
    )


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """Handle HTTP exceptions (such as 404 Not Found, 405 Method Not Allowed)."""
    req_id = get_request_id(request)

    if exc.status_code == status.HTTP_404_NOT_FOUND:
        # Avoid echoing arbitrary requested URLs or user query strings
        return build_error_envelope(
            code="NOT_FOUND",
            message="The requested endpoint does not exist.",
            request_id=req_id,
            status_code=status.HTTP_404_NOT_FOUND,
        )

    if exc.status_code == status.HTTP_405_METHOD_NOT_ALLOWED:
        return build_error_envelope(
            code="METHOD_NOT_ALLOWED",
            message="The HTTP method is not allowed for this endpoint.",
            request_id=req_id,
            status_code=status.HTTP_405_METHOD_NOT_ALLOWED,
        )

    # Generic HTTP exception code
    code = f"HTTP_{exc.status_code}"
    message = str(exc.detail) if exc.detail else "An HTTP error occurred."
    return build_error_envelope(
        code=code,
        message=message,
        request_id=req_id,
        status_code=exc.status_code,
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Catch-all handler for unexpected internal exceptions.

    Logs error details internally alongside the correlation request ID,
    but returns a strictly sanitized envelope without leaking stack traces or internal paths.
    """
    req_id = get_request_id(request)
    logger.exception("Unhandled server exception [request_id=%s]: %s", req_id, str(exc))

    return build_error_envelope(
        code="INTERNAL_ERROR",
        message="An unexpected internal server error occurred.",
        request_id=req_id,
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
    )
