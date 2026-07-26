# 安信伴老第一版完整任务目录 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 M0 至 M7 拆成按依赖排序、每项均可独立开发、评审和验收的 Task，使项目可以从当前文档基线连续推进到答辩级完整系统。

**Architecture:** 采用 Vue 3 PWA + FastAPI 模块化单体。场景、状态机、安全规则、行为事件和确定性评分构成无供应商依赖的核心；语音、LLM、家庭协同、内容管理和部署在核心稳定后逐层接入。一个 Task 原则上对应一个聚焦 PR，不跨越里程碑，不同时修改多个无关领域。

**Tech Stack:** Vue 3、TypeScript、Vite、Pinia、Vue Router、Vitest、Playwright、Python 3.12、FastAPI、Pydantic、SQLAlchemy 2、Alembic、pytest、MySQL 8、Redis 7、MinIO/S3、WebSocket、Docker Compose、Nginx。

---

> 项目治理入口：[开发规则](../../../AGENTS.md) · [当前状态](../../CURRENT_STATUS.md) · [Task 变更日志](../../TASK_CHANGELOG.md) · [提取当前 Task](../../../scripts/show_current_task.ps1) · [校验任务目录](../../../scripts/validate_task_catalog.ps1)
>
> 本目录负责 Task 范围、依赖和验收；动态开发位置以 `docs/CURRENT_STATUS.md` 为准。

## 1. Task 拆分标准

每个 Task 必须同时满足：

- 只有一个主要交付结果；
- 开始前依赖已经合入主分支；
- 功能、测试和必要文档在同一个 Task 内完成；
- 可以用明确命令或人工脚本独立验收；
- 失败时不会阻塞已经交付的上一里程碑；
- 默认对应一个 PR；只有纯文档契约可以在同一 PR 中包含多个紧密关联文件；
- 不使用“完善相关功能”“补充异常处理”等无法验收的描述。

规模标记：

- `S`：局部契约、纯规则或单一适配层；
- `M`：一个完整模块或纵向小切片；
- `L`：跨前后端但仍能独立验收的纵向交付；不得再包含第二个业务目标。

执行规则：

1. 严格按 Task ID 的默认顺序执行；
2. “依赖”满足后才可提前并行；
3. 每个 Task 先写失败测试，再做最小实现；
4. 每个里程碑的 Gate Task 不得与后续里程碑并行；
5. 发现契约需要改变时，回到定义该契约的 Task 更新文档和测试，不在调用方复制补丁。

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
- 修复后重新运行原 Task、当前 Task 和受影响 Gate；
- 不通过改写 Git 历史或降低验收标准掩盖回归。

## 2. 对上一版任务的拆分结论

| 上一版内容 | 处理 | 原因 |
| --- | --- | --- |
| 锁定开发前契约 | 拆为 T00-01 至 T00-04 | 工具链、API、场景评分、验收追踪可分别评审 |
| 工程骨架与质量入口 | 拆为 T01-01 至 T01-03 | 前端、后端、CI 的失败面不同 |
| 场景配置与校验 | 拆为 T01-04、T01-05 | 类型契约和图算法校验可以独立测试 |
| 状态机与安全停止 | 拆为 T01-06、T01-07 | 正常业务转换与安全优先规则应隔离 |
| 评分与复盘 | 拆为 T01-08、T01-09 | 数值裁决与用户文案投影不应耦合 |
| 进程内训练 API | 保持一个纵向 Task T01-10 | 仓储替身、应用服务和最小 API 共同形成首次可用后端 |
| 老人端 L4 流程 | 拆为 T01-11、T01-12、T01-13 | 主交互、学习辅助和端到端 Gate 分开 |
| 持久化工程 | 拆为 T01-14、T01-15 | 数据迁移和仓储契约是不同风险 |
| 鉴权、授权和审计 | 拆为 T01-16、T01-17 | 访问控制必须先于审计验收 |
| M1 综合验收 | 保持 T01-18 | 它是正式 M1 的阻断 Gate |
| M2 至 M7 阶段 | 拆为 T02-01 至 T07-06 | 原阶段包含多个供应商、协议、业务和部署职责 |
| 家庭权限语义与角色矩阵 | 合并为 T04-01 | 两者共同决定数据模型，分开会造成重复迁移 |
| 演示数据、演示脚本和 L3 包 | 拆为 T07-05、T07-06 | 数据脚本属于产品演示，本地包属于部署交付 |

## 3. 总依赖与 Gate

```text
T00-01 → T00-02 → T00-03 → T00-04
    └──→ T00-05（治理回归修复，完成后恢复被暂停 Task）
    ↓
T01-01 + T01-02 → T01-03
    ↓
T01-04 → T01-05 → T01-06 → T01-07 → T01-08 → T01-09
    ↓
T01-10 → T01-11 → T01-12 → T01-13（M1.0 Gate）
    ↓
T01-14 → T01-15 → T01-16 → T01-17 → T01-18（M1.1 Gate）
    ↓
T02-01 → … → T02-09（M2 Gate）
    ↓
T03-01 → … → T03-08（M3 Gate）
    ↓
T04-01 → … → T04-09（M4 Gate）
    ↓
T05-01 → … → T05-05（M5 Gate）
    ↓
T06-01 → … → T06-06（M6 Gate）
    ↓
T07-01 → … → T07-06（M7 Gate）
```

允许的有限并行：

- T01-01 与 T01-02 可并行，T01-03 等二者完成；
- T02-04 浏览器音频与 T02-05/T02-06 云端适配器可并行，T02-07 等三者完成；
- T04 家庭闭环和 T05 体验增强在多人团队中可从 M3 Gate 后并行；单人开发仍按 M4 后 M5 的顺序；
- T07-02 观测指标与 T07-03 数据治理可在 T07-01 后并行。

其余 Task 默认串行，避免在状态机、评分、权限或消息协议未稳定时同时修改调用方。

### 3.1 需求族覆盖

| 需求族 | 主要交付 Task |
| --- | --- |
| `FR-AUTH-001..008` | T01-16、T02-03、T04-02、T04-03、T04-04、T04-09 |
| `FR-LEARN-001..005` | T01-04、T01-06、T01-11、T01-12、T02-09 |
| `FR-TRAIN-001..009` | T01-14、T01-15、T02-03、T02-07、T03-04、T03-05、T03-06、T05-03 |
| `FR-ASSESS-001..008` | T01-08、T01-09、T03-03、T03-07、T03-08、T04-08 |
| `FR-FAMILY-001..007` | T04-04、T04-05、T04-06、T04-07、T04-08、T04-09 |
| `FR-SAFETY-001..004` | T01-07、T03-07、T04-05、T04-09 |
| `FR-CONTENT-001..008` | T01-04、T01-05、T06-03、T06-04、T06-05、T06-06 |
| `FR-SCENE-001..004` | T00-03、T01-04、T06-01、T06-02 |
| `FR-FALLBACK-001..005` | T02-09、T03-06、T07-06 |
| `NFR-USE-*` | T01-11、T01-12、T01-13、T05-01、T05-05 |
| `NFR-PERF-*` | T02-01、T02-07、T07-02、T07-04 |
| `NFR-SEC-*` | T01-16、T01-17、T02-03、T02-08、T04-04、T07-03、T07-04 |
| `NFR-MAINT-*` | T01-03、T01-04、T01-08、T01-14、T02-02、T06-03 |

T00-04 负责把上表展开成逐条需求映射；任何需求新增或优先级变化，都必须先更新追踪表，再调整 Task 依赖。

