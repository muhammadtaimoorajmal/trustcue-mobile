"""Tests for JWT verification, claim validation, and authentication error handling."""

import uuid

import jwt
import pytest

from trustcue_backend.core.auth import JWTValidator, create_test_jwt
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import AuthenticationError

TEST_SECRET = "test-jwt-secret-key-32-chars-long!"


@pytest.fixture
def auth_settings() -> Settings:
    """Settings configured with synthetic test JWT signing key."""
    return Settings(
        SUPABASE_JWT_SECRET=TEST_SECRET,
        SUPABASE_JWT_AUDIENCE="authenticated",
        SUPABASE_JWT_ALGORITHMS=["HS256"],
        SUPABASE_JWT_ISSUER="https://synthetic-test.supabase.co/auth/v1",
        ENVIRONMENT="test",
    )


@pytest.fixture
def validator(auth_settings: Settings) -> JWTValidator:
    """JWTValidator instance initialized with test settings."""
    return JWTValidator(settings=auth_settings)


def test_valid_jwt_extraction_and_claims(validator: JWTValidator, auth_settings: Settings) -> None:
    """Ensure a properly signed and formatted JWT succeeds with accurate user claims."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(
        user_id=user_uuid,
        email="analyst@trustcue.test",
        secret=TEST_SECRET,
        issuer=auth_settings.SUPABASE_JWT_ISSUER,
        role="authenticated",
    )

    authenticated_user = validator.validate_token(token)

    assert authenticated_user.user_id == user_uuid
    assert authenticated_user.email == "analyst@trustcue.test"
    assert authenticated_user.email_verified is True
    assert authenticated_user.role == "authenticated"
    assert authenticated_user.app_metadata.get("provider") == "email"


def test_expired_jwt_rejection(validator: JWTValidator, auth_settings: Settings) -> None:
    """Ensure expired JWTs are rejected with code 'token_expired'."""
    user_uuid = str(uuid.uuid4())
    expired_token = create_test_jwt(
        user_id=user_uuid,
        secret=TEST_SECRET,
        issuer=auth_settings.SUPABASE_JWT_ISSUER,
        expires_in_seconds=-60,  # Expired 60 seconds ago
    )

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(expired_token)

    assert exc_info.value.code == "token_expired"
    assert "expired" in exc_info.value.message.lower()
    assert exc_info.value.status_code == 401


def test_invalid_signature_rejection(validator: JWTValidator, auth_settings: Settings) -> None:
    """Ensure tokens signed with a different key are rejected with code 'unauthorized'."""
    user_uuid = str(uuid.uuid4())
    tampered_token = create_test_jwt(
        user_id=user_uuid,
        secret="different-wrong-secret-key-32-chars!",
        issuer=auth_settings.SUPABASE_JWT_ISSUER,
    )

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(tampered_token)

    assert exc_info.value.code == "unauthorized"
    assert exc_info.value.status_code == 401


def test_wrong_audience_rejection(validator: JWTValidator, auth_settings: Settings) -> None:
    """Ensure tokens with mismatched audience claims are rejected."""
    user_uuid = str(uuid.uuid4())
    wrong_aud_token = create_test_jwt(
        user_id=user_uuid,
        secret=TEST_SECRET,
        audience="wrong_audience",
        issuer=auth_settings.SUPABASE_JWT_ISSUER,
    )

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(wrong_aud_token)

    assert exc_info.value.code == "unauthorized"
    assert exc_info.value.status_code == 401


def test_wrong_issuer_rejection(validator: JWTValidator) -> None:
    """Ensure tokens with mismatched issuer are rejected with code 'invalid_issuer'."""
    user_uuid = str(uuid.uuid4())
    wrong_issuer_token = create_test_jwt(
        user_id=user_uuid,
        secret=TEST_SECRET,
        issuer="https://rogue-issuer.attacker.com/auth/v1",
    )

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(wrong_issuer_token)

    assert exc_info.value.code == "invalid_issuer"
    assert exc_info.value.status_code == 401


def test_anonymous_role_rejection(validator: JWTValidator, auth_settings: Settings) -> None:
    """Ensure tokens with 'anon' role are rejected from accessing protected user endpoints."""
    user_uuid = str(uuid.uuid4())
    anon_token = create_test_jwt(
        user_id=user_uuid,
        secret=TEST_SECRET,
        issuer=auth_settings.SUPABASE_JWT_ISSUER,
        role="anon",
    )

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(anon_token)

    assert exc_info.value.code == "unauthorized"
    assert "anonymous" in exc_info.value.message.lower()
    assert exc_info.value.status_code == 401


def test_anonymous_audience_rejection(validator: JWTValidator, auth_settings: Settings) -> None:
    """Ensure Supabase public anon tokens (aud='anon') are rejected."""
    user_uuid = str(uuid.uuid4())
    anon_token = jwt.encode(
        {"sub": user_uuid, "aud": "anon", "role": "anon", "exp": 9999999999},
        TEST_SECRET,
        algorithm="HS256",
    )

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(anon_token)

    assert exc_info.value.code == "unauthorized"
    assert exc_info.value.status_code == 401


def test_non_uuid_subject_rejection(validator: JWTValidator, auth_settings: Settings) -> None:
    """Ensure tokens with non-UUID subjects (such as arbitrary username strings) are rejected."""
    token = create_test_jwt(
        user_id="invalid-non-uuid-username",
        secret=TEST_SECRET,
        issuer=auth_settings.SUPABASE_JWT_ISSUER,
    )

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(token)

    assert exc_info.value.code == "unauthorized"
    assert "valid uuid" in exc_info.value.message.lower()
    assert exc_info.value.status_code == 401


def test_malformed_and_empty_token_rejection(validator: JWTValidator) -> None:
    """Ensure malformed or garbage token strings fail gracefully."""
    for bad_token in ["", "   ", "not-a-jwt", "part1.part2", "a.b.c.d"]:
        with pytest.raises(AuthenticationError) as exc_info:
            validator.validate_token(bad_token)
        assert exc_info.value.code == "unauthorized"
        assert exc_info.value.status_code == 401


def test_unconfigured_service_rejects_all_tokens() -> None:
    """Ensure JWTValidator without secret or JWKS rejects tokens rather than allowing bypass."""
    unconfigured_validator = JWTValidator(settings=Settings())  # No secret or JWKS
    token = create_test_jwt(user_id=str(uuid.uuid4()))

    with pytest.raises(AuthenticationError) as exc_info:
        unconfigured_validator.validate_token(token)

    assert exc_info.value.code == "unauthorized"
    assert "not configured" in exc_info.value.message.lower()
    assert exc_info.value.status_code == 401


def test_production_guard_prohibits_synthetic_jwt_generation() -> None:
    """Ensure create_test_jwt is strictly blocked in production environment."""
    with pytest.raises(ValueError) as exc_info:
        create_test_jwt(
            user_id=str(uuid.uuid4()),
            environment="production",
        )

    assert "strictly forbidden in production" in str(exc_info.value)
