# 安信伴老 M1、MVP 与完整开发顺序实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不引入语音、外部 AI、家庭端和内容管理复杂度的前提下，先交付可验证的 L4 文字训练 MVP，再按依赖顺序建设可语音、可评估、可协同、可降级的第一版完整系统。

**Architecture:** 采用 Vue 3 PWA + FastAPI 模块化单体 + MySQL。场景配置、状态机、确定性安全规则、行为事件和规则评分构成不依赖供应商的训练内核；ASR、LLM、TTS、Redis 和对象存储在首次出现真实使用者时通过适配器接入。所有后续模式复用同一场景版本、状态机、行为事件和评分含义。

**Tech Stack:** Vue 3、TypeScript、Vite、Pinia、Vue Router、Vitest、Playwright、Python 3.12、FastAPI、Pydantic、SQLAlchemy 2、Alembic、pytest、MySQL 8、Redis 7、MinIO/S3、WebSocket、Docker Compose、Nginx。

---

> 逐项开发、依赖和验收顺序以[第一版完整任务目录](2026-07-23-complete-project-task-catalog.md)为准。本文件保留版本边界、模块关系和 M1 设计依据。
>
> 项目治理入口：[开发规则](../../../AGENTS.md) · [当前状态](../../CURRENT_STATUS.md) · [Task 变更日志](../../TASK_CHANGELOG.md) · [提取当前 Task](../../../scripts/show_current_task.ps1) · [校验任务目录](../../../scripts/validate_task_catalog.ps1)

## 1. 结论先行

### 1.1 当前方向是否合理

当前文档中的核心方向是合理的，可以继续作为第一版基线：

- 先做训练内核，再接语音、AI、家庭协同和内容管理；
- 固定分支和动态 AI 共用一个状态机；
- AI 只负责自然语言理解和受控表达，最终评分由确定性规则计算；
- 第一版采用模块化单体，不拆微服务；
- 客服退款作为完整样板，保健品营销作为扩展性验证；
- Redis、MinIO 和外部 AI 在首次需要时接入，不在工程第一天堆齐；
- 社区端、真实电话、完整全双工、声音克隆和自动报警不进入第一版。

### 1.2 是否需要单独制作简易 MVP

需要一个更小的验证切片，但不需要另建一套会被长期维护的“简易产品”。

推荐把当前 M1 明确拆成两个连续验收点：

1. **M1.0 / MVP 行走骨架**：用进程内仓储和预置老人身份，跑通一个真实前后端纵向闭环，验证场景、状态机、行为事件、评分和适老页面；
2. **M1.1 / 正式 M1**：在同一代码上接入 MySQL、Alembic、最小鉴权、不可变场景版本、审计基线和 CI，形成可继续演进的工程基座。

M1.0 不是一次性原型。它使用正式领域接口，进程内仓储继续保留为自动化测试替身；M1.1 只替换基础设施实现，不重写业务内核。

### 1.3 M1 的正式名称

建议把路线图中的“M1：文字训练核心”明确为：

> **M1：客服退款 L4 文字训练 MVP**

M1 的目的不是证明页面能打开，而是证明以下产品假设成立：

```text
结构化场景
→ 确定性状态机
→ 可观察行为事件
→ 规则评分
→ 可解释个人复盘
```

## 2. 现有文档复核发现

### 2.1 已经对齐的内容

- `README.md`、`PROJECT_OVERVIEW.md`、`REQUIREMENTS.md`、`ARCHITECTURE.md`、`ROADMAP.md` 和完整设计规格对第一版范围表述一致；
- 工程仍处于实现前阶段，未把计划能力描述成已实现能力；
- M1 已正确排除 ASR、TTS、LLM、WebSocket、Redis、MinIO、家庭闭环和内容管理；
- M2 至 M7 的大方向符合主要技术依赖。

### 2.2 必须修正或补强的地方

1. **M1 缺少中间验收点。** 当前范围同时包含工程骨架、MySQL、状态机、评分和前端，若并行铺开，容易在第一次可运行前积累过多半成品。
2. **安全基线放得偏晚。** 终止按钮、终止词、敏感信息遮蔽和疑似真实受骗中止的确定性规则应从 M1 开始；M3 再增加 AI 输入输出安全。
3. **M1 缺少最小身份边界。** 完整四角色权限不必进入 M1，但持久化训练数据不能没有用户归属。M1.0 可使用预置老人身份，M1.1 必须有最小登录和资源所有权校验。
4. **CI、可访问性和可部署性不能等到末期。** CI 和适老化基线从 M1 建立；M2 语音联调前提供临时 HTTPS；M7 只负责生产级加固。
5. **P0 与里程碑容易混淆。** `REQUIREMENTS.md` 中的 P0 表示完整第一版核心需求，不表示全部必须进入 M1。需要需求到里程碑的追踪表。
6. **第二场景验证过晚有硬编码风险。** 正式保健品场景仍在 M6，但 M1 的状态机和评分测试应加入一个极小的合成场景夹具，证明引擎没有依赖客服退款常量。
7. **家庭分享语义尚未锁定。** M4 前必须确认摘要权限是持续授权，单次报告分享是单次、限时还是可撤销授权。
8. **真实设备验证不能集中到 M7。** M1 验证手机文字流程，M2 验证麦克风与 HTTPS，M5 再优化模拟来电和主动打断。

