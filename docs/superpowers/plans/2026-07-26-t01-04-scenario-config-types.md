# T01-04 Scenario Config Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Define strict Pydantic scenario configuration types and a validated, versioned customer-refund V1 seed.

**Architecture:** Keep all configuration-only contracts in `app.scenarios.schemas`, with small nested models and a single file loader. The seed contains the T00-03 contract; schema validation covers JSON shape and local field constraints, while graph reachability and cross-reference checks remain in T01-05.

**Tech Stack:** Python 3.12, Pydantic 2, pytest

---

## File map

- Modify `docs/CURRENT_STATUS.md`: move the development pointer into T01-04, then record completion after fresh verification.
- Create `backend/app/scenarios/__init__.py`: declare the scenarios package.
- Create `backend/app/scenarios/schemas.py`: own configuration enums, nested models, strict validation, and JSON loading.
- Create `backend/app/scenarios/seeds/customer_refund_v1.json`: hold the immutable customer-refund V1 configuration seed.
- Create `backend/tests/unit/scenarios/test_schema.py`: prove valid loading, missing-field rejection, strict boundary validation, and seed fidelity.

No database, API, state-machine executor, scoring engine, or graph validation file is added.

### Task 1: Start T01-04

**Files:**
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Move the pointer into T01-04**

Set the YAML block to:

```yaml
schema_version: 1
current_milestone: M1
milestone_status: active
current_task: T01-04
status: in_progress
last_completed_task: T01-03
next_task: T01-05
task_catalog: docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
last_verification:
  command: scripts/test.ps1 + Docker Compose config + CI YAML parse + traceability/governance/task catalog
  result: passed
  verified_at: 2026-07-26
updated_at: 2026-07-26
```

- [ ] **Step 2: Verify the repository resolves the intended Task**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/show_current_task.ps1
```

Expected: `Current Task: T01-04 — 定义场景配置类型（M）`, status `in_progress`, dependencies T01-01 and T00-03, and no status/catalog conflict.

- [ ] **Step 3: Commit the pointer change**

```powershell
git add docs/CURRENT_STATUS.md
git commit -m "chore: start T01-04"
```

### Task 2: Load the complete customer-refund seed

**Files:**
- Create: `backend/app/scenarios/__init__.py`
- Create: `backend/app/scenarios/schemas.py`
- Create: `backend/app/scenarios/seeds/customer_refund_v1.json`
- Create: `backend/tests/unit/scenarios/test_schema.py`

- [ ] **Step 1: Write the first failing tests**

Create `backend/tests/unit/scenarios/test_schema.py`:

```python
import json
from pathlib import Path
from typing import cast

import pytest
from pydantic import ValidationError

from app.scenarios.schemas import ScenarioConfig, load_scenario_config


SEED_PATH = (
    Path(__file__).parents[3]
    / "app"
    / "scenarios"
    / "seeds"
    / "customer_refund_v1.json"
)


def test_customer_refund_v1_seed_loads() -> None:
    config = load_scenario_config(SEED_PATH)

    assert config.scenario_key == "customer_refund"
    assert config.scenario_version == 1
    assert str(config.scenario_id) == "7bea2c71-9bbb-4a38-bf53-a89b56635cbb"
    assert str(config.scenario_version_id) == "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c"
    assert config.initial_stage_id == "customer_identity"
    assert [stage.stage_id for stage in config.stages] == [
        "customer_identity",
        "order_anomaly",
        "refund_offer",
        "sensitive_action",
        "time_pressure",
    ]
    assert [condition.end_state for condition in config.end_conditions] == [
        "completed_safe",
        "completed_risky",
        "safety_stopped",
    ]
    assert sum(item.weight_percent for item in config.scoring_policy.dimensions) == 100


def test_scenario_config_rejects_missing_required_field() -> None:
    data = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    del data["initial_stage_id"]

    with pytest.raises(ValidationError) as error:
        ScenarioConfig.model_validate_json(json.dumps(data, ensure_ascii=False))

    assert error.value.errors()[0]["loc"] == ("initial_stage_id",)
    assert error.value.errors()[0]["type"] == "missing"
