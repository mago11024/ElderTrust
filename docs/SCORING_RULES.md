# 确定性五维评分规则

## 1. 适用范围

本文锁定安信伴老场景评分的行为证据、机会点、五维权重、严重风险覆盖、总分、幂等和拒绝规则。
客服退款 V1 的具体按钮与转换见
[`SCENARIO_CUSTOMER_REFUND_V1.md`](./SCENARIO_CUSTOMER_REFUND_V1.md)。

评分只消费已经产生的结构化行为事件，不读取按钮文案、完整对话或 AI 生成结论。AI 可以在后续 Task
辅助理解自然语言，但不能直接给出、修改或覆盖最终分数。

本文遵循 [`DATA_CONVENTIONS.md`](./DATA_CONVENTIONS.md) 的 UUID、JSON 字段、枚举和
`scenario_version_id` 约定。不定义 Pydantic 模型、数据库表、HTTP 路由、页面、自由文本识别或复盘
文案生成。

## 2. 评分事件

### 2.1 必需字段

每个评分事件必须具有：

| 字段 | 约束 |
| --- | --- |
| `event_id` | UUID v4；事件的稳定幂等标识 |
| `scenario_version_id` | UUID v4；必须等于训练会话锁定的场景版本 |
| `event_type` | 本文第 3 节定义的稳定英文 `snake_case` 枚举 |
| `dimension` | 五个评分维度之一 |
| `direction` | `positive` 或 `negative` |
| `severity` | `normal` 或 `severe` |
| `evidence.source` | L4 评分事件固定为 `button_choice` |
| `evidence.stage_id` | 产生证据的阶段 |
| `evidence.choice_id` | 用户选择的稳定按钮标识 |
| `evidence.summary` | 简短、脱敏、可展示的证据摘要 |

