"""Authentication models, Supabase JWT verification, and session context management."""

import logging
import uuid
from datetime import UTC, datetime
from typing import Any

import jwt
from jwt import PyJWKClient
from pydantic import BaseModel, Field

from trustcue_backend.core.config import Settings, get_settings
from trustcue_backend.core.errors import AuthenticationError

logger = logging.getLogger("trustcue.auth")


class AuthenticatedUser(BaseModel):
    """Authenticated user context extracted from verified Supabase JWT session claims."""

    user_id: str = Field(description="Unique user UUID from JWT 'sub' claim.")
    email: str | None = Field(default=None, description="User email address if provided in claims.")
    email_verified: bool = Field(default=False, description="Whether user email address has been verified.")
    role: str = Field(default="authenticated", description="Session role (e.g. 'authenticated').")
    app_metadata: dict[str, Any] = Field(default_factory=dict, description="Supabase app metadata dictionary.")
    user_metadata: dict[str, Any] = Field(default_factory=dict, description="Supabase user metadata dictionary.")
    session_id: str | None = Field(default=None, description="Optional Supabase session ID claim.")
    claims: dict[str, Any] = Field(default_factory=dict, description="Full raw verified token claims.")


class JWTValidator:
    """
    Validates Supabase-issued JSON Web Tokens against configured cryptographic keys.

    Enforces token expiration, cryptographic signature verification, audience restrictions,
    issuer validation, and UUID subject integrity.
    """

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self.jwt_secret = self.settings.SUPABASE_JWT_SECRET
        self.algorithms = self.settings.SUPABASE_JWT_ALGORITHMS
        self.audience = self.settings.SUPABASE_JWT_AUDIENCE
        self.issuer = self.settings.SUPABASE_JWT_ISSUER
        self.jwks_url = self.settings.SUPABASE_JWKS_URL
        self.jwks_client: PyJWKClient | None = None

        if self.jwks_url:
            self.jwks_client = PyJWKClient(self.jwks_url)

    def validate_token(self, token: str) -> AuthenticatedUser:
        """
        Cryptographically decode and validate a JWT bearer token.

        Raises AuthenticationError on any validation, signature, expiration, or claim failure.
        """
        token_clean = token.strip() if token else ""
        if not token_clean:
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication token is missing or empty.",
            )

        # Resolve signing key
        key: Any
        if self.jwks_client:
            try:
                signing_key = self.jwks_client.get_signing_key_from_jwt(token_clean)
                key = signing_key.key
            except Exception as exc:
                logger.warning("Failed to retrieve signing key from JWKS: %s", exc)
                raise AuthenticationError(
                    code="unauthorized",
                    message="Unable to verify token signature against JWKS authority.",
                ) from exc
        elif self.jwt_secret:
            key = self.jwt_secret
        else:
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication service is not configured with signing credentials.",
            )

        # Verification options
        options = {
            "verify_signature": True,
            "verify_exp": True,
            "verify_aud": bool(self.audience),
            "verify_iss": bool(self.issuer),
        }

        try:
            claims = jwt.decode(
                token_clean,
                key,
                algorithms=self.algorithms,
                audience=self.audience if self.audience else None,
                issuer=self.issuer if self.issuer else None,
                options=options,
            )
        except jwt.ExpiredSignatureError as exc:
            raise AuthenticationError(
                code="token_expired",
                message="Authentication token has expired.",
            ) from exc
        except jwt.InvalidIssuerError as exc:
            raise AuthenticationError(
                code="invalid_issuer",
                message="Authentication token issuer is invalid.",
            ) from exc
        except jwt.InvalidAudienceError as exc:
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication token audience is invalid.",
            ) from exc
        except jwt.InvalidSignatureError as exc:
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication token signature verification failed.",
            ) from exc
        except jwt.DecodeError as exc:
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication token is malformed.",
            ) from exc
        except jwt.PyJWTError as exc:
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication token is invalid or unrecognized.",
            ) from exc

        # 1. Subject validation (must be valid non-empty UUID)
        sub = claims.get("sub")
        if not sub or not isinstance(sub, str):
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication token is missing a valid user subject identifier.",
            )
        try:
            uuid_obj = uuid.UUID(sub)
            user_id = str(uuid_obj)
        except (ValueError, TypeError, AttributeError) as exc:
            raise AuthenticationError(
                code="unauthorized",
                message="Authentication token subject must be a valid UUID.",
            ) from exc

        # 2. Role validation (anonymous tokens are strictly prohibited on authenticated routes)
        role = str(claims.get("role", "")).strip().lower()
        if role in ("anon", "anonymous", ""):
            raise AuthenticationError(
                code="unauthorized",
                message="Anonymous tokens are not authorized for protected user endpoints.",
            )

        # 3. Audience double-check
        aud = claims.get("aud")
        if isinstance(aud, str) and aud.lower() in ("anon", "anonymous"):
            raise AuthenticationError(
                code="unauthorized",
                message="Anonymous audience tokens are not authorized for protected endpoints.",
            )

        # 4. Extract metadata and flags
        app_metadata = claims.get("app_metadata") or {}
        user_metadata = claims.get("user_metadata") or {}
        email = claims.get("email") or user_metadata.get("email")
        email_verified = bool(
            claims.get("email_confirmed_at")
            or claims.get("email_verified")
            or user_metadata.get("email_verified", False)
        )
        session_id = claims.get("session_id")

        return AuthenticatedUser(
            user_id=user_id,
            email=str(email) if email else None,
            email_verified=email_verified,
            role=role,
            app_metadata=app_metadata if isinstance(app_metadata, dict) else {},
            user_metadata=user_metadata if isinstance(user_metadata, dict) else {},
            session_id=str(session_id) if session_id else None,
            claims=claims,
        )


def create_test_jwt(
    user_id: str,
    email: str = "synthetic-user@trustcue.test",
    secret: str = "test-jwt-secret-key-32-chars-long!",
    algorithm: str = "HS256",
    audience: str = "authenticated",
    issuer: str | None = None,
    role: str = "authenticated",
    expires_in_seconds: int = 3600,
    custom_claims: dict[str, Any] | None = None,
    environment: str = "development",
) -> str:
    """
    Generate a signed synthetic JWT for local testing and offline verification.

    Production Guard: Strictly prohibited and rejected if environment is 'production'.
    """
    if environment == "production":
        raise ValueError("Synthetic test JWT creation is strictly forbidden in production configuration.")

    now = int(datetime.now(UTC).timestamp())
    payload: dict[str, Any] = {
        "sub": user_id,
        "email": email,
        "aud": audience,
        "role": role,
        "iat": now,
        "exp": now + expires_in_seconds,
        "app_metadata": {"provider": "email", "providers": ["email"]},
        "user_metadata": {"email_verified": True},
    }
    if issuer:
        payload["iss"] = issuer
    if custom_claims:
        payload.update(custom_claims)

    return jwt.encode(payload, secret, algorithm=algorithm)
