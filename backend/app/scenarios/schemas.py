"""Pydantic models for versioned training-scenario configuration."""

from enum import StrEnum
from pathlib import Path
from uuid import UUID

from pydantic import BaseModel, Field


class ConfigModel(BaseModel):
    """Common initial configuration model."""


class Dimension(StrEnum):
    IDENTITY_VERIFICATION = "identity_verification"
    INFORMATION_PROTECTION = "information_protection"
    PAYMENT_AWARENESS = "payment_awareness"
    PRESSURE_RESPONSE = "pressure_response"
    HELP_TERMINATION = "help_termination"


class Direction(StrEnum):
    POSITIVE = "positive"
    NEGATIVE = "negative"


class EvidenceSource(StrEnum):
    BUTTON_CHOICE = "button_choice"
    SAFETY_CONTROL = "safety_control"


class Transition(ConfigModel):
    target_kind: str
    target_id: str


class BehaviorMapping(ConfigModel):
    event_id: UUID
    event_type: str
    dimension: Dimension
    direction: Direction
    severity: str
    opportunity_id: str
    evidence_source: EvidenceSource
    evidence_summary: str


class ChoiceConfig(ConfigModel):
    choice_id: str
    label: str
    transition: Transition
    behavior_mappings: list[BehaviorMapping] = Field(min_length=1)


class AiStrategyConfig(ConfigModel):
    mode: str
    enabled: bool
    allowed_response_intents: list[str]
    prohibited_actions: list[str]


class StageConfig(ConfigModel):
    stage_id: str
    order: int
    title: str
    scripted_prompt: str
    ai_strategy: AiStrategyConfig
    risk_points: list[str]
    choices: list[ChoiceConfig] = Field(min_length=1)


class ControlEventMapping(ConfigModel):
    event_type: str
    evidence_source: EvidenceSource
    scoring_eligible: bool
    evidence_summary: str


class SafetyChoiceConfig(ConfigModel):
    choice_id: str
    label: str
    transition: Transition
    end_reason: str
    control_events: list[ControlEventMapping] = Field(min_length=1)


class EndConditionConfig(ConfigModel):
    end_state: str
    condition_type: str
    triggering_event_types: list[str]


class ExternalActionPolicy(ConfigModel):
    automatic_alarm: bool
    automatic_fund_freeze: bool
    automatic_family_contact: bool


class ContentSafetyConfig(ConfigModel):
    forbidden_content: list[str]
    sensitive_data_rules: list[str]
    max_pressure_prompts: int
    suspected_real_fraud_guidance: list[str]
    external_action_policy: ExternalActionPolicy


class FallbackConfig(ConfigModel):
    interaction_mode: str
    ai_enabled: bool
    evaluation_mode: str
    fixed_content: str


class DimensionPolicy(ConfigModel):
    dimension: Dimension
    opportunity_ids: list[str] = Field(min_length=1)
    weight: int


class ScoringPolicyConfig(ConfigModel):
    positive_opportunity_score: int
    negative_opportunity_score: int
    severe_negative_dimension_cap: int
    rounding: str
    dimensions: list[DimensionPolicy] = Field(min_length=1)


class ScenarioConfig(ConfigModel):
    schema_version: int
    scenario_id: UUID
    scenario_version_id: UUID
    scenario_key: str
    scenario_version: int
    title: str = Field(min_length=1)
    runtime_level: str
    initial_stage_id: str
    stages: list[StageConfig] = Field(min_length=1)
    global_safety_choices: list[SafetyChoiceConfig] = Field(min_length=1)
    end_conditions: list[EndConditionConfig] = Field(min_length=1)
    content_safety: ContentSafetyConfig
    fallback: FallbackConfig
    scoring_policy: ScoringPolicyConfig


def load_scenario_config(path: Path) -> ScenarioConfig:
    """Load one UTF-8 JSON scenario configuration file."""

    return ScenarioConfig.model_validate_json(path.read_text(encoding="utf-8"))
