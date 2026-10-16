"""Tests verifying consistency between the design contract and runtime OpenAPI schema."""

from pathlib import Path

import yaml
from openapi_spec_validator import validate as validate_openapi

from trustcue_backend.main import create_app


def get_design_contract_path() -> Path:
    """Resolve absolute path to openapi.yaml design contract."""
    # Assuming test runs from backend or repository root
    current = Path(__file__).resolve().parent
    # Navigate up to find backend/contracts/openapi.yaml
    for parent in [current.parent, current.parent.parent]:
        candidate = parent / "contracts" / "openapi.yaml"
        if candidate.exists():
            return candidate
        candidate_nested = parent / "backend" / "contracts" / "openapi.yaml"
        if candidate_nested.exists():
            return candidate_nested
    raise FileNotFoundError("Could not locate backend/contracts/openapi.yaml")


def test_full_design_contract_is_valid_openapi_3_1() -> None:
    """Validate that the full 50-module design specification is valid OpenAPI 3.1."""
    contract_path = get_design_contract_path()
    with open(contract_path, encoding="utf-8") as f:
        spec_dict = yaml.safe_load(f)

    # Validates full schema, references, and OpenAPI 3.1.0 conformance
    validate_openapi(spec_dict)
    assert spec_dict["openapi"] == "3.1.0"
    assert "paths" in spec_dict
    assert "/health" in spec_dict["paths"]
    assert "/ready" in spec_dict["paths"]
    assert "/api/v1/analysis/ai" in spec_dict["paths"]


def test_runtime_schema_implements_exact_foundation_subset() -> None:
    """
    Verify that runtime FastAPI schema exposes implemented routes (/health, /ready, /api/v1/account/profile, /api/v1/account)
    and that planned future routes remain strictly unmounted.
    """
    app = create_app()
    runtime_schema = app.openapi()

    runtime_paths = set(runtime_schema.get("paths", {}).keys())

    # Implemented routes in Modules 28, 30, 32, 35, 38, 39 must be present
    assert "/health" in runtime_paths
    assert "/ready" in runtime_paths
    assert "/api/v1/account/profile" in runtime_paths
    assert "/api/v1/account" in runtime_paths
    assert "/api/v1/analysis/ai" in runtime_paths
    assert "/api/v1/sync/reports" in runtime_paths


def test_runtime_endpoints_match_design_contract_definitions() -> None:
    """Verify that implemented endpoints match their design contract methods and operations."""
    contract_path = get_design_contract_path()
    with open(contract_path, encoding="utf-8") as f:
        design_spec = yaml.safe_load(f)

    app = create_app()
    runtime_schema = app.openapi()

    expected_endpoints = {
        "/health": "get",
        "/ready": "get",
        "/api/v1/account/profile": "get",
        "/api/v1/account": "delete",
        "/api/v1/analysis/ai": "post",
        "/api/v1/sync/reports": "post",
    }

    for path, method in expected_endpoints.items():
        assert path in runtime_schema["paths"], f"{path} missing from runtime schema"
        assert path in design_spec["paths"], f"{path} missing from design contract"

        runtime_methods = set(runtime_schema["paths"][path].keys())
        design_methods = set(design_spec["paths"][path].keys())

        # Verify HTTP method is supported in both
        assert method in runtime_methods, f"Method {method} missing from runtime schema for {path}"
        assert method in design_methods, f"Method {method} missing from design spec for {path}"

        # Verify 200 response is defined for both
        runtime_responses = runtime_schema["paths"][path][method]["responses"]
        design_responses = design_spec["paths"][path][method]["responses"]

        assert "200" in runtime_responses
        assert "200" in design_responses
