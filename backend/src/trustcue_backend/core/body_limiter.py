"""Streaming ASGI middleware enforcing strict upper bounds on incoming request bodies."""

import uuid

from starlette.datastructures import Headers
from starlette.types import ASGIApp, Receive, Scope, Send

from trustcue_backend.core.errors import build_error_envelope


class RequestBodyLimitMiddleware:
    """
    Enforces a strict upper bound on incoming request body bytes during streaming.

    Aborts immediately with HTTP 413 if the payload exceeds max_bytes, preventing
    memory exhaustion or denial-of-service via unbounded body streaming.
    """

    def __init__(self, app: ASGIApp, max_bytes: int = 1_000_000) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = Headers(scope=scope)
        content_length_str = headers.get("content-length")

        if content_length_str is not None:
            try:
                content_length = int(content_length_str)
                if content_length > self.max_bytes:
                    req_id = str(uuid.uuid4())
                    response = build_error_envelope(
                        code="PAYLOAD_TOO_LARGE",
                        message=f"Request payload exceeds maximum allowed size of {self.max_bytes} bytes.",
                        request_id=req_id,
                        status_code=413,
                    )
                    await response(scope, receive, send)
                    return
            except ValueError:
                pass

        # Stream & accumulate up to max_bytes + 1 to detect streaming overflows
        body_chunks: list[bytes] = []
        received_bytes = 0
        has_more = True

        while has_more:
            message = await receive()
            if message["type"] != "http.request":
                # Handle client disconnect or unexpected message
                if message["type"] == "http.disconnect":
                    return
                break

            chunk = message.get("body", b"")
            received_bytes += len(chunk)

            if received_bytes > self.max_bytes:
                req_id = str(uuid.uuid4())
                response = build_error_envelope(
                    code="PAYLOAD_TOO_LARGE",
                    message=f"Request payload exceeds maximum allowed size of {self.max_bytes} bytes.",
                    request_id=req_id,
                    status_code=413,
                )
                await response(scope, receive, send)
                return

            body_chunks.append(chunk)
            has_more = message.get("more_body", False)

        full_body = b"".join(body_chunks)
        sent = False

        async def replay_receive() -> dict:
            nonlocal sent
            if not sent:
                sent = True
                return {"type": "http.request", "body": full_body, "more_body": False}
            return {"type": "http.disconnect"}

        await self.app(scope, replay_receive, send)
