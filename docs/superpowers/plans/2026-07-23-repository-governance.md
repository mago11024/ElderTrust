# Single-Maintainer Repository Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the confirmed documentation baseline into `main` and establish lightweight GitHub governance suitable for a single maintainer.

**Architecture:** GitHub remains the source of truth for pull requests, branch rules, milestones, and issues. The repository uses PR-only changes to `main` without mandatory third-party approval; destructive branch operations are blocked, and automated status checks are added only after a stable CI workflow exists.

**Tech Stack:** Git, GitHub CLI, GitHub REST API, GitHub Rulesets, GitHub Issues

---

## File and External-State Map

- Reference: `docs/superpowers/specs/2026-07-23-repository-governance-design.md`
- Reference: `docs/PRE_DEVELOPMENT_CHECKLIST.md`
- Create through GitHub: repository Ruleset `Protect main`
- Create through GitHub: Milestone `M1：文字训练核心`
- Create through GitHub: eight M1 Issues
- Create locally after merge: branch `chore/repository-governance`
- No application source files are changed in this plan.

### Task 1: Perform the final PR self-review

- [ ] **Step 1: Confirm the local branch is clean and synchronized**

Run:

```powershell
git status -sb
git rev-parse HEAD
git rev-parse origin/codex/project-documentation
```

Expected:

- current branch is `codex/project-documentation`;
- no modified or untracked files are listed;
- local and remote-tracking SHAs are identical.

- [ ] **Step 2: Validate the documentation**

Run:

```powershell
git diff --check main...HEAD

$ids = Select-String -Path 'docs\*.md','README.md' `
  -Pattern '\b(?:FR|NFR)-[A-Z]+-\d{3}\b' -AllMatches |
  ForEach-Object { $_.Matches.Value }

$duplicates = $ids | Group-Object | Where-Object Count -gt 1
if ($duplicates) {
  $duplicates | Format-Table Name,Count
  throw 'Duplicate requirement IDs found.'
}

$broken = @()
Get-ChildItem -Recurse -File -Filter '*.md' | ForEach-Object {
  $source = $_
  $content = Get-Content -LiteralPath $source.FullName -Raw
  [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)') | ForEach-Object {
    $target = $_.Groups[1].Value
    if ($target -notmatch '^(https?://|#|mailto:)') {
      $pathPart = ($target -split '#')[0]
      if ($pathPart -and -not (Test-Path -LiteralPath (Join-Path $source.DirectoryName $pathPart))) {
        $broken += "$($source.FullName) -> $target"
      }
    }
  }
}
if ($broken) {
  $broken
  throw 'Broken relative Markdown links found.'
}
```

Expected:

- `git diff --check` exits with code `0`;
- no duplicate requirement IDs;
- no broken relative Markdown links.

- [ ] **Step 3: Confirm the PR head and mergeability**

Run:

```powershell
gh pr view 1 --repo mago11024/ElderTrust `
  --json url,state,isDraft,mergeable,mergeStateStatus,headRefName,headRefOid,baseRefName,statusCheckRollup
```

Expected:

- state is `OPEN`;
- head is `codex/project-documentation`;
- base is `main`;
- `headRefOid` equals the local `HEAD`;
- mergeability is not `CONFLICTING`.

### Task 2: Mark PR #1 ready and merge it

- [ ] **Step 1: Convert the PR from Draft to Ready**

Run:

```powershell
gh pr ready 1 --repo mago11024/ElderTrust
```

Expected: GitHub reports that PR `#1` is ready for review.

- [ ] **Step 2: Re-read the PR state after the transition**

Run:

```powershell
gh pr view 1 --repo mago11024/ElderTrust `
  --json state,isDraft,mergeable,mergeStateStatus,headRefOid
```

Expected:

- `isDraft` is `false`;
- state remains `OPEN`;
- the head SHA has not changed.

- [ ] **Step 3: Squash merge while matching the reviewed head**

Run:

```powershell
$reviewedHead = git rev-parse HEAD
gh pr merge 1 --repo mago11024/ElderTrust `
  --squash `
  --delete-branch `
  --match-head-commit $reviewedHead `
  --subject 'docs: establish project and governance baseline'
