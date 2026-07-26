"""Immutable domain types for deterministic training transitions."""

from dataclasses import dataclass
from uuid import UUID

from app.scenarios.schemas import (
    Dimension,
    Direction,
    EndState,
    EvidenceSource,
    Severity,
)


@dataclass(frozen=True, slots=True)
class EmittedEvent:
    event_type: str
    evidence_source: EvidenceSource
    scoring_eligible: bool
    evidence_summary: str
    dimension: Dimension | None = None
    direction: Direction | None = None
    severity: Severity | None = None
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
    emitted_events: tuple[EmittedEvent, ...]


@dataclass(frozen=True, slots=True)
class TrainingState:
    scenario_version_id: UUID
    current_stage_id: str | None
    normal_round_count: int
    events: tuple[EmittedEvent, ...]
    processed_receipts: tuple[SelectionReceipt, ...]
    end_state: EndState | None
    end_reason: str | None


@dataclass(frozen=True, slots=True)
class TransitionResult:
    state: TrainingState
    receipt: SelectionReceipt
    emitted_events: tuple[EmittedEvent, ...]
    idempotent_replay: bool = False


class TrainingDomainError(ValueError):
    """Base class for an invalid training transition."""


class ScenarioVersionMismatchError(TrainingDomainError):
    """Raised when a command does not reference the locked scenario version."""


class StageMismatchError(TrainingDomainError):
    """Raised when a command does not reference the current stage."""


class UnknownSelectionError(TrainingDomainError):
    """Raised when a choice is unavailable in the current stage."""


class TrainingAlreadyEndedError(TrainingDomainError):
    """Raised when a new request targets an ended training."""


class MaximumRoundsExceededError(TrainingDomainError):
    """Raised when a malformed session has exhausted its defensive round limit."""


class RequestConflictError(TrainingDomainError):
    """Raised when a request ID is reused for a different command."""
