"""Typed configuration settings for the TrustCue backend service."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables and .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # --- Runtime & Server Environment ---
    ENVIRONMENT: Literal["development", "test", "production"] = "development"
    HOST: str = "127.0.0.1"
    PORT: int = 8000
    DEBUG: bool = False
    DOCS_ENABLED: bool = True

    # --- CORS Origins ---
    CORS_ALLOWED_ORIGINS: list[str] = Field(default_factory=list)

    # --- Logging & Operational Limits ---
    LOG_LEVEL: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    MAX_REQUEST_BODY_BYTES: int = 1_000_000  # 1 MB maximum payload limit

    # --- Feature Flags (Module 28 foundation defaults to all-disabled) ---
    ENABLE_CLOUD_AI: bool = False
    ENABLE_CLOUD_AUTH: bool = False
    ENABLE_CLOUD_SYNC: bool = False

    # --- Cloud Credentials & Authentication ---
    SUPABASE_URL: str | None = None
    SUPABASE_ANON_KEY: str | None = None
    SUPABASE_SERVICE_ROLE_KEY: str | None = None
    SUPABASE_JWT_SECRET: str | None = None
    SUPABASE_JWT_ALGORITHMS: list[str] = Field(default_factory=lambda: ["HS256"])
    SUPABASE_JWT_AUDIENCE: str = "authenticated"
    SUPABASE_JWT_ISSUER: str | None = None
    SUPABASE_JWKS_URL: str | None = None
    DEFAULT_DAILY_AI_QUOTA: int = 15

    GROQ_API_KEY: str | None = None
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"
    GROQ_TIMEOUT_SECONDS: float = 15.0
    GROQ_MAX_TOKENS: int = 1024
    MAX_PROVIDER_RESPONSE_BYTES: int = 65_536  # 64 KB maximum response size boundary

    GEMINI_API_KEY: str | None = None
    GEMINI_MODEL: str = "gemini-1.5-flash"

    @field_validator("DEBUG", mode="before")
    @classmethod
    def parse_debug(cls, v: object) -> bool:
        """Parse debug boolean, handling environment strings like 'release' gracefully."""
        if isinstance(v, str):
            v_clean = v.strip().lower()
            if v_clean in ("release", "prod", "production", "false", "0", "no", "off", ""):
                return False
            if v_clean in ("true", "1", "yes", "on", "debug", "dev", "development"):
                return True
        return bool(v)

    @field_validator("CORS_ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: object) -> list[str]:
        """Parse comma-separated CORS origins or list of strings."""
        if isinstance(v, str):
            v = v.strip()
            if not v:
                return []
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        if isinstance(v, (list, tuple, set)):
            return [str(origin).strip() for origin in v if str(origin).strip()]
        return []

    @field_validator("CORS_ALLOWED_ORIGINS")
    @classmethod
    def validate_cors_origins(cls, origins: list[str]) -> list[str]:
        """Ensure wildcard '*' is never used in explicit CORS origins."""
        for origin in origins:
            if origin == "*":
                raise ValueError("Wildcard '*' CORS origin is strictly forbidden for security.")
        return origins

    @model_validator(mode="after")
    def validate_environment_and_features(self) -> "Settings":
        """Enforce environment constraints and conditional feature flag requirements."""
        # Enforce debug safety in production
        if self.ENVIRONMENT == "production" and self.DEBUG:
            raise ValueError("DEBUG mode must not be enabled in production environment.")

        # Validate Cloud AI requirements only if the feature is explicitly activated
        if self.ENABLE_CLOUD_AI:
            if not self.GROQ_API_KEY and not self.GEMINI_API_KEY:
                raise ValueError(
                    "Cloud AI feature is enabled, but neither GROQ_API_KEY nor GEMINI_API_KEY "
                    "is configured. Provide an API key for the chosen provider."
                )

        # Validate Cloud Auth requirements only if the feature is explicitly activated
        if self.ENABLE_CLOUD_AUTH:
            if not self.SUPABASE_URL or not self.SUPABASE_ANON_KEY:
                raise ValueError(
                    "Cloud Auth feature is enabled, but SUPABASE_URL or SUPABASE_ANON_KEY "
                    "is missing. Both are required when ENABLE_CLOUD_AUTH is true."
                )

        # Enforce production security constraints against test keys or weak secrets
        if self.ENVIRONMENT == "production":
            insecure_secret_needles = ["test", "demo", "sample", "example", "secret", "change-me"]
            if self.SUPABASE_JWT_SECRET:
                secret_lower = self.SUPABASE_JWT_SECRET.lower()
                if any(needle == secret_lower or secret_lower.startswith("test-") for needle in insecure_secret_needles):
                    raise ValueError(
                        "Insecure or test SUPABASE_JWT_SECRET detected in production environment. "
                        "A cryptographically strong secret from the live Supabase project is required."
                    )

        return self


@lru_cache
def get_settings() -> Settings:
    """Return cached application settings singleton."""
    return Settings()