## 4. M0：开发前契约

### T00-01：锁定工具链与本地环境（S）

**依赖：** 当前文档基线。

**Files:**

- Create: `.tool-versions`
- Create: `.env.example`
- Create: `docker-compose.yml`
- Modify: `docs/DEVELOPMENT.md`
- Modify: `docs/PRE_DEVELOPMENT_CHECKLIST.md`

- [ ] 锁定 Node.js、pnpm、Python、Docker 和 Compose 版本。
- [ ] 定义开发、测试和部署配置分层，不写入真实密钥。
- [ ] 在主要 Windows 开发设备验证 MySQL 容器可启动。

**验收：** `docker compose config` 返回成功；文档版本与锁定文件一致。

**不包含：** 前后端工程初始化、Redis、MinIO、AI 供应商。

### T00-02：锁定 API 与数据约定（S）

**依赖：** T00-01。

**Files:**

- Create: `docs/API_CONVENTIONS.md`
- Create: `docs/DATA_CONVENTIONS.md`

- [ ] 固定 UUID、UTC 时间、枚举、幂等键和分页格式。
- [ ] 固定错误响应 `code`、`message`、`details`、`request_id` 字段。
- [ ] 固定训练会话、轮次和场景版本的公开命名。

**验收：** 文档示例可被解析为有效 JSON；全部后续 API Task 引用同一字段名。

**不包含：** 具体 HTTP 路由和数据库表。

### T00-03：锁定客服退款 L4 场景与评分（M）

**依赖：** T00-02。

**Files:**

- Create: `docs/SCENARIO_CUSTOMER_REFUND_V1.md`
- Create: `docs/SCORING_RULES.md`

- [ ] 固定五个阶段、每个按钮、转换目标和三种结束状态。
- [ ] 固定行为事件、证据来源和五维评分权重。
- [ ] 固定“结束训练”和“我可能正在实际受骗”安全入口。

**验收：** 每个选择均能映射到明确转换和零个或多个行为事件；所有路径有限结束；五维总分计算无歧义。

**不包含：** Pydantic 模型、页面和自由文本识别。

### T00-05：修复当前任务治理测试的状态耦合（S）

**依赖：** T00-01。

**Files:**

- Modify: `scripts/tests/test_show_current_task.ps1`

- [ ] 移除测试对 `current_task: T00-01` 和对应输出的硬编码依赖。
- [ ] 保证未知 Task 用例始终实际替换当前 Task ID。
- [ ] 覆盖 T00-01、T00-02 和 T07-06 状态夹具，证明测试不依赖当前开发指针。

**验收：** `scripts/tests/test_show_current_task.ps1` 在真实当前状态及 T00-01、T00-02、T07-06 临时状态下通过；原任务目录校验与测试继续通过。

**不包含：** 修改 `show_current_task.ps1` 生产行为、产品功能或已完成 Task 的历史范围。

### T00-04：建立需求追踪与 M1 验收脚本（S）

**依赖：** T00-03。

**Files:**

- Create: `docs/REQUIREMENT_TRACEABILITY.md`
- Create: `docs/M1_ACCEPTANCE.md`
- Create: `scripts/check_traceability.py`
- Modify: `docs/PRE_DEVELOPMENT_CHECKLIST.md`

- [ ] 将每条第一版需求映射到 M1.0、M1.1、M2、M3、M4、M5、M6 或 M7。
- [ ] 写出正常完成、主动终止、安全中止和越权拒绝脚本。
- [ ] 用脚本检查每个需求 ID 只出现一个主要交付里程碑。

**验收：** `python scripts/check_traceability.py` 退出码为 0，且不存在未分配的 P0/P1 需求。

**不包含：** 功能实现。

## 5. M1：客服退款 L4 文字训练 MVP

### T01-01：初始化 FastAPI 后端骨架（S）

**依赖：** T00-04。

**Files:**

- Create: `backend/pyproject.toml`
- Create: `backend/app/__init__.py`
- Create: `backend/app/main.py`
- Create: `backend/app/common/config.py`
- Create: `backend/tests/test_health.py`

- [ ] 先写 `/health` 测试并验证失败。
- [ ] 建立 FastAPI 应用、配置加载和统一测试入口。
- [ ] 配置格式化、静态检查和 pytest。

**验收：** `cd backend; python -m pytest tests/test_health.py -q` 通过。

**不包含：** 数据库、登录和训练 API。

### T01-02：初始化 Vue 老人端骨架（S）

**依赖：** T00-04。

**Files:**

- Create: `frontend/package.json`
- Create: `frontend/pnpm-lock.yaml`
- Create: `frontend/vite.config.ts`
- Create: `frontend/src/main.ts`
- Create: `frontend/src/App.vue`
- Create: `frontend/src/router/index.ts`
- Create: `frontend/src/styles/elder.css`
- Create: `frontend/tests/unit/App.spec.ts`

- [ ] 先写应用挂载和首页可访问测试。
- [ ] 建立 Vue、TypeScript、Router、Pinia 和老人端基础样式。
- [ ] 配置类型检查、Vitest 和 Vue Test Utils。

**验收：** `cd frontend; pnpm test --run` 与 `pnpm typecheck` 通过。

**不包含：** 训练页面和管理端组件库。

### T01-03：建立统一开发脚本与 CI（M）

**依赖：** T01-01、T01-02。

**Files:**

- Create: `scripts/dev.ps1`
- Create: `scripts/test.ps1`
- Create: `.github/workflows/ci.yml`
- Create: `.editorconfig`
- Modify: `.gitignore`
- Modify: `docker-compose.yml`
- Modify: `docs/DEVELOPMENT.md`

- [ ] 统一启动 MySQL、后端和前端的开发入口。
- [ ] 统一执行后端检查、前端检查和端到端预留入口。
- [ ] 在 CI 中复用与本地相同的检查命令。

**验收：** `powershell -ExecutionPolicy Bypass -File scripts/test.ps1` 通过；CI 配置可解析。

**不包含：** Redis、MinIO 和生产部署。

### T01-04：定义场景配置类型（M）

**依赖：** T01-01、T00-03。

**Files:**

- Create: `backend/app/scenarios/schemas.py`
- Create: `backend/app/scenarios/seeds/customer_refund_v1.json`
- Create: `backend/tests/unit/scenarios/test_schema.py`

- [ ] 先写有效配置和缺字段配置测试。
- [ ] 定义场景、阶段、选择、转换、行为映射、结束条件和评分策略类型。
- [ ] 加载并校验客服退款 v1 JSON。

**验收：** `cd backend; python -m pytest tests/unit/scenarios/test_schema.py -q` 通过。

**不包含：** 图可达性校验和数据库版本。

### T01-05：实现场景图与发布前校验（M）

**依赖：** T01-04。

**Files:**

- Create: `backend/app/scenarios/validation.py`
- Create: `backend/tests/unit/scenarios/test_validation.py`
- Create: `backend/tests/fixtures/synthetic_second_scenario.json`

- [ ] 先写不可达阶段、未知目标、无结束路径和压力超限测试。
- [ ] 实现有向图可达性与有限退出检查。
- [ ] 用合成第二场景证明校验器没有客服退款硬编码。

**验收：** `cd backend; python -m pytest tests/unit/scenarios/test_validation.py -q` 通过。

**不包含：** 管理端发布生命周期。

### T01-06：实现纯领域训练状态机（M）

**依赖：** T01-05。

**Files:**

- Create: `backend/app/training/domain.py`
- Create: `backend/app/training/state_machine.py`
- Create: `backend/tests/unit/training/test_state_machine.py`

