# 安信伴老项目记忆与 Task 治理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在仓库中建立低 Token、可验证、可调整的项目记忆机制，使新会话能够恢复当前 Task，并正确处理 Task 变更和回归缺陷。

**Architecture:** 根目录 `AGENTS.md` 保存稳定强制规则，`docs/CURRENT_STATUS.md` 保存唯一动态指针，完整 Task 目录继续作为范围和依赖权威来源。两个只读 PowerShell 脚本分别提取当前 Task 和校验任务目录；详细调整与 Bug 流程保存在现有开发文档中。

**Tech Stack:** Markdown、YAML 代码块、Windows PowerShell 5.1、Git。

---

## 文件职责

```text
AGENTS.md
├── 稳定规则和文档入口
├── Task 执行、调整、Bugfix 摘要
└── Token 控制与完成前验证

docs/CURRENT_STATUS.md
└── 当前里程碑、Task、状态、阻塞和最近验证

docs/TASK_CHANGELOG.md
└── Task 拆分、合并、替代、Bugfix 和 Gate 重验历史

docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md
└── 65 个 Task 的范围、依赖、文件、验收和不包含内容

scripts/show_current_task.ps1
└── 只输出当前 Task、直接依赖摘要和下一个 Gate

scripts/validate_task_catalog.ps1
└── 校验 ID、依赖、文件归属、迁移、需求族和占位项
```

### Task 1：纳入任务规划基线并补充治理规则

**Files:**

- Modify: `docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md`
- Modify: `docs/superpowers/plans/2026-07-23-m1-mvp-and-development-sequence.md`
- Create: `docs/superpowers/plans/2026-07-24-project-memory-task-governance.md`

- [ ] **Step 1：在完整 Task 目录增加状态和调整规则**

在“Task 拆分标准”后增加：

```markdown
### Task 状态与调整

- Task 目录只保存计划基线，不保存日常进行状态；
- 当前状态以 `docs/CURRENT_STATUS.md` 为准；
- 未开始 Task 可以在用户确认后拆分、合并或调整依赖；
- 进行中 Task 只允许不改变主要目标的澄清；
- 已完成 Task 不改写历史范围，新工作创建新的 Task；
- Task 开始执行后 ID 保持稳定；
- 调整后必须更新需求追踪、`docs/TASK_CHANGELOG.md` 并运行任务目录校验。

### Bug 与回归

- 当前 Task 引入的回归在当前 Task 内修复；
- 已完成 Task 的潜藏缺陷创建新的 Bugfix Task；
- 权限、安全、隐私、评分或数据错误阻塞后续开发；
- 修复前先添加失败回归测试；
- 修复后重新运行原 Task、当前 Task和受影响 Gate；
- 不通过改写 Git 历史或降低验收标准掩盖回归。
```

- [ ] **Step 2：在两份主计划中加入治理入口**

加入对以下文件的相对链接：

```text
../../../AGENTS.md
../../CURRENT_STATUS.md
../../TASK_CHANGELOG.md
../../../scripts/show_current_task.ps1
../../../scripts/validate_task_catalog.ps1
```

链接文字必须说明：Task 目录负责范围，`CURRENT_STATUS.md` 负责动态进度。

- [ ] **Step 3：验证计划文件结构**

Run:

```powershell
Select-String -Path docs\superpowers\plans\2026-07-23-complete-project-task-catalog.md -Pattern 'Task 状态与调整|Bug 与回归'
```

Expected: 两个标题各命中一次。

- [ ] **Step 4：提交规划基线**

```powershell
git add -- docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md docs/superpowers/plans/2026-07-23-m1-mvp-and-development-sequence.md docs/superpowers/plans/2026-07-24-project-memory-task-governance.md
git commit -m "docs: add complete task planning baseline"
```

### Task 2：创建项目规则、当前状态和变更日志

**Files:**

- Create: `AGENTS.md`
- Create: `docs/CURRENT_STATUS.md`
- Create: `docs/TASK_CHANGELOG.md`

- [ ] **Step 1：创建根目录 AGENTS.md**

写入以下结构，最终保持在 80 至 120 行：