```

- [ ] **Step 2: Run the tests and observe RED**

Run:

```powershell
Set-Location backend
python -m pytest tests/unit/scenarios/test_schema.py -q
```

Expected: collection fails with `ModuleNotFoundError: No module named 'app.scenarios'`.

- [ ] **Step 3: Add the minimal typed configuration module**

Create an empty `backend/app/scenarios/__init__.py`.

Create `backend/app/scenarios/schemas.py`:

```python
from pathlib import Path
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


Identifier = str


class Transition(BaseModel):
    target_kind: str
    target_id: Identifier


class BehaviorMapping(BaseModel):
    event_type: Identifier
    dimension: str
    direction: str
    severity: str
    opportunity_id: Identifier
    evidence_summary: str


class ChoiceConfig(BaseModel):
    choice_id: Identifier
    label: str
    transition: Transition
    behavior_events: list[BehaviorMapping] = Field(min_length=1)


class AiStrategyConfig(BaseModel):
    mode: str
    response_policy: str
    allowed_tactics: list[str]
    prohibited_tactics: list[str]


class StageConfig(BaseModel):
    stage_id: Identifier
    order: int
    title: str
    fixed_script: str
    ai_strategy: AiStrategyConfig
    risk_points: list[str] = Field(min_length=1)
    choices: list[ChoiceConfig] = Field(min_length=1)


class ControlEventMapping(BaseModel):
    event_type: Identifier
    evidence_source: str
    scoring_eligible: Literal[False]


class SafetyChoiceConfig(BaseModel):
    choice_id: Identifier
    label: str
    transition: Transition
    control_event: ControlEventMapping


class EndConditionConfig(BaseModel):
    end_state: str
    condition_kind: str
    trigger_ids: list[Identifier] = Field(min_length=1)


class ExternalActionPolicy(BaseModel):
    automatic_alarm: Literal[False]
    automatic_fund_freeze: Literal[False]
    automatic_family_contact: Literal[False]


class ContentSafetyConfig(BaseModel):
    forbidden_content: list[str] = Field(min_length=1)
    sensitive_information_rules: list[str] = Field(min_length=1)
    max_pressure_level: int
    suspected_real_fraud_guidance: list[str] = Field(min_length=1)
    external_actions: ExternalActionPolicy


class FallbackConfig(BaseModel):
    level: str
    interaction: str
    ai_enabled: Literal[False]
    scoring: str
    content: list[str] = Field(min_length=1)


class DimensionPolicy(BaseModel):
    dimension: str
    opportunity_ids: list[Identifier] = Field(min_length=1)
    weight_percent: int


class ScoringPolicyConfig(BaseModel):
    strategy_id: Identifier
    positive_points: int
    negative_points: int
    severe_negative_dimension_cap: int
    rounding_strategy: str
    dimensions: list[DimensionPolicy] = Field(min_length=1)


class ScenarioConfig(BaseModel):
    schema_version: int
    scenario_id: UUID
    scenario_version_id: UUID
    scenario_key: Identifier
    scenario_version: int
    title: str
    runtime_level: str
    initial_stage_id: Identifier
    stages: list[StageConfig] = Field(min_length=1)
    global_safety_choices: list[SafetyChoiceConfig] = Field(min_length=1)
    end_conditions: list[EndConditionConfig] = Field(min_length=1)
    content_safety: ContentSafetyConfig
    fallback: FallbackConfig
    scoring_policy: ScoringPolicyConfig


def load_scenario_config(path: Path) -> ScenarioConfig:
    return ScenarioConfig.model_validate_json(path.read_text(encoding="utf-8"))
