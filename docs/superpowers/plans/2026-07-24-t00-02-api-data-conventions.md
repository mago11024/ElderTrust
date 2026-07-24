# T00-02 API and Data Conventions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the single API and JSON data contract that all later API tasks will reuse.

**Architecture:** `docs/DATA_CONVENTIONS.md` owns representation rules and stable training-domain names, while `docs/API_CONVENTIONS.md` owns transport-facing success, idempotency, pagination, and error contracts. Inline PowerShell assertions provide test-first verification without adding files outside T00-02, and `docs/CURRENT_STATUS.md` records only the dynamic task pointer and fresh acceptance evidence.

**Tech Stack:** Markdown, JSON, PowerShell 5.1 `ConvertFrom-Json`, repository governance scripts.

---

## File map

- Create `docs/DATA_CONVENTIONS.md`: canonical JSON types, identifiers, timestamps, enums, compatibility rules, and training-domain public names.
- Create `docs/API_CONVENTIONS.md`: canonical API success responses, idempotency header, cursor pagination, and error response.
- Modify `docs/CURRENT_STATUS.md`: dynamic task state and fresh verification evidence.

### Task 1: Start T00-02

**Files:**
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Verify the completed dependency and current pointer**

Run:

```powershell
Get-Content -LiteralPath .\docs\CURRENT_STATUS.md -Raw
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\show_current_task.ps1
```

Expected: `T00-01` is `completed`, `last_completed_task` is `T00-01`, `next_task` is `T00-02`, and `blockers` is empty.

- [ ] **Step 2: Move the dynamic pointer to T00-02**

Replace only the affected YAML values:

```yaml
current_task: T00-02
status: in_progress
last_completed_task: T00-01
next_task: T00-03
blockers: []
```

Keep `current_milestone: M0`, `milestone_status: active`, `active_regression: null`, `suspended_task: null`, and the prior verification record unchanged.

- [ ] **Step 3: Verify the new pointer**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\show_current_task.ps1
```

Expected: `Current Task: T00-02`, `Current Status: in_progress`, direct dependency `T00-01`, and next Gate `T00-04`.

- [ ] **Step 4: Commit the state transition**

```powershell
git add -- docs/CURRENT_STATUS.md
git commit -m "chore: start T00-02"
```

### Task 2: Define canonical data representations and training names

**Files:**
- Create: `docs/DATA_CONVENTIONS.md`

- [ ] **Step 1: Run the failing data-contract assertion**

Run:

```powershell
$path = 'docs\DATA_CONVENTIONS.md'
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw 'RED: docs/DATA_CONVENTIONS.md is missing.'
}
$text = Get-Content -LiteralPath $path -Raw
$required = @(
    'UUID v4',
    'RFC 3339',
    'scenario_version_id',
    'training_session_id',
    'turn_id',
    'turn_index'
)
$missing = @($required | Where-Object { -not $text.Contains($_) })
if ($missing.Count -gt 0) {
    throw "RED: missing data conventions: $($missing -join ', ')"
}
```

Expected: FAIL with `RED: docs/DATA_CONVENTIONS.md is missing.`

- [ ] **Step 2: Create the minimal data conventions**

Create `docs/DATA_CONVENTIONS.md` with these sections and rules:

```markdown
# 数据约定

## 1. 适用范围

本文是安信伴老所有公开 API、事件载荷、配置示例和后续数据模型的通用数据表示基线。具体业务契约可以增加字段，但不得重新定义本文已有字段的格式或含义。

本文不定义具体 HTTP 路由、数据库表、ORM 模型或业务状态机。

## 2. JSON 与字段命名

- JSON 对象字段统一使用英文 `snake_case`。
- 字段缺失表示调用方未提供或该字段不适用；显式 `null` 只用于契约明确声明为可空的字段。
- 布尔值只使用 JSON `true` 和 `false`，不使用 `0`、`1` 或字符串替代。
- 数量和序号使用 JSON 整数。若后续出现金额，使用最小货币单位整数，不使用浮点数。
- 服务端拒绝请求中的未知字段；响应消费者必须容忍新增字段。

## 3. 标识符