示例：

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "scenario_version_id": "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c",
  "event_type": "official_channel_verification",
  "dimension": "identity_verification",
  "direction": "positive",
  "severity": "normal",
  "evidence": {
    "source": "button_choice",
    "stage_id": "customer_identity",
    "choice_id": "verify_via_official_channel",
    "summary": "用户选择通过平台官方入口核实"
  }
}
```

证据摘要不得包含完整录音、完整转写、验证码、银行卡号、证件号、详细住址、令牌或其他敏感数据。

### 2.2 评分事件与控制事件

`button_choice` 评分事件占用固定机会点。以下安全控制事件不属于评分事件：

- `training_ended_by_user`；
- `suspected_real_fraud_declared`。

它们的证据来源为 `safety_control`，用于安全中止与安全优先复盘，不得填充评分机会点。

## 3. 客服退款 V1 事件目录

| `event_type` | `dimension` | `direction` | `severity` | 固定机会点 |
| --- | --- | --- | --- | --- |
| `identity_not_verified` | `identity_verification` | `negative` | `normal` | `identity.stage_1` |
| `official_channel_verification` | `identity_verification` | `positive` | `normal` | `identity.stage_1` |
| `trusted_person_verification` | `identity_verification` | `positive` | `normal` | `identity.stage_1` |
| `order_details_disclosed` | `information_protection` | `negative` | `normal` | `information.stage_2` |
| `personal_information_withheld` | `information_protection` | `positive` | `normal` | `information.stage_2` |
| `order_checked_independently` | `information_protection` | `positive` | `normal` | `information.stage_2` |
| `unverified_refund_accepted` | `payment_awareness` | `negative` | `normal` | `payment.stage_3` |
| `original_route_refund_recognized` | `payment_awareness` | `positive` | `normal` | `payment.stage_3` |
| `transaction_paused_for_verification` | `payment_awareness` | `positive` | `normal` | `payment.stage_3` |
| `verification_code_shared` | `information_protection` | `negative` | `severe` | `information.stage_4` |
| `verification_code_shared` | `payment_awareness` | `negative` | `severe` | `payment.stage_4` |
| `unknown_link_opened` | `information_protection` | `negative` | `severe` | `information.stage_4` |
| `unknown_link_opened` | `payment_awareness` | `negative` | `severe` | `payment.stage_4` |
| `screen_sharing_enabled` | `information_protection` | `negative` | `severe` | `information.stage_4` |
| `screen_sharing_enabled` | `payment_awareness` | `negative` | `severe` | `payment.stage_4` |
| `sensitive_request_refused` | `information_protection` | `positive` | `normal` | `information.stage_4` |
| `sensitive_request_refused` | `payment_awareness` | `positive` | `normal` | `payment.stage_4` |
| `pressure_compliance` | `pressure_response` | `negative` | `normal` | `pressure.stage_5` |
| `paused_under_pressure` | `pressure_response` | `positive` | `normal` | `pressure.stage_5` |
| `help_not_sought` | `help_termination` | `negative` | `normal` | `help.stage_5` |
| `suspicious_contact_ended` | `help_termination` | `positive` | `normal` | `help.stage_5` |
| `help_sought` | `help_termination` | `positive` | `normal` | `help.stage_5` |

同一个阶段 4 按钮产生两个具有不同 `event_id` 的事件，分别占用信息保护和支付警觉机会点。事件类型可以
相同，但 `dimension` 与固定机会点不同。

## 4. 五维机会点与权重

| 维度 | 固定机会点 | 机会点数 | 权重 |
| --- | --- | ---: | ---: |
| `identity_verification`（身份核实） | `identity.stage_1` | 1 | 20% |
| `information_protection`（信息保护） | `information.stage_2`、`information.stage_4` | 2 | 25% |
| `payment_awareness`（支付警觉） | `payment.stage_3`、`payment.stage_4` | 2 | 25% |
| `pressure_response`（压力应对） | `pressure.stage_5` | 1 | 15% |
| `help_termination`（求助终止） | `help.stage_5` | 1 | 15% |

按表格顺序，五维机会点数固定为 `1, 2, 2, 1, 1`，权重固定为 `20, 25, 25, 15, 15`，权重之和为 100。

每个普通完成会话必须为七个固定机会点各提供且只提供一个有效事件。一个不同 `event_id` 的事件不得重复
占用已经被其他有效事件占用的机会点。

## 5. 维度分

每个固定机会点先转换为机会点分：

```text
positive opportunity = 100
negative opportunity = 0
```

维度基础分是该维度所有机会点分的算术平均：

```text
dimension_score = round_half_up(sum(opportunity_points) / opportunity_count)
```

这里的 `round_half_up` 只处理非负数，恰好为 `.5` 时向上取整。每个维度分必须是 0 至 100 的整数。

若一个维度包含任何 `severity=severe` 且 `direction=negative` 的事件，则在计算基础分后应用：

```text
dimension_score = min(dimension_score, 20)
```

因此严重负向事件把对应维度封顶为 20，但不把总分直接清零，也不删除其他维度的正向行为。

## 6. 总分

只有五个维度全部成功计算后才能计算总分：

```text
weighted_numerator =
    identity_verification * 20
  + information_protection * 25
  + payment_awareness * 25
  + pressure_response * 15
  + help_termination * 15