```markdown
# 安信伴老项目开发规则

## 开始工作

1. 读取 `docs/CURRENT_STATUS.md`；
2. 运行 `scripts/show_current_task.ps1`；
3. 只读取当前 Task 和明确关联的专题章节；
4. 确认依赖和上一 Gate 后再开始；
5. 一次只执行一个 Task，不提前实现“不包含”范围。

## 项目硬边界

- 前端采用 Vue 3、TypeScript 和手机优先 PWA；
- 后端采用 Python 3.12、FastAPI 模块化单体；
- 最终评分只能来自确定性规则；
- 固定学习与动态测评必须复用同一状态机；
- 前端不得直接调用 AI 服务；
- Redis 不保存唯一业务事实；
- 第一版不包含社区端、真实电话、完整全双工、声音克隆和自动报警。

## 开发与验证

- 先写失败测试，再写满足测试的最小实现；
- 每个 Task 原则上对应一个聚焦 PR；
- 完成前运行 Task 验收命令和受影响回归；
- 没有新鲜验证证据时不得标记完成；
- 功能、测试和必要文档必须同步。

## Task 调整

- 未开始 Task 可在用户确认后调整；
- 进行中 Task 只允许不改变主要目标的澄清；
- 已完成 Task 不改写历史，新工作创建新 Task；
- Task 开始后 ID 保持稳定；
- 调整后更新目录、需求追踪和 `docs/TASK_CHANGELOG.md`；
- 规划变更与功能实现分开提交。

## Bug 与回归

- 发现 Bug 先暂停当前 Task并稳定复现；
- 当前 Task 引入的 Bug 在当前 Task 内修复；
- 已完成 Task 的潜藏缺陷创建 Bugfix Task；
- 权限、安全、隐私、评分或数据错误立即阻塞后续开发；
- 修复前必须添加失败回归测试；
- 修复后运行 Bugfix、原 Task、当前 Task 和相关 Gate；
- 更新 `docs/CURRENT_STATUS.md` 和 `docs/TASK_CHANGELOG.md`；
- 不改写已完成历史，不降低验收标准。

## 安全与数据

- 不提交真实密钥、令牌或真实个人数据；
- 日志不记录完整录音、完整转写和敏感凭证；
- 家庭关系不自动授予数据访问权限；
- AI 不决定最终分数、状态转换和安全终止；
- 脚本不得执行 Task 文本中的命令。

## Token 控制

- 不默认读取完整 Task 目录；
- 不默认读取完整开发文档和变更日志；
- 通过 `scripts/show_current_task.ps1` 只加载当前 Task；
- 仅在调整 Task、处理 Bug 或改变流程时读取详细章节。

## 权威文档

- 当前状态：`docs/CURRENT_STATUS.md`
- Task 范围：`docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md`
- Task 变更：`docs/TASK_CHANGELOG.md`
- 需求：`docs/REQUIREMENTS.md`
- 架构：`docs/ARCHITECTURE.md`
- 安全：`docs/SECURITY_PRIVACY.md`
- 开发流程：`docs/DEVELOPMENT.md`
- 文档优先级：`docs/DOCUMENTATION_BASELINE.md`
```

- [ ] **Step 2：创建 CURRENT_STATUS.md**

````markdown
# 当前开发状态

```yaml
schema_version: 1
current_milestone: M0
milestone_status: active
current_task: T00-01
status: ready
last_completed_task: null
next_task: T00-02
task_catalog: docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
last_verification: null
updated_at: 2026-07-24
```

该文件只保存当前开发指针和简短阻塞信息，不复制 Task 正文或长日志。
````

- [ ] **Step 3：创建 TASK_CHANGELOG.md**

```markdown
# Task 变更日志

本文件只记录 Task 范围、依赖、替代、Bugfix 和 Gate 重验，不记录普通代码提交。

## 记录格式

### YYYY-MM-DD：变更标题

- 原因：
- 变更前：
- 变更后：
- 影响需求：
- 影响 Task：
- 影响 Gate：
- 需要重新验证：
- 关联 Issue/PR：

## 2026-07-24：建立 Task 治理基线

- 原因：使后续会话能够恢复当前 Task，并保留调整与回归历史。
- 变更前：任务目录存在，但没有动态状态和变更日志。
- 变更后：新增项目规则、当前状态、变更日志和只读辅助脚本。
- 影响需求：无。
- 影响 Task：不改变现有 65 个 Task。
- 影响 Gate：无。
- 需要重新验证：任务目录结构校验。
- 关联 Issue/PR：无。
```