```

- [ ] **Step 4: Add the complete seed**

Create `backend/app/scenarios/seeds/customer_refund_v1.json` with this top-level contract:

```json
{
  "schema_version": 1,
  "scenario_id": "7bea2c71-9bbb-4a38-bf53-a89b56635cbb",
  "scenario_version_id": "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c",
  "scenario_key": "customer_refund",
  "scenario_version": 1,
  "title": "客服退款",
  "runtime_level": "l4",
  "initial_stage_id": "customer_identity",
  "stages": [
    {
      "stage_id": "customer_identity",
      "order": 1,
      "title": "客服身份",
      "fixed_script": "您好，我是安信商城售后客服。系统显示您最近购买的保温杯存在问题，我的工号是虚构的 A-17，请先听我说明处理办法。",
      "ai_strategy": {
        "mode": "fixed_script",
        "response_policy": "用户选择后进入订单异常阶段，不索取真实身份或订单资料。",
        "allowed_tactics": ["虚构客服身份"],
        "prohibited_tactics": ["索取真实个人信息"]
      },
      "risk_points": ["冒充客服", "未经独立渠道核实"],
      "choices": [
        {
          "choice_id": "listen_without_verifying",
          "label": "我先听听你怎么说",
          "transition": {"target_kind": "stage", "target_id": "order_anomaly"},
          "behavior_events": [
            {"event_type": "identity_not_verified", "dimension": "identity_verification", "direction": "negative", "severity": "normal", "opportunity_id": "identity.stage_1", "evidence_summary": "用户未核实客服身份"}
          ]
        },
        {
          "choice_id": "verify_via_official_channel",
          "label": "我会从平台官方入口核实",
          "transition": {"target_kind": "stage", "target_id": "order_anomaly"},
          "behavior_events": [
            {"event_type": "official_channel_verification", "dimension": "identity_verification", "direction": "positive", "severity": "normal", "opportunity_id": "identity.stage_1", "evidence_summary": "用户选择通过平台官方入口核实"}
          ]
        },
        {
          "choice_id": "ask_trusted_person_to_verify",
          "label": "我请可信家人一起核实",
          "transition": {"target_kind": "stage", "target_id": "order_anomaly"},
          "behavior_events": [
            {"event_type": "trusted_person_verification", "dimension": "identity_verification", "direction": "positive", "severity": "normal", "opportunity_id": "identity.stage_1", "evidence_summary": "用户请求可信家人协助核实"}
          ]
        }
      ]
    },
    {
      "stage_id": "order_anomaly",
      "order": 2,
      "title": "订单异常",
      "fixed_script": "这笔虚构订单被标记为重复扣费，需要马上确认资料才能取消。您可以继续听退款方案，也可以自己核对。",
      "ai_strategy": {
        "mode": "fixed_script",
        "response_policy": "只描述虚构订单异常，不接收真实订单资料。",
        "allowed_tactics": ["虚构重复扣费"],
        "prohibited_tactics": ["接收真实订单资料"]
      },
      "risk_points": ["订单异常借口", "诱导披露资料"],
      "choices": [
        {
          "choice_id": "disclose_order_details",
          "label": "我把模拟订单资料告诉你",
          "transition": {"target_kind": "stage", "target_id": "refund_offer"},
          "behavior_events": [
            {"event_type": "order_details_disclosed", "dimension": "information_protection", "direction": "negative", "severity": "normal", "opportunity_id": "information.stage_2", "evidence_summary": "用户选择披露模拟订单资料"}
          ]
        },
        {
          "choice_id": "continue_without_disclosure",
          "label": "我不提供个人资料，你继续说明",
          "transition": {"target_kind": "stage", "target_id": "refund_offer"},
          "behavior_events": [
            {"event_type": "personal_information_withheld", "dimension": "information_protection", "direction": "positive", "severity": "normal", "opportunity_id": "information.stage_2", "evidence_summary": "用户拒绝提供个人资料"}
          ]
        },
        {
          "choice_id": "check_order_independently",
          "label": "我自己打开平台核对订单",
          "transition": {"target_kind": "stage", "target_id": "refund_offer"},
          "behavior_events": [
            {"event_type": "order_checked_independently", "dimension": "information_protection", "direction": "positive", "severity": "normal", "opportunity_id": "information.stage_2", "evidence_summary": "用户选择独立核对订单"}
          ]
        }
      ]
    },
    {
      "stage_id": "refund_offer",
      "order": 3,
      "title": "退款赔付",
      "fixed_script": "为表示歉意，我们可以办理退款和额外赔付。您只要按我说的步骤操作，款项很快就能到账。",
      "ai_strategy": {
        "mode": "fixed_script",
        "response_policy": "只描述模拟退款方案，不发起真实资金操作。",
        "allowed_tactics": ["虚构退款赔付"],
        "prohibited_tactics": ["真实转账", "索取银行卡信息"]
      },
      "risk_points": ["额外赔付诱惑", "偏离原路退款"],
      "choices": [
        {
          "choice_id": "accept_unverified_refund",
          "label": "我按你的退款步骤操作",
          "transition": {"target_kind": "stage", "target_id": "sensitive_action"},
          "behavior_events": [
            {"event_type": "unverified_refund_accepted", "dimension": "payment_awareness", "direction": "negative", "severity": "normal", "opportunity_id": "payment.stage_3", "evidence_summary": "用户接受未经核实的退款步骤"}
          ]
        },
        {
          "choice_id": "require_original_route_refund",
          "label": "退款应原路返回，不需要我额外操作",
          "transition": {"target_kind": "stage", "target_id": "sensitive_action"},
          "behavior_events": [
            {"event_type": "original_route_refund_recognized", "dimension": "payment_awareness", "direction": "positive", "severity": "normal", "opportunity_id": "payment.stage_3", "evidence_summary": "用户识别退款应原路返回"}
          ]
        },
        {
          "choice_id": "pause_for_official_verification",
          "label": "我先联系平台官方客服核实",
          "transition": {"target_kind": "stage", "target_id": "sensitive_action"},
          "behavior_events": [
            {"event_type": "transaction_paused_for_verification", "dimension": "payment_awareness", "direction": "positive", "severity": "normal", "opportunity_id": "payment.stage_3", "evidence_summary": "用户暂停交易并联系官方客服"}
          ]
        }
      ]
    },
    {
      "stage_id": "sensitive_action",
      "order": 4,
      "title": "敏感操作",
      "fixed_script": "系统提示退款通道需要进一步验证。训练中会模拟陌生链接、屏幕共享和验证码请求，但不会执行任何真实操作。",
      "ai_strategy": {
        "mode": "fixed_script",
        "response_policy": "只模拟敏感请求，不展示可操作链接，不启动共享，不接收验证码。",
        "allowed_tactics": ["模拟陌生链接", "模拟屏幕共享", "模拟验证码请求"],
        "prohibited_tactics": ["可操作链接", "真实屏幕共享", "接收真实验证码"]
      },
      "risk_points": ["验证码", "陌生链接", "屏幕共享"],
      "choices": [
        {
          "choice_id": "share_verification_code",
          "label": "我把模拟验证码告诉你",
          "transition": {"target_kind": "stage", "target_id": "time_pressure"},
          "behavior_events": [
            {"event_type": "verification_code_shared", "dimension": "information_protection", "direction": "negative", "severity": "severe", "opportunity_id": "information.stage_4", "evidence_summary": "用户选择提供模拟验证码"},
            {"event_type": "verification_code_shared", "dimension": "payment_awareness", "direction": "negative", "severity": "severe", "opportunity_id": "payment.stage_4", "evidence_summary": "用户选择提供模拟验证码"}
          ]
        },
        {
          "choice_id": "open_unknown_link",
          "label": "我点击模拟陌生链接",
          "transition": {"target_kind": "stage", "target_id": "time_pressure"},
          "behavior_events": [
            {"event_type": "unknown_link_opened", "dimension": "information_protection", "direction": "negative", "severity": "severe", "opportunity_id": "information.stage_4", "evidence_summary": "用户选择点击模拟陌生链接"},
            {"event_type": "unknown_link_opened", "dimension": "payment_awareness", "direction": "negative", "severity": "severe", "opportunity_id": "payment.stage_4", "evidence_summary": "用户选择点击模拟陌生链接"}
          ]
        },
        {
          "choice_id": "enable_screen_sharing",
          "label": "我同意模拟屏幕共享",
          "transition": {"target_kind": "stage", "target_id": "time_pressure"},
          "behavior_events": [
            {"event_type": "screen_sharing_enabled", "dimension": "information_protection", "direction": "negative", "severity": "severe", "opportunity_id": "information.stage_4", "evidence_summary": "用户选择同意模拟屏幕共享"},
            {"event_type": "screen_sharing_enabled", "dimension": "payment_awareness", "direction": "negative", "severity": "severe", "opportunity_id": "payment.stage_4", "evidence_summary": "用户选择同意模拟屏幕共享"}
          ]
        },
        {
          "choice_id": "refuse_sensitive_actions",
          "label": "我全部拒绝，不点击也不共享",
          "transition": {"target_kind": "stage", "target_id": "time_pressure"},
          "behavior_events": [
            {"event_type": "sensitive_request_refused", "dimension": "information_protection", "direction": "positive", "severity": "normal", "opportunity_id": "information.stage_4", "evidence_summary": "用户拒绝全部敏感操作"},
            {"event_type": "sensitive_request_refused", "dimension": "payment_awareness", "direction": "positive", "severity": "normal", "opportunity_id": "payment.stage_4", "evidence_summary": "用户拒绝全部敏感操作"}
          ]
        }
      ]
    },
    {
      "stage_id": "time_pressure",
      "order": 5,
      "title": "时间压力",
      "fixed_script": "如果现在不完成，退款资格会失效，而且可能继续产生虚构扣费。请马上决定。",
      "ai_strategy": {
        "mode": "fixed_script",
        "response_policy": "施加一次受限的模拟时间压力后结束普通流程。",
        "allowed_tactics": ["虚构退款资格失效", "虚构持续扣费"],
        "prohibited_tactics": ["威胁人身安全", "持续升级压力"]
      },
      "risk_points": ["限时催促", "压力下顺从"],
      "choices": [
        {
          "choice_id": "comply_under_pressure",
          "label": "我马上照做",
          "transition": {"target_kind": "end_state", "target_id": "completed_risky"},
          "behavior_events": [
            {"event_type": "pressure_compliance", "dimension": "pressure_response", "direction": "negative", "severity": "normal", "opportunity_id": "pressure.stage_5", "evidence_summary": "用户在压力下选择顺从"},
            {"event_type": "help_not_sought", "dimension": "help_termination", "direction": "negative", "severity": "normal", "opportunity_id": "help.stage_5", "evidence_summary": "用户未寻求帮助或结束联系"}
          ]
        },
        {
          "choice_id": "pause_and_verify",
          "label": "我暂停操作，挂断后独立核实",
          "transition": {"target_kind": "end_state", "target_id": "completed_safe"},
          "behavior_events": [
            {"event_type": "paused_under_pressure", "dimension": "pressure_response", "direction": "positive", "severity": "normal", "opportunity_id": "pressure.stage_5", "evidence_summary": "用户在压力下暂停操作"},
            {"event_type": "suspicious_contact_ended", "dimension": "help_termination", "direction": "positive", "severity": "normal", "opportunity_id": "help.stage_5", "evidence_summary": "用户结束可疑联系并独立核实"}
          ]
        },
        {
          "choice_id": "seek_trusted_help",
          "label": "我请家人或官方客服协助",
          "transition": {"target_kind": "end_state", "target_id": "completed_safe"},
          "behavior_events": [
            {"event_type": "paused_under_pressure", "dimension": "pressure_response", "direction": "positive", "severity": "normal", "opportunity_id": "pressure.stage_5", "evidence_summary": "用户在压力下暂停操作"},
            {"event_type": "help_sought", "dimension": "help_termination", "direction": "positive", "severity": "normal", "opportunity_id": "help.stage_5", "evidence_summary": "用户寻求可信家人或官方客服帮助"}
          ]
        }
      ]
    }
  ],
  "global_safety_choices": [
    {
      "choice_id": "end_training",
      "label": "结束训练",
      "transition": {"target_kind": "end_state", "target_id": "safety_stopped"},
      "control_event": {"event_type": "training_ended_by_user", "evidence_source": "safety_control", "scoring_eligible": false}
    },
    {
      "choice_id": "suspected_real_fraud",
      "label": "我可能正在实际受骗",
      "transition": {"target_kind": "end_state", "target_id": "safety_stopped"},
      "control_event": {"event_type": "suspected_real_fraud_declared", "evidence_source": "safety_control", "scoring_eligible": false}
    }
  ],
  "end_conditions": [
    {"end_state": "completed_safe", "condition_kind": "choice_candidate", "trigger_ids": ["pause_and_verify", "seek_trusted_help"]},
    {"end_state": "completed_risky", "condition_kind": "risk_override", "trigger_ids": ["comply_under_pressure", "verification_code_shared", "unknown_link_opened", "screen_sharing_enabled"]},
    {"end_state": "safety_stopped", "condition_kind": "safety_control", "trigger_ids": ["end_training", "suspected_real_fraud"]}
  ],
  "content_safety": {
    "forbidden_content": ["真实可操作陌生链接", "真实资金操作", "声音克隆", "真实个人数据"],
    "sensitive_information_rules": ["不接收验证码", "不接收银行卡号", "不接收证件号", "不接收详细住址"],
    "max_pressure_level": 3,
    "suspected_real_fraud_guidance": ["停止转账", "停止提供信息", "通过独立官方渠道核实"],
    "external_actions": {"automatic_alarm": false, "automatic_fund_freeze": false, "automatic_family_contact": false}
  },
  "fallback": {
    "level": "l4",
    "interaction": "text_buttons",
    "ai_enabled": false,
    "scoring": "deterministic_rules",
    "content": ["固定五阶段话术", "固定按钮选择", "规则评分"]
  },
  "scoring_policy": {
    "strategy_id": "customer_refund_v1_deterministic",
    "positive_points": 100,
    "negative_points": 0,
    "severe_negative_dimension_cap": 20,
    "rounding_strategy": "half_up_integer",
    "dimensions": [
      {"dimension": "identity_verification", "opportunity_ids": ["identity.stage_1"], "weight_percent": 20},
      {"dimension": "information_protection", "opportunity_ids": ["information.stage_2", "information.stage_4"], "weight_percent": 25},
      {"dimension": "payment_awareness", "opportunity_ids": ["payment.stage_3", "payment.stage_4"], "weight_percent": 25},
      {"dimension": "pressure_response", "opportunity_ids": ["pressure.stage_5"], "weight_percent": 15},
      {"dimension": "help_termination", "opportunity_ids": ["help.stage_5"], "weight_percent": 15}
    ]
  }
}
```

- [ ] **Step 5: Run the focused tests and observe GREEN**

Run:

```powershell
Set-Location backend
python -m pytest tests/unit/scenarios/test_schema.py -q
```

Expected: `2 passed`.

- [ ] **Step 6: Commit the first green slice**

```powershell
git add app/scenarios tests/unit/scenarios/test_schema.py
git commit -m "feat: load customer refund scenario config"
```

### Task 3: Enforce strict field boundaries

**Files:**
- Modify: `backend/app/scenarios/schemas.py`
- Modify: `backend/tests/unit/scenarios/test_schema.py`

- [ ] **Step 1: Add failing boundary tests**

Append to `backend/tests/unit/scenarios/test_schema.py`:

```python
def load_seed_data() -> dict[str, object]:
    loaded = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    return cast(dict[str, object], loaded)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("scenario_id", "6ba7b810-9dad-11d1-80b4-00c04fd430c8"),
        ("scenario_version_id", "550e8400-e29b-11d4-a716-446655440000"),
        ("scenario_version", 0),
        ("runtime_level", "l3"),
    ],
)
def test_scenario_config_rejects_invalid_contract_values(
    field: str, value: object
) -> None:
    data = load_seed_data()
    data[field] = value

    with pytest.raises(ValidationError):
        ScenarioConfig.model_validate_json(json.dumps(data, ensure_ascii=False))