## 3. M1 范围

### 3.1 M1.0 / MVP 行走骨架纳入

- Vue 3 和 FastAPI 最小可运行工程；
- 一个预置老人体验身份，不做注册、短信和家庭关系；
- 一个已审核的 `customer_refund` 场景版本；
- L4 文字与大按钮交互；
- 统一场景状态机；
- 用户可随时结束训练；
- 按钮选择直接映射为带证据的行为事件；
- 五维确定性评分；
- 一页基础个人复盘；
- 进程内仓储实现；
- 后端状态机和评分单元测试；
- 一条 Playwright 主流程。

### 3.2 M1.1 / 正式 M1 增加

- MySQL 8 与可重复执行的 Alembic 迁移；
- `User`、`ScenarioVersion`、`TrainingSession`、`TrainingTurn`、`BehaviorEvent`、`AssessmentResult` 的最小持久化模型；
- 场景启动时锁定不可变版本；
- 最小登录、短期 Cookie 会话和训练资源所有权校验；
- 统一 API 错误格式、ID、时间和枚举约定；
- 训练开始、结束、中止和评分失败的审计事件；
- 敏感数字串遮蔽和疑似真实受骗确定性中止；
- 后端、前端和端到端 CI；
- 人工主流程验收脚本和手机适老化检查。

### 3.3 M1 明确不纳入

- ASR、TTS、LLM 和任何云端 AI 调用；
- WebSocket、Redis、MinIO 和录音保存；
- 自由文本的 AI 行为识别；
- 家庭绑定、授权、分享和行动卡；
- 管理端场景编辑、审核和发布；
- 模拟来电、主动打断和多语音角色；
- 保健品营销正式内容；
- 社区端、真实电话、声音克隆、自动报警；
- 完整注册、短信验证码、找回密码和生产级账号治理。

### 3.4 M1 最小场景

客服退款 L4 场景固定为以下阶段，避免开发时临时发明流程：

| 阶段 ID | 训练内容 | 至少提供的安全选择 | 至少提供的风险选择 |
| --- | --- | --- | --- |
| `identity_claim` | 对方自称平台客服并声称订单异常 | 询问工号并准备独立核实 | 直接相信身份 |
| `refund_offer` | 对方提出退款或赔付 | 挂断后从平台官方入口处理 | 跟随陌生流程 |
| `sensitive_request` | 索取验证码、银行卡信息或要求共享屏幕 | 明确拒绝提供或共享 | 提供验证码、点击链接或共享屏幕 |
| `pressure` | 以退款失效、扣款等理由催促 | 暂停操作并联系家属或官方客服 | 在压力下继续操作 |
| `resolution` | 结束本次训练 | 主动挂断、核实或求助 | 由最大轮数规则强制结束 |

每个阶段同时提供固定的“结束训练”和“我可能正在实际受骗，需要帮助”入口；后者直接进入 `safety_stopped`，不再显示诈骗话术。

所有路径必须在有限步内进入 `completed`、`user_terminated` 或 `safety_stopped`，不存在无法结束的循环。

### 3.5 M1 首版行为事件

| 事件类型 | 能力维度 | 正负向 | 证据来源 |
| --- | --- | --- | --- |
| `questioned_identity` | 身份核实 | 正向 | 按钮标签与阶段 ID |
| `used_independent_channel` | 身份核实 | 正向 | 按钮标签与阶段 ID |
| `refused_sensitive_information` | 信息保护 | 正向 | 按钮标签与阶段 ID |
| `disclosed_sensitive_information` | 信息保护 | 严重负向 | 脱敏按钮语义，不保存真实信息 |
| `refused_unknown_link_or_screen_share` | 支付警觉 | 正向 | 按钮标签与阶段 ID |
| `accepted_unknown_link_or_screen_share` | 支付警觉 | 严重负向 | 按钮标签与阶段 ID |
| `paused_under_pressure` | 压力应对 | 正向 | 按钮标签与阶段 ID |
| `continued_under_pressure` | 压力应对 | 负向 | 按钮标签与阶段 ID |
| `terminated_conversation` | 求助终止 | 正向 | 结束按钮或安全选择 |
| `sought_help` | 求助终止 | 正向 | 按钮标签与阶段 ID |
| `reported_possible_real_fraud` | 求助终止 | 安全中止 | 固定求助入口 |

M1 中所有按钮产生的事件置信度为 `1.0`；低置信度事件只在 M3 自由语言理解出现后启用。

### 3.6 M1 评分约定

- 每个维度分数范围固定为 `0..100`；
- 初始分和权重集中在版本化评分策略中，不散落在前端或路由处理函数；
- 严重负向事件可以覆盖同维度的一般正向事件，但不能产生小于 0 的分数；
- 同一事件集合、场景版本和评分策略版本必须产生完全相同的结果；
- 缺少证据的事件不进入评分；
- 总结文案不改变数值结果；
- 前端不计算最终分数。