total_score = floor((weighted_numerator + 50) / 100)
```

实现必须使用整数分子和上述加 50 后整除的等价操作，不使用二进制浮点数决定舍入。`total_score` 是
0 至 100 的整数。

## 7. 完整性、幂等与拒绝

评分前按以下顺序处理事件：

1. 检查会话状态；`safety_stopped` 不生成总分。
2. 检查所有事件的 `scenario_version_id` 等于会话锁定值，否则返回
   `SCORING_SCENARIO_VERSION_MISMATCH`。
3. 按 `event_id` 去重；同一 `event_id` 的内容完全相同时只计算一次。
4. 同一 `event_id` 对应不同内容时返回 `SCORING_EVENT_CONFLICT`。
5. 检查事件类型、维度、方向、严重度和机会点与第 3 节一致，未知或不一致时返回
   `SCORING_EVENT_INVALID`。
6. 若两个不同事件占用同一固定机会点，返回 `SCORING_OPPORTUNITY_CONFLICT`。
7. 若任一固定机会点没有证据，返回 `SCORING_EVIDENCE_INCOMPLETE`，不以零分代替缺失证据。
8. 完整事件集才进入维度分、严重事件封顶、总分和普通结束状态计算。

任何拒绝结果都只返回安全的机器码和脱敏详情，不回显完整对话或敏感数据。

## 8. 结束状态

评分规则只为已经完成五阶段的普通会话派生普通结束状态：

- 存在任一严重负向事件，或存在 `pressure_compliance` 时，派生 `completed_risky`；
- 否则派生 `completed_safe`。

普通负向事件可以降低分数，但除 `pressure_compliance` 外不会单独把会话改为 `completed_risky`。
结束状态描述训练流程风险，不替代五维分数。

通过全局安全入口产生的 `safety_stopped` 由安全规则直接决定。控制事件保留给安全优先复盘，但该会话
不生成总分，也不派生普通结束状态。

## 9. 确定性示例

### 9.1 全正向路径

| 维度 | 机会点分 | 封顶后维度分 | 权重贡献 |
| --- | --- | ---: | ---: |
| 身份核实 | 100 | 100 | 2000 |
| 信息保护 | 100、100 | 100 | 2500 |
| 支付警觉 | 100、100 | 100 | 2500 |
| 压力应对 | 100 | 100 | 1500 |
| 求助终止 | 100 | 100 | 1500 |

`weighted_numerator=10000`，`total_score=100`，结束状态为 `completed_safe`。

```json
{
  "dimension_scores": {
    "identity_verification": 100,
    "information_protection": 100,
    "payment_awareness": 100,
    "pressure_response": 100,
    "help_termination": 100
  },
  "total_score": 100,
  "end_state": "completed_safe"
}
```

### 9.2 严重负向维度封顶

用户在阶段 2 和 3 作出正向选择，但阶段 4 选择模拟提供验证码，随后暂停并结束联系：

| 维度 | 机会点分 | 基础分 | 封顶后维度分 |
| --- | --- | ---: | ---: |
| 身份核实 | 100 | 100 | 100 |
| 信息保护 | 100、0 | 50 | 20 |
| 支付警觉 | 100、0 | 50 | 20 |
| 压力应对 | 100 | 100 | 100 |
| 求助终止 | 100 | 100 | 100 |

`weighted_numerator=6000`，`total_score=60`。由于存在严重负向事件，结束状态为
`completed_risky`，但阶段 5 的恢复行为仍保留为正向证据。

```json
{
  "dimension_scores": {
    "identity_verification": 100,
    "information_protection": 20,
    "payment_awareness": 20,
    "pressure_response": 100,
    "help_termination": 100
  },
  "total_score": 60,
  "end_state": "completed_risky",
  "severe_event_types": [
    "verification_code_shared"
  ]
}
```

### 9.3 幂等重复事件

以下两次输入内容完全相同，只占用一次 `identity.stage_1`：

```json
{
  "input_event_ids": [
    "550e8400-e29b-41d4-a716-446655440000",
    "550e8400-e29b-41d4-a716-446655440000"
  ],
  "unique_event_count": 1,
  "result": "accepted"
}
```

如果第二条事件复用该 ID 但改变 `event_type`、`dimension`、方向、严重度、版本或证据中的任一内容，
结果为 `SCORING_EVENT_CONFLICT`，不计算部分分数。

### 9.4 缺失证据

缺少阶段 5 的压力应对和求助终止证据时：

```json
{
  "code": "SCORING_EVIDENCE_INCOMPLETE",
  "message": "评分证据不完整",
  "details": {
    "missing_opportunities": [
      "pressure.stage_5",
      "help.stage_5"
    ]
  },
  "request_id": "a9cb2a7c-4c09-4f7b-8414-4ad3d2aeb004"
}
```

该结果没有 `dimension_scores` 或 `total_score` 字段。

## 10. 需求追踪

- FR-LEARN-005：学习与测评复用相同风险点、结束条件和评分含义；
- FR-ASSESS-001：结构化事件携带来源、证据和场景版本；
- FR-ASSESS-002 至 FR-ASSESS-003：最终分数仅由本文的确定性规则计算；
- FR-ASSESS-004：结果固定包含身份核实、信息保护、支付警觉、压力应对和求助终止；
- FR-ASSESS-005：严重负向结论必须来自确定性的高风险按钮证据；
- FR-FALLBACK-004 至 FR-FALLBACK-005：L4 使用按钮证据和相同规则评分，不改变评分含义。