- [ ] 先写正常完成、主动结束、最大轮次和重复选择测试。
- [ ] 实现不依赖 FastAPI、数据库和 AI 的纯状态转换。
- [ ] 遍历客服退款全部配置路径并断言有限结束。

**验收：** `cd backend; python -m pytest tests/unit/training/test_state_machine.py -q` 通过。

**不包含：** 安全关键词、持久化和 HTTP。

### T01-07：实现确定性安全规则（M）

**依赖：** T01-06。

**Files:**

- Create: `backend/app/safety/redaction.py`
- Create: `backend/app/safety/stop_rules.py`
- Create: `backend/app/safety/real_fraud_rules.py`
- Create: `backend/tests/unit/safety/test_stop_rules.py`

- [ ] 先写终止词、真实受骗表达和敏感数字遮蔽测试。
- [ ] 实现安全规则并保证它们先于正常状态转换。
- [ ] 安全中止后禁止继续提交训练选择。

**验收：** `cd backend; python -m pytest tests/unit/safety -q` 通过。

**不包含：** LLM 输出安全和自动联系家属。

### T01-08：实现行为事件与确定性评分（M）

**依赖：** T01-06、T00-03。

**Files:**

- Create: `backend/app/assessment/domain.py`
- Create: `backend/app/assessment/scoring.py`
- Create: `backend/tests/unit/assessment/test_scoring.py`
- Create: `backend/tests/fixtures/customer_refund_score_golden.json`

- [ ] 先写五维计分、严重负向覆盖、事件幂等和缺证据拒绝测试。
- [ ] 实现不可变行为事件和版本化评分策略。
- [ ] 生成金标准结果并验证重复评分完全一致。

**验收：** `cd backend; python -m pytest tests/unit/assessment/test_scoring.py -q` 通过。

**不包含：** AI 行为理解和复盘文案。

### T01-09：实现个人复盘投影（S）

**依赖：** T01-08、T01-07。

**Files:**

- Create: `backend/app/assessment/review.py`
- Create: `backend/tests/unit/assessment/test_review.py`

- [ ] 先写正常完成与安全中止复盘测试。
- [ ] 生成鼓励总结、正向行为、未处理风险、脱敏证据和一条优先建议。
- [ ] 安全中止报告先展示求助指引，再展示训练结果。

**验收：** `cd backend; python -m pytest tests/unit/assessment/test_review.py -q` 通过。

**不包含：** 家庭摘要和跨训练成长比较。

### T01-10：交付进程内训练应用服务与 API（L）

**依赖：** T01-07、T01-08、T01-09。

**Files:**

- Create: `backend/app/storage/memory.py`
- Create: `backend/app/scenarios/repository.py`
- Create: `backend/app/training/repository.py`
- Create: `backend/app/training/service.py`
- Create: `backend/app/training/api.py`
- Create: `backend/tests/integration/test_training_api.py`

- [ ] 先写场景列表、创建会话、提交选择、结束和读取复盘接口测试。
- [ ] 实现仓储协议、进程内实现和预置老人身份。
- [ ] 校验会话所有者、阶段、状态、轮次号和幂等键。

**验收：** `cd backend; python -m pytest tests/integration/test_training_api.py -q` 通过；关闭 MySQL 和公网后仍可运行。

**不包含：** 生产鉴权和 SQLAlchemy。

### T01-11：实现老人端 L4 训练交互（L）

**依赖：** T01-10、T01-02。

**Files:**

- Create: `frontend/src/api/client.ts`
- Create: `frontend/src/api/training.ts`
- Create: `frontend/src/features/elder/training/training.store.ts`
- Create: `frontend/src/features/elder/training/TrainingStartView.vue`
- Create: `frontend/src/features/elder/training/TrainingTurnView.vue`
- Create: `frontend/src/features/elder/training/TrainingReviewView.vue`
- Create: `frontend/src/features/elder/training/components/LargeChoiceButton.vue`
- Create: `frontend/src/features/elder/training/components/EndTrainingButton.vue`
- Create: `frontend/tests/unit/training.store.spec.ts`

- [ ] 先写开始、提交中、成功、失败、结束和复盘状态测试。
- [ ] 实现场景开始、逐阶段选择、始终可见结束和复盘页面。
- [ ] 防止重复提交，并为错误提供明确继续动作。

**验收：** `cd frontend; pnpm test --run tests/unit/training.store.spec.ts` 与 `pnpm typecheck` 通过。

**不包含：** 端到端 Gate、登录页和语音状态。

### T01-12：实现学习模式暂停、重听、提示与解释（M）

**依赖：** T01-11。

**Files:**

- Modify: `backend/app/scenarios/schemas.py`
- Modify: `backend/app/scenarios/seeds/customer_refund_v1.json`
- Modify: `frontend/src/features/elder/training/training.store.ts`
- Create: `frontend/src/features/elder/training/components/LearningAssistPanel.vue`
- Create: `frontend/tests/unit/learning-assist.spec.ts`

- [ ] 为关键阶段配置可审核的提示、解释和固定重听内容。
- [ ] 学习模式允许暂停、重听、查看提示和解释，测评模式不暴露答案。
- [ ] 连续操作不改变轮次号、行为事件和评分结果。

**验收：** `cd frontend; pnpm test --run tests/unit/learning-assist.spec.ts` 通过。

**不包含：** 语音重听和动态 AI 测评。

### T01-13：M1.0 端到端与适老 Gate（M）

**依赖：** T01-12。

**Files:**

- Create: `frontend/tests/e2e/m1-training.spec.ts`
- Modify: `docs/M1_ACCEPTANCE.md`

- [ ] 覆盖正常完成、主动结束和安全求助三条路径。
- [ ] 覆盖学习模式暂停、提示、解释和固定内容重听。
- [ ] 使用手机视口、键盘导航和 200% 缩放检查主流程。
- [ ] 在真实手机或等效触控设备执行人工脚本。

**验收：** `cd frontend; pnpm exec playwright test tests/e2e/m1-training.spec.ts` 通过；M1.0 人工脚本签字完成。

**不包含：** MySQL、正式登录和家庭端。

### T01-14：建立 MySQL 模型与 Alembic 基线（M）

**依赖：** T01-13。

**Files:**

- Create: `backend/alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/alembic/versions/0001_m1_training_core.py`
- Create: `backend/app/storage/database.py`
- Create: `backend/app/users/models.py`
- Create: `backend/app/scenarios/models.py`
- Create: `backend/app/training/models.py`
- Create: `backend/app/assessment/models.py`
- Create: `backend/tests/integration/test_migrations.py`

- [ ] 先写空库升级和重复升级测试。
- [ ] 定义用户、场景版本、会话、轮次、事件和评估结果表。
- [ ] 增加所有者、版本和幂等约束及必要索引。

**验收：** `cd backend; python -m pytest tests/integration/test_migrations.py -q` 通过；`python -m alembic upgrade head` 可重复执行。

**不包含：** SQL 仓储和家庭表。

### T01-15：实现 MySQL 仓储与事务（M）

**依赖：** T01-14、T01-10。

**Files:**

- Create: `backend/app/users/repository.py`
- Modify: `backend/app/scenarios/repository.py`
- Modify: `backend/app/training/repository.py`
- Create: `backend/app/assessment/repository.py`
- Create: `backend/tests/integration/test_training_persistence.py`
- Create: `backend/tests/integration/test_repository_contracts.py`