M1 首版采用以下可解释权重：

| 能力维度 | 计分规则 |
| --- | --- |
| 身份核实 | `questioned_identity` 计 40 分，`used_independent_channel` 计 60 分 |
| 信息保护 | `refused_sensitive_information` 计 100 分；出现 `disclosed_sensitive_information` 时本维度强制为 0 |
| 支付警觉 | `refused_unknown_link_or_screen_share` 计 100 分；出现 `accepted_unknown_link_or_screen_share` 时本维度强制为 0 |
| 压力应对 | `paused_under_pressure` 计 100 分；出现 `continued_under_pressure` 时本维度强制为 0 |
| 求助终止 | `terminated_conversation` 计 60 分，`sought_help` 或 `reported_possible_real_fraud` 计 40 分 |

同一规则最多计分一次，各维度封顶 100，总分为五个维度的算术平均值并取整。安全中止仍生成报告，但报告必须先显示真实求助指引，再显示训练评分。后续调整权重必须生成新的评分策略版本，不得修改已完成会话的历史结果。

### 3.7 M1 完成定义

M1.0 完成必须同时满足：

- 单条命令可启动前后端测试环境；
- 从场景开始到复盘的 Playwright 主流程通过；
- 所有状态转换、结束条件和评分规则有单元测试；
- 同一输入重复运行得到相同评分；
- 正常结束、主动结束和安全中止均有自动化路径；
- 主流程可在手机尺寸浏览器完成；
- 没有语音或 AI 服务也不影响任何 M1 功能。

M1.1 完成必须同时满足：

- 全新数据库执行 `alembic upgrade head` 成功，重复执行不报错；
- 应用重启后训练、事件和评分结果仍可读取；
- 其他用户不能读取或继续当前老人的训练；
- 场景新版本发布后，进行中的会话仍引用启动版本；
- 日志不含密码、令牌、完整敏感数字串和完整训练请求体；
- CI 在后端、前端和端到端检查全部通过；
- 至少一次真实手机人工验收完成，关键页面只有一个主要下一步；
- `docs/ROADMAP.md`、`docs/DEVELOPMENT.md` 和实际命令一致。

## 4. 模块依赖

```text
工程与契约
├── common（配置、ID、时间、错误）
├── auth/users（身份与资源归属）
├── scenarios（场景配置与不可变版本）
├── safety（终止、脱敏、真实受骗检测）
└── storage（仓储接口与实现）

scenarios + safety
        ↓
training（状态机、会话、轮次）
        ↓ emits
assessment（行为事件、规则评分）
        ↓
review（个人复盘投影）
        ↓
family（授权摘要、行动卡、复训）

ai/adapters（ASR、LLM、TTS）
        ↓
voice/websocket（轮流、重连、取消、降级）
        ↓
training（只接收统一结果，不感知供应商）

scenarios 稳定后
        ↓
第二场景验证
        ↓
内容管理、审核与发布
```

硬依赖规则：

- `training` 可以依赖 `scenarios` 和 `safety` 的公开类型，不能读取它们的 ORM 私有表；
- `assessment` 消费行为事件，不读取前端按钮或 AI 供应商原始响应；
- `family` 只读取经过授权的报告投影，不直接查询完整训练轮次；
- `ai` 适配器不能决定状态转换或最终评分；
- Redis 不能保存唯一业务事实；
- 前端不能持有评分规则、供应商密钥或权限判定逻辑。

## 5. 计划文件结构

M1 完成时建议形成以下文件边界。后续里程碑沿用，不另建第二套训练系统。

```text
frontend/
├── package.json
├── pnpm-lock.yaml
├── vite.config.ts
├── src/
│   ├── api/
│   │   ├── client.ts
│   │   ├── auth.ts
│   │   └── training.ts
│   ├── features/
│   │   └── elder/
│   │       └── training/
│   │           ├── TrainingStartView.vue
│   │           ├── TrainingTurnView.vue
│   │           ├── TrainingReviewView.vue
│   │           ├── training.store.ts
│   │           └── components/
│   │               ├── LargeChoiceButton.vue
│   │               ├── TrainingProgress.vue
│   │               └── EndTrainingButton.vue
│   ├── router/
│   │   └── index.ts
│   ├── styles/
│   │   └── elder.css
│   └── main.ts
└── tests/
    ├── unit/
    │   └── training.store.spec.ts
    └── e2e/
        ├── m1-training.spec.ts
        └── m1-unauthorized.spec.ts

backend/
├── pyproject.toml
├── alembic.ini
├── alembic/
│   ├── env.py
│   └── versions/
│       └── 0001_m1_training_core.py
├── app/
│   ├── main.py
│   ├── common/
│   │   ├── config.py
│   │   ├── errors.py
│   │   ├── ids.py
│   │   └── time.py
│   ├── auth/
│   │   ├── api.py
│   │   ├── service.py
│   │   └── schemas.py
│   ├── users/
│   │   ├── models.py
│   │   └── repository.py
│   ├── scenarios/
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── validation.py
│   │   ├── repository.py
│   │   └── seeds/
│   │       └── customer_refund_v1.json
│   ├── training/
│   │   ├── api.py
│   │   ├── domain.py
│   │   ├── models.py
│   │   ├── state_machine.py
│   │   ├── service.py
│   │   └── repository.py
│   ├── assessment/
│   │   ├── domain.py
│   │   ├── models.py
│   │   ├── scoring.py
│   │   ├── review.py
│   │   └── repository.py
│   ├── safety/
│   │   ├── redaction.py
│   │   ├── stop_rules.py
│   │   └── real_fraud_rules.py
│   ├── audit/
│   │   ├── events.py
│   │   └── repository.py
│   └── storage/
│       ├── database.py
│       └── memory.py
└── tests/
    ├── test_health.py
    ├── unit/
    │   ├── scenarios/test_validation.py
    │   ├── training/test_state_machine.py
    │   ├── assessment/test_scoring.py
    │   └── safety/test_stop_rules.py
    ├── integration/
    │   ├── test_training_api.py
    │   ├── test_training_persistence.py
    │   └── test_migrations.py
    └── fixtures/
        ├── customer_refund_v1.json
        └── synthetic_second_scenario.json

docs/
├── API_CONVENTIONS.md
├── M1_ACCEPTANCE.md
├── REQUIREMENT_TRACEABILITY.md
└── SCORING_RULES.md

scripts/
├── dev.ps1
└── test.ps1

.github/workflows/ci.yml
.env.example
.editorconfig
.gitignore
docker-compose.yml
```

