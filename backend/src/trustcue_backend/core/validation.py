"""Strict input validation for user-submitted text and analysis requests."""

import unicodedata

from trustcue_backend.core.errors import TrustCueError


class ValidationError(TrustCueError):
    """Exception raised when user input fails strict semantic or structural validation."""

    def __init__(
        self,
        code: str = "invalid_payload",
        message: str = "The submitted input failed validation.",
        status_code: int = 400,
        details: dict | None = None,
    ) -> None:
        super().__init__(
            code=code,
            message=message,
            status_code=status_code,
            details=details,
        )


def validate_analysis_text(
    text: str,
    max_code_points: int = 10_000,
    max_utf8_bytes: int = 40_000,
) -> str:
    """
    Validate reviewed text against strict boundaries matching the Flutter client contract.

    Invariants:
    1. Maximum 10,000 Unicode code points (runes).
    2. Maximum 40,000 UTF-8 encoded bytes.
    3. At least one non-whitespace visible character.
    4. Valid Unicode without lone surrogates.
    5. Disallows non-printable control characters, allowing only tab, newline, and carriage return.

    Privacy & Security:
    Never returns or logs the raw input text on failure.
    """
    if not isinstance(text, str):
        raise ValidationError(
            code="invalid_payload",
            message="Text must be a valid string.",
        )

    # 1. Non-whitespace check
    if not text.strip():
        raise ValidationError(
            code="only_whitespace",
            message="Text must contain at least one non-whitespace character.",
        )

    # 2. Unicode code point limit (runes)
    if len(text) > max_code_points:
        raise ValidationError(
            code="text_too_long",
            message=f"Text exceeds the maximum limit of {max_code_points} Unicode code points.",
        )

    # 3. UTF-8 byte boundary limit and surrogate check
    try:
        encoded_bytes = text.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise ValidationError(
            code="malformed_unicode",
            message="Text contains malformed Unicode sequences or unassigned surrogates.",
        ) from exc

    if len(encoded_bytes) > max_utf8_bytes:
        raise ValidationError(
            code="text_too_long",
            message=f"Text exceeds the maximum UTF-8 byte limit of {max_utf8_bytes} bytes.",
        )

    # 4. Check for lone surrogates or ill-formed Unicode characters
    for ch in text:
        cp = ord(ch)
        # Lone surrogates (U+D800 to U+DFFF)
        if 0xD800 <= cp <= 0xDFFF:
            raise ValidationError(
                code="malformed_unicode",
                message="Text contains invalid Unicode surrogate code points.",
            )

        # Disallowed control characters:
        # Standard allowed whitespace: \t (0x09), \n (0x0A), \r (0x0D)
        if cp in (0x09, 0x0A, 0x0D):
            continue

        # ASCII control characters 0x00-0x1F and 0x7F (DEL)
        if cp < 0x20 or cp == 0x7F:
            raise ValidationError(
                code="malformed_unicode",
                message="Text contains disallowed control characters.",
            )

        # Unicode category check: reject Other, Control (Cc) and Other, Surrogate (Cs)
        cat = unicodedata.category(ch)
        if cat in ("Cc", "Cs"):
            raise ValidationError(
                code="malformed_unicode",
                message="Text contains disallowed Unicode control or surrogate characters.",
            )

    return text

