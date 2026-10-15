"""Development entrypoint runner for TrustCue backend service."""

import uvicorn

from trustcue_backend.core.config import get_settings


def main() -> None:
    """Run uvicorn server on configured host and port."""
    settings = get_settings()
    uvicorn.run(
        "trustcue_backend.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_config=None,  # We manage privacy-safe logging configuration
    )


if __name__ == "__main__":
    main()