## 6. M1 实施任务

### Task 1：锁定开发前契约

**Files:**

- Create: `docs/API_CONVENTIONS.md`
- Create: `docs/SCORING_RULES.md`
- Create: `docs/M1_ACCEPTANCE.md`
- Create: `docs/REQUIREMENT_TRACEABILITY.md`
- Modify: `docs/PRE_DEVELOPMENT_CHECKLIST.md`

- [ ] 确认 Node.js、pnpm、Python 和 Docker 的项目锁定版本。
- [ ] 固定 UUID、UTC 时间、JSON 枚举值和分页约定。
- [ ] 固定 API 错误格式为 `{"code": "...", "message": "...", "details": {}, "request_id": "..."}`。
- [ ] 把第 3.4 节场景阶段写成可审核的客服退款 L4 内容表。
- [ ] 把第 3.5 节行为事件与每个按钮选择逐项对应。
- [ ] 在 `SCORING_RULES.md` 锁定每个事件的维度、权重、上限、下限和严重负向覆盖规则。
- [ ] 把全部第一版需求映射到 M1.0、M1.1、M2、M3、M4、M5、M6 或 M7，消除“P0 等于 M1”的误读。
- [ ] 写出正常完成、主动终止、安全中止和越权拒绝四条人工验收脚本。
- [ ] 更新启动阻塞清单，只在上述文件均通过评审后关闭 M1 契约阻塞项。

**Gate:** 场景、事件和评分规则必须先于实现合并；规则未锁定时不得开始编写评分代码。

### Task 2：建立工程骨架与质量入口

**Files:**

- Create: `backend/pyproject.toml`
- Create: `backend/app/main.py`
- Create: `backend/app/common/config.py`
- Create: `backend/tests/test_health.py`
- Create: `frontend/package.json`
- Create: `frontend/pnpm-lock.yaml`
- Create: `frontend/vite.config.ts`
- Create: `frontend/src/main.ts`
- Create: `frontend/src/router/index.ts`
- Create: `scripts/dev.ps1`
- Create: `scripts/test.ps1`
- Create: `.env.example`
- Create: `.editorconfig`
- Create: `.gitignore`
- Create: `docker-compose.yml`
- Create: `.github/workflows/ci.yml`
- Modify: `docs/DEVELOPMENT.md`

- [ ] 初始化 FastAPI 应用并提供不泄露配置的 `/health`。
- [ ] 初始化 Vue 3 + TypeScript + Vite 应用。
- [ ] 配置后端格式化、静态检查和 pytest。
- [ ] 配置前端格式化、类型检查、Vitest 和 Playwright。
- [ ] 提供 `scripts/dev.ps1` 统一启动本地依赖、后端和前端，提供 `scripts/test.ps1` 运行全量检查。
- [ ] 先建立只启动 MySQL 的 Docker Compose 服务；Redis 和 MinIO 暂不加入默认启动链路。
- [ ] 配置 CI 顺序：后端静态检查 → 后端测试 → 前端类型检查 → 前端单元测试 → Playwright。
- [ ] 在 `DEVELOPMENT.md` 记录实际可运行命令，不保留未经验证的占位命令。
- [ ] 运行全部健康检查，确认空工程在 Windows 主要开发环境可复现。

**Gate:** 后续功能 PR 必须通过同一套本地命令和 CI，不能为每个模块发明独立启动方式。

### Task 3：实现共享类型和场景配置校验

**Files:**

- Create: `backend/app/common/errors.py`
- Create: `backend/app/common/ids.py`
- Create: `backend/app/common/time.py`
- Create: `backend/app/scenarios/schemas.py`
- Create: `backend/app/scenarios/validation.py`
- Create: `backend/app/scenarios/seeds/customer_refund_v1.json`
- Create: `backend/tests/unit/scenarios/test_validation.py`
- Create: `backend/tests/fixtures/synthetic_second_scenario.json`

