"""Groq Cloud API provider adapter implementing protected scam indicator inference."""

import json
import logging
import time

import httpx

from trustcue_backend.api.schemas.analysis import FindingSeverity, IndicatorCategory
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
    RawAiFinding,
    RawEvidenceReference,
    RawSuggestedAction,
)
from trustcue_backend.providers.prompts import build_groq_messages

logger = logging.getLogger("trustcue.providers.groq")


class GroqProviderAdapter(AiProvider):
    """
    Adapter communicating with Groq Cloud API via OpenAI-compatible Chat Completions.

    Invariants:
    1. Provider credentials stay exclusively on backend.
    2. Endpoint is strictly controlled via backend configuration, never user input.
    3. Untrusted reviewed text is enclosed in XML tags without alteration.
    4. HTTP client lifecycle is explicitly managed.
    5. Response size and execution time are bounded.
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
        Execute protected analysis request against Groq Cloud API.

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
            response = await self._client.post(url, json=payload, headers=headers)
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

        # Handle HTTP status codes
        if response.status_code in (401, 403):
            logger.error("Groq authentication failed (HTTP %d) for requestId: %s", response.status_code, request.request_id)
            raise ProviderAuthenticationError()

        if response.status_code == 429:
            retry_after_hdr = response.headers.get("Retry-After")
            retry_after = int(retry_after_hdr) if retry_after_hdr and retry_after_hdr.isdigit() else None
            logger.warning("Groq upstream rate limit encountered for requestId: %s", request.request_id)
            raise ProviderRateLimitError(retry_after=retry_after)

        if response.status_code >= 500:
            logger.error("Groq server error (HTTP %d) for requestId: %s", response.status_code, request.request_id)
            raise ProviderError(
                code="ai_provider_unavailable",
                message="Upstream AI provider returned a server error.",
                status_code=503,
            )

        if response.status_code != 200:
            logger.error("Groq unexpected HTTP %d for requestId: %s", response.status_code, request.request_id)
            raise ProviderError(
                code="ai_provider_unavailable",
                message=f"AI provider returned unexpected status {response.status_code}.",
                status_code=503,
            )

        # Enforce maximum response boundary
        content_bytes = response.content
        if len(content_bytes) > self.max_response_bytes:
            logger.warning("Groq response exceeded boundary (%d bytes) for requestId: %s", len(content_bytes), request.request_id)
            raise ProviderResponseError(
                f"AI provider response exceeded maximum boundary ({len(content_bytes)} bytes > {self.max_response_bytes})."
            )

        # Parse wrapper envelope
        try:
            envelope = response.json()
        except Exception as exc:
            logger.warning("Groq response JSON parse failed for requestId: %s", request.request_id)
            raise ProviderResponseError("AI provider returned invalid JSON envelope.") from exc

        choices = envelope.get("choices")
        if not choices or not isinstance(choices, list) or len(choices) == 0:
            raise ProviderResponseError("AI provider returned empty choices list.")

        message_obj = choices[0].get("message")
        if not message_obj or not isinstance(message_obj, dict):
            raise ProviderResponseError("AI provider returned invalid message object.")

        content_str = message_obj.get("content")
        if not content_str or not isinstance(content_str, str) or not content_str.strip():
            raise ProviderResponseError("AI provider returned empty completion content.")

        # Parse inner JSON content
        try:
            content_json = json.loads(content_str)
        except Exception as exc:
            logger.warning("Groq inner content JSON parse failed for requestId: %s", request.request_id)
            raise ProviderResponseError("AI provider completion content is not valid JSON.") from exc

        if not isinstance(content_json, dict):
            raise ProviderResponseError("AI provider completion JSON root is not an object.")

        usage = envelope.get("usage")
        raw_usage = usage if isinstance(usage, dict) else None

        result = self._parse_structured_result(content_json, raw_usage)

        logger.info(
            "Groq inference succeeded in %d ms for requestId: %s (findings: %d)",
            elapsed_ms,
            request.request_id,
            len(result.findings),
        )
        return result

    def _parse_structured_result(
        self,
        data: dict,
        raw_usage: dict | None,
    ) -> ProviderAnalysisResult:
        """
        Convert raw parsed JSON into validated ProviderAnalysisResult.

        Supports both camelCase and snake_case properties gracefully.
        """
        factual_summary = data.get("factualSummary") or data.get("factual_summary") or ""
        if not isinstance(factual_summary, str) or not factual_summary.strip():
            factual_summary = "AI analysis completed evaluation of the submitted text."

        findings: list[RawAiFinding] = []
        raw_findings = data.get("findings")
        if isinstance(raw_findings, list):
            for idx, item in enumerate(raw_findings):
                if not isinstance(item, dict):
                    continue
                finding = self._parse_raw_finding(item, default_id=f"ai-finding-{idx + 1}")
                if finding is not None:
                    findings.append(finding)

        uncertainty_notes: list[str] = []
        raw_notes = data.get("uncertaintyNotes") or data.get("uncertainty_notes")
        if isinstance(raw_notes, list):
            for note in raw_notes:
                if isinstance(note, str) and note.strip():
                    uncertainty_notes.append(note.strip())

        suggested_actions: list[RawSuggestedAction] = []
        raw_actions = data.get("suggestedActions") or data.get("suggested_actions")
        if isinstance(raw_actions, list):
            for idx, action_item in enumerate(raw_actions):
                if not isinstance(action_item, dict):
                    continue
                action = self._parse_raw_action(action_item, default_id=f"action-{idx + 1}")
                if action is not None:
                    suggested_actions.append(action)

        return ProviderAnalysisResult(
            provider="groq-cloud",
            model=self.model,
            factual_summary=factual_summary[:512],
            findings=findings,
            uncertainty_notes=uncertainty_notes,
            suggested_actions=suggested_actions,
            raw_usage=raw_usage,
        )

    def _parse_raw_finding(self, item: dict, default_id: str) -> RawAiFinding | None:
        """Parse and validate a single finding item against the 10 indicator categories."""
        raw_cat = str(item.get("category", "")).strip()
        try:
            category = IndicatorCategory(raw_cat)
        except ValueError:
            # Drop invalid category finding
            return None

        raw_sev = str(item.get("severity", "informational")).strip().lower()
        try:
            severity = FindingSeverity(raw_sev)
        except ValueError:
            severity = FindingSeverity.informational

        finding_id = str(item.get("id") or default_id).strip()
        title = str(item.get("title") or "Potential scam indicator observed").strip()[:128]
        explanation = str(item.get("explanation") or "Pattern warrants independent verification.").strip()[:1024]

        evidence_refs: list[RawEvidenceReference] = []
        raw_refs = item.get("evidenceReferences") or item.get("evidence_references") or []
        if isinstance(raw_refs, list):
            for ref_item in raw_refs:
                if isinstance(ref_item, dict):
                    excerpt = str(ref_item.get("excerpt") or "").strip()
                    if excerpt:
                        start_offset = ref_item.get("startOffset") or ref_item.get("start_offset")
                        end_offset = ref_item.get("endOffset") or ref_item.get("end_offset")
                        evidence_refs.append(
                            RawEvidenceReference(
                                excerpt=excerpt,
                                start_offset=int(start_offset) if isinstance(start_offset, (int, float)) else None,
                                end_offset=int(end_offset) if isinstance(end_offset, (int, float)) else None,
                            )
                        )

        return RawAiFinding(
            id=finding_id,
            category=category,
            severity=severity,
            title=title,
            explanation=explanation,
            evidence_references=evidence_refs,
        )

    def _parse_raw_action(self, item: dict, default_id: str) -> RawSuggestedAction | None:
        """Parse a suggested action item."""
        action_id = str(item.get("id") or default_id).strip()
        priority = str(item.get("priority") or "recommended").strip().lower()
        if priority not in ("immediate", "recommended", "conditional"):
            priority = "recommended"

        title = str(item.get("title") or "Verify independently").strip()[:128]
        detail = str(item.get("detail") or "Check official account channels directly.").strip()[:512]

        return RawSuggestedAction(
            id=action_id,
            priority=priority,
            title=title,
            detail=detail,
        )

    async def close(self) -> None:
        """Close the underlying HTTP client if owned by this adapter."""
        if self._owns_client and hasattr(self, "_client"):
            await self._client.aclose()