- [ ] **Step 4：验证 AGENTS 长度和状态字段**

Run:

```powershell
$agentLines = (Get-Content AGENTS.md).Count
$status = Get-Content -Raw docs\CURRENT_STATUS.md
if ($agentLines -lt 80 -or $agentLines -gt 120) { throw "AGENTS.md must contain 80-120 lines" }
if ($status -notmatch 'current_task: T00-01') { throw "Current task is not T00-01" }
```

Expected: 退出码 0。

- [ ] **Step 5：提交项目记忆文档**

```powershell
git add -- AGENTS.md docs/CURRENT_STATUS.md docs/TASK_CHANGELOG.md
git commit -m "docs: add persistent project task memory"
```

### Task 3：实现当前 Task 低 Token 提取脚本

**Files:**

- Create: `scripts/show_current_task.ps1`
- Create: `scripts/tests/test_show_current_task.ps1`

- [ ] **Step 1：先写失败测试**

`scripts/tests/test_show_current_task.ps1` 必须：

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$scriptPath = Join-Path $repoRoot 'scripts\show_current_task.ps1'

if (Test-Path $scriptPath) {
    throw 'Expected show_current_task.ps1 to be absent during the red test'
}
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tests\test_show_current_task.ps1
```

Expected: FAIL，因为实现脚本尚不存在。

- [ ] **Step 2：实现 show_current_task.ps1**

实现必须包含这些公开参数：

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')),
    [string]$StatusPath = 'docs\CURRENT_STATUS.md'
)
```

核心行为：

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Stop-WithError {
    param([string]$Message)
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function Resolve-RepositoryPath {
    param([string]$Root, [string]$RelativePath)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-WithError "Path escapes repository: $RelativePath"
    }
    return $candidate
}

function Get-StatusValues {
    param([string]$Content)
    $blocks = [regex]::Matches($Content, '(?ms)^```yaml\s*\r?\n(?<body>.*?)^```\s*$')
    if ($blocks.Count -ne 1) {
        Stop-WithError 'CURRENT_STATUS.md must contain exactly one yaml code block'
    }
    $values = @{}
    foreach ($line in ($blocks[0].Groups['body'].Value -split '\r?\n')) {
        if ($line -match '^(?<key>[a-z_]+):\s*(?<value>.*)$') {
            $values[$Matches['key']] = $Matches['value'].Trim()
        }
    }
    return $values
}
```

Task 解析必须使用标题模式 `### Txx-yy：`，确保当前 ID 唯一；只输出：

```text
Current Task
Direct Dependencies
Next Gate
Current Task Content
```

依赖摘要只保留标题和 `验收` 行，不输出依赖 Task 全文。

完整实现：

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')),
    [string]$StatusPath = 'docs\CURRENT_STATUS.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Stop-WithError {
    param([string]$Message)
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function Resolve-RepositoryPath {
    param([string]$Root, [string]$RelativePath)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-WithError "Path escapes repository: $RelativePath"
    }
    return $candidate
}

function Get-StatusValues {
    param([string]$Content)
    $blocks = [regex]::Matches($Content, '(?ms)^```yaml\s*\r?\n(?<body>.*?)^```\s*$')
    if ($blocks.Count -ne 1) {
        Stop-WithError 'CURRENT_STATUS.md must contain exactly one yaml code block'
    }
    $values = @{}
    foreach ($line in ($blocks[0].Groups['body'].Value -split '\r?\n')) {
        if ($line -match '^(?<key>[a-z_]+):\s*(?<value>.*)$') {
            $values[$Matches['key']] = $Matches['value'].Trim()
        }
    }
    return $values
}