- [ ] 先写测试，覆盖有效客服退款配置可加载。
- [ ] 写失败测试，覆盖缺少开始阶段、结束条件、降级文案和评分映射。
- [ ] 写失败测试，覆盖不可达阶段、未知转换目标、无界循环和压力等级超限。
- [ ] 定义场景、阶段、选择、转换、行为事件映射、结束条件和评分策略的 Pydantic 类型。
- [ ] 实现场景图校验，保证所有阶段从入口可达且所有非终态存在有限退出路径。
- [ ] 加载客服退款首版配置并生成稳定内容哈希。
- [ ] 加载合成第二场景夹具，证明校验器不依赖 `customer_refund` 特有字段。
- [ ] 运行 `python -m pytest backend/tests/unit/scenarios -q`，预期全部通过。

**Gate:** 状态机只能接收通过校验的场景版本。

### Task 4：实现纯领域状态机和安全停止

**Files:**

- Create: `backend/app/training/domain.py`
- Create: `backend/app/training/state_machine.py`
- Create: `backend/app/safety/redaction.py`
- Create: `backend/app/safety/stop_rules.py`
- Create: `backend/app/safety/real_fraud_rules.py`
- Create: `backend/tests/unit/training/test_state_machine.py`
- Create: `backend/tests/unit/safety/test_stop_rules.py`

- [ ] 先写从 `identity_claim` 到 `completed` 的正常路径失败测试。
- [ ] 写用户点击结束后立即进入 `user_terminated` 的失败测试。
- [ ] 写疑似真实受骗文本优先进入 `safety_stopped` 的失败测试。
- [ ] 写超过最大轮数后强制结束的失败测试。
- [ ] 写重复、迟到选择不会重复生成事件的失败测试。
- [ ] 实现无数据库、无 FastAPI、无供应商依赖的纯状态转换函数。
- [ ] 实现终止词、真实受骗关键词和敏感数字串遮蔽的确定性规则。
- [ ] 保证安全检查先于正常阶段转换。
- [ ] 运行状态机测试并对所有配置路径执行遍历测试。

**Gate:** 状态机测试未通过前，不开发训练页面。

### Task 5：实现行为事件、规则评分和基础复盘

**Files:**

- Create: `backend/app/assessment/domain.py`
- Create: `backend/app/assessment/scoring.py`
- Create: `backend/app/assessment/review.py`
- Create: `backend/tests/unit/assessment/test_scoring.py`

- [ ] 先写五维事件产生预期维度结果的失败测试。
- [ ] 写同一事件重复输入不会重复计分的失败测试。
- [ ] 写严重负向事件覆盖一般正向事件且分数不小于 0 的失败测试。
- [ ] 写相同事件集合重复评分结果完全相同的失败测试。
- [ ] 写缺少证据的事件被拒绝计分的失败测试。
- [ ] 实现不可变行为事件、评分策略版本和五维结果类型。
- [ ] 实现只依赖事件与版本的纯评分函数。
- [ ] 实现基础复盘投影：鼓励总结、做得好的行为、未处理风险、脱敏证据和一条优先建议。
- [ ] 运行评分测试并保存一份客服退款金标准结果夹具。

**Gate:** 前端只展示后端复盘结果，不自行推导分数或风险结论。

### Task 6：交付 M1.0 进程内训练 API

**Files:**

- Create: `backend/app/storage/memory.py`
- Create: `backend/app/scenarios/repository.py`
- Create: `backend/app/training/repository.py`
- Create: `backend/app/training/service.py`
- Create: `backend/app/training/api.py`
- Create: `backend/tests/integration/test_training_api.py`

- [ ] 定义场景和训练仓储协议，并提供进程内实现。
- [ ] 提供预置老人身份，仅在 M1.0 开发和测试配置启用。
- [ ] 实现获取可训练场景、创建会话、提交选择、主动结束和读取复盘接口。
- [ ] 每次提交校验会话所有者、会话状态、阶段 ID 和客户端轮次号。
- [ ] 对重复请求返回同一结果，对迟到或越序请求返回统一业务错误。
- [ ] 将状态机、行为事件、评分和复盘串成一条应用服务，不把业务逻辑写入 API 路由。
- [ ] 写集成测试覆盖正常结束、主动结束、安全中止、重复请求和越权访问。
- [ ] 运行 `python -m pytest backend/tests -q`，预期全部通过。

**Gate:** API 必须能在完全关闭 MySQL、Redis、对象存储和公网网络时运行。

### Task 7：交付 M1.0 老人端 L4 流程

**Files:**

- Create: `frontend/src/api/client.ts`
- Create: `frontend/src/api/training.ts`
- Create: `frontend/src/features/elder/training/TrainingStartView.vue`
- Create: `frontend/src/features/elder/training/TrainingTurnView.vue`
- Create: `frontend/src/features/elder/training/TrainingReviewView.vue`
- Create: `frontend/src/features/elder/training/training.store.ts`
- Create: `frontend/src/features/elder/training/components/LargeChoiceButton.vue`
- Create: `frontend/src/features/elder/training/components/TrainingProgress.vue`
- Create: `frontend/src/features/elder/training/components/EndTrainingButton.vue`
- Create: `frontend/src/styles/elder.css`
- Create: `frontend/tests/unit/training.store.spec.ts`
- Create: `frontend/tests/e2e/m1-training.spec.ts`