def test_scenario_config_rejects_unknown_fields() -> None:
    data = load_seed_data()
    data["unexpected"] = True

    with pytest.raises(ValidationError) as error:
        ScenarioConfig.model_validate_json(json.dumps(data, ensure_ascii=False))

    assert error.value.errors()[0]["type"] == "extra_forbidden"


def test_scenario_config_rejects_invalid_nested_enum() -> None:
    data = load_seed_data()
    stages = data["stages"]
    assert isinstance(stages, list)
    first_stage = stages[0]
    assert isinstance(first_stage, dict)
    first_stage["choices"][0]["behavior_events"][0]["severity"] = "critical"

    with pytest.raises(ValidationError):
        ScenarioConfig.model_validate_json(json.dumps(data, ensure_ascii=False))
```

- [ ] **Step 2: Run only the new tests and observe RED**

Run:

```powershell
Set-Location backend
python -m pytest tests/unit/scenarios/test_schema.py -q -k "invalid_contract or unknown_fields or invalid_nested"
```

Expected: failures because non-v4 UUIDs, zero versions, `l3`, extra fields, and `critical` are still accepted.

- [ ] **Step 3: Tighten the schema types**

Replace the imports and shared base declarations in `backend/app/scenarios/schemas.py` with:

```python
from enum import StrEnum
from pathlib import Path
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, PositiveInt, UUID4


