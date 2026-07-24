# T00-03 客服退款 L4 场景与评分设计

## 1. 文档状态

- 日期：2026-07-24
- 状态：已确认，等待用户审核后进入实施计划
- Task：T00-03
- 依赖：T00-02
- 交付目标：锁定客服退款 L4 场景、行为证据和确定性评分规则

本文记录 T00-03 已确认的产品契约设计。正式交付将写入
`docs/SCENARIO_CUSTOMER_REFUND_V1.md` 和 `docs/SCORING_RULES.md`。

## 2. 设计边界

本 Task 只定义文字按钮模式下的场景阶段、选择、转换、行为事件、证据来源、结束状态和评分算法。
所有文案与订单资料均为虚构内容，任何按钮都不得要求用户输入真实验证码、订单、银行卡或身份信息。

本 Task 不定义 Pydantic 模型、HTTP 路由、数据库表、页面、自由文本识别、管理端发布生命周期或 AI
裁决逻辑。

## 3. 场景图

场景使用无回环的五阶段有向图：

```text
customer_identity
→ order_anomaly
→ refund_offer
→ sensitive_action
→ time_pressure
→ completed_safe / completed_risky
```

普通选择只向下一阶段推进。安全选择不会提前结束普通场景，因为完整五维评分需要覆盖全部固定证据机会。
诈骗者在用户作出安全选择后更换话术继续试探，不否定用户已经产生的正向事件。

任一阶段均提供两个全局安全入口，它们优先于普通转换并立即进入 `safety_stopped`：

- `end_training`：结束训练，`end_reason=user_ended`；
- `suspected_real_fraud`：我可能正在实际受骗，`end_reason=suspected_real_fraud`。

因此普通路径固定在五次场景选择后结束，安全路径在当前选择立即结束，不存在循环或无穷路径。

## 4. 阶段、按钮与转换

### 4.1 `customer_identity`

诈骗者自称平台客服并给出虚构工号。

| `choice_id` | 按钮含义 | 事件 | 目标 |
| --- | --- | --- | --- |
| `listen_without_verifying` | 不核实，继续听 | `identity_not_verified` | `order_anomaly` |
| `verify_via_official_channel` | 通过平台官方入口核实 | `official_channel_verification` | `order_anomaly` |
| `ask_trusted_person_to_verify` | 请可信家人协助核实 | `trusted_person_verification` | `order_anomaly` |

### 4.2 `order_anomaly`

诈骗者声称虚构订单存在质量问题或异常扣费。

| `choice_id` | 按钮含义 | 事件 | 目标 |
| --- | --- | --- | --- |
| `disclose_order_details` | 告知模拟订单资料 | `order_details_disclosed` | `refund_offer` |
| `continue_without_disclosure` | 不提供个人资料，要求继续说明 | `personal_information_withheld` | `refund_offer` |
| `check_order_independently` | 自己打开平台核对订单 | `order_checked_independently` | `refund_offer` |

### 4.3 `refund_offer`

诈骗者承诺退款或额外赔付，并诱导用户按其流程操作。

| `choice_id` | 按钮含义 | 事件 | 目标 |
| --- | --- | --- | --- |
| `accept_unverified_refund` | 接受未经核实的退款步骤 | `unverified_refund_accepted` | `sensitive_action` |
| `require_original_route_refund` | 指出退款应原路返回 | `original_route_refund_recognized` | `sensitive_action` |
| `pause_for_official_verification` | 暂停并联系平台官方客服 | `transaction_paused_for_verification` | `sensitive_action` |

### 4.4 `sensitive_action`

诈骗者要求点击陌生链接、共享屏幕或提供验证码。

| `choice_id` | 按钮含义 | 事件 | 目标 |
| --- | --- | --- | --- |
| `share_verification_code` | 提供模拟验证码 | `verification_code_shared` | `time_pressure` |
| `open_unknown_link` | 点击模拟陌生链接 | `unknown_link_opened` | `time_pressure` |
| `enable_screen_sharing` | 同意模拟屏幕共享 | `screen_sharing_enabled` | `time_pressure` |
| `refuse_sensitive_actions` | 全部拒绝 | `sensitive_request_refused` | `time_pressure` |

每个阶段 4 选择都分别为信息保护和支付警觉生成一个评分机会事件。文档中的行为事件名称表示用户行为，
不表示系统真的展示可操作链接、启动屏幕共享或接收验证码。

### 4.5 `time_pressure`

诈骗者以退款失效、持续扣费等理由催促。

| `choice_id` | 按钮含义 | 事件 | 普通结束候选 |
| --- | --- | --- | --- |
| `comply_under_pressure` | 马上照做 | `pressure_compliance`、`help_not_sought` | `completed_risky` |
| `pause_and_verify` | 暂停操作，挂断后独立核实 | `paused_under_pressure`、`suspicious_contact_ended` | `completed_safe` |
| `seek_trusted_help` | 请家人或官方客服协助 | `paused_under_pressure`、`help_sought` | `completed_safe` |