- [ ] 先写 store 测试，覆盖开始、提交中、成功、失败、结束和复盘状态。
- [ ] 先写 Playwright 主流程，断言可从开始页到达复盘页。
- [ ] 实现场景介绍页，明确“这是模拟训练”和随时退出方式。
- [ ] 实现每屏一个主要问题、一个主操作区和始终可见的结束按钮。
- [ ] 实现至少 18px 正文字号、44px 以上点击目标、高对比度和清晰焦点态。
- [ ] 禁止双击重复提交；请求失败时说明已保存状态和可继续动作。
- [ ] 复盘页展示五维结果、脱敏证据和一条优先建议。
- [ ] 使用手机视口、键盘导航和 200% 缩放运行测试。

**Gate:** M1.0 达标后先做一次演示和体验复核，再接入 MySQL；发现流程问题时优先改领域和契约，不用数据库掩盖问题。

### Task 8：把 M1.0 升级为 M1.1 持久化工程

**Files:**

- Create: `backend/app/storage/database.py`
- Create: `backend/app/users/models.py`
- Create: `backend/app/users/repository.py`
- Create: `backend/app/scenarios/models.py`
- Create: `backend/app/training/models.py`
- Create: `backend/app/assessment/models.py`
- Create: `backend/app/assessment/repository.py`
- Create: `backend/alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/alembic/versions/0001_m1_training_core.py`
- Create: `backend/tests/integration/test_training_persistence.py`
- Create: `backend/tests/integration/test_migrations.py`

- [ ] 先写迁移测试，验证空库升级到 head。
- [ ] 先写重启后仍可读取训练和评分的失败测试。
- [ ] 定义最小用户、不可变场景版本、训练会话、轮次、行为事件和评估结果表。
- [ ] 为业务幂等键、所有者查询和场景版本查询建立必要唯一约束与索引。
- [ ] 实现 SQLAlchemy 仓储，不修改领域服务公开接口。
- [ ] 在创建会话时保存场景版本 ID、内容哈希和评分策略版本。
- [ ] 保证评分结果和产生它的事件在同一事务边界内持久化。
- [ ] 验证迁移升级、重复升级和开发环境重建。
- [ ] 保留进程内仓储作为单元测试和 M1.0 演示替身。

**Gate:** 业务测试必须对进程内仓储和 MySQL 仓储运行同一组契约测试。

### Task 9：增加最小鉴权、资源授权和审计

**Files:**

- Create: `backend/app/auth/schemas.py`
- Create: `backend/app/auth/service.py`
- Create: `backend/app/auth/api.py`
- Create: `backend/app/audit/events.py`
- Create: `backend/app/audit/repository.py`
- Create: `frontend/src/api/auth.ts`
- Create: `frontend/tests/e2e/m1-unauthorized.spec.ts`

- [ ] 提供预置体验账号登录，不依赖短信服务。
- [ ] 使用短期、HttpOnly Cookie 保存身份凭证；开发环境明确记录 Secure 属性差异。
- [ ] 在每个训练读写接口执行身份和资源所有权校验。
- [ ] 写两个老人账号互相读取、继续或结束对方训练均被拒绝的测试。
- [ ] 记录登录、训练开始、训练结束、安全中止和评分失败事件。
- [ ] 审计字段只保存事件类型、主体、对象、时间、结果和脱敏原因，不保存完整训练内容。
- [ ] 验证日志中不存在 Cookie、JWT、密码和完整敏感数字串。

**Gate:** 全部训练接口先有后端资源授权，再进入 M1 验收。

### Task 10：M1 综合验收

**Files:**

- Modify: `docs/M1_ACCEPTANCE.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DEVELOPMENT.md`
- Modify: `docs/DOCUMENTATION_BASELINE.md`

- [ ] 在全新环境执行安装、数据库启动、迁移、后端启动和前端启动。
- [ ] 执行后端单元与集成测试。
- [ ] 执行前端单元、类型检查和 Playwright。
- [ ] 人工执行正常完成、主动结束、安全中止和越权拒绝脚本。
- [ ] 使用真实手机或等效触控设备完成主流程。
- [ ] 搜索日志和数据库样本，确认没有未脱敏敏感输入。
- [ ] 复核所有 M1 需求在追踪表中有实现与测试证据。
- [ ] 更新路线图为 M1.0/M1.1 两个验收点，并记录实际命令。
- [ ] 只有全部完成定义满足后，才把 M1 标记完成并开始 M2。

## 7. M1 之后的完整开发顺序

### Phase A：M2 固定分支语音

依赖：M1 的场景版本、状态机、行为事件、评分、身份和持久化全部稳定。

顺序：