try {
    $repoFull = [IO.Path]::GetFullPath($RepoRoot)
    $statusFull = Resolve-RepositoryPath -Root $repoFull -RelativePath $StatusPath
    if (-not (Test-Path -LiteralPath $statusFull -PathType Leaf)) {
        Stop-WithError "Status file not found: $StatusPath"
    }

    $statusValues = Get-StatusValues -Content (Get-Content -Raw -Encoding UTF8 -LiteralPath $statusFull)
    foreach ($requiredKey in @('current_milestone', 'current_task', 'status', 'task_catalog')) {
        if (-not $statusValues.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($statusValues[$requiredKey])) {
            Stop-WithError "Missing status key: $requiredKey"
        }
    }

    $currentTask = $statusValues['current_task']
    if ($currentTask -notmatch '^T\d{2}-\d{2}$') {
        Stop-WithError "Invalid current_task: $currentTask"
    }

    $catalogFull = Resolve-RepositoryPath -Root $repoFull -RelativePath $statusValues['task_catalog']
    if (-not (Test-Path -LiteralPath $catalogFull -PathType Leaf)) {
        Stop-WithError "Task catalog not found: $($statusValues['task_catalog'])"
    }

    $catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogFull
    $taskPattern = '(?ms)^###\s+(?<id>T\d{2}-\d{2})：(?<title>[^\r\n]+)\r?\n(?<body>.*?)(?=^###\s+T\d{2}-\d{2}：|\z)'
    $tasks = @([regex]::Matches($catalog, $taskPattern))
    $currentMatches = @($tasks | Where-Object { $_.Groups['id'].Value -eq $currentTask })
    if ($currentMatches.Count -ne 1) {
        Stop-WithError "Current task must appear exactly once: $currentTask"
    }

    $currentMatch = $currentMatches[0]
    $dependencyLine = [regex]::Match($currentMatch.Groups['body'].Value, '(?m)^\*\*依赖：\*\*\s*(?<value>.*)$')
    $dependencyIds = @()
    if ($dependencyLine.Success) {
        $dependencyIds = @(
            [regex]::Matches($dependencyLine.Groups['value'].Value, 'T\d{2}-\d{2}') |
                ForEach-Object { $_.Value } |
                Select-Object -Unique
        )
    }

    $dependencySummaries = @()
    foreach ($dependencyId in $dependencyIds) {
        $dependencyTask = @($tasks | Where-Object { $_.Groups['id'].Value -eq $dependencyId })
        if ($dependencyTask.Count -ne 1) {
            Stop-WithError "Dependency must appear exactly once: $dependencyId"
        }
        $acceptance = [regex]::Match(
            $dependencyTask[0].Groups['body'].Value,
            '(?m)^\*\*验收：\*\*\s*(?<value>.*)$'
        )
        $acceptanceText = if ($acceptance.Success) { $acceptance.Groups['value'].Value.Trim() } else { 'missing acceptance' }
        $dependencySummaries += "- $dependencyId：$($dependencyTask[0].Groups['title'].Value.Trim()) | 验收：$acceptanceText"
    }

    $milestonePrefix = $currentTask.Substring(0, 3)
    $nextGate = @(
        $tasks |
            Where-Object {
                $_.Index -ge $currentMatch.Index -and
                $_.Groups['id'].Value.StartsWith($milestonePrefix, [StringComparison]::Ordinal) -and
                $_.Groups['title'].Value -match 'Gate'
            } |
            Select-Object -First 1
    )
    $gateText = if ($nextGate.Count -eq 1) {
        "$($nextGate[0].Groups['id'].Value)：$($nextGate[0].Groups['title'].Value.Trim())"
    } else {
        'none in current milestone'
    }

    Write-Output "Current Milestone: $($statusValues['current_milestone'])"
    Write-Output "Current Status: $($statusValues['status'])"
    Write-Output "Current Task: $currentTask：$($currentMatch.Groups['title'].Value.Trim())"
    Write-Output ''
    Write-Output 'Direct Dependencies:'
    if ($dependencySummaries.Count -eq 0) {
        Write-Output '- none'
    } else {
        $dependencySummaries | Write-Output
    }
    Write-Output ''
    Write-Output "Next Gate: $gateText"
    Write-Output ''
    Write-Output 'Current Task Content:'
    Write-Output "### $currentTask：$($currentMatch.Groups['title'].Value.Trim())"
    Write-Output $currentMatch.Groups['body'].Value.TrimEnd()
    exit 0
} catch {
    Stop-WithError $_.Exception.Message
}
```

- [ ] **Step 3：把测试改为成功与失败场景**

测试必须覆盖：

- 成功输出 T00-01；
- 输出不包含 T07-06 正文；
- 不存在的 Task ID 返回 1；
- 状态文件包含两个 YAML 块返回 1；
- `task_catalog` 越出仓库返回 1。

临时状态文件创建在 `scripts/tests/` 下并在 `finally` 中用 `Remove-Item -LiteralPath` 删除，不进行递归删除。

- [ ] **Step 4：运行提取脚本测试**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tests\test_show_current_task.ps1
```