Identifier = Annotated[str, Field(pattern=r"^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$")]
NonEmptyText = Annotated[str, Field(min_length=1)]


class StrictConfigModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class RuntimeLevel(StrEnum):
    L4 = "l4"


class TargetKind(StrEnum):
    STAGE = "stage"
    END_STATE = "end_state"


class ScoringDimension(StrEnum):
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


class EndState(StrEnum):
    COMPLETED_SAFE = "completed_safe"
    COMPLETED_RISKY = "completed_risky"
    SAFETY_STOPPED = "safety_stopped"


class EndConditionKind(StrEnum):
    CHOICE_CANDIDATE = "choice_candidate"
    RISK_OVERRIDE = "risk_override"
    SAFETY_CONTROL = "safety_control"
```

Make every model inherit `StrictConfigModel`, then apply these exact field types:

```python
class Transition(StrictConfigModel):
    target_kind: TargetKind
    target_id: Identifier


class BehaviorMapping(StrictConfigModel):
    event_type: Identifier
    dimension: ScoringDimension
    direction: Direction
    severity: Severity
    opportunity_id: Identifier
    evidence_summary: NonEmptyText


class ChoiceConfig(StrictConfigModel):
    choice_id: Identifier
    label: NonEmptyText
    transition: Transition
    behavior_events: list[BehaviorMapping] = Field(min_length=1)