```

Expected:

- PR `#1` becomes merged;
- GitHub creates one squash commit on `main`;
- remote branch `codex/project-documentation` is deleted.

### Task 3: Synchronize the local repository with merged `main`

- [ ] **Step 1: Switch to the existing local `main` branch**

Run:

```powershell
git switch main
```

Expected: current branch becomes `main`.

- [ ] **Step 2: Fast-forward local `main`**

Run:

```powershell
git pull --ff-only origin main
```

Expected: local `main` advances to the squash merge commit without a local merge commit.

- [ ] **Step 3: Verify local and remote `main`**

Run:

```powershell
git status -sb
git rev-parse main
git ls-remote --heads origin main
gh pr view 1 --repo mago11024/ElderTrust `
  --json state,mergedAt,mergeCommit,url
```

Expected:

- working tree is clean;
- local and remote `main` SHAs match;
- PR state is `MERGED`.

### Task 4: Create the lightweight `main` Ruleset

- [ ] **Step 1: Verify that no repository Ruleset already exists**

Run:

```powershell
gh api repos/mago11024/ElderTrust/rulesets `
  --jq 'map({id,name,enforcement,target})'
```

Expected: the result is an empty array. If a Ruleset exists, stop rather than creating an overlapping rule.

- [ ] **Step 2: Prepare the exact Ruleset request**

Create a temporary JSON file outside the repository:

```powershell
$rulesetPath = Join-Path $env:TEMP 'eldertrust-main-ruleset.json'

$ruleset = @{
  name        = 'Protect main'
  target      = 'branch'
  enforcement = 'active'
  conditions  = @{
    ref_name = @{
      include = @('refs/heads/main')
      exclude = @()
    }
  }
  rules = @(
    @{ type = 'deletion' },
    @{ type = 'non_fast_forward' },
    @{
      type = 'pull_request'
      parameters = @{
        allowed_merge_methods             = @('squash')
        dismiss_stale_reviews_on_push      = $false
        require_code_owner_review          = $false
        require_last_push_approval         = $false
        required_approving_review_count    = 0
        required_review_thread_resolution  = $true
      }
    }
  )
  bypass_actors = @()
}

$ruleset | ConvertTo-Json -Depth 10 |
  Set-Content -LiteralPath $rulesetPath -Encoding utf8
```

Expected: the temporary file contains one active branch Ruleset targeting only `refs/heads/main`.

- [ ] **Step 3: Create the Ruleset**

Run:

```powershell
gh api --method POST repos/mago11024/ElderTrust/rulesets `
  --input $rulesetPath
```

Expected: response contains a numeric Ruleset ID, name `Protect main`, target `branch`, and enforcement `active`.

- [ ] **Step 4: Verify the effective Ruleset**

Run:

```powershell
gh api repos/mago11024/ElderTrust/rulesets `
  --jq 'map({id,name,enforcement,target,conditions,rules})'
```

Expected:

- one active Ruleset named `Protect main`;
- `main` is the only included ref;
- deletion and non-fast-forward rules are enabled;
- PR approval count is `0`;
- review-thread resolution is required;
- no required status-check rule exists.

### Task 5: Create the M1 Milestone

- [ ] **Step 1: Confirm the milestone does not already exist**

Run:

```powershell
gh api 'repos/mago11024/ElderTrust/milestones?state=all' `
  --jq 'map({number,title,state})'
```

Expected: no milestone has the exact title `M1：文字训练核心`.

- [ ] **Step 2: Create the milestone**

Run:

```powershell
gh api --method POST repos/mago11024/ElderTrust/milestones `
  -f title='M1：文字训练核心' `
  -f state='open' `
  -f description='不用语音和外部 AI，完成客服退款场景的最小文字训练纵向闭环。'
```

Expected: response state is `open` and the response includes a milestone number.

- [ ] **Step 3: Store and verify the milestone number**

Run:

```powershell
$milestoneNumber = gh api 'repos/mago11024/ElderTrust/milestones?state=open' `
  --jq '.[] | select(.title=="M1：文字训练核心") | .number'