若任意阶段已经产生严重负向事件，最终状态改为 `completed_risky`，即使用户在阶段 5 恢复了安全行为；
恢复行为仍保留为正向证据并进入复盘。

## 5. 行为事件与证据

评分事件包含稳定的英文事件类型、评分维度、方向、严重度和证据：

- `direction` 仅为 `positive` 或 `negative`；
- `severity` 仅为 `normal` 或 `severe`；
- L4 评分事件的 `evidence_source` 固定为 `button_choice`；
- 证据引用 `stage_id`、`choice_id`，并提供不含个人数据的简短摘要；
- 事件必须关联会话锁定的 `scenario_version_id`。

`verification_code_shared`、`unknown_link_opened` 和 `screen_sharing_enabled` 是严重负向行为，并分别在
信息保护与支付警觉维度产生事件。其他普通选择按其表格语义产生正向或普通负向事件。

全局安全入口生成不参与评分的控制事件：

- `training_ended_by_user`；
- `suspected_real_fraud_declared`。

控制事件的 `evidence_source` 为 `safety_control`。安全中止只保留脱敏证据并进入对应安全复盘，不生成
五维总分。

## 6. 评分设计

### 6.1 维度与权重

| 维度 | 固定机会点 | 权重 |
| --- | ---: | ---: |
| 身份核实 | 阶段 1，共 1 个 | 20% |
| 信息保护 | 阶段 2、4，共 2 个 | 25% |
| 支付警觉 | 阶段 3、4，共 2 个 | 25% |
| 压力应对 | 阶段 5，共 1 个 | 15% |
| 求助终止 | 阶段 5，共 1 个 | 15% |

### 6.2 维度分

- 每个正向机会点计 100 分；
- 每个负向机会点计 0 分；
- 多个机会点取算术平均，并按非负整数四舍五入；
- 任一严重负向事件会将其所属维度最终分封顶为 20 分。

严重负向采用维度封顶而不是总分清零，既明确反映验证码、陌生链接和屏幕共享风险，也保留其他已观察
安全行为的学习价值。

### 6.3 总分

```text
weighted_numerator =
    identity_verification * 20
  + information_protection * 25
  + payment_awareness * 25
  + pressure_response * 15
  + help_termination * 15

total_score = floor((weighted_numerator + 50) / 100)
```

所有维度分和总分均为 0 至 100 的整数。整数分子与加 50 后整除的规则固定了四舍五入语义，避免浮点
实现差异。

### 6.4 完整性与幂等

- 缺少任一固定机会点证据时拒绝评分，不以零分代替；
- 同一 `event_id`、内容完全相同的重复事件只计算一次；
- 同一 `event_id` 对应不同内容时拒绝评分；
- 事件不属于会话锁定的 `scenario_version_id` 时拒绝评分；
- `safety_stopped` 会话拒绝生成总分。

## 7. 结束状态

- `completed_safe`：完成五阶段，不存在严重负向事件，且最终没有在压力下继续操作；
- `completed_risky`：完成五阶段，并出现至少一个严重负向事件或 `pressure_compliance`；
- `safety_stopped`：通过任一全局安全入口立即退出诈骗角色。

结束状态描述训练流程结果，不替代五维得分。普通负向事件可能出现在 `completed_safe` 会话中，并继续
影响维度分和复盘内容。

## 8. 文档验收设计

正式交付文档需要通过可重复的文档契约检查，至少证明：

1. 五个阶段、所有按钮、目标和三种结束状态均有唯一稳定标识；
2. 每个普通选择映射到一个下一目标和一个或多个评分事件；
3. 两个全局安全入口从任一阶段都能立即结束；
4. 图中不存在未知目标、回环或无结束路径；
5. 五维机会点完整，权重之和为 100；
6. 示例事件能够按 T00-02 的 JSON、字段命名、枚举和 `scenario_version_id` 约定解析；
7. 评分示例覆盖全正向、普通负向、严重负向封顶、重复事件和缺失证据。

## 9. 需求追踪

- FR-LEARN-005：固定学习和动态测评复用场景状态机、风险点、结束条件和评分定义；
- FR-TRAIN-005：用户可随时结束训练；
- FR-ASSESS-001 至 FR-ASSESS-005：证据事件、确定性评分、五维结果和严重结论约束；
- FR-SAFETY-001 至 FR-SAFETY-004：疑似真实受骗时优先退出角色且不自动对外处置；
- FR-SCENE-001：覆盖身份、订单异常、退款、验证码、陌生链接、屏幕共享和时间压力；
- FR-FALLBACK-004 至 FR-FALLBACK-005：L4 使用文字按钮和规则评分，且不改变结束与评分含义。
