"""Tests for application configuration, validation, and zero-credential defaults."""

import pytest
from pydantic import ValidationError

from trustcue_backend.core.config import Settings


def test_default_settings_requires_no_cloud_credentials() -> None:
    """Ensure default settings construct successfully without any cloud keys."""
    settings = Settings()

    assert settings.ENVIRONMENT in ("development", "test")
    assert settings.HOST == "127.0.0.1"
    assert settings.PORT == 8000
    assert settings.DEBUG is False
    assert settings.DOCS_ENABLED is True

    # Cloud features must default to disabled
    assert settings.ENABLE_CLOUD_AI is False
    assert settings.ENABLE_CLOUD_AUTH is False
    assert settings.ENABLE_CLOUD_SYNC is False

    # Credentials must be absent/None
    assert settings.SUPABASE_URL is None
    assert settings.SUPABASE_ANON_KEY is None
    assert settings.SUPABASE_SERVICE_ROLE_KEY is None
    assert settings.GROQ_API_KEY is None
    assert settings.GEMINI_API_KEY is None


def test_production_rejects_debug_mode() -> None:
    """Ensure production environment prohibits DEBUG=True."""
    with pytest.raises(ValidationError) as exc_info:
        Settings(ENVIRONMENT="production", DEBUG=True)

    assert "DEBUG mode must not be enabled in production" in str(exc_info.value)


def test_cors_origins_parsing_and_wildcard_rejection() -> None:
    """Test CORS origin parsing and ensure '*' is strictly prohibited."""
    # Comma-separated string parsing
    settings = Settings(
        CORS_ALLOWED_ORIGINS="https://app.trustcue.test, https://staging.trustcue.test"  # type: ignore[arg-type]
    )
    assert settings.CORS_ALLOWED_ORIGINS == [
        "https://app.trustcue.test",
        "https://staging.trustcue.test",
    ]

    # Rejection of wildcard origin
    with pytest.raises(ValidationError) as exc_info:
        Settings(CORS_ALLOWED_ORIGINS=["*"])

    assert "Wildcard '*' CORS origin is strictly forbidden" in str(exc_info.value)


def test_cloud_ai_feature_validation() -> None:
    """Ensure enabling Cloud AI without keys fails clearly without leaking secrets."""
    with pytest.raises(ValidationError) as exc_info:
        Settings(ENABLE_CLOUD_AI=True, GROQ_API_KEY=None, GEMINI_API_KEY=None)

    assert "neither GROQ_API_KEY nor GEMINI_API_KEY is configured" in str(exc_info.value)

    # Succeeds when Groq key is provided
    valid_groq = Settings(ENABLE_CLOUD_AI=True, GROQ_API_KEY="gsk_test_mock_key")
    assert valid_groq.ENABLE_CLOUD_AI is True
    assert valid_groq.GROQ_API_KEY == "gsk_test_mock_key"


def test_cloud_auth_feature_validation() -> None:
    """Ensure enabling Cloud Auth requires both project URL and anon key."""
    with pytest.raises(ValidationError) as exc_info:
        Settings(ENABLE_CLOUD_AUTH=True, SUPABASE_URL=None)

    assert "SUPABASE_URL or SUPABASE_ANON_KEY is missing" in str(exc_info.value)

    # Succeeds when both are provided
    valid_auth = Settings(
        ENABLE_CLOUD_AUTH=True,
        SUPABASE_URL="https://example.supabase.co",
        SUPABASE_ANON_KEY="mock_anon_key",
    )
    assert valid_auth.ENABLE_CLOUD_AUTH is True


def test_jwt_configuration_defaults() -> None:
    """Ensure default JWT settings match safe local-first defaults."""
    settings = Settings()
    assert settings.SUPABASE_JWT_SECRET is None
    assert settings.SUPABASE_JWT_ALGORITHMS == ["HS256"]
    assert settings.SUPABASE_JWT_AUDIENCE == "authenticated"
    assert settings.SUPABASE_JWT_ISSUER is None
    assert settings.DEFAULT_DAILY_AI_QUOTA == 15


def test_production_rejects_insecure_jwt_secret() -> None:
    """Ensure production environment prohibits test or weak JWT secrets."""
    insecure_keys = [
        "test",
        "secret",
        "test-secret",
        "test-jwt-secret-key-32-chars-long!",
        "demo",
        "example",
    ]

    for bad_key in insecure_keys:
        with pytest.raises(ValidationError) as exc_info:
            Settings(
                ENVIRONMENT="production",
                SUPABASE_JWT_SECRET=bad_key,
            )
        assert "Insecure or test SUPABASE_JWT_SECRET detected in production" in str(exc_info.value)
