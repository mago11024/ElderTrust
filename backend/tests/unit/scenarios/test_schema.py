import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.scenarios.schemas import ScenarioConfig, load_scenario_config

SEED_PATH = (
    Path(__file__).resolve().parents[3] / "app" / "scenarios" / "seeds" / "customer_refund_v1.json"
)


def test_loads_customer_refund_v1_seed() -> None:
    config = load_scenario_config(SEED_PATH)

    assert str(config.scenario_id) == "7bea2c71-9bbb-4a38-bf53-a89b56635cbb"
    assert str(config.scenario_version_id) == "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c"
    assert [stage.stage_id for stage in config.stages] == [
        "customer_identity",
        "order_anomaly",
        "refund_offer",
        "sensitive_action",
        "time_pressure",
    ]
    assert {condition.end_state for condition in config.end_conditions} == {
        "completed_safe",
        "completed_risky",
        "safety_stopped",
    }
    assert sum(policy.weight for policy in config.scoring_policy.dimensions) == 100


def test_customer_refund_risky_override_uses_emitted_event_types() -> None:
    config = load_scenario_config(SEED_PATH)
    risk_override = next(
        condition
        for condition in config.end_conditions
        if condition.condition_type == "risk_override"
    )

    assert set(risk_override.triggering_event_types) == {
        "pressure_compliance",
        "verification_code_shared",
        "unknown_link_opened",
        "screen_sharing_enabled",
    }


def test_behavior_mappings_are_static_definitions_without_runtime_event_ids() -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    config = load_scenario_config(SEED_PATH)
    mapping = config.stages[0].choices[0].behavior_mappings[0]

    assert mapping.event_type == "identity_not_verified"
    assert mapping.dimension == "identity_verification"
    assert mapping.direction == "negative"
    assert mapping.severity == "normal"
    assert "event_id" not in mapping.model_dump()
    assert all(
        "event_id" not in behavior_mapping
        for stage in payload["stages"]
        for choice in stage["choices"]
        for behavior_mapping in choice["behavior_mappings"]
    )


def test_rejects_seed_missing_initial_stage_id() -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    del payload["initial_stage_id"]

    with pytest.raises(ValidationError):
        ScenarioConfig.model_validate_json(json.dumps(payload))


def test_accepts_another_structurally_valid_scenario_identity() -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    payload.update(
        {
            "scenario_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            "scenario_version_id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            "scenario_key": "another_scenario",
            "scenario_version": 2,
        }
    )

    config = ScenarioConfig.model_validate_json(json.dumps(payload))

    assert str(config.scenario_id) == "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    assert str(config.scenario_version_id) == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    assert config.scenario_key == "another_scenario"
    assert config.scenario_version == 2


@pytest.mark.parametrize(
    ("mutation", "description"),
    [
        (
            lambda payload: payload.update({"scenario_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8"}),
            "a non-v4 scenario UUID",
        ),
        (lambda payload: payload.update({"scenario_version": 0}), "a non-positive version"),
        (lambda payload: payload.update({"runtime_level": "l3"}), "an unsupported runtime level"),
        (lambda payload: payload.update({"unexpected": True}), "an unknown top-level field"),
        (
            lambda payload: payload["stages"][0]["choices"][0]["behavior_mappings"][0].update(
                {"severity": "critical"}
            ),
            "an invalid nested severity",
        ),
    ],
)
def test_rejects_invalid_scenario_contract_fields(mutation: object, description: str) -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    assert callable(mutation), description
    mutation(payload)

    with pytest.raises(ValidationError):
        ScenarioConfig.model_validate_json(json.dumps(payload))


@pytest.mark.parametrize(
    "invalid_scenario_id",
    [
        "7BEA2C71-9BBB-4A38-BF53-A89B56635CBB",
        "7bea2c719bbb4a38bf53a89b56635cbb",
    ],
)
def test_rejects_noncanonical_uuid4_json_text(invalid_scenario_id: str) -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    payload["scenario_id"] = invalid_scenario_id

    with pytest.raises(ValidationError):
        ScenarioConfig.model_validate_json(json.dumps(payload))
