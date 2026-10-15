"""Privacy-safe exceptions for external AI provider interactions."""

from trustcue_backend.core.errors import TrustCueError


class ProviderError(TrustCueError):
    """Base exception for all AI provider interaction errors."""

    def __init__(
        self,
        code: str = "ai_provider_unavailable",
        message: str = "Remote AI analysis is temporarily unavailable.",
        status_code: int = 503,
        details: dict | None = None,
    ) -> None:
        super().__init__(code=code, message=message, status_code=status_code, details=details)


class ProviderConfigurationError(ProviderError):
    """Raised when an AI provider is requested but not configured or enabled."""

    def __init__(self, message: str = "AI provider is not configured or disabled.") -> None:
        super().__init__(
            code="ai_provider_unavailable",
            message=message,
            status_code=503,
        )


class ProviderAuthenticationError(ProviderError):
    """Raised when provider rejects authentication (401/403). Never leaks API key."""

    def __init__(self) -> None:
        super().__init__(
            code="ai_provider_unavailable",
            message="Remote AI provider authentication failed on backend.",
            status_code=503,
        )


class ProviderRateLimitError(ProviderError):
    """Raised when the upstream AI provider returns HTTP 429."""

    def __init__(self, retry_after: int | None = None) -> None:
        details = {"retryAfterSeconds": retry_after} if retry_after else None
        super().__init__(
            code="rate_limit_exceeded",
            message="AI provider capacity limit exceeded. Please retry shortly.",
            status_code=429,
            details=details,
        )


class ProviderTimeoutError(ProviderError):
    """
    Raised when connection or read operation to the provider times out.

    is_connect_timeout indicates whether failure occurred before data transmission.
    """

    def __init__(self, is_connect_timeout: bool = False) -> None:
        self.is_connect_timeout = is_connect_timeout
        super().__init__(
            code="ai_provider_unavailable",
            message="AI provider request timed out. Local analysis remains active.",
            status_code=503,
            details={"isConnectTimeout": is_connect_timeout},
        )


class ProviderResponseError(ProviderError):
    """Raised when provider returns malformed JSON, invalid schema, or oversized payload."""

    def __init__(self, message: str = "AI provider returned an unparseable response.") -> None:
        super().__init__(
            code="ai_provider_unavailable",
            message=message,
            status_code=502,
        )


class ProviderNetworkError(ProviderError):
    """Raised on connection drop, DNS failure, or TLS negotiation failure."""

    def __init__(self, message: str = "Network communication with AI provider failed.") -> None:
        super().__init__(
            code="ai_provider_unavailable",
            message=message,
            status_code=503,
        )