- [ ] 对进程内和 MySQL 仓储运行同一契约测试。
- [ ] 在会话创建时锁定场景哈希和评分策略版本。
- [ ] 在同一事务中保存事件与对应评分结果。

**验收：** `cd backend; python -m pytest tests/integration/test_repository_contracts.py tests/integration/test_training_persistence.py -q` 通过。

**不包含：** 登录和审计。

### T01-16：实现最小登录与资源授权（M）

**依赖：** T01-15。

**Files:**

- Create: `backend/app/auth/schemas.py`
- Create: `backend/app/auth/service.py`
- Create: `backend/app/auth/api.py`
- Create: `backend/tests/integration/test_training_authorization.py`
- Create: `frontend/src/api/auth.ts`
- Create: `frontend/src/features/auth/LoginView.vue`

- [ ] 先写预置体验账号登录和两个老人互相越权测试。
- [ ] 使用短期 HttpOnly Cookie 保存身份。
- [ ] 在所有训练读写入口校验用户、资源所有权和会话状态。

**验收：** `cd backend; python -m pytest tests/integration/test_training_authorization.py -q` 通过。

**不包含：** 短信、找回密码、家庭权限和管理员功能。

### T01-17：建立审计与日志脱敏基线（S）

**依赖：** T01-16、T01-07。

**Files:**

- Create: `backend/app/audit/events.py`
- Create: `backend/app/audit/models.py`
- Create: `backend/app/audit/repository.py`
- Create: `backend/app/common/logging.py`
- Create: `backend/alembic/versions/0002_audit_logs.py`
- Create: `backend/tests/integration/test_audit_and_logging.py`

- [ ] 记录登录、训练开始、结束、安全中止和评分失败。
- [ ] 禁止记录 Cookie、JWT、密码、完整请求体和完整敏感数字。
- [ ] 用自动化测试扫描结构化日志字段。

**验收：** `cd backend; python -m pytest tests/integration/test_audit_and_logging.py -q` 通过。

**不包含：** 管理员审计查询页面。

### T01-18：M1.1 综合验收 Gate（M）

**依赖：** T01-17。

**Files:**

- Create: `frontend/tests/e2e/m1-unauthorized.spec.ts`
- Modify: `docs/M1_ACCEPTANCE.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DEVELOPMENT.md`
- Modify: `docs/DOCUMENTATION_BASELINE.md`

- [ ] 在全新环境执行安装、迁移、启动和全部测试。
- [ ] 验证重启后数据可读、会话锁定版本、越权拒绝和日志脱敏。
- [ ] 更新实际命令与需求追踪证据。

**验收：** `powershell -ExecutionPolicy Bypass -File scripts/test.ps1` 通过；M1.1 人工验收全部勾选。

**不包含：** 任何 M2 语音代码。

## 6. M2：固定分支语音与 L2/L3/L4

### T02-01：完成语音供应商与音频格式原型决策（M）

**依赖：** T01-18。

**Files:**

- Create: `docs/decisions/ADR-001-asr-tts-and-audio-format.md`
- Create: `docs/prototypes/VOICE_BASELINE.md`

- [ ] 比较至少两种 ASR/TTS 方案的中文效果、延迟、价格、保留和退出成本。
- [ ] 在目标手机验证采集格式、采样率、分片和最大时长。
- [ ] 记录实际延迟与识别成功样本，确定 M2 测试阈值。

**验收：** ADR 明确一个首选和一个降级方案；基线数据来自实际原型。

**不包含：** 正式供应商适配器。

### T02-02：定义语音适配器协议与模拟实现（M）

**依赖：** T02-01。

**Files:**

- Create: `backend/app/ai/protocols.py`
- Create: `backend/app/ai/errors.py`
- Create: `backend/app/ai/fakes.py`
- Create: `backend/tests/unit/ai/test_voice_protocols.py`

- [ ] 定义 ASR/TTS 请求、结果、超时、取消、健康和统一错误类型。
- [ ] 实现不访问公网的确定性模拟适配器。
- [ ] 测试超时、取消和供应商错误归一化。

**验收：** `cd backend; python -m pytest tests/unit/ai/test_voice_protocols.py -q` 通过。

**不包含：** WebSocket 和供应商 SDK。

### T02-03：锁定 WebSocket 消息与安全契约（M）

**依赖：** T02-01、T01-16。

**Files:**

- Create: `docs/WEBSOCKET_PROTOCOL.md`
- Create: `backend/app/training/ws_messages.py`
- Create: `backend/app/training/ws_api.py`
- Create: `backend/tests/integration/test_websocket_auth.py`

- [ ] 固定建连、轮次、音频、确认、取消、重连和错误消息。
- [ ] 建连时验证 Cookie、Origin、会话所有权和会话状态。
- [ ] 拒绝家属角色、迟到轮次和重复消息。

**验收：** `cd backend; python -m pytest tests/integration/test_websocket_auth.py -q` 通过。

**不包含：** 音频识别和播放。

### T02-04：实现浏览器录音与播放组件（M）

**依赖：** T02-01、T01-11。

**Files:**

- Create: `frontend/src/features/elder/training/audio/recorder.ts`
- Create: `frontend/src/features/elder/training/audio/player.ts`
- Create: `frontend/src/features/elder/training/audio/device.ts`
- Create: `frontend/tests/unit/audio.spec.ts`

- [ ] 先写权限拒绝、录音结束、播放完成和取消测试。
- [ ] 实现 ADR 规定格式的录音与播放。
- [ ] 权限失败时返回可显示的恢复原因，不直接判训练失败。

**验收：** `cd frontend; pnpm test --run tests/unit/audio.spec.ts` 通过；目标手机可录制并回放样本。

**不包含：** WebSocket 和主动打断。

### T02-05：接入正式 ASR 适配器（M）

**依赖：** T02-02。

**Files:**

- Create: `backend/app/ai/adapters/cloud_asr.py`
- Create: `backend/tests/integration/ai/test_cloud_asr.py`

- [ ] 用录制样本先写成功、超时、空结果和取消契约测试。
- [ ] 实现供应商请求转换、最少数据传输和错误归一化。
- [ ] 记录耗时与结果状态，不记录完整转写。

**验收：** `cd backend; python -m pytest tests/integration/ai/test_cloud_asr.py -q` 通过；无密钥时测试使用模拟实现。

**不包含：** TTS 和状态机推进。

### T02-06：接入正式 TTS 与预录语音（M）

**依赖：** T02-02。

**Files:**

- Create: `backend/app/ai/adapters/cloud_tts.py`
- Create: `backend/app/audio/prerecorded.py`
- Create: `backend/tests/integration/ai/test_cloud_tts.py`

- [ ] 写合成成功、超时、取消和预录回退测试。
- [ ] 实现供应商 TTS 和固定话术预录语音选择。
- [ ] 为每段结果携带轮次 ID，禁止过期音频被播放。

**验收：** `cd backend; python -m pytest tests/integration/ai/test_cloud_tts.py -q` 通过。

**不包含：** 多语音角色和对象存储。

### T02-07：实现语音轮次编排、取消与恢复（L）

**依赖：** T02-03、T02-04、T02-05、T02-06。

**Files:**

- Create: `backend/app/training/turn_controller.py`
- Create: `backend/app/training/recovery.py`
- Create: `backend/app/storage/redis.py`
- Create: `frontend/src/features/elder/training/training.socket.ts`
- Create: `backend/tests/integration/test_voice_turns.py`

- [ ] 串联上传、ASR、安全规则、状态机、固定回复和 TTS。
- [ ] 实现轮次确认、重复/乱序拒绝、取消和重新鉴权恢复。
- [ ] Redis 只保存可恢复短期状态，最终事件仍写 MySQL。

