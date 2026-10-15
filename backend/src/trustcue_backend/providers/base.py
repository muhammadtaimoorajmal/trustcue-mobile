"""Abstract interface for replaceable AI inference providers."""

from abc import ABC, abstractmethod

from trustcue_backend.providers.models import (
    ProviderAnalysisRequest,
    ProviderAnalysisResult,
)


class AiProvider(ABC):
    """Abstract base class for server-side AI scam indicator analysis providers."""

    @abstractmethod
    async def analyze(self, request: ProviderAnalysisRequest) -> ProviderAnalysisResult:
        """
        Submit untrusted reviewed text to the AI provider and return structured findings.

        Must raise typed ProviderError subclasses on failures without leaking sensitive
        text, prompts, or API credentials.
        """
        pass

    @abstractmethod
    async def close(self) -> None:
        """Gracefully release HTTP clients and background network connections."""
        pass