class AiStrategyConfig(StrictConfigModel):
    mode: Literal["fixed_script"]
    response_policy: NonEmptyText
    allowed_tactics: list[NonEmptyText] = Field(min_length=1)
    prohibited_tactics: list[NonEmptyText] = Field(min_length=1)


class StageConfig(StrictConfigModel):
    stage_id: Identifier
    order: PositiveInt
    title: NonEmptyText
    fixed_script: NonEmptyText
    ai_strategy: AiStrategyConfig
    risk_points: list[NonEmptyText] = Field(min_length=1)
    choices: list[ChoiceConfig] = Field(min_length=1)


class ControlEventMapping(StrictConfigModel):
    event_type: Identifier
    evidence_source: Literal["safety_control"]
    scoring_eligible: Literal[False]


class SafetyChoiceConfig(StrictConfigModel):
    choice_id: Identifier
    label: NonEmptyText
    transition: Transition
    control_event: ControlEventMapping


class EndConditionConfig(StrictConfigModel):
    end_state: EndState
    condition_kind: EndConditionKind
    trigger_ids: list[Identifier] = Field(min_length=1)


class ExternalActionPolicy(StrictConfigModel):
    automatic_alarm: Literal[False]
    automatic_fund_freeze: Literal[False]
    automatic_family_contact: Literal[False]