公开资源标识符统一使用 UUID v4，以小写、带连字符的 JSON 字符串表示：

```json
{
  "resource_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

不得使用自增数据库主键作为公开标识符，也不得从 UUID 推断资源类型、创建时间或所属用户。

## 4. 时间与日期

时间戳使用 UTC RFC 3339，固定以 `Z` 结尾并保留三位毫秒；字段名使用 `*_at`：

```json
{
  "created_at": "2026-07-24T08:30:15.123Z"
}
```

不含时间的自然日使用 `YYYY-MM-DD`。API 不接受或返回无时区时间戳。

## 5. 枚举

枚举值使用稳定的英文小写 `snake_case` 字符串：

```json
{
  "status": "in_progress"
}
```

已发布枚举值不得改名、复用或改变含义。新增枚举值属于兼容性扩展；消费者遇到未知值时必须进入安全降级路径，不得擅自映射为另一个既有值。

## 6. 训练领域公开命名

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `training_session_id` | UUID v4 string | 一次训练会话的公开标识符 |
| `turn_id` | UUID v4 string | 会话内单个轮次的公开标识符 |
| `turn_index` | integer，最小值 1 | 轮次在会话内从 1 开始的稳定序号 |
| `scenario_id` | UUID v4 string | 跨版本保持稳定的场景标识符 |
| `scenario_version_id` | UUID v4 string | 不可变场景版本的公开标识符 |

训练会话开始时必须记录并锁定 `scenario_version_id`。后续轮次、降级和评分均引用该版本。

公开契约不得使用含糊的 `session_id`、`round_id`、`scene_id` 或 `version` 代替上述字段。

## 7. 兼容性

- 新增可选字段属于兼容性变更。
- 删除字段、重命名字段、收紧既有字段取值范围或改变字段含义属于不兼容变更。
- 后续 API Task 必须引用本文，不得定义同义字段。
```

- [ ] **Step 3: Run the data-contract assertion again**

Run the command from Step 1.

Expected: PASS with exit code 0.

- [ ] **Step 4: Parse every JSON example**

Run:

```powershell
$text = Get-Content -LiteralPath 'docs\DATA_CONVENTIONS.md' -Raw
$blocks = [regex]::Matches($text, '(?ms)^```json\s*\r?\n(?<json>.*?)^```\s*$')
if ($blocks.Count -lt 3) { throw "Expected at least 3 JSON examples; found $($blocks.Count)." }
foreach ($block in $blocks) {
    $null = $block.Groups['json'].Value | ConvertFrom-Json -ErrorAction Stop
}
```

Expected: exit code 0 and at least three parsed JSON blocks.

- [ ] **Step 5: Commit the data contract**

```powershell
git add -- docs/DATA_CONVENTIONS.md
git commit -m "docs: define T00-02 data conventions"
```

### Task 3: Define API, idempotency, pagination, and error contracts

**Files:**
- Create: `docs/API_CONVENTIONS.md`
- Reference: `docs/DATA_CONVENTIONS.md`

- [ ] **Step 1: Run the failing API-contract assertion**

Run:

```powershell
$path = 'docs\API_CONVENTIONS.md'
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw 'RED: docs/API_CONVENTIONS.md is missing.'
}
$text = Get-Content -LiteralPath $path -Raw
$required = @(
    'Idempotency-Key',
    'cursor',
    'limit',
    'items',
    'next_cursor',
    'has_more',
    '"code"',
    '"message"',
    '"details"',
    '"request_id"'
)
$missing = @($required | Where-Object { -not $text.Contains($_) })
if ($missing.Count -gt 0) {
    throw "RED: missing API conventions: $($missing -join ', ')"
}
```

Expected: FAIL with `RED: docs/API_CONVENTIONS.md is missing.`

- [ ] **Step 2: Create the minimal API conventions**

Create `docs/API_CONVENTIONS.md` with these sections and rules:

```markdown
# API 约定

## 1. 适用范围

本文定义安信伴老公开 HTTP API 的通用请求和响应契约。所有字段的数据表示遵循 [`DATA_CONVENTIONS.md`](./DATA_CONVENTIONS.md)。

本文不定义具体 HTTP 路由、数据库表或业务状态机。WebSocket 消息契约由后续任务单独定义。

## 2. 成功响应

单一资源直接返回资源对象，不增加通用 `data` 包装层：

```json
{
  "training_session_id": "550e8400-e29b-41d4-a716-446655440000",
  "scenario_version_id": "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c",
  "created_at": "2026-07-24T08:30:15.123Z"
}
```

集合响应使用第 4 节定义的统一游标分页对象。

## 3. 幂等写请求

需要幂等保护的写请求使用 `Idempotency-Key` 请求头。键由客户端生成，格式为 UUID v4。

幂等作用域至少包含已认证主体和端点：

- 同一作用域、同一键和同一请求语义返回首次业务结果。
- 并发收到相同请求时只执行一次业务副作用。
- 同一作用域和同一键被不同请求体复用时返回 `IDEMPOTENCY_KEY_REUSED`。
- 服务端必须保存足以比较请求语义并重放业务结果的信息；具体保存介质和期限由实现任务定义。

## 4. 游标分页

分页请求参数固定为：

- `cursor`：可选的不透明字符串，由服务端生成；客户端不得解析或构造。
- `limit`：可选整数，默认值 20，允许范围 1 至 100。

非末页响应：

```json
{
  "items": [
    {
      "training_session_id": "550e8400-e29b-41d4-a716-446655440000"
    }
  ],
  "next_cursor": "eyJvZmZzZXQiOjIwfQ",
  "has_more": true
}
```

末页响应：

```json
{
  "items": [],
  "next_cursor": null,
  "has_more": false
}
```

`items` 始终为数组。`has_more` 为 `true` 时 `next_cursor` 必须是非空字符串；为 `false` 时 `next_cursor` 必须为 `null`。

## 5. 错误响应

所有错误使用同一顶层结构：

```json
{
  "code": "VALIDATION_ERROR",
  "message": "请求参数不符合要求",
  "details": {
    "fields": [
      {
        "field": "limit",
        "reason": "must_be_between_1_and_100"
      }
    ]
  },
  "request_id": "a9cb2a7c-4c09-4f7b-8414-4ad3d2aeb004"
}
```

- `code`：稳定的英文大写 `UPPER_SNAKE_CASE` 机器码，客户端只依据此字段分支。
- `message`：安全、可展示的简体中文说明，不作为程序分支依据。
- `details`：始终为 JSON 对象；无额外信息时返回空对象。
- `request_id`：UUID 字符串，用于日志关联。

错误响应不得包含内部堆栈、SQL、密钥、令牌、完整录音、完整转写或其他敏感数据。

首批通用错误码：

| `code` | 含义 |
| --- | --- |
| `VALIDATION_ERROR` | 请求格式或字段校验失败 |
| `AUTHENTICATION_REQUIRED` | 缺少或无法验证身份 |
| `PERMISSION_DENIED` | 已认证主体无权执行操作 |
| `RESOURCE_NOT_FOUND` | 资源不存在或不可向当前主体披露 |
| `CONFLICT` | 当前资源状态与操作冲突 |
| `IDEMPOTENCY_KEY_REUSED` | 幂等键被不同请求语义复用 |
| `RATE_LIMITED` | 请求频率超过限制 |
| `INTERNAL_ERROR` | 未公开内部细节的服务端错误 |

无字段级详情的错误示例：

```json
{
  "code": "RESOURCE_NOT_FOUND",
  "message": "未找到请求的资源",
  "details": {},
  "request_id": "59d84a2f-63de-40f4-bf25-04723c74fa78"
}
```

## 6. 请求关联与演进

服务端为每个请求生成或传播内部认可的请求标识，并在错误响应中返回 `request_id`。客户端不得用 `request_id` 推断用户、资源或时间信息。

后续 API Task 必须引用本文和 `DATA_CONVENTIONS.md`，不得重新定义分页、错误结构或训练领域字段名。
```

- [ ] **Step 3: Run the API-contract assertion again**

Run the command from Step 1.

Expected: PASS with exit code 0.

- [ ] **Step 4: Parse every JSON example**

Run:

