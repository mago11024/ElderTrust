# 安信伴老项目记忆与 Task 治理设计

## 1. 文档状态

- 日期：2026-07-24
- 状态：方案已口头确认，待书面规格复核
- 适用范围：M0 至 M7 的开发会话恢复、Task 执行、Task 调整、缺陷修复和验收留痕
- 不改变内容：产品需求、系统架构、现有 65 个 Task 的功能范围和开发顺序

## 2. 背景

项目已经形成 M1/MVP 设计和包含 65 个独立 Task 的完整任务目录，但任务目录较大，后续开发不能依赖模型跨会话自然记忆，也不应要求用户每次复制当前 Task。

需要建立一套仓库内持久记忆机制，使新的开发会话能够：

1. 自动获得稳定项目规则；
2. 找到当前里程碑和当前 Task；
3. 只加载当前 Task，而不是完整任务目录；
4. 在完成、暂停、调整或修复后更新状态；
5. 保留 Task 变化和回归修复的历史；
6. 通过自动校验避免 ID、依赖、迁移和文档结构失配。

## 3. 设计目标

### 3.1 功能目标

- 用户在同一工作区的新会话中只需说“继续执行当前 Task”；
- 开发代理可以从仓库恢复当前状态，无需依赖聊天历史；
- 每次默认只读取当前 Task 和直接依赖，控制 Token 消耗；
- 未开始、进行中、已完成和已替代的 Task 使用不同调整规则；
- 发现 Bug 时能够判断归属、暂停当前任务、建立修复任务并重新验证 Gate；
- 权威文档职责清楚，同一事实只有一个主要来源。

### 3.2 质量目标

- `AGENTS.md` 保持短小、稳定、可执行；
- 动态状态采用结构清晰、容易人工编辑的 Markdown + YAML；
- 脚本只读取仓库文件，不访问网络；
- 校验失败返回非零退出码和可操作错误；
- 不把完整 Task 目录默认注入每次对话；
- 不记录密钥、真实个人数据或完整敏感训练内容。

## 4. 非目标

- 不实现 Task 管理 Web 页面；
- 不自动创建 65 个 GitHub Issues；
- 不依赖外部数据库或第三方项目管理服务；
- 不替代 Git、Pull Request 或 GitHub Issue 的执行记录；
- 不自动修改 Task 范围、依赖或完成状态；
- 不开始 T00-01 或其他产品功能开发；
- 不把完整需求、架构和安全文档复制到 `AGENTS.md`。

## 5. 文档与脚本结构

### 5.1 根目录 `AGENTS.md`

`AGENTS.md` 是项目开发的强制入口，负责稳定规则，不保存动态进度。

内容包括：

- 项目技术和产品硬边界；
- 权威文档导航；
- 开始 Task 前的读取顺序；
- 一次只执行一个 Task；
- 依赖和 Gate 检查；
- TDD、验收和文档同步规则；
- Task 调整规则；
- Bug 与回归处理规则；
- 安全、隐私、评分、AI 和数据约束；
- Token 控制规则；
- 完成前验证要求。

控制原则：

- 目标长度为 80 至 120 行；
- 只写必须遵守的规则；
- 详细示例链接到专题文档；
- 不复制 65 个 Task；
- 不要求默认读取完整 `DEVELOPMENT.md`、`TASK_CHANGELOG.md` 或任务目录。

### 5.2 `docs/CURRENT_STATUS.md`

该文件是当前开发位置的权威来源，使用一个 YAML 代码块保存机器可读状态，后面可附少量说明。

初始内容：

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

允许状态：

- `planned`：存在但尚未满足依赖；
- `ready`：依赖和上一 Gate 已满足；
- `in_progress`：正在执行；
- `blocked`：存在明确阻塞；
- `regression_fix`：正在处理阻塞性回归；
- `completed`：当前 Task 已验收，尚未切换下一 Task。

里程碑状态：

- `active`：当前里程碑正常推进；
- `completed`：当前里程碑 Gate 有效；
- `regression_detected`：已通过 Gate 后发现阻塞性回归，等待修复和重验。

更新规则：

- 开始、完成、暂停、恢复或切换 Task 时更新；
- 发生阻塞性 Bug 时记录 `active_regression` 和 `suspended_task`；
- 完成验证时记录命令、结果和日期；
- 不在此文件复制 Task 正文；
- 不保存长日志，详细记录进入 PR、Issue 或 `TASK_CHANGELOG.md`。

### 5.3 完整 Task 目录

权威文件：

`docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md`

负责：

- Task ID、名称和规模；
- 依赖关系；
- 主要文件；
- 实施检查项；
- 验收条件；
- 不包含范围；
- 里程碑 Gate。

它不负责日常状态。Task 调整获批后才修改；单纯开始或完成 Task 不修改目录。

### 5.4 `docs/TASK_CHANGELOG.md`

该文件记录计划历史，不记录普通代码提交。

需要记录：

