# 安信伴老项目开发规则

本文件是仓库内开发会话的强制入口，负责稳定规则，不保存动态进度。

## 开始工作

1. 读取 `docs/CURRENT_STATUS.md`。
2. 运行 `scripts/show_current_task.ps1`。
3. 只读取当前 Task 和明确关联的专题章节。
4. 确认直接依赖和上一里程碑 Gate 后再开始。
5. 一次只执行一个 Task。
6. 不提前实现当前 Task“**不包含**”中的内容。
7. 当前状态与目录冲突时先停止并报告，不自行猜测。

## 项目硬边界

- 前端采用 Vue 3、TypeScript 和手机优先 PWA。
- 后端采用 Python 3.12、FastAPI 模块化单体。
- 最终评分只能来自确定性规则。
- 固定学习与动态测评必须复用同一状态机。
- 前端不得直接调用 AI 服务。
- Redis 不保存唯一业务事实。
- 场景版本在训练开始时锁定。
- 家庭绑定不自动授予数据访问权限。
- 第一版不包含社区端、真实电话、完整全双工、声音克隆和自动报警。

## 开发与验证

- 先写失败测试，确认按预期失败，再写满足测试的最小实现。
- 每个 Task 原则上对应一个聚焦 PR。
- 不在一个 Task 中顺带实现无关重构或后续功能。
- 完成前运行 Task 指定验收命令。
- 同时运行受影响模块的回归测试。
- 没有新鲜验证证据时不得标记完成。
- 功能、测试、需求追踪和必要文档必须同步。
- 外部服务必须支持超时、取消、模拟和降级。
- 当前仓库没有可运行源码时，以文档和治理脚本验证为基线。

## Task 状态

- `planned`：存在但尚未满足依赖。
- `ready`：依赖和上一 Gate 已满足。
- `in_progress`：正在执行。
- `blocked`：存在明确阻塞。
- `regression_fix`：正在处理阻塞性回归。
- `completed`：已验收但尚未切换下一 Task。
- 动态状态只写入 `docs/CURRENT_STATUS.md`。
- Task 目录不保存日常进行状态。

## Task 调整

- 提出调整后先做影响分析，等待用户确认再修改。
- 未开始 Task 可以拆分、合并、调整依赖和验收。
- 进行中 Task 只允许不改变主要目标的澄清。
- 已完成 Task 不改写历史，新工作创建新的 Task。
- Task 开始执行后 ID 保持稳定。
- 新 Task 使用当前里程碑下一个未使用编号。
- 实际顺序由显式依赖和当前状态决定。
- 调整后更新目录、需求追踪和 `docs/TASK_CHANGELOG.md`。
- 调整后运行 `scripts/validate_task_catalog.ps1`。
- 规划变更与功能实现分开提交。

## Bug 与回归

- 发现 Bug 先暂停当前 Task 并稳定复现。
- 先判断 Bug 属于当前 Task、已完成 Task 还是需求变化。
- 当前 Task 引入的 Bug 在当前 Task 内修复。
- 已完成 Task 的潜藏缺陷创建独立 Bugfix Task。
- 新需求改变原行为时走 Task 调整流程，不标记为 Bug。
- 权限、安全、隐私、评分或数据错误立即阻塞后续开发。
- 修复前必须添加能够复现问题的失败测试。
- 修复后运行 Bugfix、原 Task、当前 Task 和相关 Gate。
- 更新 `docs/CURRENT_STATUS.md` 和 `docs/TASK_CHANGELOG.md`。
- 不改写已完成历史，不删除失败测试，不降低验收标准。
- 不使用破坏性 Git 操作掩盖回归。

## 安全与数据

- 不提交真实密钥、令牌或真实个人数据。
- 日志不记录完整录音、完整转写和敏感凭证。
- 家属默认不能查看录音、逐字对话和敏感回答。
- AI 不决定最终分数、状态转换和安全终止。
- 脚本不得执行 Task 文本中的命令。
- 状态和 Task 路径必须解析在仓库内部。
- 工作区存在无关修改时只触碰当前 Task 明确列出的文件。

## Token 控制

- 不默认读取完整 Task 目录。
- 不默认读取完整 `DEVELOPMENT.md` 和 `TASK_CHANGELOG.md`。
- 通过 `scripts/show_current_task.ps1` 只加载当前 Task。
- 只读取当前 Task 明确关联的需求、架构或安全章节。
- 仅在调整 Task、处理 Bug 或改变流程时读取详细专题。
- 不要求用户在提示词中复制完整 Task。

## 权威文档

- 当前状态：`docs/CURRENT_STATUS.md`
- Task 范围：`docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md`
- Task 变更：`docs/TASK_CHANGELOG.md`
- 需求：`docs/REQUIREMENTS.md`
- 架构：`docs/ARCHITECTURE.md`
- 安全：`docs/SECURITY_PRIVACY.md`
- 开发流程：`docs/DEVELOPMENT.md`
- 文档优先级：`docs/DOCUMENTATION_BASELINE.md`