class ContentSafetyConfig(StrictConfigModel):
    forbidden_content: list[NonEmptyText] = Field(min_length=1)
    sensitive_information_rules: list[NonEmptyText] = Field(min_length=1)
    max_pressure_level: int = Field(ge=1, le=5)
    suspected_real_fraud_guidance: list[NonEmptyText] = Field(min_length=1)
    external_actions: ExternalActionPolicy


class FallbackConfig(StrictConfigModel):
    level: Literal["l4"]
    interaction: Literal["text_buttons"]
    ai_enabled: Literal[False]
    scoring: Literal["deterministic_rules"]
    content: list[NonEmptyText] = Field(min_length=1)


class DimensionPolicy(StrictConfigModel):
    dimension: ScoringDimension
    opportunity_ids: list[Identifier] = Field(min_length=1)
    weight_percent: int = Field(ge=1, le=100)


class ScoringPolicyConfig(StrictConfigModel):
    strategy_id: Identifier
    positive_points: Literal[100]
    negative_points: Literal[0]
    severe_negative_dimension_cap: Literal[20]
    rounding_strategy: Literal["half_up_integer"]
    dimensions: list[DimensionPolicy] = Field(min_length=1)


class ScenarioConfig(StrictConfigModel):
    schema_version: PositiveInt
    scenario_id: UUID4
    scenario_version_id: UUID4
    scenario_key: Identifier
    scenario_version: PositiveInt
    title: NonEmptyText
    runtime_level: RuntimeLevel
    initial_stage_id: Identifier
    stages: list[StageConfig] = Field(min_length=1)
    global_safety_choices: list[SafetyChoiceConfig] = Field(min_length=1)
    end_conditions: list[EndConditionConfig] = Field(min_length=1)
    content_safety: ContentSafetyConfig
    fallback: FallbackConfig
    scoring_policy: ScoringPolicyConfig