- Task 拆分、合并或替代；
- 新增 Task 或 Bugfix Task；
- 依赖顺序变化；
- 里程碑 Gate 变化；
- 已完成 Task 后发现的潜藏缺陷；
- 调整原因、影响范围和重新验证要求。

每条记录包含：

- 日期；
- 变更标题；
- 原因；
- 变更前；
- 变更后；
- 影响的需求、Task 和 Gate；
- 是否需要重新验证；
- 关联 Issue 或 PR（存在时）。

普通 Task 开始、完成和无范围影响的文案修正不进入变更日志。

### 5.5 `docs/DEVELOPMENT.md`

新增两个详细章节：

1. Task 调整与版本控制；
2. Bug、回归和 Gate 重验。

该文件保存完整流程、模板和示例。`AGENTS.md` 只保留强制摘要，并要求在相关事件发生时按需读取对应章节。

### 5.6 `scripts/show_current_task.ps1`

该脚本用于低 Token 恢复当前工作。

处理流程：

1. 读取 `docs/CURRENT_STATUS.md` 中唯一的 YAML 代码块；
2. 获取 `current_task` 和 `task_catalog`；
3. 验证目录文件存在；
4. 定位格式为 `### Txx-yy：` 的当前 Task 标题；
5. 输出当前 Task 的完整章节；
6. 从“依赖”字段提取直接依赖 ID；
7. 输出直接依赖的标题和验收摘要；
8. 输出当前里程碑及下一个 Gate；
9. 不输出其他 Task 正文。

错误处理：

- 状态文件不存在：退出码 1；
- YAML 代码块不存在或超过一个：退出码 1；
- `current_task` 缺失：退出码 1；
- Task ID 在目录中不存在或重复：退出码 1；
- 目录路径越出仓库：退出码 1；
- 成功：退出码 0。

脚本只输出必要内容，默认不读取需求、架构、安全、开发和变更日志全文。

### 5.7 `scripts/validate_task_catalog.ps1`

该脚本验证任务治理结构。

检查项：

- Task ID 唯一；
- 依赖 ID 存在；
- 默认执行顺序中依赖先于调用者；
- 每个 Task 都有 `Files`、至少三个实施检查项、`验收` 和`不包含`；
- `Create` 路径没有被多个 Task 重复声明；
- Alembic 迁移编号唯一且连续；
- M0 至 M7 Task 数与目录汇总一致；
- 需求族覆盖表包含全部功能和非功能需求族；
- 主计划能够链接到完整 Task 目录；
- 不存在未完成占位标记。

输出：

- 成功时输出统计摘要并返回 0；
- 失败时逐项输出错误位置并返回 1；
- 不自动修改文件。

### 5.8 现有文档更新

`README.md` 增加“继续开发”入口：

```text
AGENTS.md
→ docs/CURRENT_STATUS.md
→ scripts/show_current_task.ps1
→ 当前 Task 的关联文档
```

`docs/DOCUMENTATION_BASELINE.md` 增加权威关系：

| 信息 | 权威来源 |
| --- | --- |
| 强制开发规则 | `AGENTS.md` |
| 当前开发位置 | `docs/CURRENT_STATUS.md` |
| Task 范围和依赖 | 完整 Task 目录 |
| Task 变更历史 | `docs/TASK_CHANGELOG.md` |
| 开发与缺陷流程 | `docs/DEVELOPMENT.md` |

## 6. 正常 Task 流程

### 6.1 新会话恢复

```text
读取 AGENTS.md
→ 读取 CURRENT_STATUS.md
→ 运行 show_current_task.ps1
→ 检查依赖和上一 Gate
→ 按需读取当前 Task 关联专题章节
→ 开始当前 Task
```

用户提示词可简化为：

```text
继续执行当前 Task。
```

### 6.2 Task 开始

- 状态必须为 `ready`；
- 当前 Task 必须存在且唯一；
- 直接依赖必须已经完成；
- 上一里程碑 Gate 必须有效；
- 更新状态为 `in_progress`；
- 不提前实现“不包含”范围和后续 Task。

### 6.3 Task 完成

```text
运行 Task 指定测试
→ 运行受影响模块回归
→ 检查安全、隐私、权限、评分和降级影响
→ 更新必要文档
→ 保存验证证据
→ 更新 CURRENT_STATUS
→ 切换到下一 Task
```

没有新鲜验证证据时不得标记完成。

## 7. Task 调整流程

### 7.1 状态规则

| Task 状态 | 调整规则 |
| --- | --- |
| 未开始 | 可以拆分、合并、调整依赖和验收 |
| 进行中 | 只允许不改变主要目标的澄清 |
| 已完成 | 不改写历史范围，新建补充或修复 Task |
| 已替代 | 保留原记录并指向替代 Task |

### 7.2 稳定 ID

- Task 开始执行后 ID 不再改变；
- 新增 Task 使用当前里程碑下一个未使用编号；
- 实际执行顺序由显式依赖和 `CURRENT_STATUS.md` 决定；
- 不为了保持数字连续而重编号进行中或已完成 Task。

### 7.3 变更步骤

