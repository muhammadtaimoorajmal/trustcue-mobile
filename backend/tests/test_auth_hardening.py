"""Security tests verifying JWT validation hardening against algorithm confusion and header injection."""

import jwt
import pytest

from trustcue_backend.core.auth import JWTValidator
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import AuthenticationError


def test_jwt_validator_rejects_none_algorithm() -> None:
    """Tokens with 'none' algorithm must be rejected immediately."""
    settings = Settings(SUPABASE_JWT_SECRET="valid-test-secret-key-32-chars-long!")
    validator = JWTValidator(settings=settings)

    payload = {
        "sub": "00000000-0000-0000-0000-000000000001",
        "role": "authenticated",
        "aud": "authenticated",
        "exp": 9999999999,
    }
    # Unsigned token with alg: none
    token = jwt.encode(payload, key="", algorithm="none")

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(token)
    assert exc_info.value.code == "unauthorized"


def test_jwt_validator_rejects_jku_and_x5u_headers() -> None:
    """Tokens containing jku or x5u remote URL headers are rejected to prevent header injection."""
    secret = "valid-test-secret-key-32-chars-long!"
    settings = Settings(SUPABASE_JWT_SECRET=secret)
    validator = JWTValidator(settings=settings)

    payload = {
        "sub": "00000000-0000-0000-0000-000000000001",
        "role": "authenticated",
        "aud": "authenticated",
        "exp": 9999999999,
    }

    # 1. Test jku header injection
    token_jku = jwt.encode(
        payload,
        secret,
        algorithm="HS256",
        headers={"jku": "https://malicious-site.test/keys.json"},
    )
    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(token_jku)
    assert "Insecure token header parameter" in exc_info.value.message

    # 2. Test x5u header injection
    token_x5u = jwt.encode(
        payload,
        secret,
        algorithm="HS256",
        headers={"x5u": "https://malicious-site.test/cert.pem"},
    )
    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(token_x5u)
    assert "Insecure token header parameter" in exc_info.value.message


def test_jwt_validator_rejects_asymmetric_alg_when_hmac_configured() -> None:
    """
    Prevents algorithm confusion: If server has an HMAC secret, tokens claiming RS256
    must be rejected before key resolution.
    """
    secret = "valid-test-secret-key-32-chars-long!"
    settings = Settings(SUPABASE_JWT_SECRET=secret, SUPABASE_JWT_ALGORITHMS=["HS256"])
    validator = JWTValidator(settings=settings)

    payload = {
        "sub": "00000000-0000-0000-0000-000000000001",
        "role": "authenticated",
        "aud": "authenticated",
        "exp": 9999999999,
    }
    import base64
    import json

    hdr = base64.urlsafe_b64encode(json.dumps({"alg": "RS256"}).encode()).decode().rstrip("=")
    bdy = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    sig = base64.urlsafe_b64encode(b"sig").decode().rstrip("=")
    forged_token = f"{hdr}.{bdy}.{sig}"

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(forged_token)
    assert "Asymmetric algorithms are not permitted when HMAC secret is configured" in exc_info.value.message


def test_jwt_validator_rejects_symmetric_alg_when_jwks_configured() -> None:
    """
    Prevents HMAC-JWKS key confusion: If server is configured with JWKS URL,
    tokens claiming symmetric HMAC (HS256) are rejected without calling JWKS.
    """
    settings = Settings(
        SUPABASE_JWKS_URL="https://example.supabase.co/auth/v1/.well-known/jwks.json",
        SUPABASE_JWT_ALGORITHMS=["RS256"],
    )
    validator = JWTValidator(settings=settings)

    payload = {
        "sub": "00000000-0000-0000-0000-000000000001",
        "role": "authenticated",
        "aud": "authenticated",
        "exp": 9999999999,
    }

    # Token signed with symmetric HS256
    hmac_token = jwt.encode(payload, "secret-key", algorithm="HS256")

    with pytest.raises(AuthenticationError) as exc_info:
        validator.validate_token(hmac_token)
    assert "Symmetric HMAC algorithms are not permitted for JWKS verification" in exc_info.value.message
