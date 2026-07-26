# T01-06 Pure Training State Machine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic, idempotent, framework-free training state machine that locks the scenario version and terminates every customer-refund path within the configured stage bound.

**Architecture:** Frozen dataclasses in `training/domain.py` represent commands, emitted events, receipts, and immutable session state. Pure functions in `training/state_machine.py` create initial state and apply one configured choice without FastAPI, persistence, or AI dependencies. Processed request receipts make retries idempotent, while scenario end conditions deterministically apply the risky-completion override.

**Tech Stack:** Python 3.12, standard-library dataclasses and UUIDs, Pydantic scenario configuration models, pytest 8/9, Ruff, mypy strict mode.

---

## File map

- Create `backend/app/training/__init__.py`: mark the training domain package.
- Create `backend/app/training/domain.py`: immutable state, commands, receipts, emitted events, and domain errors.
- Create `backend/app/training/state_machine.py`: pure initialization and transition functions.
- Create `backend/tests/unit/training/__init__.py`: mark the unit-test package.
- Create `backend/tests/unit/training/test_state_machine.py`: focused TDD and exhaustive path tests.
- Modify `docs/CURRENT_STATUS.md`: move T01-06 from `ready/in_progress` to `completed` only after fresh verification.

The implementation must not modify scenario schemas, validation, seed JSON, scoring, safety keyword rules, persistence, HTTP, or AI modules.

### Task 1: Mark T01-06 active and define initial immutable state

**Files:**
- Create: `backend/app/training/__init__.py`
- Create: `backend/app/training/domain.py`
- Create: `backend/app/training/state_machine.py`
- Create: `backend/tests/unit/training/__init__.py`
- Create: `backend/tests/unit/training/test_state_machine.py`
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Mark the Task in progress**

Change only the dynamic fields in `docs/CURRENT_STATUS.md`:

```yaml
current_task: T01-06
status: in_progress
last_completed_task: T01-05
next_task: null
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
```

Keep the T01-05 verification record until T01-06 has fresh evidence.

- [ ] **Step 2: Write the failing initialization test**

Create empty package files and start `backend/tests/unit/training/test_state_machine.py` with:

```python
from pathlib import Path

from app.scenarios.schemas import load_scenario_config
from app.training.state_machine import start_training

SEED_PATH = (
    Path(__file__).resolve().parents[3]
    / "app"
    / "scenarios"
    / "seeds"
    / "customer_refund_v1.json"
)


def test_starts_at_locked_scenario_version_and_initial_stage() -> None:
    config = load_scenario_config(SEED_PATH)

    state = start_training(config)

    assert state.scenario_version_id == config.scenario_version_id
    assert state.current_stage_id == config.initial_stage_id
    assert state.round_count == 0
    assert state.events == ()
    assert state.receipts == ()
    assert state.end_state is None
    assert state.end_reason is None
```

- [ ] **Step 3: Run the test and verify the expected RED state**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py::test_starts_at_locked_scenario_version_and_initial_stage -q
```

Expected: FAIL during collection because `app.training.state_machine` or `start_training` does not exist.

- [ ] **Step 4: Implement the minimum immutable initial state**

Create `backend/app/training/domain.py`:

```python
"""Immutable domain values for deterministic training transitions."""

from dataclasses import dataclass
from uuid import UUID

from app.scenarios.schemas import EndState


@dataclass(frozen=True, slots=True)
class TrainingState:
    scenario_version_id: UUID
    current_stage_id: str | None
    round_count: int = 0
    events: tuple["EmittedEvent", ...] = ()
    receipts: tuple["SelectionReceipt", ...] = ()
    end_state: EndState | None = None
    end_reason: str | None = None


@dataclass(frozen=True, slots=True)
class EmittedEvent:
    event_type: str
    evidence_source: str
    evidence_summary: str
    scoring_eligible: bool
    dimension: str | None = None
    direction: str | None = None
    severity: str | None = None
    opportunity_id: str | None = None


@dataclass(frozen=True, slots=True)
class SelectionCommand:
    request_id: str
    scenario_version_id: UUID
    stage_id: str
    choice_id: str


@dataclass(frozen=True, slots=True)
class SelectionReceipt:
    command: SelectionCommand
    events: tuple[EmittedEvent, ...]
    resulting_stage_id: str | None
    end_state: EndState | None
    end_reason: str | None
    round_count: int


@dataclass(frozen=True, slots=True)
class TransitionResult:
    state: TrainingState
    receipt: SelectionReceipt
    idempotent_replay: bool = False
