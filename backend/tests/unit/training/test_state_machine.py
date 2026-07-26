from dataclasses import replace
from itertools import product
from pathlib import Path
from uuid import uuid4

import pytest

from app.scenarios.schemas import (
    EndState,
    ScenarioConfig,
    TransitionTargetKind,
    load_scenario_config,
)
from app.training.domain import (
    MaximumRoundsExceededError,
    RequestConflictError,
    ScenarioVersionMismatchError,
    SelectionCommand,
    StageMismatchError,
    TrainingAlreadyEndedError,
    TrainingState,
    TransitionResult,
    UnknownSelectionError,
)
from app.training.state_machine import start_training

SEED_PATH = (
    Path(__file__).resolve().parents[3] / "app" / "scenarios" / "seeds" / "customer_refund_v1.json"
)


def load_customer_refund_config() -> ScenarioConfig:
    return load_scenario_config(SEED_PATH)


def apply_selection(
    config: ScenarioConfig, state: TrainingState, command: SelectionCommand
) -> TransitionResult:
    from app.training.state_machine import apply_selection as apply

    return apply(config, state, command)


def command(
    config: ScenarioConfig,
    state: TrainingState,
    choice_id: str,
    *,
    request_id: str | None = None,
) -> SelectionCommand:
    assert state.current_stage_id is not None
    return SelectionCommand(
        request_id=request_id or str(uuid4()),
        scenario_version_id=config.scenario_version_id,
        stage_id=state.current_stage_id,
        choice_id=choice_id,
    )


def choose(config: ScenarioConfig, state: TrainingState, choice_id: str) -> TrainingState:
    return apply_selection(config, state, command(config, state, choice_id)).state


def test_start_training_locks_version_and_initializes_state() -> None:
    config = load_customer_refund_config()

    state = start_training(config)

    assert state.scenario_version_id == config.scenario_version_id
    assert state.current_stage_id == config.initial_stage_id
    assert state.normal_round_count == 0
    assert state.events == ()
    assert state.processed_receipts == ()
    assert state.end_state is None
    assert state.end_reason is None


def test_normal_safe_path_completes_with_deterministic_events() -> None:
    config = load_customer_refund_config()
    state = start_training(config)

    for choice_id in (
        "verify_via_official_channel",
        "continue_without_disclosure",
        "require_original_route_refund",
        "refuse_sensitive_actions",
        "pause_and_verify",
    ):
        state = choose(config, state, choice_id)

    assert state.end_state == EndState.COMPLETED_SAFE
    assert state.current_stage_id is None
    assert state.normal_round_count == 5
    assert [event.event_type for event in state.events] == [
        "official_channel_verification",
        "personal_information_withheld",
        "original_route_refund_recognized",
        "sensitive_request_refused",
        "sensitive_request_refused",
        "paused_under_pressure",
        "suspicious_contact_ended",
    ]
    assert all(event.scoring_eligible for event in state.events)


def test_severe_negative_event_overrides_safe_candidate_to_risky() -> None:
    config = load_customer_refund_config()
    state = start_training(config)

    for choice_id in (
        "verify_via_official_channel",
        "continue_without_disclosure",
        "require_original_route_refund",
        "share_verification_code",
        "pause_and_verify",
    ):
        state = choose(config, state, choice_id)

    assert state.end_state == EndState.COMPLETED_RISKY
    assert "verification_code_shared" in {event.event_type for event in state.events}


@pytest.mark.parametrize(
    ("preceding_choices", "expected_stage"),
    [
        ((), "customer_identity"),
        (("verify_via_official_channel",), "order_anomaly"),
        (
            ("verify_via_official_channel", "continue_without_disclosure"),
            "refund_offer",
        ),
        (
            (
                "verify_via_official_channel",
                "continue_without_disclosure",
                "require_original_route_refund",
            ),
            "sensitive_action",
        ),
        (
            (
                "verify_via_official_channel",
                "continue_without_disclosure",
                "require_original_route_refund",
                "refuse_sensitive_actions",
            ),
            "time_pressure",
        ),
    ],
)
def test_end_training_stops_safely_at_any_stage_without_counting_a_normal_round(
    preceding_choices: tuple[str, ...], expected_stage: str
) -> None:
    config = load_customer_refund_config()
    state = start_training(config)
    for choice_id in preceding_choices:
        state = choose(config, state, choice_id)
    assert state.current_stage_id == expected_stage

    result = apply_selection(config, state, command(config, state, "end_training"))

    assert result.state.end_state == EndState.SAFETY_STOPPED
    assert result.state.end_reason == "user_ended"
    assert result.state.current_stage_id is None
    assert result.state.normal_round_count == len(preceding_choices)
    assert [event.event_type for event in result.emitted_events] == ["training_ended_by_user"]
    assert not result.emitted_events[0].scoring_eligible


