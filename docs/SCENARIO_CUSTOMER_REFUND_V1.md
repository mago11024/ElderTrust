# 客服退款 L4 场景 V1

## 1. 契约身份

- 场景键：`customer_refund`
- 场景版本：`1`
- 运行等级：`l4`
- 交互方式：文字与审核按钮
- 初始阶段：`customer_identity`
- 普通结束状态：`completed_safe`、`completed_risky`
- 安全结束状态：`safety_stopped`

本文遵循 [`DATA_CONVENTIONS.md`](./DATA_CONVENTIONS.md) 的字段和枚举约定。训练会话开始时必须锁定
`scenario_version_id`，后续选择、行为事件和评分均引用同一版本。

场景仅使用虚构平台、虚构商品和虚构订单。按钮表达的是模拟训练行为，不展示可操作的陌生链接，不启动
屏幕共享，不接收验证码、银行卡号、证件号、详细住址或其他真实个人数据。

本文只锁定 L4 文字按钮契约，不定义 Pydantic 模型、HTTP 路由、数据库表、页面、自由文本识别、语音
识别或管理端发布生命周期。

## 2. 场景结构

普通流程是单向、无回环的五阶段有向图：

```text
customer_identity
→ order_anomaly
→ refund_offer
→ sensitive_action
→ time_pressure
→ completed_safe / completed_risky
```

普通按钮在前四个阶段只转换到紧邻的下一阶段。阶段 5 的选择结束普通流程，具体结束状态依据
[`SCORING_RULES.md`](./SCORING_RULES.md) 中的严重负向事件和压力顺从规则确定。

用户作出安全选择后，诈骗者会更换话术继续试探，让一次完整训练覆盖全部五维评分机会。前一阶段已经产生
的正向或负向事件均保留，不因后续选择被删除。

## 3. 阶段与普通选择

### 3.1 `customer_identity`：客服身份

虚构话术：

> 您好，我是安信商城售后客服。系统显示您最近购买的保温杯存在问题，我的工号是虚构的 A-17，请先听我
> 说明处理办法。

| `choice_id` | 按钮文案 | 行为事件 | 方向 | 严重度 | 目标 |
| --- | --- | --- | --- | --- | --- |
| `listen_without_verifying` | 我先听听你怎么说 | `identity_not_verified` | `negative` | `normal` | `order_anomaly` |
| `verify_via_official_channel` | 我会从平台官方入口核实 | `official_channel_verification` | `positive` | `normal` | `order_anomaly` |
| `ask_trusted_person_to_verify` | 我请可信家人一起核实 | `trusted_person_verification` | `positive` | `normal` | `order_anomaly` |

本阶段的三个选择分别占用身份核实维度的唯一固定机会点。

### 3.2 `order_anomaly`：订单异常

虚构话术：

> 这笔虚构订单被标记为重复扣费，需要马上确认资料才能取消。您可以继续听退款方案，也可以自己核对。

| `choice_id` | 按钮文案 | 行为事件 | 方向 | 严重度 | 目标 |
| --- | --- | --- | --- | --- | --- |
| `disclose_order_details` | 我把模拟订单资料告诉你 | `order_details_disclosed` | `negative` | `normal` | `refund_offer` |
| `continue_without_disclosure` | 我不提供个人资料，你继续说明 | `personal_information_withheld` | `positive` | `normal` | `refund_offer` |
| `check_order_independently` | 我自己打开平台核对订单 | `order_checked_independently` | `positive` | `normal` | `refund_offer` |

本阶段的三个选择分别占用信息保护维度的第一个固定机会点。按钮不会打开真实订单，也不会要求用户输入
订单资料。

### 3.3 `refund_offer`：退款赔付

虚构话术：

> 为表示歉意，我们可以办理退款和额外赔付。您只要按我说的步骤操作，款项很快就能到账。

| `choice_id` | 按钮文案 | 行为事件 | 方向 | 严重度 | 目标 |
| --- | --- | --- | --- | --- | --- |
| `accept_unverified_refund` | 我按你的退款步骤操作 | `unverified_refund_accepted` | `negative` | `normal` | `sensitive_action` |
| `require_original_route_refund` | 退款应原路返回，不需要我额外操作 | `original_route_refund_recognized` | `positive` | `normal` | `sensitive_action` |
| `pause_for_official_verification` | 我先联系平台官方客服核实 | `transaction_paused_for_verification` | `positive` | `normal` | `sensitive_action` |

本阶段的三个选择分别占用支付警觉维度的第一个固定机会点。

### 3.4 `sensitive_action`：敏感操作

虚构话术：

> 系统提示退款通道需要进一步验证。训练中会模拟陌生链接、屏幕共享和验证码请求，但不会执行任何真实
> 操作。

阶段 4 的每个选择同时产生信息保护和支付警觉两个评分事件，并分别占用这两个维度的第二个固定机会点。

