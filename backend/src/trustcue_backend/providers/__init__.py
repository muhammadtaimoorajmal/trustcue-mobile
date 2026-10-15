"""TrustCue backend AI provider integration package."""

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
from trustcue_backend.providers.groq import GroqProviderAdapter
from trustcue_backend.providers.models import (
    ProviderAnalysisRequest,
    ProviderAnalysisResult,
    RawAiFinding,
    RawEvidenceReference,
    RawSuggestedAction,
)
from trustcue_backend.providers.prompts import (
    SYSTEM_PROMPT,
    build_groq_messages,
    extract_untrusted_content_from_prompt,
)
from trustcue_backend.providers.service import ProtectedAiService

__all__ = [
    "AiProvider",
    "GroqProviderAdapter",
    "ProtectedAiService",
    "ProviderAnalysisRequest",
    "ProviderAnalysisResult",
    "RawAiFinding",
    "RawEvidenceReference",
    "RawSuggestedAction",
    "SYSTEM_PROMPT",
    "build_groq_messages",
    "extract_untrusted_content_from_prompt",
    "ProviderError",
    "ProviderConfigurationError",
    "ProviderAuthenticationError",
    "ProviderRateLimitError",
    "ProviderTimeoutError",
    "ProviderResponseError",
    "ProviderNetworkError",
]
