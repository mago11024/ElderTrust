"""Pure deterministic state transitions for training sessions."""

import hashlib
import json
from dataclasses import replace

from app.scenarios.schemas import (
    BehaviorMapping,
    ChoiceConfig,
    EndConditionType,
    EndState,
    SafetyChoiceConfig,
    ScenarioConfig,
    TransitionTargetKind,
)
from app.training.domain import (
    EmittedEvent,
    MaximumRoundsExceededError,
    RequestConflictError,
    ScenarioConfigurationMismatchError,
    ScenarioVersionMismatchError,
    SelectionCommand,
    SelectionReceipt,
    StageMismatchError,
    TrainingAlreadyEndedError,
    TrainingState,
    TransitionResult,
    UnknownSelectionError,
)


def start_training(config: ScenarioConfig) -> TrainingState:
    """Create an empty training state locked to one scenario version."""

    return TrainingState(
        scenario_version_id=config.scenario_version_id,
        scenario_config_fingerprint=_scenario_config_fingerprint(config),
        current_stage_id=config.initial_stage_id,
        normal_round_count=0,
        events=(),
        processed_receipts=(),
        end_state=None,
        end_reason=None,
    )


def apply_selection(
    config: ScenarioConfig,
    state: TrainingState,
    command: SelectionCommand,
) -> TransitionResult:
    """Apply one deterministic selection without reading or mutating external state."""

    replay = _find_receipt(state, command.request_id)
    if replay is not None:
        if replay.command != command:
            raise RequestConflictError(
                f"request ID {command.request_id!r} was already used for a different command"
            )
        return TransitionResult(
            state=state,
            receipt=replay,
            newly_emitted_events=(),
            idempotent_replay=True,
        )

    if (
        config.scenario_version_id != state.scenario_version_id
        or command.scenario_version_id != state.scenario_version_id
    ):
        raise ScenarioVersionMismatchError(
            f"scenario version must match locked version {state.scenario_version_id}"
        )
    if _scenario_config_fingerprint(config) != state.scenario_config_fingerprint:
        raise ScenarioConfigurationMismatchError(
            "scenario configuration does not match the content locked at training start"
        )
    if state.end_state is not None:
        raise TrainingAlreadyEndedError(f"training already ended as {state.end_state}")
    if command.stage_id != state.current_stage_id:
        raise StageMismatchError(
            f"command stage {command.stage_id!r} does not match current stage "
            f"{state.current_stage_id!r}"
        )

    safety_choice = next(
        (
            choice
            for choice in config.global_safety_choices
            if choice.choice_id == command.choice_id
        ),
        None,
    )
    if safety_choice is not None:
        return _apply_safety_choice(state, command, safety_choice)

    if state.normal_round_count >= len(config.stages):
        raise MaximumRoundsExceededError(
            f"maximum normal rounds ({len(config.stages)}) already reached"
        )

    stage = next(
        (stage for stage in config.stages if stage.stage_id == state.current_stage_id),
        None,
    )
    if stage is None:
        raise StageMismatchError(f"current stage {state.current_stage_id!r} is not configured")
    choice = next(
        (choice for choice in stage.choices if choice.choice_id == command.choice_id),
        None,
    )
    if choice is None:
        raise UnknownSelectionError(
            f"unknown selection {command.choice_id!r} for stage {stage.stage_id!r}"
        )
    return _apply_normal_choice(config, state, command, choice)


def _find_receipt(state: TrainingState, request_id: str) -> SelectionReceipt | None:
    return next(
        (
            receipt
            for receipt in state.processed_receipts
            if receipt.command.request_id == request_id
        ),
        None,
    )


def _scenario_config_fingerprint(config: ScenarioConfig) -> str:
    canonical_json = json.dumps(
        config.model_dump(mode="json"),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )
    return hashlib.sha256(canonical_json.encode("utf-8")).hexdigest()


def _apply_safety_choice(
    state: TrainingState,
    command: SelectionCommand,
    choice: SafetyChoiceConfig,
) -> TransitionResult:
    emitted_events = tuple(
        EmittedEvent(
            event_type=mapping.event_type,
            evidence_source=mapping.evidence_source,
            scoring_eligible=mapping.scoring_eligible,
            evidence_summary=mapping.evidence_summary,
        )
        for mapping in choice.control_events
    )
    return _complete_transition(
        state=state,
        command=command,
        emitted_events=emitted_events,
        current_stage_id=None,
        normal_round_count=state.normal_round_count,
        end_state=EndState(choice.transition.target_id),
        end_reason=choice.end_reason,
    )


def _apply_normal_choice(
    config: ScenarioConfig,
    state: TrainingState,
    command: SelectionCommand,
    choice: ChoiceConfig,
) -> TransitionResult:
    emitted_events = tuple(_behavior_event(mapping) for mapping in choice.behavior_mappings)
    normal_round_count = state.normal_round_count + 1
    if choice.transition.target_kind == TransitionTargetKind.STAGE:
        return _complete_transition(
            state=state,
            command=command,
            emitted_events=emitted_events,
            current_stage_id=choice.transition.target_id,
            normal_round_count=normal_round_count,
            end_state=None,
            end_reason=None,
        )

    candidate_end_state = EndState(choice.transition.target_id)
    end_state = _apply_risk_override(
        config,
        candidate_end_state,
        state.events + emitted_events,
    )
    return _complete_transition(
        state=state,
        command=command,
        emitted_events=emitted_events,
        current_stage_id=None,
        normal_round_count=normal_round_count,
        end_state=end_state,
        end_reason=None,
    )


def _behavior_event(mapping: BehaviorMapping) -> EmittedEvent:
    return EmittedEvent(
        event_type=mapping.event_type,
        evidence_source=mapping.evidence_source,
        scoring_eligible=True,
        evidence_summary=mapping.evidence_summary,
        dimension=mapping.dimension,
        direction=mapping.direction,
        severity=mapping.severity,
        opportunity_id=mapping.opportunity_id,
    )


def _apply_risk_override(
    config: ScenarioConfig,
    candidate: EndState,
    events: tuple[EmittedEvent, ...],
) -> EndState:
    event_types = {event.event_type for event in events}
    for condition in config.end_conditions:
        if condition.condition_type == EndConditionType.RISK_OVERRIDE and event_types.intersection(
            condition.triggering_event_types
        ):
            return condition.end_state
    return candidate


def _complete_transition(
    *,
    state: TrainingState,
    command: SelectionCommand,
    emitted_events: tuple[EmittedEvent, ...],
    current_stage_id: str | None,
    normal_round_count: int,
    end_state: EndState | None,
    end_reason: str | None,
) -> TransitionResult:
    receipt = SelectionReceipt(command=command, original_events=emitted_events)
    next_state = replace(
        state,
        current_stage_id=current_stage_id,
        normal_round_count=normal_round_count,
        events=state.events + emitted_events,
        processed_receipts=state.processed_receipts + (receipt,),
        end_state=end_state,
        end_reason=end_reason,
    )
    return TransitionResult(
        state=next_state,
        receipt=receipt,
        newly_emitted_events=emitted_events,
    )
