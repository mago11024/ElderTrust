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


def test_rejects_seed_missing_initial_stage_id() -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    del payload["initial_stage_id"]

    with pytest.raises(ValidationError):
        ScenarioConfig.model_validate_json(json.dumps(payload))


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