Expected: 所有 5 个场景通过，退出码 0。

- [ ] **Step 5：人工检查低 Token 输出**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\show_current_task.ps1
```

Expected: 输出 T00-01、直接依赖摘要和下一个 Gate，不包含其他 64 个 Task 正文。

- [ ] **Step 6：提交提取脚本**

```powershell
git add -- scripts/show_current_task.ps1 scripts/tests/test_show_current_task.ps1
git commit -m "feat: add current task context extractor"
```

### Task 4：实现任务目录校验脚本

**Files:**

- Create: `scripts/validate_task_catalog.ps1`
- Create: `scripts/tests/test_validate_task_catalog.ps1`

- [ ] **Step 1：写缺少实现的失败测试**

测试入口：

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$validator = Join-Path $repoRoot 'scripts\validate_task_catalog.ps1'

if (Test-Path $validator) {
    throw 'Expected validate_task_catalog.ps1 to be absent during the red test'
}
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tests\test_validate_task_catalog.ps1
```

Expected: FAIL，因为校验脚本尚不存在。

- [ ] **Step 2：实现校验脚本参数与失败收集**

公开参数：

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')),
    [string]$CatalogPath = 'docs\superpowers\plans\2026-07-23-complete-project-task-catalog.md',
    [string]$MainPlanPath = 'docs\superpowers\plans\2026-07-23-m1-mvp-and-development-sequence.md',
    [int]$ExpectedTaskCount = 65
)
```

错误收集：

```powershell
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}
```

脚本解析每个 `### Txx-yy：` 章节并检查：

- 总数和唯一性；
- `依赖` 中的 ID 已存在且位于当前 Task 之前；
- `Files`、至少三个检查项、`验收`、`不包含`；
- `Create` 路径唯一；
- Alembic 编号从 1 连续到最大值；
- T00 至 T07 汇总数字与实际一致；
- 13 个需求族均出现在覆盖表；
- 主计划包含目录文件名；
- 没有未完成占位标记。

完整实现：

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')),
    [string]$CatalogPath = 'docs\superpowers\plans\2026-07-23-complete-project-task-catalog.md',
    [string]$MainPlanPath = 'docs\superpowers\plans\2026-07-23-m1-mvp-and-development-sequence.md',
    [int]$ExpectedTaskCount = 65
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}

function Resolve-RepositoryPath {
    param([string]$Root, [string]$RelativePath)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes repository: $RelativePath"
    }
    return $candidate
}