**验收：** `cd backend; python -m pytest tests/integration/test_voice_turns.py -q` 通过；断开连接后可恢复有效会话。

**不包含：** 动态 LLM 回复。

### T02-08：实现音频对象存储与过期删除（M）

**依赖：** T02-07。

**Files:**

- Create: `backend/app/audio/models.py`
- Create: `backend/app/audio/api.py`
- Create: `backend/app/storage/object_store.py`
- Create: `backend/app/audio/retention.py`
- Create: `backend/alembic/versions/0003_audio_assets.py`
- Create: `frontend/src/features/elder/privacy/RecordingSettingsView.vue`
- Create: `backend/tests/integration/test_audio_retention.py`
- Create: `frontend/tests/e2e/m2-recording-privacy.spec.ts`

- [ ] 保存对象创建、到期、删除状态和最小访问元数据。
- [ ] 实现到期删除、失败重试和审计事件。
- [ ] 允许老人立即删除或按单次授权延长保留，并明确展示到期时间。
- [ ] 默认不向家属或普通管理员提供录音访问。

**验收：** `cd backend; python -m pytest tests/integration/test_audio_retention.py -q` 与录音隐私 Playwright 测试通过。

**不包含：** 用户延长保留和导出。

### T02-09：实现 L2/L3/L4 降级并完成 M2 Gate（L）

**依赖：** T02-08。

**Files:**

- Create: `backend/app/training/fallback.py`
- Create: `backend/tests/integration/test_voice_fallback.py`
- Create: `frontend/tests/e2e/m2-voice-learning.spec.ts`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/REQUIREMENT_TRACEABILITY.md`

- [ ] 实现实时 TTS、预录语音和文字按钮之间的确定性降级策略。
- [ ] 验证降级不改变场景版本、结束规则和评分含义。
- [ ] 用手机和临时 HTTPS 执行完整固定语音学习。

**验收：** 后端降级测试与 `pnpm exec playwright test tests/e2e/m2-voice-learning.spec.ts` 通过；关闭 ASR/TTS 后仍可完成训练。

**不包含：** L1 动态 AI。

## 7. M3：受控 AI 动态测评

### T03-01：锁定 LLM 契约与安全测试集（M）

**依赖：** T02-09。

**Files:**

- Create: `docs/LLM_CONTRACT.md`
- Create: `backend/tests/fixtures/llm_safety_cases.json`
- Create: `backend/tests/fixtures/behavior_expression_cases.json`

- [ ] 固定允许策略、结构化输出、禁止内容和最大压力。
- [ ] 建立提示注入、越界、敏感信息、重复回复和无法结束样本。
- [ ] 建立同一安全行为的不同中文表达样本。

**验收：** 每个安全约束至少有一个应通过和一个应拒绝样本。

**不包含：** 供应商调用。

### T03-02：实现 LLM 适配器与模拟模型（M）

**依赖：** T03-01、T02-02。

**Files:**

- Create: `backend/app/ai/llm_contracts.py`
- Create: `backend/app/ai/adapters/cloud_llm.py`
- Create: `backend/app/ai/fake_llm.py`
- Create: `backend/tests/unit/ai/test_llm_contracts.py`

- [ ] 先写结构化成功、格式错误、超时和取消测试。
- [ ] 实现统一 LLM 请求、结果与模拟模型。
- [ ] 供应商异常不得原样暴露到业务层。

**验收：** `cd backend; python -m pytest tests/unit/ai/test_llm_contracts.py -q` 通过。

**不包含：** 状态机和最终评分。

### T03-03：实现自然语言行为事件提取（M）

**依赖：** T03-02、T01-08。

**Files:**

- Create: `backend/app/assessment/extractor.py`
- Create: `backend/tests/unit/assessment/test_extractor.py`

- [ ] 将自然语言映射为类型、证据片段、置信度和来源。
- [ ] 低置信度事件不得触发严重负向结论。
- [ ] 用表达样本验证同义行为映射一致。

**验收：** `cd backend; python -m pytest tests/unit/assessment/test_extractor.py -q` 通过。

**不包含：** 回复生成。

### T03-04：实现受状态机约束的回复生成（M）

**依赖：** T03-02、T01-06。

**Files:**

- Create: `backend/app/training/dialogue_service.py`
- Create: `backend/tests/unit/training/test_dialogue_service.py`

- [ ] 状态机先给出当前阶段、允许策略和压力上限。
- [ ] LLM 只能填充表达，不得返回下一阶段或最终分数。
- [ ] 超时和格式错误返回审核固定话术。

**验收：** `cd backend; python -m pytest tests/unit/training/test_dialogue_service.py -q` 通过。

**不包含：** 播放前禁止内容扫描。

### T03-05：实现 AI 输出安全校验（M）

**依赖：** T03-04、T03-01。

**Files:**

- Create: `backend/app/safety/output_guard.py`
- Create: `backend/tests/unit/safety/test_output_guard.py`

- [ ] 检查结构、阶段、策略、敏感信息和禁止内容。
- [ ] 拦截结果不得展示、播放或进入训练数据。
- [ ] 记录脱敏异常事件和降级原因。

**验收：** `cd backend; python -m pytest tests/unit/safety/test_output_guard.py -q` 通过全部安全样本。

**不包含：** 管理端异常查看。

### T03-06：接入 L1 动态训练编排与降级（L）

**依赖：** T03-03、T03-05、T02-07、T02-09。

**Files:**

- Create: `backend/app/training/dynamic_service.py`
- Create: `backend/tests/integration/test_dynamic_training.py`

- [ ] 串联 ASR、真实受骗检查、行为提取、状态机、受控回复、输出检查和 TTS。
- [ ] 老人结束或打断时取消未完成生成和合成。
- [ ] 越界、超时和格式错误从 L1 降到 L2/L3/L4。

**验收：** `cd backend; python -m pytest tests/integration/test_dynamic_training.py -q` 通过；关闭 LLM 后同一会话可安全降级。

**不包含：** 家庭分享。

### T03-07：完善证据复盘与确认式求助（M）

**依赖：** T03-06、T01-09。

**Files:**

- Create: `backend/app/safety/help_flow.py`
- Modify: `backend/app/assessment/review.py`
- Create: `frontend/src/features/elder/training/SafetyHelpView.vue`
- Create: `backend/tests/integration/test_real_fraud_help.py`

- [ ] 展示带置信度和脱敏证据的五维复盘。
- [ ] 疑似真实受骗时立即退出角色并展示停止转账、停止信息提供和独立核实。
- [ ] 第一版不自动报警、不自动联系家属。

**验收：** `cd backend; python -m pytest tests/integration/test_real_fraud_help.py -q` 通过。

**不包含：** 家属通知；该能力在 M4 授权后接入。

### T03-08：完成 M3 一致性、安全与降级 Gate（L）

**依赖：** T03-07。

**Files:**

- Create: `backend/tests/evaluation/test_behavior_consistency.py`
- Create: `backend/tests/evaluation/test_llm_safety.py`
- Create: `frontend/tests/e2e/m3-dynamic-assessment.spec.ts`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/REQUIREMENT_TRACEABILITY.md`

- [ ] 对表达样本重复运行行为识别和规则评分。
- [ ] 对安全样本运行输出拦截与降级。
- [ ] 完成手机端动态测评、复盘和关闭 AI 降级路径。

**验收：** evaluation 测试与 M3 Playwright 测试通过；最终分数始终来自规则评分器。