```

Create `backend/app/training/state_machine.py`:

```python
"""Pure state transitions for configured anti-fraud training."""

from app.scenarios.schemas import ScenarioConfig
from app.training.domain import TrainingState


def start_training(config: ScenarioConfig) -> TrainingState:
    return TrainingState(
        scenario_version_id=config.scenario_version_id,
        current_stage_id=config.initial_stage_id,
    )
```

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py::test_starts_at_locked_scenario_version_and_initial_stage -q
```

Expected: `1 passed`.

- [ ] **Step 6: Commit the initial domain state**

```powershell
git add -- docs/CURRENT_STATUS.md backend/app/training backend/tests/unit/training
git commit -m "feat: start pure training state machine"
```

### Task 2: Implement configured normal transitions and risky completion override

**Files:**
- Modify: `backend/app/training/domain.py`
- Modify: `backend/app/training/state_machine.py`
- Modify: `backend/tests/unit/training/test_state_machine.py`

- [ ] **Step 1: Add failing normal-completion and risky-override tests**

Append:

```python
from uuid import uuid4

from app.scenarios.schemas import EndState, ScenarioConfig
from app.training.domain import (
    SelectionCommand,
    TrainingState,
    TransitionResult,
)
from app.training.state_machine import apply_selection


def submit(
    config: ScenarioConfig,
    state: TrainingState,
    choice_id: str,
) -> TransitionResult:
    assert state.current_stage_id is not None
    return apply_selection(
        config,
        state,
        SelectionCommand(
            request_id=str(uuid4()),
            scenario_version_id=config.scenario_version_id,
            stage_id=state.current_stage_id,
            choice_id=choice_id,
        ),
    )


def test_completes_customer_refund_safe_path() -> None:
    config = load_scenario_config(SEED_PATH)
    state = start_training(config)

    for choice_id in (
        "verify_via_official_channel",
        "continue_without_disclosure",
        "require_original_route_refund",
        "refuse_sensitive_actions",
        "pause_and_verify",
    ):
        state = submit(config, state, choice_id).state

    assert state.current_stage_id is None
    assert state.end_state == EndState.COMPLETED_SAFE
    assert state.round_count == 5
    assert [event.event_type for event in state.events] == [
        "official_channel_verification",
        "personal_information_withheld",
        "original_route_refund_recognized",
        "sensitive_request_refused",
        "sensitive_request_refused",
        "paused_under_pressure",
        "suspicious_contact_ended",
    ]


def test_severe_negative_event_overrides_safe_end_candidate() -> None:
    config = load_scenario_config(SEED_PATH)
    state = start_training(config)

    for choice_id in (
        "listen_without_verifying",
        "disclose_order_details",
        "accept_unverified_refund",
        "share_verification_code",
        "pause_and_verify",
    ):
        state = submit(config, state, choice_id).state

    assert state.end_state == EndState.COMPLETED_RISKY
    assert "verification_code_shared" in {event.event_type for event in state.events}
```

- [ ] **Step 2: Run both tests and verify RED**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py::test_completes_customer_refund_safe_path tests/unit/training/test_state_machine.py::test_severe_negative_event_overrides_safe_end_candidate -q
```

Expected: FAIL because `apply_selection` is not defined.

- [ ] **Step 3: Add explicit transition errors**

Append to `backend/app/training/domain.py`:

```python
class TrainingTransitionError(ValueError):
    """Base class for rejected training transitions."""


class ScenarioVersionMismatchError(TrainingTransitionError):
    """The command or config does not match the locked scenario version."""


class StageMismatchError(TrainingTransitionError):
    """The command does not target the active stage."""


class UnknownChoiceError(TrainingTransitionError):
    """The choice is not available in the active stage."""


class TrainingAlreadyEndedError(TrainingTransitionError):
    """No transition is allowed after a terminal state."""


class MaximumRoundsExceededError(TrainingTransitionError):
    """The defensive ordinary-round bound has been reached."""


class RequestConflictError(TrainingTransitionError):
    """One request identifier was reused with different command content."""
```

- [ ] **Step 4: Implement normal configured transitions**

Add to `backend/app/training/state_machine.py`:

```python
from dataclasses import replace

from app.scenarios.schemas import (
    BehaviorMapping,
    EndConditionType,
    EndState,
    ScenarioConfig,
    TransitionTargetKind,
)
from app.training.domain import (
    EmittedEvent,
    SelectionCommand,
    SelectionReceipt,
    StageMismatchError,
    TrainingAlreadyEndedError,
    TrainingState,
    TransitionResult,
    UnknownChoiceError,
)


