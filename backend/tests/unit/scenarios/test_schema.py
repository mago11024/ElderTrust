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


def test_customer_refund_seed_matches_exact_configuration_contract() -> None:
    config = load_scenario_config(SEED_PATH)

    assert {
        stage.stage_id: [
            (
                choice.choice_id,
                choice.transition.target_kind,
                choice.transition.target_id,
                [
                    (
                        mapping.event_type,
                        mapping.dimension,
                        mapping.direction,
                        mapping.severity,
                        mapping.opportunity_id,
                    )
                    for mapping in choice.behavior_mappings
                ],
            )
            for choice in stage.choices
        ]
        for stage in config.stages
    } == {
        "customer_identity": [
            (
                "listen_without_verifying",
                "stage",
                "order_anomaly",
                [
                    (
                        "identity_not_verified",
                        "identity_verification",
                        "negative",
                        "normal",
                        "identity.stage_1",
                    )
                ],
            ),
            (
                "verify_via_official_channel",
                "stage",
                "order_anomaly",
                [
                    (
                        "official_channel_verification",
                        "identity_verification",
                        "positive",
                        "normal",
                        "identity.stage_1",
                    )
                ],
            ),
            (
                "ask_trusted_person_to_verify",
                "stage",
                "order_anomaly",
                [
                    (
                        "trusted_person_verification",
                        "identity_verification",
                        "positive",
                        "normal",
                        "identity.stage_1",
                    )
                ],
            ),
        ],
        "order_anomaly": [
            (
                "disclose_order_details",
                "stage",
                "refund_offer",
                [
                    (
                        "order_details_disclosed",
                        "information_protection",
                        "negative",
                        "normal",
                        "information.stage_2",
                    )
                ],
            ),
            (
                "continue_without_disclosure",
                "stage",
                "refund_offer",
                [
                    (
                        "personal_information_withheld",
                        "information_protection",
                        "positive",
                        "normal",
                        "information.stage_2",
                    )
                ],
            ),
            (
                "check_order_independently",
                "stage",
                "refund_offer",
                [
                    (
                        "order_checked_independently",
                        "information_protection",
                        "positive",
                        "normal",
                        "information.stage_2",
                    )
                ],
            ),
        ],
        "refund_offer": [
            (
                "accept_unverified_refund",
                "stage",
                "sensitive_action",
                [
                    (
                        "unverified_refund_accepted",
                        "payment_awareness",
                        "negative",
                        "normal",
                        "payment.stage_3",
                    )
                ],
            ),
            (
                "require_original_route_refund",
                "stage",
                "sensitive_action",
                [
                    (
                        "original_route_refund_recognized",
                        "payment_awareness",
                        "positive",
                        "normal",
                        "payment.stage_3",
                    )
                ],
            ),
            (
                "pause_for_official_verification",
                "stage",
                "sensitive_action",
                [
                    (
                        "transaction_paused_for_verification",
                        "payment_awareness",
                        "positive",
                        "normal",
                        "payment.stage_3",
                    )
                ],
            ),
        ],
        "sensitive_action": [
            (
                "share_verification_code",
                "stage",
                "time_pressure",
                [
                    (
                        "verification_code_shared",
                        "information_protection",
                        "negative",
                        "severe",
                        "information.stage_4",
                    ),
                    (
                        "verification_code_shared",
                        "payment_awareness",
                        "negative",
                        "severe",
                        "payment.stage_4",
                    ),
                ],
            ),
            (
                "open_unknown_link",
                "stage",
                "time_pressure",
                [
                    (
                        "unknown_link_opened",
                        "information_protection",
                        "negative",
                        "severe",
                        "information.stage_4",
                    ),
                    (
                        "unknown_link_opened",
                        "payment_awareness",
                        "negative",
                        "severe",
                        "payment.stage_4",
                    ),
                ],
            ),
            (
                "enable_screen_sharing",
                "stage",
                "time_pressure",
                [
                    (
                        "screen_sharing_enabled",
                        "information_protection",
                        "negative",
                        "severe",
                        "information.stage_4",
                    ),
                    (
                        "screen_sharing_enabled",
                        "payment_awareness",
                        "negative",
                        "severe",
                        "payment.stage_4",
                    ),
                ],
            ),
            (
                "refuse_sensitive_actions",
                "stage",
                "time_pressure",
                [
                    (
                        "sensitive_request_refused",
                        "information_protection",
                        "positive",
                        "normal",
                        "information.stage_4",
                    ),
                    (
                        "sensitive_request_refused",
                        "payment_awareness",
                        "positive",
                        "normal",
                        "payment.stage_4",
                    ),
                ],
            ),
        ],
        "time_pressure": [
            (
                "comply_under_pressure",
                "end",
                "completed_risky",
                [
                    (
                        "pressure_compliance",
                        "pressure_response",
                        "negative",
                        "normal",
                        "pressure.stage_5",
                    ),
                    ("help_not_sought", "help_termination", "negative", "normal", "help.stage_5"),
                ],
            ),
            (
                "pause_and_verify",
                "end",
                "completed_safe",
                [
                    (
                        "paused_under_pressure",
                        "pressure_response",
                        "positive",
                        "normal",
                        "pressure.stage_5",
                    ),
                    (
                        "suspicious_contact_ended",
                        "help_termination",
                        "positive",
                        "normal",
                        "help.stage_5",
                    ),
                ],
            ),
            (
                "seek_trusted_help",
                "end",
                "completed_safe",
                [
                    (
                        "paused_under_pressure",
                        "pressure_response",
                        "positive",
                        "normal",
                        "pressure.stage_5",
                    ),
                    ("help_sought", "help_termination", "positive", "normal", "help.stage_5"),
                ],
            ),
        ],
    }
    assert [
        (
            choice.choice_id,
            choice.transition.target_kind,
            choice.transition.target_id,
            choice.end_reason,
            [
                (event.event_type, event.evidence_source, event.scoring_eligible)
                for event in choice.control_events
            ],
        )
        for choice in config.global_safety_choices
    ] == [
        (
            "end_training",
            "end",
            "safety_stopped",
            "user_ended",
            [("training_ended_by_user", "safety_control", False)],
        ),
        (
            "suspected_real_fraud",
            "end",
            "safety_stopped",
            "suspected_real_fraud",
            [("suspected_real_fraud_declared", "safety_control", False)],
        ),
    ]
    assert [
        (policy.dimension, policy.opportunity_ids, policy.weight)
        for policy in config.scoring_policy.dimensions
    ] == [
        ("identity_verification", ["identity.stage_1"], 20),
        ("information_protection", ["information.stage_2", "information.stage_4"], 25),
        ("payment_awareness", ["payment.stage_3", "payment.stage_4"], 25),
        ("pressure_response", ["pressure.stage_5"], 15),
        ("help_termination", ["help.stage_5"], 15),
    ]
    assert config.content_safety.forbidden_content == [
        "真实陌生链接",
        "真实屏幕共享",
        "真实验证码收集",
        "真实银行卡号收集",
        "真实证件号收集",
        "详细住址收集",
    ]
    assert config.content_safety.sensitive_data_rules == [
        "不要求输入真实验证码",
        "不要求输入银行卡号",
        "不要求输入证件号",
        "不要求输入详细住址",
    ]
    assert config.content_safety.max_pressure_prompts == 1
    assert config.content_safety.suspected_real_fraud_guidance == [
        "停止转账",
        "停止提供信息",
        "通过独立官方渠道核实",
    ]
    assert config.content_safety.external_action_policy.model_dump() == {
        "automatic_alarm": False,
        "automatic_fund_freeze": False,
        "automatic_family_contact": False,
    }
    assert config.fallback.model_dump() == {
        "interaction_mode": "text_buttons",
        "ai_enabled": False,
        "evaluation_mode": "deterministic_rules",
        "fixed_content": "使用固定话术、文字按钮和确定性规则完成训练。",
    }
    assert next(
        condition
        for condition in config.end_conditions
        if condition.condition_type == "risk_override"
    ).triggering_event_types == [
        "pressure_compliance",
        "verification_code_shared",
        "unknown_link_opened",
        "screen_sharing_enabled",
    ]


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