**不包含：** 家庭端和主动打断体验优化。

## 8. M4：家庭协同闭环

### T04-01：锁定家庭权限、角色与分享语义（M）

**依赖：** T03-08。

**Files:**

- Create: `docs/FAMILY_AUTHORIZATION_MODEL.md`
- Modify: `docs/REQUIREMENTS.md`
- Modify: `docs/SECURITY_PRIVACY.md`

- [ ] 固定四角色资源操作矩阵。
- [ ] 区分家庭绑定、持续权限和单次报告分享。
- [ ] 固定摘要、提醒、共同复盘和求助通知的默认值与撤销行为。

**验收：** 每个角色对每类资源均有 allow/deny 结论；不存在“绑定即开放全部数据”。

**不包含：** 数据库与页面。

### T04-02：实现四角色基础授权矩阵（M）

**依赖：** T04-01、T01-16。

**Files:**

- Modify: `backend/app/users/models.py`
- Modify: `backend/app/auth/schemas.py`
- Modify: `backend/app/auth/service.py`
- Create: `backend/tests/integration/test_role_matrix.py`

- [ ] 为老人、家属、内容管理员和系统管理员建立后端角色策略。
- [ ] 未知角色、角色不匹配和前端伪造角色一律拒绝。
- [ ] 为训练、家庭、内容和系统资源写 allow/deny 矩阵测试。

**验收：** `cd backend; python -m pytest tests/integration/test_role_matrix.py -q` 通过。

**不包含：** 家庭绑定和具体内容管理接口。

### T04-03：实现家庭绑定关系（M）

**依赖：** T04-02。

**Files:**

- Create: `backend/app/family/models.py`
- Create: `backend/app/family/link_service.py`
- Create: `backend/alembic/versions/0004_family_links.py`
- Create: `backend/tests/integration/family/test_links.py`

- [ ] 实现双方发起邀请、老人确认、拒绝和解除。
- [ ] 绑定状态变化记录审计。
- [ ] 未经老人确认不产生任何数据访问权限。

**验收：** `cd backend; python -m pytest tests/integration/family/test_links.py -q` 通过。

**不包含：** 分项权限和报告分享。

### T04-04：实现分项权限与即时撤销（M）

**依赖：** T04-03。

**Files:**

- Create: `backend/app/family/permission_service.py`
- Create: `backend/app/family/access_log_service.py`
- Modify: `backend/app/family/models.py`
- Create: `backend/alembic/versions/0005_family_permissions.py`
- Create: `frontend/src/features/elder/family/PermissionSettingsView.vue`
- Create: `backend/tests/integration/family/test_permissions.py`

- [ ] 实现查看摘要、推荐训练、提醒、共同复盘和求助通知权限。
- [ ] 所有家庭端接口在服务端检查当前有效权限。
- [ ] 撤销后新的访问立即拒绝。
- [ ] 老人可以查看绑定对象、权限范围和最近访问记录。

**验收：** `cd backend; python -m pytest tests/integration/family/test_permissions.py -q` 通过。

**不包含：** 报告内容投影。

### T04-05：实现单次分享与家庭摘要（L）

**依赖：** T04-04、T03-07。

**Files:**

- Create: `backend/app/family/share_service.py`
- Create: `backend/app/family/report_projection.py`
- Modify: `backend/app/family/models.py`
- Create: `backend/alembic/versions/0006_share_grants.py`
- Create: `frontend/src/features/elder/family/ShareReviewView.vue`
- Create: `frontend/src/features/family/FamilySummaryView.vue`
- Create: `backend/tests/integration/family/test_sharing.py`

- [ ] 老人先查看个人报告，再确认分享范围。
- [ ] 家庭摘要只含主题、维度摘要、一至两个薄弱点和建议。
- [ ] 不返回完整录音、逐字对话和敏感回答。

**验收：** `cd backend; python -m pytest tests/integration/family/test_sharing.py -q` 通过。

**不包含：** 行动卡。

### T04-06：实现家庭行动卡（M）

**依赖：** T04-05。

**Files:**

- Create: `backend/app/family/action_service.py`
- Modify: `backend/app/family/models.py`
- Create: `backend/alembic/versions/0007_family_actions.py`
- Create: `frontend/src/features/family/ActionCardView.vue`
- Create: `backend/tests/integration/family/test_actions.py`

- [ ] 每张行动卡只生成一个可完成任务。
- [ ] 行动完成不修改老人得分。
- [ ] 记录任务完成时间和家庭成员，不写入能力事件。

**验收：** `cd backend; python -m pytest tests/integration/family/test_actions.py -q` 通过。

**不包含：** 日历和外部消息推送。

### T04-07：实现训练推荐、计划、提醒与复训（M）

**依赖：** T04-06。

**Files:**

- Create: `backend/app/family/training_plan_service.py`
- Modify: `backend/app/family/models.py`
- Create: `backend/alembic/versions/0008_training_plans.py`
- Create: `frontend/src/features/family/FamilyTrainingPlanView.vue`
- Create: `backend/tests/integration/family/test_training_plans.py`

- [ ] 家属仅在获得相应权限后推荐场景和设置计划。
- [ ] 实现应用内提醒，不接入短信、电话或第三方日历。
- [ ] 根据薄弱行为生成针对性复训建议。

**验收：** `cd backend; python -m pytest tests/integration/family/test_training_plans.py -q` 通过。

**不包含：** 外部消息推送。

### T04-08：实现成长对比与复训变体（M）

**依赖：** T04-07、T03-08。

**Files:**

- Create: `backend/app/assessment/growth.py`
- Create: `backend/app/scenarios/variants.py`
- Create: `frontend/src/features/elder/training/GrowthComparisonView.vue`
- Create: `backend/tests/integration/test_growth_comparison.py`

- [ ] 只比较同类场景中的具体行为变化，不只比较总分。
- [ ] 重复测评更换虚构背景、商品和允许策略表达。
- [ ] 缺少可比训练时明确显示“暂无对比”，不制造趋势。

**验收：** `cd backend; python -m pytest tests/integration/test_growth_comparison.py -q` 通过。

**不包含：** 跨场景排名和家庭成员评分。

### T04-09：完成家庭权限与闭环 Gate（L）

**依赖：** T04-08。

**Files:**

