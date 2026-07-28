from pathlib import Path

import pytest

from app.scenarios.schemas import (
    ScenarioConfig,
    TransitionTargetKind,
    load_scenario_config,
)
from app.scenarios.validation import validate_scenario_config

SEED_PATH = (
    Path(__file__).resolve().parents[3] / "app" / "scenarios" / "seeds" / "customer_refund_v1.json"
)
SECOND_SCENARIO_PATH = (
    Path(__file__).resolve().parents[2] / "fixtures" / "synthetic_second_scenario.json"
)


def load_customer_refund_config() -> ScenarioConfig:
    return load_scenario_config(SEED_PATH).model_copy(deep=True)


def test_accepts_seed_and_structurally_different_second_scenario() -> None:
    validate_scenario_config(load_customer_refund_config())
    validate_scenario_config(load_scenario_config(SECOND_SCENARIO_PATH))


def test_rejects_unreachable_stage() -> None:
    config = load_customer_refund_config()
    orphan = config.stages[-1].model_copy(deep=True)
    orphan.stage_id = "orphan_stage"
    orphan.order = 6
    config.stages.append(orphan)

    with pytest.raises(ValueError, match=r"unreachable stage.*orphan_stage"):
        validate_scenario_config(config)


def test_rejects_unknown_stage_target() -> None:
    config = load_customer_refund_config()
    config.stages[0].choices[0].transition.target_id = "missing_stage"

    with pytest.raises(ValueError, match=r"unknown stage target.*missing_stage"):
        validate_scenario_config(config)


def test_rejects_stage_without_finite_end_path() -> None:
    config = load_customer_refund_config()
    final_stage = config.stages[-1]
    for choice in final_stage.choices:
        choice.transition.target_kind = TransitionTargetKind.STAGE
        choice.transition.target_id = final_stage.stage_id

    with pytest.raises(ValueError, match=r"no finite end path.*time_pressure"):
        validate_scenario_config(config)


def test_rejects_cycle_even_when_an_alternative_choice_can_end() -> None:
    config = load_customer_refund_config()
    final_stage = config.stages[-1]
    looping_choice = final_stage.choices[0]
    looping_choice.transition.target_kind = TransitionTargetKind.STAGE
    looping_choice.transition.target_id = final_stage.stage_id

    with pytest.raises(ValueError, match=r"non-terminating cycle.*time_pressure"):
        validate_scenario_config(config)


def test_rejects_pressure_prompt_limit_exceeded() -> None:
    config = load_customer_refund_config()
    config.stages[0].risk_points.append("authority_pressure")

    with pytest.raises(ValueError, match=r"pressure prompt limit exceeded.*2.*1"):
        validate_scenario_config(config)
