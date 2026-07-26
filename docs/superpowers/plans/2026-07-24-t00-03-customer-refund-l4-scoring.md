# T00-03 Customer Refund L4 Scenario and Scoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an unambiguous, finite customer-refund L4 button scenario and deterministic five-dimension scoring contract.

**Architecture:** Two Markdown contracts separate scenario flow from reusable scoring semantics. The scenario contract owns stages, choices, transitions, behavior-event mappings, and safety controls; the scoring contract owns evidence completeness, idempotency, dimension calculation, severe-event caps, total calculation, and end-state derivation. Executable PowerShell assertions validate both contracts without introducing runtime models that belong to later Tasks.

**Tech Stack:** Markdown, JSON examples, PowerShell 5.1-compatible contract assertions, existing repository governance scripts.

---

## File map

- Create `docs/SCENARIO_CUSTOMER_REFUND_V1.md`: versioned L4 scenario graph, button choices, events, global safety controls, and finite-path proof.
- Create `docs/SCORING_RULES.md`: behavior evidence contract, five dimensions, fixed opportunity points, weights, severe-event caps, idempotency, formula, examples, and refusal conditions.
- Modify `docs/CURRENT_STATUS.md`: move the development pointer to T00-03 at start and mark it completed only after fresh acceptance evidence.

The Task does not create Pydantic models, application source, UI files, HTTP routes, database tables, or free-text recognition rules.

### Task 1: Start T00-03 and establish the RED contract

**Files:**
- Modify: `docs/CURRENT_STATUS.md`
- Test: transient PowerShell assertions against `docs/SCENARIO_CUSTOMER_REFUND_V1.md` and `docs/SCORING_RULES.md`

- [ ] **Step 1: Move the current development pointer to T00-03**

Set the YAML fields in `docs/CURRENT_STATUS.md` to:

```yaml
current_milestone: M0
milestone_status: active
current_task: T00-03
status: in_progress
last_completed_task: T00-02
next_task: T00-04
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
updated_at: 2026-07-24
```

Keep the existing `task_catalog` and last successful T00-02 verification record unchanged.

- [ ] **Step 2: Verify the repository reports T00-03 and its satisfied dependency**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/show_current_task.ps1
```

Expected: output includes `Current Task: T00-03`, dependency `T00-02`, and next Gate `T00-04`.

- [ ] **Step 3: Run the scenario/scoring existence assertion and observe RED**

Run:

```powershell
powershell.exe -NoProfile -Command @'
$ErrorActionPreference = "Stop"
$required = @(
  "docs/SCENARIO_CUSTOMER_REFUND_V1.md",
  "docs/SCORING_RULES.md"
)
foreach ($path in $required) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "missing contract: $path"
  }
}
'@
```

Expected: FAIL with `missing contract: docs/SCENARIO_CUSTOMER_REFUND_V1.md`.

- [ ] **Step 4: Commit the focused Task start**

```powershell
git add -- docs/CURRENT_STATUS.md
git commit -m "chore: start T00-03"
```

### Task 2: Define the finite L4 scenario contract

**Files:**
- Create: `docs/SCENARIO_CUSTOMER_REFUND_V1.md`
- Test: transient PowerShell scenario assertions

- [ ] **Step 1: Write the scenario document with the locked identity and scope**

Create the document with:

```markdown
# 客服退款 L4 场景 V1

## 1. 契约身份

- 场景键：`customer_refund`
- 场景版本：`1`
- 运行等级：`l4`
- 交互方式：文字与审核按钮
- 初始阶段：`customer_identity`