```powershell
$text = Get-Content -LiteralPath 'docs\API_CONVENTIONS.md' -Raw
$blocks = [regex]::Matches($text, '(?ms)^```json\s*\r?\n(?<json>.*?)^```\s*$')
if ($blocks.Count -lt 5) { throw "Expected at least 5 JSON examples; found $($blocks.Count)." }
foreach ($block in $blocks) {
    $null = $block.Groups['json'].Value | ConvertFrom-Json -ErrorAction Stop
}
```

Expected: exit code 0 and at least five parsed JSON blocks.

- [ ] **Step 5: Commit the API contract**

```powershell
git add -- docs/API_CONVENTIONS.md
git commit -m "docs: define T00-02 API conventions"
```

### Task 4: Run cross-document acceptance and complete T00-02

**Files:**
- Verify: `docs/API_CONVENTIONS.md`
- Verify: `docs/DATA_CONVENTIONS.md`
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Run the complete focused acceptance**

Run:

```powershell
$paths = @('docs\API_CONVENTIONS.md', 'docs\DATA_CONVENTIONS.md')
foreach ($path in $paths) {
    $text = Get-Content -LiteralPath $path -Raw
    $blocks = [regex]::Matches($text, '(?ms)^```json\s*\r?\n(?<json>.*?)^```\s*$')
    if ($blocks.Count -eq 0) { throw "$path contains no JSON examples." }
    foreach ($block in $blocks) {
        $null = $block.Groups['json'].Value | ConvertFrom-Json -ErrorAction Stop
    }
}

$api = Get-Content -LiteralPath 'docs\API_CONVENTIONS.md' -Raw
$data = Get-Content -LiteralPath 'docs\DATA_CONVENTIONS.md' -Raw
$canonical = @(
    'training_session_id',
    'turn_id',
    'turn_index',
    'scenario_id',
    'scenario_version_id'
)
foreach ($name in $canonical) {
    if (-not $data.Contains("``$name``")) { throw "Missing canonical data name: $name" }
}
foreach ($name in @('training_session_id', 'scenario_version_id')) {
    if (-not $api.Contains("``$name``") -and -not $api.Contains("`"$name`"")) {
        throw "API examples do not reuse canonical name: $name"
    }
}

$errorFields = @('"code"', '"message"', '"details"', '"request_id"')
foreach ($field in $errorFields) {
    if (-not $api.Contains($field)) { throw "Missing error field: $field" }
}

if ($api -match '(?im)^\s*(GET|POST|PUT|PATCH|DELETE)\s+/') {
    throw 'T00-02 must not define concrete HTTP routes.'
}
if (($api + $data) -match '(?i)\b(CREATE TABLE|FOREIGN KEY|PRIMARY KEY)\b') {
    throw 'T00-02 must not define database tables.'
}
```

Expected: exit code 0; every JSON block parses and every canonical contract assertion passes.

- [ ] **Step 2: Run governance regression tests**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_task_catalog.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\tests\test_show_current_task.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\tests\test_validate_task_catalog.ps1
git diff --check
```

Expected: catalog validation passes with 65 tasks and 12 migrations; both PowerShell test suites pass; `git diff --check` emits no output.

- [ ] **Step 3: Mark T00-02 completed**

Update only the dynamic state and fresh verification record:

```yaml
current_task: T00-02
status: completed
last_completed_task: T00-02
next_task: T00-03
blockers: []
last_verification:
  command: JSON example parsing + T00-02 contract assertions + scripts/validate_task_catalog.ps1 + governance regression tests
  result: passed
  verified_at: 2026-07-24
updated_at: 2026-07-24
```

- [ ] **Step 4: Verify the completed pointer**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\show_current_task.ps1
git status --short
```

Expected: `Current Task: T00-02`, `Current Status: completed`, `next_task: T00-03`, and only `docs/CURRENT_STATUS.md` remains uncommitted.

- [ ] **Step 5: Commit completion metadata**

```powershell
git add -- docs/CURRENT_STATUS.md
git commit -m "chore: complete T00-02"
```

- [ ] **Step 6: Run final verification against committed state**

Run the complete focused acceptance from Step 1, the governance commands from Step 2, and:

```powershell
git status --short
```

Expected: all commands exit 0 and the worktree is clean.