- Create: `frontend/tests/e2e/m4-family-loop.spec.ts`
- Create: `frontend/tests/e2e/m4-family-permissions.spec.ts`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/REQUIREMENT_TRACEABILITY.md`

- [ ] 完成老人分享、家属查看、行动卡和复训路径。
- [ ] 验证未授权、撤销后访问和家属连接实时训练均被拒绝。
- [ ] 验证求助通知必须同时满足事先授权和当次确认。
- [ ] 验证训练计划、提醒和成长对比不修改历史评分。

**验收：** 两组 M4 Playwright 测试通过；家庭操作不改变评分数据。

**不包含：** 模拟来电和主动打断。

## 9. M5：旗舰语音体验

### T05-01：实现训练前设备检查与语音状态（M）

**依赖：** T03-08；单人顺序还依赖 T04-09。

**Files:**

- Create: `frontend/src/features/elder/training/DeviceCheckView.vue`
- Create: `frontend/src/features/elder/training/components/VoiceStatus.vue`
- Create: `frontend/tests/unit/device-check.spec.ts`

- [ ] 检查安全上下文、麦克风权限、输入设备和播放能力。
- [ ] 明确展示播放、等待、识别、生成和降级状态。
- [ ] 麦克风不可用时提供 L4 入口。

**验收：** `cd frontend; pnpm test --run tests/unit/device-check.spec.ts` 通过。

**不包含：** 来电界面和主动打断。

### T05-02：实现明确标识的模拟来电界面（M）

**依赖：** T05-01。

**Files:**

- Create: `frontend/src/features/elder/training/SimulatedCallView.vue`
- Create: `frontend/tests/unit/simulated-call.spec.ts`

- [ ] 页面始终明确标识“模拟训练”。
- [ ] 提供接听、拒绝、结束和训练说明。
- [ ] 不调用真实电话系统。

**验收：** `cd frontend; pnpm test --run tests/unit/simulated-call.spec.ts` 通过。

**不包含：** 声音克隆和系统级来电。

### T05-03：实现主动打断与过期任务取消（L）

**依赖：** T05-02、T03-06。

**Files:**

- Create: `frontend/src/features/elder/training/audio/barge_in.ts`
- Create: `backend/app/training/cancellation.py`
- Create: `backend/tests/integration/test_barge_in.py`
- Create: `frontend/tests/e2e/m5-barge-in.spec.ts`

- [ ] 老人开口后停止当前播放并进入识别。
- [ ] 取消旧轮次的 LLM 和 TTS 任务。
- [ ] 丢弃迟到音频、回复和完成事件。

**验收：** 主动打断集成与 Playwright 测试通过；旧轮次内容不会在新轮次播放。

**不包含：** 完整全双工。

### T05-04：实现多种合成语音角色（M）

**依赖：** T05-03。

**Files:**

- Create: `backend/app/audio/voice_roles.py`
- Create: `backend/alembic/versions/0009_voice_roles.py`
- Create: `backend/tests/integration/test_voice_roles.py`

- [ ] 支持年龄感、性别、语速、情绪和表达风格配置。
- [ ] 只允许合成角色和有明确授权的固定录音。
- [ ] 禁止上传家属或真实人员声音进行克隆。

**验收：** `cd backend; python -m pytest tests/integration/test_voice_roles.py -q` 通过。

**不包含：** 内容管理员试听页面；在 M6 实现。

### T05-05：完成 PWA、适老化与可用性 Gate（L）

**依赖：** T05-04。

**Files:**

- Create: `frontend/public/manifest.webmanifest`
- Create: `frontend/tests/e2e/m5-elder-usability.spec.ts`
- Modify: `frontend/src/styles/elder.css`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/REQUIREMENT_TRACEABILITY.md`

- [ ] 配置安装清单、图标和手机显示模式。
- [ ] 检查字号、对比度、点击区、焦点、200% 缩放和错误恢复。
- [ ] 让目标老人或代表性中老年测试者无开发人员指导完成流程。

**验收：** M5 Playwright 测试和人工可用性脚本通过。

**不包含：** 复杂离线应用缓存；L3 演示包由 M7 提供。

## 10. M6：第二场景与内容管理

### T06-01：锁定保健品营销场景规则（M）

**依赖：** T05-05。

**Files:**

- Create: `docs/SCENARIO_HEALTH_PRODUCT_V1.md`
- Modify: `docs/SCORING_RULES.md`

- [ ] 固定慢节奏信任建立、虚假权威、健康焦虑、限时优惠和隐瞒家属阶段。
- [ ] 固定医疗边界、权威核实、理性决策和持续诱导事件。
- [ ] 明确与客服退款不同的压力曲线和结束条件。

**验收：** 每个阶段、事件和评分规则均有确定定义，不能通过替换客服话术完成。

**不包含：** 管理端和代码实现。

### T06-02：接入第二场景并清除硬编码（L）

**依赖：** T06-01、T01-05、T03-08。

**Files:**

- Create: `backend/app/scenarios/seeds/health_product_v1.json`
- Create: `backend/tests/integration/test_two_scenarios.py`
- Modify: `backend/app/training/state_machine.py`
- Modify: `backend/app/assessment/scoring.py`

- [ ] 先写两场景共用引擎契约测试。
- [ ] 接入保健品场景并只在配置中表达差异。
- [ ] 删除发现的客服退款专用条件分支。

**验收：** `cd backend; python -m pytest tests/integration/test_two_scenarios.py -q` 通过；引擎不判断具体场景 ID。

**不包含：** 内容编辑页面。

### T06-03：实现内容生命周期与不可变版本（M）

**依赖：** T06-02。

**Files:**

- Create: `backend/app/scenarios/lifecycle.py`
- Create: `backend/alembic/versions/0010_scenario_lifecycle.py`
- Create: `backend/tests/integration/scenarios/test_lifecycle.py`

- [ ] 实现草稿、测试、待审核、已发布和已下线转换。
- [ ] 发布生成不可变版本，新训练使用最新发布版本。
- [ ] 进行中训练继续引用启动版本。

**验收：** `cd backend; python -m pytest tests/integration/scenarios/test_lifecycle.py -q` 通过。

**不包含：** 表单和拖拽编排器。

### T06-04：实现轻量内容表单与沙盒（L）

**依赖：** T06-03、T05-04。

**Files:**

- Create: `frontend/src/features/admin/scenarios/ScenarioFormView.vue`
- Create: `frontend/src/features/admin/scenarios/ScenarioSandboxView.vue`
- Create: `backend/app/scenarios/admin_api.py`
- Create: `frontend/tests/e2e/m6-scenario-admin.spec.ts`

- [ ] 表单编辑结构化阶段、策略、风险、评分和降级内容。
- [ ] 沙盒模拟典型回答路径并试听语音角色。
- [ ] 仅内容管理员可操作，系统管理员默认无内容发布权。

**验收：** M6 管理端 Playwright 测试通过。

**不包含：** 拖拽画布。

### T06-05：实现发布检查与审核记录（M）

**依赖：** T06-04、T01-05。

**Files:**

- Create: `backend/app/scenarios/publishing.py`
- Create: `backend/app/scenarios/review_models.py`
- Create: `backend/alembic/versions/0011_content_reviews.py`
- Create: `backend/tests/integration/scenarios/test_publishing.py`

- [ ] 发布前检查不可达分支、缺少结束、压力超限和降级缺失。
- [ ] 待审核内容必须由有权限的内容管理员确认。
- [ ] 保存审核人、时间、版本哈希和检查结果。

**验收：** `cd backend; python -m pytest tests/integration/scenarios/test_publishing.py -q` 通过。

**不包含：** 自动使用异常对话训练模型。

### T06-06：实现异常治理并完成双场景 Gate（L）

**依赖：** T06-05、T03-05。

**Files:**