```

Keep the loader unchanged:

```python
def load_scenario_config(path: Path) -> ScenarioConfig:
    return ScenarioConfig.model_validate_json(path.read_text(encoding="utf-8"))
```

- [ ] **Step 4: Run the focused suite and observe GREEN**

Run:

```powershell
Set-Location backend
python -m pytest tests/unit/scenarios/test_schema.py -q
```

Expected: `8 passed`.

- [ ] **Step 5: Run affected static checks**

Run:

```powershell
Set-Location backend
python -m ruff check app/scenarios tests/unit/scenarios/test_schema.py
python -m ruff format --check app/scenarios tests/unit/scenarios/test_schema.py
python -m mypy app/scenarios tests/unit/scenarios/test_schema.py
```

Expected: all three commands exit 0.

- [ ] **Step 6: Commit strict validation**

```powershell
git add app/scenarios/schemas.py tests/unit/scenarios/test_schema.py
git commit -m "test: enforce strict scenario config validation"
```

### Task 4: Verify acceptance and complete T01-04

**Files:**
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Run the Task acceptance command**

Run:

```powershell
Set-Location backend
python -m pytest tests/unit/scenarios/test_schema.py -q
```

Expected: all scenario schema tests pass.

- [ ] **Step 2: Run the only final full regression**

From the repository root, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1
```

Expected: backend tests, backend lint/format/type checks, frontend tests/typecheck/build, and governance checks all exit 0.

- [ ] **Step 3: Inspect the final diff against the Task boundary**

Run:

```powershell
git status --short
git diff --stat 400aafc..HEAD
git diff --check 400aafc..HEAD
```

Expected: only T01-04 files plus `docs/CURRENT_STATUS.md` are part of this Task; pre-existing untracked generated files remain untouched. No whitespace errors.

- [ ] **Step 4: Record completion**

Update the YAML block in `docs/CURRENT_STATUS.md`:

```yaml
schema_version: 1
current_milestone: M1
milestone_status: active
current_task: T01-04
status: completed
last_completed_task: T01-04
next_task: T01-05
task_catalog: docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
last_verification:
  command: scripts/test.ps1 + T01-04 focused acceptance
  result: passed
  verified_at: 2026-07-26
updated_at: 2026-07-26
```

- [ ] **Step 5: Validate the completed pointer**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/show_current_task.ps1
python scripts/check_traceability.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate_task_catalog.ps1
```

Expected: T01-04 is `completed`, next Task is T01-05, traceability has no unassigned P0/P1 requirement, and the task catalog is valid.

- [ ] **Step 6: Commit completion metadata**

```powershell
git add docs/CURRENT_STATUS.md
git commit -m "chore: complete T01-04"
```

- [ ] **Step 7: Verify the committed result without rerunning the unchanged regression**

Run:

```powershell
git status --short
git log -4 --oneline
```

Expected: the implementation and completion commits are present; only the three pre-existing untracked generated artifacts may remain.
