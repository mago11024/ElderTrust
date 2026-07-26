"""Pydantic models for versioned training-scenario configuration."""

from enum import StrEnum
from pathlib import Path
from typing import Annotated, Literal, Self

from pydantic import (
    UUID4,
    AfterValidator,
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    PositiveInt,
    StringConstraints,
    ValidationInfo,
    model_validator,
)


def validate_non_blank(value: str) -> str:
    """Reject blank strings without changing the supplied content."""

    if not value.strip():
        raise ValueError("string must contain non-whitespace characters")
    return value


NonEmptyString = Annotated[str, StringConstraints(min_length=1), AfterValidator(validate_non_blank)]
StableIdentifier = Annotated[str, StringConstraints(pattern=r"^[a-z][a-z0-9_]*$", min_length=1)]
OpportunityIdentifier = Annotated[
    str, StringConstraints(pattern=r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$", min_length=3)
]
Percentage = Annotated[PositiveInt, Field(le=100)]


def validate_canonical_uuid4_text(value: object, info: ValidationInfo) -> object:
    """Require lowercase, hyphenated UUID-v4 JSON text before UUID parsing."""

    if info.mode != "json":
        return value
    if not isinstance(value, str) or len(value) != 36:
        raise ValueError("UUID v4 must use lowercase hyphenated JSON text")
    if value[8] != "-" or value[13] != "-" or value[18] != "-" or value[23] != "-":
        raise ValueError("UUID v4 must use lowercase hyphenated JSON text")
    if value != value.lower():
        raise ValueError("UUID v4 must use lowercase hyphenated JSON text")
    return value


CanonicalUUID4 = Annotated[UUID4, BeforeValidator(validate_canonical_uuid4_text)]


class ConfigModel(BaseModel):
    """Strict shared base for every scenario configuration object."""

    model_config = ConfigDict(extra="forbid", strict=True)


class Dimension(StrEnum):
    IDENTITY_VERIFICATION = "identity_verification"
    INFORMATION_PROTECTION = "information_protection"
    PAYMENT_AWARENESS = "payment_awareness"
    PRESSURE_RESPONSE = "pressure_response"
    HELP_TERMINATION = "help_termination"


class Direction(StrEnum):
    POSITIVE = "positive"
    NEGATIVE = "negative"


class Severity(StrEnum):
    NORMAL = "normal"
    SEVERE = "severe"


class EvidenceSource(StrEnum):
    BUTTON_CHOICE = "button_choice"
    SAFETY_CONTROL = "safety_control"


class TransitionTargetKind(StrEnum):
    STAGE = "stage"
    END = "end"


class EndState(StrEnum):
    COMPLETED_SAFE = "completed_safe"
    COMPLETED_RISKY = "completed_risky"
    SAFETY_STOPPED = "safety_stopped"


class EndConditionType(StrEnum):
    NORMAL_COMPLETION = "normal_completion"
    RISK_OVERRIDE = "risk_override"
    SAFETY_STOP = "safety_stop"


class Transition(ConfigModel):
    target_kind: TransitionTargetKind
    target_id: StableIdentifier


class BehaviorMapping(ConfigModel):
    event_type: StableIdentifier
    dimension: Dimension
    direction: Direction
    severity: Severity
    opportunity_id: OpportunityIdentifier
    evidence_source: Literal[EvidenceSource.BUTTON_CHOICE]
    evidence_summary: NonEmptyString


class ChoiceConfig(ConfigModel):
    choice_id: StableIdentifier
    label: NonEmptyString
    transition: Transition
    behavior_mappings: list[BehaviorMapping] = Field(min_length=1)


class AiStrategyConfig(ConfigModel):
    mode: Literal["fixed_content"]
    enabled: Literal[False]
    allowed_response_intents: list[StableIdentifier] = Field(min_length=1)
    prohibited_actions: list[StableIdentifier] = Field(min_length=1)


class StageConfig(ConfigModel):
    stage_id: StableIdentifier
    order: PositiveInt
    title: NonEmptyString
    scripted_prompt: NonEmptyString
    ai_strategy: AiStrategyConfig
    risk_points: list[StableIdentifier] = Field(min_length=1)
    choices: list[ChoiceConfig] = Field(min_length=1)


class ControlEventMapping(ConfigModel):
    event_type: StableIdentifier
    evidence_source: Literal[EvidenceSource.SAFETY_CONTROL]
    scoring_eligible: Literal[False]
    evidence_summary: NonEmptyString


class SafetyChoiceConfig(ConfigModel):
    choice_id: StableIdentifier
    label: NonEmptyString
    transition: Transition
    end_reason: StableIdentifier
    control_events: list[ControlEventMapping] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_safety_stop_transition(self) -> Self:
        if (
            self.transition.target_kind != TransitionTargetKind.END
            or self.transition.target_id != EndState.SAFETY_STOPPED
        ):
            raise ValueError("global safety choices must end at safety_stopped")
        return self


class EndConditionConfig(ConfigModel):
    end_state: EndState
    condition_type: EndConditionType
    triggering_event_types: list[StableIdentifier]

    @model_validator(mode="after")
    def validate_local_condition_contract(self) -> Self:
        if self.condition_type == EndConditionType.NORMAL_COMPLETION:
            if self.end_state != EndState.COMPLETED_SAFE or self.triggering_event_types:
                raise ValueError("normal_completion requires completed_safe with no triggers")
        elif self.condition_type == EndConditionType.RISK_OVERRIDE:
            if self.end_state != EndState.COMPLETED_RISKY or not self.triggering_event_types:
                raise ValueError("risk_override requires completed_risky with triggers")
        elif self.end_state != EndState.SAFETY_STOPPED or not self.triggering_event_types:
            raise ValueError("safety_stop requires safety_stopped with triggers")
        return self


class ExternalActionPolicy(ConfigModel):
    automatic_alarm: Literal[False]
    automatic_fund_freeze: Literal[False]
    automatic_family_contact: Literal[False]


class ContentSafetyConfig(ConfigModel):
    forbidden_content: list[NonEmptyString] = Field(min_length=1)
    sensitive_data_rules: list[NonEmptyString] = Field(min_length=1)
    max_pressure_prompts: PositiveInt
    suspected_real_fraud_guidance: list[NonEmptyString] = Field(min_length=1)
    external_action_policy: ExternalActionPolicy


class FallbackConfig(ConfigModel):
    interaction_mode: Literal["text_buttons"]
    ai_enabled: Literal[False]
    evaluation_mode: Literal["deterministic_rules"]
    fixed_content: NonEmptyString


class DimensionPolicy(ConfigModel):
    dimension: Dimension
    opportunity_ids: list[OpportunityIdentifier] = Field(min_length=1)
    weight: Percentage


class ScoringPolicyConfig(ConfigModel):
    positive_opportunity_score: Literal[100]
    negative_opportunity_score: Literal[0]
    severe_negative_dimension_cap: Literal[20]
    rounding: Literal["half_up_integer"]
    dimensions: list[DimensionPolicy] = Field(min_length=1)


class ScenarioConfig(ConfigModel):
    schema_version: PositiveInt
    scenario_id: CanonicalUUID4
    scenario_version_id: CanonicalUUID4
    scenario_key: StableIdentifier
    scenario_version: PositiveInt
    title: NonEmptyString
    runtime_level: Literal["l4"]
    initial_stage_id: StableIdentifier
    stages: list[StageConfig] = Field(min_length=1)
    global_safety_choices: list[SafetyChoiceConfig] = Field(min_length=1)
    end_conditions: list[EndConditionConfig] = Field(min_length=1)
    content_safety: ContentSafetyConfig
    fallback: FallbackConfig
    scoring_policy: ScoringPolicyConfig


def load_scenario_config(path: Path) -> ScenarioConfig:
    """Load one UTF-8 JSON scenario configuration file."""

    return ScenarioConfig.model_validate_json(path.read_text(encoding="utf-8"))