本文遵循 `DATA_CONVENTIONS.md`。示例只使用虚构订单和模拟风险操作。
```

Add explicit exclusions for real links, real verification codes, screen-sharing activation, personal-data collection, free-text recognition, and runtime models.

- [ ] **Step 2: Add all stages, choice IDs, events, and targets**

Use this exact transition inventory:

| Stage | Choice | Scoring event type(s) | Target |
| --- | --- | --- | --- |
| `customer_identity` | `listen_without_verifying` | `identity_not_verified` | `order_anomaly` |
| `customer_identity` | `verify_via_official_channel` | `official_channel_verification` | `order_anomaly` |
| `customer_identity` | `ask_trusted_person_to_verify` | `trusted_person_verification` | `order_anomaly` |
| `order_anomaly` | `disclose_order_details` | `order_details_disclosed` | `refund_offer` |
| `order_anomaly` | `continue_without_disclosure` | `personal_information_withheld` | `refund_offer` |
| `order_anomaly` | `check_order_independently` | `order_checked_independently` | `refund_offer` |
| `refund_offer` | `accept_unverified_refund` | `unverified_refund_accepted` | `sensitive_action` |
| `refund_offer` | `require_original_route_refund` | `original_route_refund_recognized` | `sensitive_action` |
| `refund_offer` | `pause_for_official_verification` | `transaction_paused_for_verification` | `sensitive_action` |
| `sensitive_action` | `share_verification_code` | `verification_code_shared` in information and payment | `time_pressure` |
| `sensitive_action` | `open_unknown_link` | `unknown_link_opened` in information and payment | `time_pressure` |
| `sensitive_action` | `enable_screen_sharing` | `screen_sharing_enabled` in information and payment | `time_pressure` |
| `sensitive_action` | `refuse_sensitive_actions` | `sensitive_request_refused` in information and payment | `time_pressure` |
| `time_pressure` | `comply_under_pressure` | `pressure_compliance`, `help_not_sought` | ordinary end |
| `time_pressure` | `pause_and_verify` | `paused_under_pressure`, `suspicious_contact_ended` | ordinary end |
| `time_pressure` | `seek_trusted_help` | `paused_under_pressure`, `help_sought` | ordinary end |

For every choice, include visible Simplified Chinese button copy and a short, synthetic scammer prompt. State that every ordinary choice advances exactly one stage and that stage 5 derives either `completed_safe` or `completed_risky` according to `SCORING_RULES.md`.

- [ ] **Step 3: Add global safety transitions and the finite-path proof**

Specify both controls as available at every stage and evaluated before ordinary choices:

| Control choice | Control event | End state | End reason |
| --- | --- | --- | --- |
| `end_training` | `training_ended_by_user` | `safety_stopped` | `user_ended` |
| `suspected_real_fraud` | `suspected_real_fraud_declared` | `safety_stopped` | `suspected_real_fraud` |

State that the ordinary graph has edges only from stage index `n` to `n + 1`, so an ordinary path has exactly five choices; a safety path ends immediately. No target may point to an undefined stage.

- [ ] **Step 4: Add machine-readable JSON examples**

Include one ordinary choice example and one safety-control example. The ordinary example must use:

```json
{
  "scenario_key": "customer_refund",
  "scenario_version": 1,
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

- [ ] **Step 5: Run scenario assertions**

Run:

```powershell
powershell.exe -NoProfile -Command @'
$ErrorActionPreference = "Stop"
$path = "docs/SCENARIO_CUSTOMER_REFUND_V1.md"
$text = Get-Content -Raw -LiteralPath $path
$required = @(
  "customer_identity", "order_anomaly", "refund_offer", "sensitive_action", "time_pressure",
  "listen_without_verifying", "verify_via_official_channel", "ask_trusted_person_to_verify",
  "disclose_order_details", "continue_without_disclosure", "check_order_independently",
  "accept_unverified_refund", "require_original_route_refund", "pause_for_official_verification",
  "share_verification_code", "open_unknown_link", "enable_screen_sharing", "refuse_sensitive_actions",
  "comply_under_pressure", "pause_and_verify", "seek_trusted_help",
  "end_training", "suspected_real_fraud",
  "completed_safe", "completed_risky", "safety_stopped",
  "无回环", "最多五次"
)
foreach ($value in $required) {
  if (-not $text.Contains($value)) { throw "missing scenario contract value: $value" }
}
$matches = [regex]::Matches($text, '(?ms)```json\s*(.*?)\s*```')
if ($matches.Count -lt 2) { throw "scenario contract needs at least two JSON examples" }
foreach ($match in $matches) {
  $null = $match.Groups[1].Value | ConvertFrom-Json
}
Write-Output "T00-03 scenario contract passed"
'@
```

Expected: PASS with a final line `T00-03 scenario contract passed`.

- [ ] **Step 6: Commit the scenario contract**

```powershell
git add -- docs/SCENARIO_CUSTOMER_REFUND_V1.md
git commit -m "docs: define customer refund L4 scenario"
```

### Task 3: Define deterministic scoring and evidence rules

**Files:**
- Create: `docs/SCORING_RULES.md`
- Test: transient PowerShell scoring assertions

- [ ] **Step 1: Write the evidence contract and fixed opportunity matrix**

Define these required fields for a scoring event:

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

Lock the opportunities and weights:

| Dimension | Required opportunities | Weight |
| --- | --- | ---: |
| `identity_verification` | stage 1 | 20 |
| `information_protection` | stages 2 and 4 | 25 |
| `payment_awareness` | stages 3 and 4 | 25 |
| `pressure_response` | stage 5 | 15 |
| `help_termination` | stage 5 | 15 |

- [ ] **Step 2: Define dimension and total formulas**

Write these exact rules:

```text
positive opportunity = 100
negative opportunity = 0
dimension_score = round_half_up(sum(opportunity_points) / opportunity_count)
if dimension contains a severe negative event:
    dimension_score = min(dimension_score, 20)

weighted_numerator =
    identity_verification * 20
  + information_protection * 25
  + payment_awareness * 25
  + pressure_response * 15
  + help_termination * 15

total_score = floor((weighted_numerator + 50) / 100)
```

State that every dimension and the total are integers from 0 through 100 and that weights total 100.

- [ ] **Step 3: Define rejection, deduplication, safety, and end-state rules**

Lock these behaviors:

- reject scoring if any required opportunity is missing;
- count byte-for-byte equivalent duplicate `event_id` content once;
- reject the event set when one `event_id` has conflicting content;
- reject events whose `scenario_version_id` differs from the session lock;
- never score `safety_stopped`;
- derive `completed_risky` when any severe negative exists or `pressure_compliance` exists;
- otherwise derive `completed_safe` after all five stages.

Clarify that control events use `safety_control`, do not occupy scoring opportunities, and remain available for a safety-first review.

- [ ] **Step 4: Add complete deterministic examples**

Include tables for:

1. an all-positive path producing five dimension scores of 100 and total 100;
2. a path with positive stage-2 information behavior and severe stage-4 information/payment behavior, producing information and payment scores capped at 20;
3. duplicate identical events producing the same score;
4. missing stage-5 evidence producing `SCORING_EVIDENCE_INCOMPLETE` rather than a score.

All JSON examples must follow UUID, `snake_case`, enum, and `scenario_version_id` conventions from T00-02.

- [ ] **Step 5: Run scoring assertions**

Run:

```powershell
powershell.exe -NoProfile -Command @'
$ErrorActionPreference = "Stop"
$path = "docs/SCORING_RULES.md"
$text = Get-Content -Raw -LiteralPath $path
$required = @(
  "identity_verification", "information_protection", "payment_awareness",
  "pressure_response", "help_termination",
  "20%", "25%", "15%", "权重之和为 100",
  "1, 2, 2, 1, 1", "封顶为 20",
  "floor((weighted_numerator + 50) / 100)",
  "completed_safe", "completed_risky", "safety_stopped",
  "event_id", "只计算一次", "不同内容",
  "SCORING_EVIDENCE_INCOMPLETE", "不生成总分"
)
foreach ($value in $required) {
  if (-not $text.Contains($value)) { throw "missing scoring contract value: $value" }
}
$matches = [regex]::Matches($text, '(?ms)```json\s*(.*?)\s*```')
if ($matches.Count -lt 2) { throw "scoring contract needs at least two JSON examples" }
foreach ($match in $matches) {
  $null = $match.Groups[1].Value | ConvertFrom-Json
}
Write-Output "T00-03 scoring contract passed"
'@
```

Expected: PASS with a final line `T00-03 scoring contract passed`.

- [ ] **Step 6: Commit the scoring contract**

```powershell
git add -- docs/SCORING_RULES.md
git commit -m "docs: define deterministic five-dimension scoring"
```

### Task 4: Run acceptance, regression, and complete T00-03

**Files:**
- Modify: `docs/CURRENT_STATUS.md`
- Verify: both T00-03 contracts and repository governance

- [ ] **Step 1: Run the combined T00-03 contract assertion**

Run:

```powershell
powershell.exe -NoProfile -Command @'
$ErrorActionPreference = "Stop"
$contracts = @(
  @{
    Path = "docs/SCENARIO_CUSTOMER_REFUND_V1.md"
    Required = @(
      "customer_identity", "order_anomaly", "refund_offer", "sensitive_action", "time_pressure",
      "listen_without_verifying", "verify_via_official_channel", "ask_trusted_person_to_verify",
      "disclose_order_details", "continue_without_disclosure", "check_order_independently",
      "accept_unverified_refund", "require_original_route_refund", "pause_for_official_verification",
      "share_verification_code", "open_unknown_link", "enable_screen_sharing", "refuse_sensitive_actions",
      "comply_under_pressure", "pause_and_verify", "seek_trusted_help",
      "end_training", "suspected_real_fraud",
      "completed_safe", "completed_risky", "safety_stopped",
      "无回环", "最多五次"
    )
    Success = "T00-03 scenario contract passed"
  },
  @{
    Path = "docs/SCORING_RULES.md"
    Required = @(
      "identity_verification", "information_protection", "payment_awareness",
      "pressure_response", "help_termination",
      "20%", "25%", "15%", "权重之和为 100",
      "1, 2, 2, 1, 1", "封顶为 20",
      "floor((weighted_numerator + 50) / 100)",
      "completed_safe", "completed_risky", "safety_stopped",
      "event_id", "只计算一次", "不同内容",
      "SCORING_EVIDENCE_INCOMPLETE", "不生成总分"
    )
    Success = "T00-03 scoring contract passed"
  }
)
foreach ($contract in $contracts) {
  $text = Get-Content -Raw -LiteralPath $contract.Path
  foreach ($value in $contract.Required) {
    if (-not $text.Contains($value)) {
      throw "missing contract value in $($contract.Path): $value"
    }
  }
  $matches = [regex]::Matches($text, '(?ms)```json\s*(.*?)\s*```')
  if ($matches.Count -lt 2) { throw "insufficient JSON examples: $($contract.Path)" }
  foreach ($match in $matches) {
    $null = $match.Groups[1].Value | ConvertFrom-Json
  }
  Write-Output $contract.Success
}
'@
```

Expected: both `T00-03 scenario contract passed` and `T00-03 scoring contract passed`.

- [ ] **Step 2: Parse every JSON example in both new documents**

Run:

```powershell
powershell.exe -NoProfile -Command @'
$ErrorActionPreference = "Stop"
$paths = @(
  "docs/SCENARIO_CUSTOMER_REFUND_V1.md",
  "docs/SCORING_RULES.md"
)
foreach ($path in $paths) {
  $text = Get-Content -Raw -LiteralPath $path
  $matches = [regex]::Matches($text, '(?ms)```json\s*(.*?)\s*```')
  if ($matches.Count -eq 0) { throw "no JSON examples: $path" }
  foreach ($match in $matches) {
    $null = $match.Groups[1].Value | ConvertFrom-Json
  }
}
Write-Output "T00-03 JSON examples passed"
'@
```

Expected: PASS with `T00-03 JSON examples passed`.

- [ ] **Step 3: Run affected regression and catalog validation**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_show_current_task.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_validate_task_catalog.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate_task_catalog.ps1
```

Expected: all commands return exit code 0.

- [ ] **Step 4: Check repository hygiene**

Run:

```powershell
git diff --check
Select-String -Path docs/SCENARIO_CUSTOMER_REFUND_V1.md,docs/SCORING_RULES.md -Pattern 'T[B]D|T[O]DO|真实验证码|真实银行卡号'
git status --short
```

Expected: `git diff --check` is clean; no placeholders or real sensitive test data; only the intended status update remains uncommitted.

- [ ] **Step 5: Mark T00-03 completed with fresh evidence**

Update `docs/CURRENT_STATUS.md`:

```yaml
current_task: T00-03
status: completed
last_completed_task: T00-03
next_task: T00-04
last_verification:
  command: T00-03 scenario/scoring assertions + JSON parsing + governance tests + scripts/validate_task_catalog.ps1
  result: passed
  verified_at: 2026-07-24
updated_at: 2026-07-24
```

Keep blockers empty and do not advance `current_task` to T00-04.

- [ ] **Step 6: Re-run the current-task reporter**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/show_current_task.ps1
```

Expected: T00-03 is current and completed; T00-04 is reported as the next Gate.

- [ ] **Step 7: Commit Task completion**

```powershell
git add -- docs/CURRENT_STATUS.md
git commit -m "chore: complete T00-03"
```

- [ ] **Step 8: Confirm the final tree**

Run:

```powershell
git status --short
git log -5 --oneline
```

Expected: clean worktree and focused T00-03 commits only.