1. 完成 ASR/TTS 供应商对比和数据保留评审；
2. 固定浏览器音频格式、分片和 WebSocket 消息协议；
3. 建立 `SpeechRecognizer`、`SpeechSynthesizer` 和模拟适配器；
4. 接入对象存储并确定录音保留、过期与删除状态；
5. 实现 WebSocket 鉴权、轮次号、确认、取消和重连；
6. 实现浏览器采集、播放、麦克风权限和自动轮流；
7. 接入 ASR，识别结果先经过安全规则再进入状态机；
8. 接入 TTS，播放前确认回复仍属于当前轮次；
9. 建立 L2 实时 TTS、L3 预录语音、L4 文字按钮降级；
10. 用真实手机和临时 HTTPS 测量延迟、失败率和恢复体验。

M2 完成门：

- 手机可完成一次固定分支语音学习；
- ASR 或 TTS 失败自动降级且评分含义不变；
- 断线重连重新鉴权并恢复已持久化状态；
- 日志不保存完整转写和原始音频；
- 性能阈值来自实测，不使用臆测数字。

### Phase B：M3 受控 AI 测评与完整五维复盘

依赖：M2 稳定的轮次控制、取消、降级和语音观测指标。

顺序：

1. 固定 LLM 结构化输入输出契约；
2. 建立提示注入、越界、敏感信息、重复回复和无法结束测试集；
3. 实现 `DialogueModel` 模拟适配器和供应商适配器；
4. 实现自然语言到带证据、置信度行为事件的映射；
5. 对低置信度事件执行“不下严重结论”规则；
6. 状态机先决定当前阶段与允许策略，LLM 只生成范围内表达；
7. 播放前执行结构、阶段、敏感信息和禁止内容检查；
8. 越界、超时或格式错误时使用审核话术并从 L1 降到 L2/L3/L4；
9. 把 AI 辅助证据送入既有确定性评分器；
10. 完善五维复盘、证据追踪和疑似真实受骗求助页面。

M3 完成门：

- AI 无权修改阶段、最终得分和结束规则；
- 同义表达能映射到同类行为事件；
- 越界输出在展示和播放前被拦截；
- 终止和真实受骗规则优先于 AI；
- 关闭 LLM 后仍能完成同一场景。

### Phase C：M4 家庭协同闭环

依赖：稳定的个人复盘和明确的数据最小化投影。

顺序：

1. 锁定绑定、持续权限和单次分享的语义；
2. 完成老人、家属、内容管理员和系统管理员角色矩阵；
3. 实现双方发起、老人确认的 `FamilyLink`；
4. 实现分项 `FamilyPermission` 和撤销即时生效；
5. 实现老人先看个人报告，再创建 `ShareGrant`；
6. 从报告生成家庭摘要投影，不返回完整轮次、录音和敏感回答；
7. 生成只包含一个任务的 `FamilyActionCard`；
8. 家属记录行动完成，但不修改老人能力得分；
9. 根据薄弱行为创建复训建议；
10. 测试越权、撤销、实时 WebSocket 禁止和审计记录。

M4 完成门：

- 未授权家属看不到摘要；
- 家属不能连接老人实时训练；
- 撤销后新访问立即失败；
- 老人明确知道分享了什么；
- 行动卡完成情况与能力评分完全隔离。

### Phase D：M5 旗舰体验增强

依赖：M2 的语音控制和 M3 的动态测评已稳定。

顺序：

1. 增加训练前设备与权限检查；
2. 实现明确标识为模拟训练的来电界面；
3. 实现老人开口后停止当前播放；
4. 取消过期 ASR、LLM 和 TTS 任务；
5. 防止迟到音频或回复进入新轮次；
6. 接入多种合成语音角色，不接入声音克隆；
7. 完成 PWA 安装、手机适配和弱网恢复；
8. 进行老人可用性测试并修正文字、节奏、点击区和错误恢复。

M5 完成门：

- 主动打断不会播放过期回复；
- 麦克风拒绝时可直接进入 L4；
- 用户能随时识别当前是“系统播放、等待回答、识别中还是生成中”；
- 老人无需开发人员指导可完成旗舰流程。

### Phase E：M6 第二场景与轻量内容管理

依赖：训练引擎没有客服退款硬编码，场景版本模型已稳定。

顺序：

1. 先以代码配置接入保健品营销正式场景；
2. 增加慢节奏信任积累、健康焦虑和持续诱导规则；
3. 运行两场景契约测试，修正真正共性的场景模型；
4. 模型稳定后再建设内容管理表单；
5. 实现草稿、测试、待审核、已发布和已下线生命周期；
6. 实现沙盒路径模拟和语音试听；
7. 发布前检查不可达分支、缺失结束、压力超限和降级缺失；
8. 发布后生成不可变版本；
9. 实现脱敏后的越界、重复和评分失败异常记录；
10. 验证进行中会话继续使用启动版本。

M6 完成门：

- 两个机制不同的场景使用同一训练内核；
- 引擎代码不存在客服退款专用分支；
- 内容管理员不能跳过校验直接发布；
- 第一版仍不建设拖拽式编排器。

### Phase F：M7 部署、数据治理与答辩加固

