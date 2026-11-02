"""Privacy-safe operational observability, latency metrics, and bounded telemetry."""

import contextlib
import contextvars
import json
import logging
import re
import threading
import time
import uuid
from typing import Any, Literal

logger = logging.getLogger("trustcue.telemetry")

# Context variable for correlating operations across async tasks
current_correlation_id: contextvars.ContextVar[str] = contextvars.ContextVar(
    "current_correlation_id", default=""
)

# Strict correlation ID regex: 8 to 64 chars of [a-zA-Z0-9_.-]
CORRELATION_ID_PATTERN = re.compile(r"^[a-zA-Z0-9_\-\.]{8,64}$")

OutcomeCategory = Literal[
    "success",
    "client_error",
    "auth_error",
    "consent_rejected",
    "concurrency_rejected",
    "quota_exhausted",
    "rate_limited",
    "provider_timeout_connect",
    "provider_timeout_read",
    "provider_error",
    "malformed_output",
    "grounding_failed",
    "database_error",
    "internal_error",
]

StageName = Literal[
    "request_total",
    "quota_reserve",
    "quota_dispatch",
    "provider_inference",
    "grounding",
    "quota_settle",
]

VALID_OUTCOMES: set[str] = {
    "success",
    "client_error",
    "auth_error",
    "consent_rejected",
    "concurrency_rejected",
    "quota_exhausted",
    "rate_limited",
    "provider_timeout_connect",
    "provider_timeout_read",
    "provider_error",
    "malformed_output",
    "grounding_failed",
    "database_error",
    "internal_error",
}

VALID_STAGES: set[str] = {
    "request_total",
    "quota_reserve",
    "quota_dispatch",
    "provider_inference",
    "grounding",
    "quota_settle",
}


def validate_or_generate_correlation_id(incoming: str | None) -> str:
    """
    Validate incoming correlation ID against strict character and length constraints.
    If absent, invalid, or outside 8-64 chars, generates a server-controlled random ID.
    Prevents untrusted header injection into system logs.
    """
    if incoming:
        cleaned = incoming.strip()
        if CORRELATION_ID_PATTERN.match(cleaned):
            return cleaned

    return f"req_{uuid.uuid4().hex[:16]}"


def get_current_correlation_id() -> str:
    """Retrieve the current task's correlation ID or empty string if unset."""
    return current_correlation_id.get()


class MetricsCollector:
    """
    In-process, low-overhead operational metrics collector with strictly bounded cardinality.

    Invariants:
    1. Metric keys are composed strictly of bounded enums: stage names and outcome categories.
    2. Never records user IDs, reservation IDs, request IDs, IPs, prompts, or message excerpts.
    3. Thread-safe counter and latency distribution accumulation.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        # Map: (metric_name, outcome) -> count
        self._counters: dict[tuple[str, str], int] = {}
        # Map: (stage, outcome) -> {"count": int, "total_ms": float, "min_ms": float, "max_ms": float}
        self._latencies: dict[tuple[str, str], dict[str, float]] = {}

    def record_counter(self, metric: str, outcome: str, count: int = 1) -> None:
        """Increment a bounded metric counter."""
        safe_outcome = outcome if outcome in VALID_OUTCOMES else "internal_error"
        key = (metric, safe_outcome)
        with self._lock:
            self._counters[key] = self._counters.get(key, 0) + count

    def record_latency(self, stage: str, duration_ms: float, outcome: str) -> None:
        """Record bounded stage latency in milliseconds."""
        safe_stage = stage if stage in VALID_STAGES else "request_total"
        safe_outcome = outcome if outcome in VALID_OUTCOMES else "internal_error"
        key = (safe_stage, safe_outcome)

        with self._lock:
            if key not in self._latencies:
                self._latencies[key] = {
                    "count": 1.0,
                    "total_ms": duration_ms,
                    "min_ms": duration_ms,
                    "max_ms": duration_ms,
                }
            else:
                entry = self._latencies[key]
                entry["count"] += 1.0
                entry["total_ms"] += duration_ms
                entry["min_ms"] = min(entry["min_ms"], duration_ms)
                entry["max_ms"] = max(entry["max_ms"], duration_ms)

    def get_summary(self) -> dict[str, Any]:
        """Return a snapshot of accumulated operational metrics."""
        with self._lock:
            counters_summary = {
                f"{metric}:{outcome}": count
                for (metric, outcome), count in self._counters.items()
            }
            latencies_summary = {
                f"{stage}:{outcome}": {
                    "count": int(data["count"]),
                    "avg_ms": round(data["total_ms"] / max(1.0, data["count"]), 2),
                    "min_ms": round(data["min_ms"], 2),
                    "max_ms": round(data["max_ms"], 2),
                }
                for (stage, outcome), data in self._latencies.items()
            }
            return {
                "counters": counters_summary,
                "latencies": latencies_summary,
            }

    def reset(self) -> None:
        """Reset all metrics (primarily for test isolation)."""
        with self._lock:
            self._counters.clear()
            self._latencies.clear()


# Global singleton metrics collector
metrics = MetricsCollector()


def record_stage_duration(
    stage: StageName,
    duration_ms: float,
    outcome: OutcomeCategory,
    extra_log_fields: dict[str, Any] | None = None,
) -> None:
    """
    Record stage duration to in-process metrics and emit a structured privacy-safe log event.
    """
    metrics.record_latency(stage, duration_ms, outcome)

    event_payload: dict[str, Any] = {
        "event": f"stage_{stage}",
        "stage": stage,
        "duration_ms": duration_ms,
        "outcome": outcome,
        "correlation_id": get_current_correlation_id(),
    }
    if extra_log_fields:
        for k, v in extra_log_fields.items():
            # Allowlist safe operational metadata
            if k in {"quota_mode", "provider", "status_code"}:
                event_payload[k] = v

    logger.info("Stage metric: %s", json.dumps(event_payload))


def record_event(
    event_type: str,
    outcome: OutcomeCategory,
    extra_log_fields: dict[str, Any] | None = None,
) -> None:
    """
    Record an operational event count and emit a structured privacy-safe log entry.
    """
    metrics.record_counter(event_type, outcome)

    event_payload: dict[str, Any] = {
        "event": event_type,
        "outcome": outcome,
        "correlation_id": get_current_correlation_id(),
    }
    if extra_log_fields:
        for k, v in extra_log_fields.items():
            if k in {"quota_mode", "provider", "status_code", "reaped_count"}:
                event_payload[k] = v

    logger.info("Operational event: %s", json.dumps(event_payload))


@contextlib.asynccontextmanager
async def measure_stage(stage: StageName, extra_log_fields: dict[str, Any] | None = None):
    """
    Async context manager measuring stage execution duration with monotonic clock (time.perf_counter).
    Defaults to 'success' outcome unless an exception is raised or outcome is set on context state.
    """
    start_time = time.perf_counter()
    outcome_holder: list[OutcomeCategory] = ["success"]
    try:
        yield outcome_holder
    except Exception:
        outcome_holder[0] = "internal_error"
        raise
    finally:
        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
        record_stage_duration(
            stage=stage,
            duration_ms=duration_ms,
            outcome=outcome_holder[0],
            extra_log_fields=extra_log_fields,
        )