def test_round_trips_a_loaded_config_in_python_mode() -> None:
    config = load_scenario_config(SEED_PATH)

    revalidated = ScenarioConfig.model_validate(config.model_dump())

    assert revalidated == config


@pytest.mark.parametrize(
    ("mutation", "description"),
    [
        (
            lambda payload: payload["global_safety_choices"][0]["transition"].update(
                {"target_kind": "stage", "target_id": "order_anomaly"}
            ),
            "a safety choice targeting a stage",
        ),
        (
            lambda payload: payload["end_conditions"][0].update({"end_state": "completed_risky"}),
            "normal completion paired with the wrong end state",
        ),
        (
            lambda payload: payload["end_conditions"][1].update({"end_state": "completed_safe"}),
            "risk override paired with the wrong end state",
        ),
        (
            lambda payload: payload["end_conditions"][2].update({"triggering_event_types": []}),
            "safety stop without a trigger",
        ),
    ],
)
def test_rejects_locally_contradictory_safety_and_end_conditions(
    mutation: object, description: str
) -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    assert callable(mutation), description
    mutation(payload)

    with pytest.raises(ValidationError):
        ScenarioConfig.model_validate_json(json.dumps(payload))


def test_rejects_whitespace_only_nested_content() -> None:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    payload["content_safety"]["forbidden_content"][0] = " \t "

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