if (-not $milestoneNumber) {
  throw 'M1 milestone was not found after creation.'
}
```

Expected: `$milestoneNumber` contains exactly one integer.

### Task 6: Create the eight M1 Issues

For every issue below, use the same assignee and milestone:

```powershell
--assignee mago11024 --milestone 'M1：文字训练核心'
```

- [ ] **Step 1: Create “工程骨架与版本锁定”**

Run `gh issue create` with:

- title: `M1-01 工程骨架与版本锁定`
- body:

```markdown
## 目标

建立 Vue 3、FastAPI 和 MySQL 的可运行工程骨架，并锁定 Node.js、pnpm、Python 和依赖版本。

## 范围

- 创建前后端最小入口；
- 固定 Node.js 24 LTS、pnpm 和 Python 3.12 版本；
- 添加 `.gitignore`、`.editorconfig`、`.env.example`；
- 提供统一启动和基础检查命令。

## 不包含

- 语音、LLM、Redis、MinIO 和业务页面。

## 完成条件

- 新环境按文档可安装依赖；
- 前后端健康检查可运行；
- 版本不匹配时给出明确错误；
- 仓库不跟踪密钥、虚拟环境或构建产物。

## 关联

- NFR-MAINT-001
- NFR-MAINT-005
```

- [ ] **Step 2: Create “MySQL 与 Alembic 基线”**

Title: `M1-02 MySQL 与 Alembic 基线`

Body:

```markdown
## 目标

建立可重复运行的 MySQL 本地环境、SQLAlchemy 基础配置和 Alembic 迁移链路。

## 不包含

- Redis、对象存储和生产数据库高可用。

## 完成条件

- `docker compose up -d mysql` 可运行；
- 空数据库可升级到最新迁移；
- 迁移可在测试环境重复执行；
- 数据库密钥仅来自环境配置。

## 关联

- NFR-MAINT-004
- NFR-PERF-003
```

- [ ] **Step 3: Create “客服退款 L4 场景配置与校验”**

Title: `M1-03 客服退款 L4 场景配置与校验`

Body:

```markdown
## 目标

定义客服退款场景的最小阶段、转换条件、结束条件、风险点和 L4 固定话术，并通过 Pydantic 校验。

## 不包含

- 动态 AI、语音角色和管理端编辑器。

## 完成条件

- 配置包含所有阶段和结束路径；
- 不可达阶段、缺失结束条件和缺失降级内容会校验失败；
- 场景版本不可在训练过程中改变；
- 配置不包含真实订单或个人敏感信息。

## 关联

- FR-CONTENT-001
- FR-CONTENT-002
- FR-CONTENT-004
- FR-SCENE-001
- FR-FALLBACK-004
- NFR-MAINT-003
```

- [ ] **Step 4: Create “L4 训练状态机”**

Title: `M1-04 L4 训练状态机`

Body:

```markdown
## 目标

实现文字与按钮模式的确定性训练状态机，使用户能从开始稳定走到正常结束、主动终止或安全中止。

## 不包含

- WebSocket、ASR、TTS 和动态 LLM。

## 完成条件

- 所有允许转换具有单元测试；
- 非法、重复和结束后的输入被拒绝或幂等处理；
- 终止操作优先于正常阶段转换；
- L4 使用与后续语音模式相同的场景版本和结束语义。

## 关联

- FR-LEARN-002
- FR-LEARN-005
- FR-TRAIN-005
- FR-TRAIN-008
- FR-FALLBACK-004
- FR-FALLBACK-005
```

- [ ] **Step 5: Create “行为事件与确定性规则评分”**

Title: `M1-05 行为事件与确定性规则评分`

Body:

```markdown
## 目标

定义首版行为事件、脱敏证据格式和五维确定性评分规则。

## 不包含

- LLM 自然语言映射和生成式复盘。

## 完成条件

- 同一事件和场景版本重复计算得到相同分数；
- 评分覆盖五个能力维度；
- 低置信度或缺失证据不会直接产生严重负面结论；
- 每个分值可追溯到行为事件和规则版本。

## 关联

- FR-ASSESS-001
- FR-ASSESS-002
- FR-ASSESS-004
- FR-ASSESS-005
- FR-ASSESS-006
```

- [ ] **Step 6: Create “训练会话 API 与统一错误格式”**

Title: `M1-06 训练会话 API 与统一错误格式`

Body:

```markdown
## 目标