| `choice_id` | 按钮文案 | 行为事件 | 方向 | 严重度 | 目标 |
| --- | --- | --- | --- | --- | --- |
| `share_verification_code` | 我把模拟验证码告诉你 | `verification_code_shared` × 2 | `negative` | `severe` | `time_pressure` |
| `open_unknown_link` | 我点击模拟陌生链接 | `unknown_link_opened` × 2 | `negative` | `severe` | `time_pressure` |
| `enable_screen_sharing` | 我同意模拟屏幕共享 | `screen_sharing_enabled` × 2 | `negative` | `severe` | `time_pressure` |
| `refuse_sensitive_actions` | 我全部拒绝，不点击也不共享 | `sensitive_request_refused` × 2 | `positive` | `normal` | `time_pressure` |

表中的“× 2”表示相同 `event_type` 分别生成一条 `information_protection` 事件和一条
`payment_awareness` 事件；每条事件具有独立 `event_id`，不得用一条事件同时占用两个机会点。

### 3.5 `time_pressure`：时间压力

虚构话术：

> 如果现在不完成，退款资格会失效，而且可能继续产生虚构扣费。请马上决定。

| `choice_id` | 按钮文案 | 行为事件 | 方向 | 严重度 | 普通结束候选 |
| --- | --- | --- | --- | --- | --- |
| `comply_under_pressure` | 我马上照做 | `pressure_compliance`、`help_not_sought` | `negative`、`negative` | `normal` | `completed_risky` |
| `pause_and_verify` | 我暂停操作，挂断后独立核实 | `paused_under_pressure`、`suspicious_contact_ended` | `positive`、`positive` | `normal` | `completed_safe` |
| `seek_trusted_help` | 我请家人或官方客服协助 | `paused_under_pressure`、`help_sought` | `positive`、`positive` | `normal` | `completed_safe` |

第一个事件占用压力应对机会点，第二个事件占用求助终止机会点。若前四个阶段存在任一 `severe` 负向
事件，即使阶段 5 的选择是正向，最终状态仍从候选值改为 `completed_risky`；阶段 5 的正向事件继续进入
评分和复盘。

## 4. 全局安全入口

以下两个按钮在五个阶段始终展示，并在普通选择之前处理：

| `choice_id` | 按钮文案 | 控制事件 | `evidence_source` | 结束状态 | `end_reason` |
| --- | --- | --- | --- | --- | --- |
| `end_training` | 结束训练 | `training_ended_by_user` | `safety_control` | `safety_stopped` | `user_ended` |
| `suspected_real_fraud` | 我可能正在实际受骗 | `suspected_real_fraud_declared` | `safety_control` | `safety_stopped` | `suspected_real_fraud` |

安全入口立即停止诈骗角色和后续普通转换。`suspected_real_fraud` 还必须进入安全优先复盘，提醒用户停止
转账、停止提供信息并通过独立官方渠道核实；它不自动报警、不自动冻结资金，也不在未经当次确认时联系
家属。

两个控制事件不占用评分机会点，`safety_stopped` 会话不生成五维总分。

## 5. 有限结束证明

五个普通阶段的索引依次为 1 至 5。所有普通边满足以下条件：

- 阶段 1 至 4 的目标索引严格等于当前索引加 1；
- 阶段 5 没有指向普通阶段的边，只产生一个普通结束状态；
- 全局安全边从任意阶段直接指向 `safety_stopped`；
- 文档没有指向未定义阶段或未定义结束状态的目标。

因此普通路径恰好包含五次普通选择，安全路径在当前阶段立即结束。任何路径都不会回到既有阶段，最多五次
普通选择后必然结束，不存在循环、无回环例外或无结束路径。

## 6. 机器可读示例

### 6.1 严重负向普通选择

```json
{
  "scenario_key": "customer_refund",
  "scenario_version": 1,
  "scenario_version_id": "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c",
  "stage_id": "sensitive_action",
  "choice_id": "share_verification_code",
  "target": "time_pressure",
  "behavior_events": [
    {
      "event_type": "verification_code_shared",
      "dimension": "information_protection",
      "direction": "negative",
      "severity": "severe",
      "evidence_source": "button_choice"
    },
    {
      "event_type": "verification_code_shared",
      "dimension": "payment_awareness",
      "direction": "negative",
      "severity": "severe",
      "evidence_source": "button_choice"
    }
  ]
}
```

### 6.2 疑似真实受骗安全选择

```json
{
  "scenario_key": "customer_refund",
  "scenario_version": 1,
  "scenario_version_id": "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c",
  "stage_id": "refund_offer",
  "choice_id": "suspected_real_fraud",
  "target": "safety_stopped",
  "end_reason": "suspected_real_fraud",
  "control_events": [
    {
      "event_type": "suspected_real_fraud_declared",
      "evidence_source": "safety_control",
      "scoring_eligible": false
    }
  ]
}
```

## 7. 需求追踪

- FR-LEARN-005：固定学习与动态测评可复用相同阶段、风险点和结束定义；
- FR-TRAIN-005：两个全局入口允许用户随时结束角色扮演；
- FR-ASSESS-001 至 FR-ASSESS-005：每个普通按钮生成可追踪的确定性证据事件；
- FR-SAFETY-001 至 FR-SAFETY-004：疑似真实受骗优先于普通转换且不触发未经授权的外部处置；
- FR-SCENE-001：覆盖客服身份、订单异常、退款赔付、验证码、陌生链接、屏幕共享和时间压力；
- FR-FALLBACK-004 至 FR-FALLBACK-005：L4 使用文字按钮和规则评分，不改变场景版本和安全含义。
