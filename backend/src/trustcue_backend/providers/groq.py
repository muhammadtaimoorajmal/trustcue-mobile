"""Groq Cloud API provider adapter implementing protected scam indicator inference."""

import asyncio
import json
import logging
import time

import httpx

from trustcue_backend.core.config import Settings
from trustcue_backend.providers.base import AiProvider
from trustcue_backend.providers.exceptions import (
    ProviderAuthenticationError,
    ProviderConfigurationError,
    ProviderError,
    ProviderNetworkError,
    ProviderRateLimitError,
    ProviderResponseError,
    ProviderTimeoutError,
)
from trustcue_backend.providers.models import (
    ProviderAnalysisRequest,
    ProviderAnalysisResult,
)
from trustcue_backend.providers.prompts import build_groq_messages
from trustcue_backend.validation.output_validator import OutputValidator

logger = logging.getLogger("trustcue.providers.groq")


class GroqProviderAdapter(AiProvider):
    """
    Adapter communicating with Groq Cloud API via OpenAI-compatible Chat Completions.

    Invariants:
    1. Provider credentials stay exclusively on backend.
    2. Endpoint is strictly controlled via backend configuration, never user input.
    3. Untrusted reviewed text is enclosed in XML tags without alteration.
    4. HTTP client lifecycle is explicitly managed with stream chunk-bounding.
    5. Response size and overall execution deadline are strictly bounded.
    6. Raw prompt text and response bodies are never logged.
    """

    def __init__(
        self,
        settings: Settings,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.api_key = settings.GROQ_API_KEY
        self.model = settings.GROQ_MODEL
        self.base_url = settings.GROQ_BASE_URL.rstrip("/")
        self.timeout_seconds = settings.GROQ_TIMEOUT_SECONDS
        self.max_tokens = settings.GROQ_MAX_TOKENS
        self.max_response_bytes = settings.MAX_PROVIDER_RESPONSE_BYTES

        self._owns_client = http_client is None
        if http_client is not None:
            self._client = http_client
        else:
            timeout = httpx.Timeout(
                self.timeout_seconds,
                connect=5.0,
                read=self.timeout_seconds,
                write=5.0,
                pool=5.0,
            )
            self._client = httpx.AsyncClient(timeout=timeout)

    async def analyze(self, request: ProviderAnalysisRequest) -> ProviderAnalysisResult:
        """
        Execute protected analysis request against Groq Cloud API with streaming bounds.

        Raises typed ProviderError on any failure without leaking credentials or text.
        """
        if not self.api_key or not self.api_key.strip():
            raise ProviderConfigurationError("GROQ_API_KEY is not configured on the backend.")

        url = f"{self.base_url}/chat/completions"
        messages = build_groq_messages(request.text)

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.0,
            "max_completion_tokens": self.max_tokens,
            "response_format": {"type": "json_object"},
        }

        headers = {
            "Authorization": f"Bearer {self.api_key.strip()}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "TrustCue-Backend/1.0",
        }

        start_time = time.monotonic()
        try:
            async with asyncio.timeout(self.timeout_seconds):
                async with self._client.stream("POST", url, json=payload, headers=headers) as response:
                    # Handle HTTP status codes
                    if response.status_code in (401, 403):
                        logger.error(
                            "Groq authentication failed (HTTP %d) for requestId: %s",
                            response.status_code,
                            request.request_id,
                        )
                        raise ProviderAuthenticationError()

                    if response.status_code == 429:
                        retry_after_hdr = response.headers.get("Retry-After")
                        retry_after = (
                            int(retry_after_hdr) if retry_after_hdr and retry_after_hdr.isdigit() else None
                        )
                        logger.warning(
                            "Groq upstream rate limit encountered for requestId: %s",
                            request.request_id,
                        )
                        raise ProviderRateLimitError(retry_after=retry_after)

                    if response.status_code >= 500:
                        logger.error(
                            "Groq server error (HTTP %d) for requestId: %s",
                            response.status_code,
                            request.request_id,
                        )
                        raise ProviderError(
                            code="ai_provider_unavailable",
                            message="Upstream AI provider returned a server error.",
                            status_code=503,
                        )

                    if response.status_code != 200:
                        logger.error(
                            "Groq unexpected HTTP %d for requestId: %s",
                            response.status_code,
                            request.request_id,
                        )
                        raise ProviderError(
                            code="ai_provider_unavailable",
                            message=f"AI provider returned unexpected status {response.status_code}.",
                            status_code=503,
                        )

                    # Incremental streaming accumulation with strict byte boundary enforcement
                    body_chunks: list[bytes] = []
                    total_bytes = 0
                    async for chunk in response.aiter_bytes():
                        total_bytes += len(chunk)
                        if total_bytes > self.max_response_bytes:
                            logger.warning(
                                "Groq response exceeded boundary (%d bytes > %d) for requestId: %s",
                                total_bytes,
                                self.max_response_bytes,
                                request.request_id,
                            )
                            raise ProviderResponseError(
                                f"AI provider response exceeded maximum boundary ({self.max_response_bytes} bytes)."
                            )
                        body_chunks.append(chunk)

                    content_bytes = b"".join(body_chunks)

        except TimeoutError as exc:
            logger.warning("Groq overall operation deadline reached for requestId: %s", request.request_id)
            raise ProviderTimeoutError(is_connect_timeout=False) from exc
        except httpx.ConnectTimeout as exc:
            logger.warning("Groq connection timeout for requestId: %s", request.request_id)
            raise ProviderTimeoutError(is_connect_timeout=True) from exc
        except httpx.ReadTimeout as exc:
            logger.warning("Groq read timeout for requestId: %s", request.request_id)
            raise ProviderTimeoutError(is_connect_timeout=False) from exc
        except (httpx.ConnectError, httpx.NetworkError) as exc:
            logger.warning("Groq network connection error for requestId: %s", request.request_id)
            raise ProviderNetworkError("Network communication with Groq API failed.") from exc
        except httpx.RequestError as exc:
            logger.warning("Groq request error for requestId: %s", request.request_id)
            raise ProviderNetworkError("Failed to dispatch request to Groq API.") from exc

        elapsed_ms = int((time.monotonic() - start_time) * 1000)

        # Parse wrapper envelope
        try:
            envelope = json.loads(content_bytes.decode("utf-8"))
        except Exception as exc:
            logger.warning("Groq response JSON parse failed for requestId: %s", request.request_id)
            raise ProviderResponseError("AI provider returned invalid JSON envelope.") from exc

        choices = envelope.get("choices")
        if not choices or not isinstance(choices, list) or len(choices) == 0:
            raise ProviderResponseError("AI provider returned empty choices list.")

        first_choice = choices[0]
        finish_reason = first_choice.get("finish_reason")
        if finish_reason == "length":
            logger.warning("Groq completion truncated due to token limit for requestId: %s", request.request_id)
            raise ProviderResponseError("AI provider completion was truncated due to token limit.")

        message_obj = first_choice.get("message")
        if not message_obj or not isinstance(message_obj, dict):
            raise ProviderResponseError("AI provider returned invalid message object.")

        if message_obj.get("refusal"):
            raise ProviderResponseError(f"AI provider refused request: {message_obj['refusal']}")

        content_str = message_obj.get("content")
        if not content_str or not isinstance(content_str, str) or not content_str.strip():
            raise ProviderResponseError("AI provider returned empty completion content.")

        # Delegate strict parsing and validation of structured completion content
        try:
            validated_output = OutputValidator.parse_and_validate(content_str)
        except Exception as exc:
            logger.warning("Groq structured output validation failed for requestId: %s: %s", request.request_id, exc)
            if isinstance(exc, ProviderError):
                raise
            raise ProviderResponseError(f"AI provider output failed validation: {exc}") from exc

        usage = envelope.get("usage")
        raw_usage = usage if isinstance(usage, dict) else None

        result = ProviderAnalysisResult(
            provider="groq-cloud",
            model=self.model,
            factual_summary=validated_output.factual_summary,
            findings=validated_output.findings,
            uncertainty_notes=validated_output.uncertainty_notes,
            suggested_actions=validated_output.suggested_actions,
            raw_usage=raw_usage,
        )

        logger.info(
            "Groq inference succeeded in %d ms for requestId: %s (findings: %d)",
            elapsed_ms,
            request.request_id,
            len(result.findings),
        )
        return result

    async def close(self) -> None:
        """Close the underlying HTTP client if owned by this adapter."""
        if self._owns_client and hasattr(self, "_client"):
            await self._client.aclose()