def _behavior_event(mapping: BehaviorMapping) -> EmittedEvent:
    return EmittedEvent(
        event_type=mapping.event_type,
        evidence_source=mapping.evidence_source.value,
        evidence_summary=mapping.evidence_summary,
        scoring_eligible=True,
        dimension=mapping.dimension.value,
        direction=mapping.direction.value,
        severity=mapping.severity.value,
        opportunity_id=mapping.opportunity_id,
    )


def _ordinary_end_state(
    config: ScenarioConfig,
    candidate: EndState,
    events: tuple[EmittedEvent, ...],
) -> EndState:
    risk_event_types = {
        event_type
        for condition in config.end_conditions
        if condition.condition_type == EndConditionType.RISK_OVERRIDE
        for event_type in condition.triggering_event_types
    }
    if any(event.event_type in risk_event_types for event in events):
        return EndState.COMPLETED_RISKY
    return candidate


def apply_selection(
    config: ScenarioConfig,
    state: TrainingState,
    command: SelectionCommand,
) -> TransitionResult:
    if state.end_state is not None:
        raise TrainingAlreadyEndedError("training has already ended")
    if command.stage_id != state.current_stage_id:
        raise StageMismatchError(
            f"expected stage '{state.current_stage_id}', got '{command.stage_id}'"
        )

    stage = next(item for item in config.stages if item.stage_id == state.current_stage_id)
    choice = next((item for item in stage.choices if item.choice_id == command.choice_id), None)
    if choice is None:
        raise UnknownChoiceError(
            f"choice '{command.choice_id}' is not available in stage '{stage.stage_id}'"
        )

    new_events = tuple(_behavior_event(mapping) for mapping in choice.behavior_mappings)
    all_events = state.events + new_events
    next_stage_id: str | None
    end_state: EndState | None
    if choice.transition.target_kind == TransitionTargetKind.STAGE:
        next_stage_id = choice.transition.target_id
        end_state = None
    else:
        next_stage_id = None
        end_state = _ordinary_end_state(
            config,
            EndState(choice.transition.target_id),
            all_events,
        )

    receipt = SelectionReceipt(
        command=command,
        events=new_events,
        resulting_stage_id=next_stage_id,
        end_state=end_state,
        end_reason=None,
        round_count=state.round_count + 1,
    )
    next_state = replace(
        state,
        current_stage_id=next_stage_id,
        round_count=receipt.round_count,
        events=all_events,
        receipts=state.receipts + (receipt,),
        end_state=end_state,
    )
    return TransitionResult(state=next_state, receipt=receipt)
```

Keep one consolidated import block after editing; do not leave the earlier duplicate `ScenarioConfig` or `TrainingState` imports.

- [ ] **Step 5: Run the normal transition tests and verify GREEN**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py -q
```

Expected: all current tests pass.

- [ ] **Step 6: Commit normal transitions**

```powershell
git add -- backend/app/training backend/tests/unit/training/test_state_machine.py
git commit -m "feat: apply configured training choices"
```

### Task 3: Enforce version lock, safety exit, maximum rounds, and idempotency

**Files:**
- Modify: `backend/app/training/state_machine.py`
- Modify: `backend/tests/unit/training/test_state_machine.py`

- [ ] **Step 1: Add failing boundary tests**

Append:

```python
from dataclasses import replace

import pytest

from app.training.domain import (
    MaximumRoundsExceededError,
    RequestConflictError,
    ScenarioVersionMismatchError,
    TrainingAlreadyEndedError,
)


def test_end_training_stops_immediately_without_scoring_event() -> None:
    config = load_scenario_config(SEED_PATH)
    state = start_training(config)
    command = SelectionCommand(
        request_id="end-request",
        scenario_version_id=config.scenario_version_id,
        stage_id=config.initial_stage_id,
        choice_id="end_training",
    )

    result = apply_selection(config, state, command)

    assert result.state.end_state == EndState.SAFETY_STOPPED
    assert result.state.end_reason == "user_ended"
    assert result.state.round_count == 0
    assert [event.event_type for event in result.receipt.events] == [
        "training_ended_by_user"
    ]
    assert all(not event.scoring_eligible for event in result.receipt.events)
    with pytest.raises(TrainingAlreadyEndedError):
        apply_selection(config, result.state, replace(command, request_id="after-end"))


def test_rejects_config_or_command_outside_locked_scenario_version() -> None:
    config = load_scenario_config(SEED_PATH)
    state = start_training(config)
    changed_config = config.model_copy(
        update={"scenario_version_id": uuid4()},
        deep=True,
    )
    command = SelectionCommand(
        request_id="wrong-version",
        scenario_version_id=changed_config.scenario_version_id,
        stage_id=config.initial_stage_id,
        choice_id="verify_via_official_channel",
    )

    with pytest.raises(ScenarioVersionMismatchError):
        apply_selection(changed_config, state, command)


def test_replays_identical_request_without_duplicating_state_events() -> None:
    config = load_scenario_config(SEED_PATH)
    state = start_training(config)
    command = SelectionCommand(
        request_id="stable-request",
        scenario_version_id=config.scenario_version_id,
        stage_id=config.initial_stage_id,
        choice_id="verify_via_official_channel",
    )
    first = apply_selection(config, state, command)

    replay = apply_selection(config, first.state, command)

    assert replay.idempotent_replay is True
    assert replay.receipt == first.receipt
    assert replay.state == first.state
    assert replay.state.events == first.state.events


def test_rejects_request_id_reused_for_different_choice() -> None:
    config = load_scenario_config(SEED_PATH)
    state = start_training(config)
    first_command = SelectionCommand(
        request_id="conflicting-request",
        scenario_version_id=config.scenario_version_id,
        stage_id=config.initial_stage_id,
        choice_id="verify_via_official_channel",
    )
    first = apply_selection(config, state, first_command)

    with pytest.raises(RequestConflictError):
        apply_selection(
            config,
            first.state,
            replace(first_command, choice_id="listen_without_verifying"),
        )


def test_rejects_abnormal_state_at_derived_maximum_rounds_without_events() -> None:
    config = load_scenario_config(SEED_PATH)
    state = replace(
        start_training(config),
        round_count=len(config.stages),
    )
    command = SelectionCommand(
        request_id="over-limit",
        scenario_version_id=config.scenario_version_id,
        stage_id=config.initial_stage_id,
        choice_id="verify_via_official_channel",
    )

    with pytest.raises(MaximumRoundsExceededError):
        apply_selection(config, state, command)

    assert state.events == ()
    assert state.receipts == ()
```

- [ ] **Step 2: Run the boundary tests and verify RED**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py -q
```

Expected: FAIL for missing version, safety, replay, conflict, and maximum-round handling.

- [ ] **Step 3: Implement checks in deterministic order**

Extend imports in `state_machine.py` with `ControlEventMapping`, `ScenarioVersionMismatchError`, `RequestConflictError`, and `MaximumRoundsExceededError`. Add:

```python
def _control_event(mapping: ControlEventMapping) -> EmittedEvent:
    return EmittedEvent(
        event_type=mapping.event_type,
        evidence_source=mapping.evidence_source.value,
        evidence_summary=mapping.evidence_summary,
        scoring_eligible=mapping.scoring_eligible,
    )


def _replay_or_conflict(
    state: TrainingState,
    command: SelectionCommand,
) -> TransitionResult | None:
    receipt = next(
        (
            item
            for item in state.receipts
            if item.command.request_id == command.request_id
        ),
        None,
    )
    if receipt is None:
        return None
    if receipt.command != command:
        raise RequestConflictError(
            f"request '{command.request_id}' conflicts with its first command"
        )
    return TransitionResult(
        state=state,
        receipt=receipt,
        idempotent_replay=True,
    )
```

At the start of `apply_selection`, enforce this order:

```python
    replay = _replay_or_conflict(state, command)
    if replay is not None:
        return replay
    if (
        config.scenario_version_id != state.scenario_version_id
        or command.scenario_version_id != state.scenario_version_id
    ):
        raise ScenarioVersionMismatchError("scenario version does not match the session lock")
    if state.end_state is not None:
        raise TrainingAlreadyEndedError("training has already ended")
    if command.stage_id != state.current_stage_id:
        raise StageMismatchError(
            f"expected stage '{state.current_stage_id}', got '{command.stage_id}'"
        )
```

Resolve global safety choices before the ordinary-round limit and ordinary stage choices:

```python
    safety_choice = next(
        (
            item
            for item in config.global_safety_choices
            if item.choice_id == command.choice_id
        ),
        None,
    )
    if safety_choice is not None:
        new_events = tuple(
            _control_event(mapping) for mapping in safety_choice.control_events
        )
        end_state = EndState(safety_choice.transition.target_id)
        receipt = SelectionReceipt(
            command=command,
            events=new_events,
            resulting_stage_id=None,
            end_state=end_state,
            end_reason=safety_choice.end_reason,
            round_count=state.round_count,
        )
        next_state = replace(
            state,
            current_stage_id=None,
            events=state.events + new_events,
            receipts=state.receipts + (receipt,),
            end_state=end_state,
            end_reason=safety_choice.end_reason,
        )
        return TransitionResult(state=next_state, receipt=receipt)

    if state.round_count >= len(config.stages):
        raise MaximumRoundsExceededError(
            f"maximum ordinary rounds reached: {len(config.stages)}"
        )