try {
    $repoFull = [IO.Path]::GetFullPath($RepoRoot)
    $catalogFull = Resolve-RepositoryPath -Root $repoFull -RelativePath $CatalogPath
    $mainPlanFull = Resolve-RepositoryPath -Root $repoFull -RelativePath $MainPlanPath

    if (-not (Test-Path -LiteralPath $catalogFull -PathType Leaf)) {
        throw "Catalog not found: $CatalogPath"
    }
    if (-not (Test-Path -LiteralPath $mainPlanFull -PathType Leaf)) {
        throw "Main plan not found: $MainPlanPath"
    }

    $catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogFull
    $mainPlan = Get-Content -Raw -Encoding UTF8 -LiteralPath $mainPlanFull
    $taskPattern = '(?ms)^###\s+(?<id>T\d{2}-\d{2})：(?<title>[^\r\n]+)\r?\n(?<body>.*?)(?=^###\s+T\d{2}-\d{2}：|\z)'
    $taskMatches = @([regex]::Matches($catalog, $taskPattern))

    if ($taskMatches.Count -ne $ExpectedTaskCount) {
        Add-ValidationError "Expected $ExpectedTaskCount tasks, found $($taskMatches.Count)"
    }

    $taskIds = @($taskMatches | ForEach-Object { $_.Groups['id'].Value })
    foreach ($duplicate in @($taskIds | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-ValidationError "Duplicate task ID: $($duplicate.Name)"
    }

    $taskOrder = @{}
    for ($index = 0; $index -lt $taskMatches.Count; $index++) {
        if (-not $taskOrder.ContainsKey($taskMatches[$index].Groups['id'].Value)) {
            $taskOrder[$taskMatches[$index].Groups['id'].Value] = $index
        }
    }

    for ($index = 0; $index -lt $taskMatches.Count; $index++) {
        $taskId = $taskMatches[$index].Groups['id'].Value
        $body = $taskMatches[$index].Groups['body'].Value
        if ($body -notmatch '(?m)^\*\*Files:\*\*\s*$') {
            Add-ValidationError "$taskId is missing Files"
        }
        if (([regex]::Matches($body, '(?m)^- \[ \]')).Count -lt 3) {
            Add-ValidationError "$taskId has fewer than three checklist steps"
        }
        if ($body -notmatch '(?m)^\*\*验收：\*\*') {
            Add-ValidationError "$taskId is missing acceptance"
        }
        if ($body -notmatch '(?m)^\*\*不包含：\*\*') {
            Add-ValidationError "$taskId is missing exclusions"
        }

        $dependencyLine = [regex]::Match($body, '(?m)^\*\*依赖：\*\*\s*(?<value>.*)$')
        if ($dependencyLine.Success) {
            foreach ($dependencyMatch in [regex]::Matches($dependencyLine.Groups['value'].Value, 'T\d{2}-\d{2}')) {
                $dependencyId = $dependencyMatch.Value
                if (-not $taskOrder.ContainsKey($dependencyId)) {
                    Add-ValidationError "$taskId has unknown dependency $dependencyId"
                } elseif ($taskOrder[$dependencyId] -ge $index) {
                    Add-ValidationError "$taskId depends on non-prior task $dependencyId"
                }
            }
        }
    }

    $createPaths = @(
        [regex]::Matches($catalog, '(?m)^- Create: `(?<path>[^`]+)`') |
            ForEach-Object { $_.Groups['path'].Value }
    )
    foreach ($duplicate in @($createPaths | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-ValidationError "Duplicate Create path: $($duplicate.Name)"
    }

    $migrationNumbers = @(
        [regex]::Matches($catalog, 'backend/alembic/versions/(?<number>\d{4})_[^`]+') |
            ForEach-Object { [int]$_.Groups['number'].Value }
    )
    foreach ($duplicate in @($migrationNumbers | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-ValidationError "Duplicate migration number: $($duplicate.Name)"
    }
    if ($migrationNumbers.Count -gt 0) {
        $sortedMigrations = @($migrationNumbers | Sort-Object)
        $expectedMigrations = @(1..$sortedMigrations[-1])
        if ((Compare-Object $expectedMigrations $sortedMigrations).Count -gt 0) {
            Add-ValidationError 'Migration numbers are not continuous'
        }
    }

    $summary = [regex]::Match(
        $catalog,
        '共 (?<total>\d+) 个 Task：M0 (?<m0>\d+) 个、M1 (?<m1>\d+) 个、M2 (?<m2>\d+) 个、M3 (?<m3>\d+) 个、M4 (?<m4>\d+) 个、M5 (?<m5>\d+) 个、M6 (?<m6>\d+) 个、M7 (?<m7>\d+) 个'
    )
    if (-not $summary.Success) {
        Add-ValidationError 'Task count summary is missing'
    } else {
        if ([int]$summary.Groups['total'].Value -ne $taskMatches.Count) {
            Add-ValidationError 'Task count summary total does not match'
        }
        for ($milestone = 0; $milestone -le 7; $milestone++) {
            $prefix = 'T{0:D2}' -f $milestone
            $actualCount = @($taskIds | Where-Object { $_.StartsWith($prefix) }).Count
            $declaredCount = [int]$summary.Groups["m$milestone"].Value
            if ($actualCount -ne $declaredCount) {
                Add-ValidationError "M$milestone count mismatch: declared $declaredCount, actual $actualCount"
            }
        }
    }

    $requiredFamilies = @(
        'FR-AUTH-001..008',
        'FR-LEARN-001..005',
        'FR-TRAIN-001..009',
        'FR-ASSESS-001..008',
        'FR-FAMILY-001..007',
        'FR-SAFETY-001..004',
        'FR-CONTENT-001..008',
        'FR-SCENE-001..004',
        'FR-FALLBACK-001..005',
        'NFR-USE-*',
        'NFR-PERF-*',
        'NFR-SEC-*',
        'NFR-MAINT-*'
    )
    foreach ($family in $requiredFamilies) {
        if (-not $catalog.Contains($family)) {
            Add-ValidationError "Missing requirement family: $family"
        }
    }

    if (-not $mainPlan.Contains('2026-07-23-complete-project-task-catalog.md')) {
        Add-ValidationError 'Main plan does not link to task catalog'
    }

    $placeholderPatterns = @(('T' + 'BD'), ('T' + 'ODO'), 'implement' + ' later', 'fill in' + ' details')
    foreach ($placeholder in $placeholderPatterns) {
        if ($catalog -match [regex]::Escape($placeholder)) {
            Add-ValidationError "Placeholder found: $placeholder"
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($validationError in $errors) {
            [Console]::Error.WriteLine("ERROR: $validationError")
        }
        exit 1
    }

    Write-Output 'Task catalog validation passed'
    Write-Output "Tasks: $($taskMatches.Count)"
    Write-Output "Migrations: $($migrationNumbers.Count)"
    exit 0
} catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}
```

失败时逐项输出：

```powershell
if ($errors.Count -gt 0) {
    foreach ($validationError in $errors) {
        [Console]::Error.WriteLine("ERROR: $validationError")
    }
    exit 1
}

Write-Output "Task catalog validation passed"
Write-Output "Tasks: $($taskMatches.Count)"
Write-Output "Migrations: $($migrationNumbers.Count)"
exit 0
```

- [ ] **Step 3：完成变异测试**

`test_validate_task_catalog.ps1` 必须复制目录到 `scripts/tests/` 下的唯一临时文件，分别制造：

- 重复 Task ID；
- 未知依赖；
- 重复迁移编号；
- 缺失 `验收`；
- 重复 `Create` 路径。

每个变异文件都必须让校验器返回 1；原始目录必须返回 0。临时文件使用 `Remove-Item -LiteralPath` 清理。

- [ ] **Step 4：运行校验脚本测试**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tests\test_validate_task_catalog.ps1
```

Expected: 原始目录通过，5 个变异场景均被拒绝，退出码 0。

- [ ] **Step 5：运行真实目录校验**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\validate_task_catalog.ps1
```

Expected:

```text
Task catalog validation passed
Tasks: 65
Migrations: 12
```

- [ ] **Step 6：提交校验脚本**

```powershell
git add -- scripts/validate_task_catalog.ps1 scripts/tests/test_validate_task_catalog.ps1
git commit -m "test: validate project task catalog"
```

### Task 5：更新开发流程、文档基线和入口

**Files:**

- Modify: `README.md`
- Modify: `docs/DEVELOPMENT.md`
- Modify: `docs/DOCUMENTATION_BASELINE.md`

- [ ] **Step 1：更新 README 开发入口**

增加：

````markdown
## 继续开发

新会话不需要复制完整 Task。按以下顺序恢复：

```text
AGENTS.md
→ docs/CURRENT_STATUS.md
→ scripts/show_current_task.ps1
→ 当前 Task 关联的专题章节
```

常用命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\show_current_task.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate_task_catalog.ps1
```
````

- [ ] **Step 2：更新 DEVELOPMENT.md**

新增“Task 调整与版本控制”和“Bug、回归和 Gate 重验”两节，完整写入设计规格第 7、8 节的状态规则、变更步骤、归属判断、修复步骤和禁止事项。

- [ ] **Step 3：更新 DOCUMENTATION_BASELINE.md**

增加：

```markdown
| `AGENTS.md` | 强制开发规则和文档入口 |
| `CURRENT_STATUS.md` | 当前里程碑、Task、阻塞和最近验证 |
| 完整 Task 目录 | Task 范围、依赖、文件和验收 |
| `TASK_CHANGELOG.md` | Task 调整、Bugfix 和 Gate 重验历史 |
```

冲突优先级增加：

1. 安全与隐私约束；
2. 已编号需求；
3. 已批准设计与架构；
4. 完整 Task 目录；
5. 当前状态只决定执行位置，不改变 Task 范围。

- [ ] **Step 4：验证本地 Markdown 链接**

使用 PowerShell 提取三个修改文件中的本地 `.md` 链接，解析为仓库路径并检查 `Test-Path`。所有本地链接必须存在。

- [ ] **Step 5：提交导航与流程**

```powershell
git add -- README.md docs/DEVELOPMENT.md docs/DOCUMENTATION_BASELINE.md
git commit -m "docs: document task recovery and regression workflow"
```

### Task 6：执行端到端治理验收

**Files:**

- Modify: `docs/CURRENT_STATUS.md`
- Test: `scripts/tests/test_show_current_task.ps1`
- Test: `scripts/tests/test_validate_task_catalog.ps1`

- [ ] **Step 1：运行全部脚本测试**

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tests\test_show_current_task.ps1
powershell -ExecutionPolicy Bypass -File scripts\tests\test_validate_task_catalog.ps1
```

Expected: 两个测试脚本均退出 0。

- [ ] **Step 2：验证正常新会话恢复**

```powershell
powershell -ExecutionPolicy Bypass -File scripts\show_current_task.ps1
```

Expected: 当前 Task 为 T00-01，状态仍为 `ready`，没有把它标记为开始。

- [ ] **Step 3：验证错误路径**

通过测试夹具验证：

- 状态文件缺失；
- YAML 块重复；
- 当前 Task 不存在；
- 目录越出仓库；
- 重复 Task ID；
- 未知依赖；
- 迁移冲突。

所有错误必须返回 1，并以 `ERROR:` 开头输出原因。

- [ ] **Step 4：验证范围未扩大**

Run:

```powershell
git diff 3edddf7 --name-only
```

Expected: 只包含设计、计划、项目记忆、脚本和明确列出的文档；不存在 `frontend/`、`backend/` 或产品功能源码。

- [ ] **Step 5：记录最后验证**

在 `docs/CURRENT_STATUS.md` 中只把 `last_verification` 更新为：

```yaml
last_verification:
  command: scripts/show_current_task.ps1 + scripts/validate_task_catalog.ps1
  result: passed
  verified_at: 2026-07-24
```

保持：

```yaml
current_task: T00-01
status: ready
```

- [ ] **Step 6：提交验收记录**

```powershell
git add -- docs/CURRENT_STATUS.md
git commit -m "docs: record task governance verification"
```

- [ ] **Step 7：最终验证**

```powershell
git status --short
git log --oneline -8
powershell -ExecutionPolicy Bypass -File scripts\show_current_task.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate_task_catalog.ps1
```

Expected:

- 工作区没有本方案遗留的未跟踪或未提交文件；
- 当前 Task 为 T00-01；
- 任务目录校验通过；
- 尚未开始产品功能开发。

## 自检

- 规格中的 12 项验收标准分别由 Task 2 至 Task 6 覆盖；
- `current_task`、`task_catalog`、`milestone_status` 和 `gate_reverification_required` 命名在计划内一致；
- 两个脚本只读项目文件，不执行 Task 中的命令；
- 测试使用仓库内唯一临时文件并以非递归方式清理；
- 计划没有引入 GitHub、外部数据库或新运行时依赖；
- T00-01 保持 `ready`，本计划不执行产品开发。