def test_new_request_after_end_is_rejected_without_mutating_state() -> None:
    config = load_customer_refund_config()
    initial = start_training(config)
    ended = choose(config, initial, "end_training")
    attempted = SelectionCommand(
        request_id="after-end",
        scenario_version_id=config.scenario_version_id,
        stage_id=config.initial_stage_id,
        choice_id="verify_via_official_channel",
    )

    with pytest.raises(TrainingAlreadyEndedError, match="already ended"):
        apply_selection(config, ended, attempted)

    assert ended.normal_round_count == 0
    assert len(ended.events) == 1


def test_command_must_match_locked_scenario_version() -> None:
    config = load_customer_refund_config()
    state = start_training(config)
    mismatched = replace(command(config, state, "end_training"), scenario_version_id=uuid4())

    with pytest.raises(ScenarioVersionMismatchError, match="scenario version"):
        apply_selection(config, state, mismatched)

    assert state.scenario_version_id == config.scenario_version_id


def test_defensive_maximum_round_limit_rejects_without_event() -> None:
    config = load_customer_refund_config()
    state = replace(start_training(config), normal_round_count=len(config.stages))
    original_events = state.events

    with pytest.raises(MaximumRoundsExceededError, match="maximum normal rounds"):
        apply_selection(
            config,
            state,
            command(config, state, "verify_via_official_channel"),
        )

    assert state.events is original_events
    assert state.end_state is None


def test_same_request_and_command_replays_receipt_without_advancing() -> None:
    config = load_customer_refund_config()
    initial = start_training(config)
    original_command = command(
        config,
        initial,
        "verify_via_official_channel",
        request_id="stable-request",
    )
    first = apply_selection(config, initial, original_command)

    replay = apply_selection(config, first.state, original_command)

    assert replay.idempotent_replay
    assert replay.state == first.state
    assert replay.receipt == first.receipt
    assert replay.emitted_events == ()
    assert replay.state.normal_round_count == 1
    assert len(replay.state.events) == 1


def test_same_request_with_different_command_is_a_conflict() -> None:
    config = load_customer_refund_config()
    initial = start_training(config)
    first = apply_selection(
        config,
        initial,
        command(
            config,
            initial,
            "verify_via_official_channel",
            request_id="conflicting-request",
        ),
    )
    conflicting = SelectionCommand(
        request_id="conflicting-request",
        scenario_version_id=config.scenario_version_id,
        stage_id="order_anomaly",
        choice_id="continue_without_disclosure",
    )

    with pytest.raises(RequestConflictError, match="request ID"):
        apply_selection(config, first.state, conflicting)

    assert len(first.state.events) == 1


def test_unknown_choice_and_wrong_stage_are_distinct_errors() -> None:
    config = load_customer_refund_config()
    state = start_training(config)

    with pytest.raises(UnknownSelectionError, match="unknown selection"):
        apply_selection(config, state, command(config, state, "missing_choice"))

    wrong_stage = replace(command(config, state, "end_training"), stage_id="order_anomaly")
    with pytest.raises(StageMismatchError, match="current stage"):
        apply_selection(config, state, wrong_stage)


def test_all_customer_refund_normal_paths_end_within_stage_limit() -> None:
    config = load_customer_refund_config()
    choices_by_stage = [stage.choices for stage in config.stages]
    all_paths = list(product(*choices_by_stage))

    assert len(all_paths) == 324
    for path_index, path in enumerate(all_paths):
        state = start_training(config)
        for round_index, choice_config in enumerate(path, start=1):
            assert state.end_state is None
            assert state.current_stage_id is not None
            result = apply_selection(
                config,
                state,
                command(
                    config,
                    state,
                    choice_config.choice_id,
                    request_id=f"path-{path_index}-round-{round_index}",
                ),
            )
            state = result.state
            assert state.normal_round_count <= len(config.stages)

            if choice_config.transition.target_kind == TransitionTargetKind.END:
                break

        assert state.end_state is not None
        assert state.normal_round_count <= len(config.stages)