- Create: `backend/app/audit/ai_incidents.py`
- Create: `backend/alembic/versions/0012_ai_incidents.py`
- Create: `frontend/src/features/admin/incidents/IncidentListView.vue`
- Create: `frontend/tests/e2e/m6-two-scenarios.spec.ts`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/REQUIREMENT_TRACEABILITY.md`

- [ ] 展示脱敏越界、重复回复、无法结束和评分失败事件。
- [ ] 限制管理员只能查看治理所需摘要。
- [ ] 端到端完成两个场景并验证同一引擎与版本锁定。

**验收：** M6 双场景 Playwright 测试通过；异常页面不显示完整用户对话。

**不包含：** 自动模型训练和社区统计。

## 11. M7：部署、治理与答辩加固

### T07-01：建立生产部署拓扑与配置（L）

**依赖：** T06-06。

**Files:**

- Create: `deploy/nginx.conf`
- Create: `deploy/docker-compose.prod.yml`
- Create: `backend/Dockerfile`
- Create: `frontend/Dockerfile`
- Create: `docs/DEPLOYMENT.md`

- [ ] 配置 Nginx、HTTPS/WSS、前端、FastAPI、MySQL、Redis 和 MinIO。
- [ ] 分离开发、测试和生产密钥。
- [ ] 增加容器健康检查和最小权限网络。

**验收：** `docker compose -f deploy/docker-compose.prod.yml config` 通过；本地生产拓扑可启动。

**不包含：** 公网发布和域名购买。

### T07-02：实现健康、延迟与降级观测（M）

**依赖：** T07-01。

**Files:**

- Create: `backend/app/observability/metrics.py`
- Create: `backend/app/observability/health.py`
- Create: `backend/tests/integration/test_observability.py`
- Modify: `docs/DEPLOYMENT.md`

- [ ] 记录语音结束到回复开始、供应商耗时、错误和降级原因。
- [ ] 健康检查区分应用、数据库、Redis、对象存储和外部 AI。
- [ ] 指标不包含完整语音、转写和个人敏感信息。

**验收：** `cd backend; python -m pytest tests/integration/test_observability.py -q` 通过。

**不包含：** 商业监控平台绑定。

### T07-03：完成录音、删除、备份和密钥治理（M）

**依赖：** T07-01、T02-08。

**Files:**

- Create: `docs/DATA_GOVERNANCE_RUNBOOK.md`
- Create: `scripts/verify_retention.py`
- Create: `scripts/rotate_demo_secrets.ps1`
- Create: `backend/tests/integration/test_data_governance.py`

- [ ] 演练录音到期、删除失败重试和用户立即删除。
- [ ] 定义数据库备份恢复、密钥轮换和供应商退出流程。
- [ ] 验证审计可追踪但不泄露内容。

**验收：** 数据治理测试通过；运行手册中的删除、恢复和轮换步骤可执行。

**不包含：** 法律意见替代。

### T07-04：执行安全、权限、性能与韧性测试（L）

**依赖：** T07-02、T07-03。

**Files:**

- Create: `tests/security/test_access_matrix.py`
- Create: `tests/security/test_log_secrets.py`
- Create: `tests/resilience/test_provider_outages.py`
- Create: `tests/performance/test_training_latency.py`
- Create: `docs/TEST_REPORT.md`

- [ ] 覆盖越权、JWT 过期、Origin、会话 ID 篡改和家属 WebSocket。
- [ ] 覆盖日志秘密扫描、供应商中断、网络抖动和麦克风拒绝。
- [ ] 用 M2 实测基线判断性能回归。

**验收：** 安全、韧性和性能测试全部通过；报告记录环境与实际结果。

**不包含：** 未经授权的生产渗透测试。

### T07-05：准备虚构演示数据与可重复脚本（M）

**依赖：** T07-04。

**Files:**

- Create: `scripts/seed_demo_data.py`
- Create: `docs/DEMO_SCRIPT.md`
- Create: `frontend/tests/e2e/m7-demo-path.spec.ts`

- [ ] 创建老人、家属、管理员和两个场景的虚构数据。
- [ ] 固定家属推荐、模拟来电、复盘、分享、行动卡、第二场景和降级演示步骤。
- [ ] 确保重复初始化不会产生冲突数据。

**验收：** `python scripts/seed_demo_data.py` 可重复执行；`cd frontend; pnpm exec playwright test tests/e2e/m7-demo-path.spec.ts` 通过。

**不包含：** 真实老人信息。

### T07-06：构建 L3 本地包、公网部署与发布 Gate（L）

**依赖：** T07-05。

**Files:**

- Create: `deploy/docker-compose.demo-local.yml`
- Create: `scripts/build_local_demo.ps1`
- Create: `docs/RELEASE_CHECKLIST.md`
- Modify: `README.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/REQUIREMENT_TRACEABILITY.md`

- [ ] 构建锁定场景、预录语音和规则评分的离线 L3 包。
- [ ] 部署公网 HTTPS/WSS 版本并运行完整手机演示。
- [ ] 连续演练正常、关闭 AI、网络抖动和麦克风拒绝路径。

**验收：** 公网与本地包均完成发布清单；关闭公网 AI 后本地包仍可完成演示。

**不包含：** 社区端、真实电话和第一版后功能。

## 12. 最终顺序复核

### 12.1 粒度

- 共 66 个 Task：M0 5 个、M1 18 个、M2 9 个、M3 8 个、M4 9 个、M5 5 个、M6 6 个、M7 6 个；
- 每个 Task 只有一个主要结果，最大的 Task 是一个跨前后端纵向切片；
- 原计划中“状态机 + 安全”“评分 + 复盘”“鉴权 + 审计”等耦合已拆开；
- 没有把测试、文档或安全留成没有所属 Task 的尾项。

### 12.2 先后顺序

- 契约先于模型，模型先于状态机，状态机先于页面；
- 文字内核先于语音，固定语音先于动态 AI；
- 个人复盘先于家庭分享，权限先于家庭页面；
- 第二场景先证明引擎通用性，再建设内容管理；
- 基础 CI、适老化、安全和部署能力在首次需要时进入，不集中堆到 M7；
- 不存在循环依赖。

### 12.3 合并与拆分判断

保留合并：

- T00-03 把场景与评分放在同一产品契约 Task，因为按钮、事件和权重需要一次审核；
- T01-10 把进程内仓储、应用服务和最小 API 保持为一个纵向 Task，因为拆开后没有可演示结果；
- T04-01 合并角色矩阵、家庭权限和分享语义，因为它们共同决定后续数据模型。

继续拆分：

- 供应商决策、协议、浏览器音频、ASR、TTS、轮次编排和存储分别交付；
- AI 行为提取、回复生成、输出安全和动态编排分别交付；
- 第二场景、内容生命周期、管理表单、发布检查和异常治理分别交付；
- 生产拓扑、观测、数据治理、系统测试、演示数据和最终发布分别交付。

### 12.4 关键路径

```text
T00-01
→ T00-02
→ T00-03
→ T00-04
→ T01-01/T01-02
→ T01-03
→ T01-04
→ T01-05
→ T01-06
→ T01-07
→ T01-08
→ T01-09
→ T01-10
→ T01-11
→ T01-12
→ T01-13
→ T01-14
→ T01-15
→ T01-16
→ T01-17
→ T01-18
→ M2
→ M3
→ M4
→ M5
→ M6
→ M7
```

该顺序适合单人或小团队串行推进。多人团队只在第 3 节列出的边界内并行，不并行修改状态机、评分、权限和 WebSocket 核心契约。

## 13. 每个 Task 的执行模板

每次开始一个 Task 时，从本目录复制以下检查项到 Issue 或独立实施计划：

- [ ] 确认依赖 Task 已合入并通过 Gate。
- [ ] 阅读该 Task 的关联需求、安全边界和“不包含”。
- [ ] 为目标行为写失败测试并记录预期失败。
- [ ] 实现满足测试的最小代码。
- [ ] 运行该 Task 的精确验收命令。
- [ ] 运行受影响模块的回归测试。
- [ ] 更新需求追踪和相关文档。
- [ ] 检查日志、配置和测试数据不含秘密或真实个人数据。
- [ ] 提交聚焦 PR，并在描述中列出验证结果、权限、安全、隐私和降级影响。

每个 Task 在真正编码前，应再生成一份只覆盖该 Task 的代码级实施计划；本文件负责项目级顺序、边界、依赖和验收，不用一个超长 PR 同时执行多个 Task。