建立训练会话、轮次提交、会话结束和结果读取 API，并统一错误、ID、时间和枚举格式。

## 不包含

- WebSocket、家庭分享和管理员 API。

## 完成条件

- API 契约进入 OpenAPI；
- 错误包含稳定代码、用户可理解消息和追踪 ID；
- 会话、轮次和场景版本关系可持久化；
- 越权访问和无效状态在后端被拒绝。

## 关联

- FR-TRAIN-003
- FR-TRAIN-008
- NFR-PERF-003
- NFR-SEC-003
```

- [ ] **Step 7: Create “老人端文字按钮主流程”**

Title: `M1-07 老人端文字按钮主流程`

Body:

```markdown
## 目标

实现手机优先的 L4 训练主流程，包括开始、文字话术、按钮回答、主动结束和基础复盘。

## 不包含

- 麦克风、模拟来电、家庭端和管理端。

## 完成条件

- 关键页面只有一个主要下一步操作；
- 主要文字和点击区域符合项目适老化基线；
- 错误提示说明发生了什么以及如何继续；
- 用户无需开发人员指导即可完成主流程。

## 关联

- FR-LEARN-001
- FR-LEARN-003
- FR-FALLBACK-004
- NFR-USE-001
- NFR-USE-002
- NFR-USE-003
- NFR-USE-004
```

- [ ] **Step 8: Create “M1 验收测试与 CI”**

Title: `M1-08 M1 验收测试与 CI`

Body:

```markdown
## 目标

把 M1 主流程、状态机、评分和迁移验证接入自动化测试与 GitHub Actions。

## 不包含

- 语音、AI 和公网部署测试。

## 完成条件

- 后端状态机和评分单元测试通过；
- MySQL/Alembic 集成测试通过；
- 老人端 L4 主流程端到端测试通过；
- CI 执行格式化、静态检查、测试和敏感信息检查；
- CI 稳定后将检查名称加入 `main` Ruleset。

## 关联

- NFR-MAINT-005
- NFR-USE-004
- FR-FALLBACK-004
```

- [ ] **Step 9: Verify all eight Issues**

Run:

```powershell
gh issue list --repo mago11024/ElderTrust `
  --milestone 'M1：文字训练核心' `
  --state open `
  --limit 20 `
  --json number,title,assignees,milestone
```

Expected:

- exactly eight open Issues;
- titles run from `M1-01` to `M1-08`;
- every Issue is assigned to `mago11024`;
- every Issue references the M1 milestone.

### Task 7: Create the next governance branch from merged `main`

- [ ] **Step 1: Confirm the current `main` is clean**

Run:

```powershell
git switch main
git status -sb
```

Expected: clean `main` tracking `origin/main`.

- [ ] **Step 2: Create the branch**

Run:

```powershell
git switch -c chore/repository-governance
```

Expected: the new local branch starts at the verified squash merge commit.

- [ ] **Step 3: Verify provenance**

Run:

```powershell
git merge-base chore/repository-governance main
git rev-parse main
git status -sb
```

Expected:

- merge-base equals `main`;
- the branch has no commits or uncommitted changes beyond `main`.

### Task 8: Final governance verification

- [ ] **Step 1: Verify GitHub state**

Run:

```powershell
gh pr view 1 --repo mago11024/ElderTrust `
  --json state,mergedAt,mergeCommit,url

gh api repos/mago11024/ElderTrust/rulesets `
  --jq 'map({id,name,enforcement,target,conditions,rules})'

gh api 'repos/mago11024/ElderTrust/milestones?state=open' `
  --jq 'map({number,title,state,open_issues})'

gh issue list --repo mago11024/ElderTrust `
  --milestone 'M1：文字训练核心' `
  --state open `
  --limit 20 `
  --json number,title
```

Expected:

- PR `#1` is merged;
- one active `Protect main` Ruleset exists;
- one open M1 milestone exists;
- eight M1 Issues exist.

- [ ] **Step 2: Verify local state**

Run:

```powershell
git status -sb
git branch --show-current
git log -1 --oneline --decorate
```

Expected:

- current branch is `chore/repository-governance`;
- working tree is clean;
- branch starts from the merged `main` commit.