```text
提出调整
→ 不修改文件，先做影响分析
→ 用户确认
→ 修改 Task 目录和下游依赖
→ 更新需求追踪
→ 记录 TASK_CHANGELOG
→ 运行 validate_task_catalog.ps1
→ 独立提交规划变更
→ 恢复功能开发
```

规划调整与功能实现不放在同一个提交。

## 8. Bug 与回归流程

### 8.1 归属判断

| 情况 | 处理 |
| --- | --- |
| 当前 Task 引入回归 | 在当前 Task 内修复，当前 Task 不得完成 |
| 已完成 Task 的潜藏缺陷 | 创建独立 Bugfix Task |
| 新需求改变原行为 | 走 Task 调整流程，不标记为 Bug |
| 不阻塞的轻微问题 | 建立后续 Task，不降低当前 Gate |
| 权限、安全、隐私、评分或数据问题 | 立即阻塞后续开发并优先修复 |

### 8.2 修复步骤

```text
暂停当前 Task
→ 稳定复现
→ 判断引入来源和严重程度
→ 写能够失败的回归测试
→ 当前 Task 内修复或新增 Bugfix Task
→ 修复根因
→ 运行 Bugfix 测试
→ 运行原 Task 测试
→ 运行当前 Task 测试
→ 重新运行受影响 Gate
→ 更新 CURRENT_STATUS 和 TASK_CHANGELOG
→ 恢复被暂停 Task
```

禁止：

- 改写已完成 Task 的历史范围；
- 删除失败测试或降低验收标准；
- 把无关 Bug 偷塞入当前 Task；
- 通过 `git reset --hard` 或重写共享历史掩盖回归；
- 只运行修复测试而不运行受影响 Gate。

### 8.3 Gate 失效与重验

已通过 Gate 后发现阻塞性回归时：

- 保留原完成历史；
- 把当前里程碑健康状态标记为 `regression_detected`；
- 设置 `gate_reverification_required: true`；
- 修复完成后重新运行原 Gate；
- 记录新验证时间、命令和结果；
- 验证通过后恢复里程碑完成状态。

## 9. Token 控制

每次对话默认只加载：

1. 精简 `AGENTS.md`；
2. 很短的 `CURRENT_STATUS.md`；
3. `show_current_task.ps1` 输出的当前 Task；
4. 当前 Task 明确关联的少量专题章节。

默认不加载：

- 完整 65 Task 目录；
- 完整 `TASK_CHANGELOG.md`；
- 完整 `DEVELOPMENT.md`；
- 全部需求、架构和安全文档；
- 历史 Task 的完整执行记录。

只有调整 Task、处理回归或改变流程时才读取相应专题内容。

## 10. 安全与文件边界

- 所有脚本将仓库根目录作为最大允许范围；
- 状态文件中的目录路径必须解析到仓库内部；
- 脚本不执行状态文件或任务目录中的任意代码；
- 不从 Task 文本构造并自动执行命令；
- Task 的验收命令必须由开发代理单独审查后执行；
- 状态和变更日志不保存密钥、JWT、录音、完整转写或真实个人信息；
- Git 工作区有无关改动时只修改本方案明确列出的文件。

## 11. 实施文件

新增：

```text
AGENTS.md
docs/CURRENT_STATUS.md
docs/TASK_CHANGELOG.md
scripts/show_current_task.ps1
scripts/validate_task_catalog.ps1
```

修改：

```text
README.md
docs/DEVELOPMENT.md
docs/DOCUMENTATION_BASELINE.md
docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md
```

设计规格本身：

```text
docs/superpowers/specs/2026-07-24-project-memory-task-governance-design.md
```

## 12. 验收标准

实施完成时必须满足：

1. 新会话可以通过 `AGENTS.md` 和 `CURRENT_STATUS.md` 找到当前 Task；
2. `show_current_task.ps1` 只输出当前 Task、直接依赖摘要和 Gate；
3. 当前 Task 不存在、重复或状态文件损坏时脚本明确失败；
4. `validate_task_catalog.ps1` 对现有 65 个 Task 返回成功；
5. 人为制造重复 ID、未知依赖或迁移冲突时校验脚本返回失败；
6. `AGENTS.md` 不复制完整 Task 目录；
7. 正常完成、Task 调整和回归修复流程都有文档入口；
8. `CURRENT_STATUS.md` 初始指向 T00-01，且不表示 T00-01 已经开始；
9. README 和文档基线能够正确导航到新增文件；
10. 不改变产品需求、架构和 Task 功能范围；
11. 不开始任何产品功能开发；
12. 所有新增 Markdown 文件不存在占位符和失效的本地链接。

## 13. 后续实施顺序

```text
用户复核本设计规格
→ 编写代码级实施计划
→ 创建 AGENTS.md 和状态/变更文档
→ 实现 show_current_task.ps1
→ 实现 validate_task_catalog.ps1
→ 更新现有导航和开发流程
→ 执行正常、错误、Task 调整和 Bugfix 场景验证
→ 提交治理变更
→ 用户决定是否开始 T00-01
```