依赖：核心闭环和双场景均完成，CI 已从 M1 持续运行。

顺序：

1. 固定生产配置、域名、HTTPS/WSS 和部署区域；
2. 构建 Nginx、前端、FastAPI、MySQL、Redis 和 MinIO 容器拓扑；
3. 实现健康检查、关键延迟、降级次数和失败原因指标；
4. 验证录音过期、删除重试和审计；
5. 完成权限、安全、日志脱敏和供应商退出测试；
6. 完成备份、恢复、密钥轮换和数据删除演练；
7. 准备虚构演示账号、固定场景版本和可重复演示数据；
8. 打包不依赖公网 AI 的 L3 本地演示版本；
9. 执行公网手机主流程、断网、麦克风拒绝和关闭 AI 演练；
10. 完成隐私告知、用户协议、训练免责声明和第三方素材清单。

M7 完成门：

- 公网手机可重复完成客服退款全闭环；
- 保健品场景证明扩展能力；
- 关闭公网 AI 后本地包仍可演示；
- 录音自动过期、授权撤销和越权拒绝都有证据；
- 答辩脚本连续演练通过。

### Phase G：第一版之后

以下能力必须单独立项，不得顺带塞进 M1 至 M7：

- 社区组织、活动、任务和匿名群体统计；
- 小程序或原生应用；
- 本地 ASR、TTS 或大模型；
- 真实电话；
- 可视化拖拽编排器；
- 外部机构自动联动。

## 8. 总体交付顺序

```text
M0 文档与治理基线
→ M1.0 L4 行走骨架
→ M1.1 持久化文字训练 MVP
→ M2 固定分支语音与 L2/L3/L4
→ M3 受控 AI 与 L1
→ M4 家庭授权、分享和行动卡
→ M5 模拟来电、主动打断和 PWA 体验
→ M6 保健品场景与内容管理
→ M7 公网部署、本地降级包和答辩加固
→ 第一版后再评估社区共育
```

不可颠倒的关键依赖：

- 场景契约先于状态机；
- 状态机先于 AI 对话；
- 行为事件先于评分；
- 评分先于家庭摘要；
- 个人复盘先于分享；
- 适配器契约先于供应商 SDK；
- 固定语音轮次先于动态 AI；
- 第二场景验证先于可视化编排；
- CI、安全、隐私和适老化贯穿每个里程碑，不是 M7 的补丁。

## 9. 每个里程碑的统一开发循环

每个模块和里程碑均按以下顺序推进：

1. 确认关联需求、明确不包含范围和安全影响；
2. 固定公开类型、API 或消息契约；
3. 先写失败的单元或契约测试；
4. 实现最小领域逻辑；
5. 运行单元测试；
6. 接入仓储、网络或供应商适配器；
7. 运行集成测试；
8. 接入前端纵向流程；
9. 运行手机端到端和人工验收；
10. 更新需求追踪、开发命令、安全说明和里程碑状态；
11. 小步提交并通过 PR 合入；
12. 只有完成门全部满足后才开始下一里程碑。

## 10. 最终合理性复核

### 10.1 范围复核

- M1 只验证训练内核和文字闭环，没有混入语音、AI、家庭或管理端；
- 第一版核心闭环的每一段都在 M1 至 M7 中有明确归属；
- 社区方向保留为后续，不影响当前验收；
- 没有把真实电话、声音克隆或自动报警重新带回范围。

### 10.2 依赖复核

- 所有外部 AI 能力都建立在可独立运行的 L4 内核上；
- 家庭端只依赖已完成的个人评估，不反向影响训练得分；
- 内容管理建立在两个场景验证后的稳定模型上；
- Redis、MinIO 和 WebSocket 均在首次真实需求出现时接入；
- 每个里程碑都能形成可运行版本。

### 10.3 风险复核

- 最高返工风险的场景契约、状态机和评分规则被前置；
- 最高不确定性的语音供应商和延迟通过 M2 原型实测关闭；
- 最高安全风险的终止、脱敏、越权和 AI 输出检查分别在首次相关功能出现时实现；
- 最高演示风险的公网依赖通过 L3/L4 降级包兜底；
- 第二场景硬编码风险由 M1 合成夹具和 M6 正式场景双重验证。

### 10.4 资源复核

- M1.0 允许在 MySQL 完整接入前验证产品闭环，但其代码和测试不会被丢弃；
- 单人或小团队可以按纵向切片串行推进，不要求并行维护多个半成品；
- 每次只引入当前里程碑需要的基础设施和供应商；
- 未来每个里程碑应再拆成独立、可跟踪的实现计划和 Issues，避免用本主计划代替日常任务管理。

### 10.5 最终判断

该顺序合理，可作为当前项目的主开发路线。最重要的调整不是增加功能，而是：

1. 把 M1 明确成真正的 L4 文字训练 MVP；
2. 用 M1.0/M1.1 两个门槛控制第一次可运行和第一次可持续演进；
3. 把安全、CI、适老化和临时部署前移到首次相关功能；
4. 建立需求到里程碑追踪，避免 P0 被误解为 M1 全量范围。

在这四项调整完成后，不需要再设计第三个“更简易版本”。