```

The existing ordinary transition code follows these guards unchanged.

- [ ] **Step 4: Run boundary and focused tests and verify GREEN**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py -q
```

Expected: all current tests pass.

- [ ] **Step 5: Commit transition boundaries**

```powershell
git add -- backend/app/training backend/tests/unit/training/test_state_machine.py
git commit -m "feat: guard and replay training transitions"
```

### Task 4: Prove every customer-refund configuration path ends

**Files:**
- Modify: `backend/tests/unit/training/test_state_machine.py`

- [ ] **Step 1: Add the exhaustive configured-path test**

Append:

```python
def walk_paths(
    config: ScenarioConfig,
    state: TrainingState,
) -> list[TrainingState]:
    if state.end_state is not None:
        return [state]
    assert state.current_stage_id is not None
    stage = next(
        item for item in config.stages if item.stage_id == state.current_stage_id
    )
    terminal_states: list[TrainingState] = []
    for index, choice in enumerate(stage.choices):
        result = apply_selection(
            config,
            state,
            SelectionCommand(
                request_id=f"path-{state.round_count}-{index}-{choice.choice_id}",
                scenario_version_id=config.scenario_version_id,
                stage_id=stage.stage_id,
                choice_id=choice.choice_id,
            ),
        )
        terminal_states.extend(walk_paths(config, result.state))
    return terminal_states


def test_every_customer_refund_ordinary_path_ends_within_stage_bound() -> None:
    config = load_scenario_config(SEED_PATH)

    terminal_states = walk_paths(config, start_training(config))

    expected_path_count = 1
    for stage in config.stages:
        expected_path_count *= len(stage.choices)
    assert len(terminal_states) == expected_path_count
    assert {state.end_state for state in terminal_states} <= {
        EndState.COMPLETED_SAFE,
        EndState.COMPLETED_RISKY,
    }
    assert all(state.round_count <= len(config.stages) for state in terminal_states)
    assert all(state.current_stage_id is None for state in terminal_states)
```

- [ ] **Step 2: Run the exhaustive test**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py::test_every_customer_refund_ordinary_path_ends_within_stage_bound -q
```

Expected: PASS and 324 terminal paths for the current seed.

- [ ] **Step 3: Run focused quality checks**

Run:

```powershell
cd backend
python -m ruff check app/training tests/unit/training
python -m ruff format --check app/training tests/unit/training
python -m mypy app/training tests/unit/training
python -m pytest tests/unit/training/test_state_machine.py -q
```

Expected: all commands exit 0.

- [ ] **Step 4: Commit exhaustive proof and focused cleanup**

```powershell
git add -- backend/app/training backend/tests/unit/training/test_state_machine.py
git commit -m "test: prove configured training paths terminate"
```

### Task 5: Run acceptance and regression, then complete T01-06

**Files:**
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Run the Task acceptance command**

Run:

```powershell
cd backend
python -m pytest tests/unit/training/test_state_machine.py -q
```

Expected: all T01-06 tests pass.

- [ ] **Step 2: Run affected scenario regression**

Run:

```powershell
cd backend
python -m pytest tests/unit/scenarios -q
```

Expected: all scenario schema and validation tests pass.

- [ ] **Step 3: Run the complete repository regression once**

From the repository root, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1
```

Expected: exit 0 with all repository checks passing.

- [ ] **Step 4: Update the dynamic status only after fresh evidence**

Set:

```yaml
current_task: T01-06
status: completed
last_completed_task: T01-06
next_task: T01-07
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
last_verification:
  command: scripts/test.ps1 + T01-06 focused acceptance
  result: passed
  verified_at: 2026-07-26
updated_at: 2026-07-26
```

- [ ] **Step 5: Validate the final diff and commit completion**

Run:

```powershell
git diff --check
git status --short
```

Confirm only T01-06 files and the pre-existing unrelated untracked files appear. Then:

```powershell
git add -- docs/CURRENT_STATUS.md
git commit -m "chore: complete T01-06"
```

Do not stage `_tmp_*`, `backend/anxin_training_backend.egg-info/`, or any unrelated user file.
