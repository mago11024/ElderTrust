# 开发指南

## 1. 当前状态

仓库目前只有设计和开发文档，前后端源码尚未建立。本文件定义工程落地后的目录、环境、命令契约和质量要求；在工程骨架提交前，不应把下列计划命令描述为已经可运行。

## 2. 开发原则

- 每个里程碑交付一个可运行的纵向版本。
- 先验证客服退款核心训练，再开发家庭和管理功能。
- 固定分支和动态 AI 共用状态机。
- 确定性规则优先于 AI 推断。
- 外部服务必须可模拟、可超时、可取消、可降级。
- 安全、隐私和适老化要求进入测试，不作为上线前补丁。

## 3. 计划目录

```text
.
├── frontend/
│   ├── src/
│   │   ├── api/
│   │   ├── components/
│   │   ├── features/
│   │   │   ├── elder/
│   │   │   ├── family/
│   │   │   └── admin/
│   │   ├── stores/
│   │   └── views/
│   └── tests/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── auth/
│   │   ├── users/
│   │   ├── family/
│   │   ├── scenarios/
│   │   ├── training/
│   │   ├── assessment/
│   │   ├── ai/
│   │   ├── safety/
│   │   ├── audit/
│   │   ├── storage/
│   │   └── common/
│   ├── alembic/
│   └── tests/
├── docs/
├── scripts/
├── tests/
└── docker-compose.yml
```

模块应保持单一职责。跨模块调用使用应用服务和明确类型，不能跨目录直接操作内部 ORM 模型。

## 4. 开发环境

| 工具 | 版本基线 |
| --- | --- |
| Node.js | 24.18.0 |
| pnpm | 11.4.0 |
| Python | 3.12.10 |
| MySQL | 8.4.10 |
| Redis | 7.x |
| MinIO | 与 S3 API 兼容的稳定版本 |
| Docker | 29.6.2 |
| Docker Compose | 5.1.4 |

`.tool-versions` 是 Node.js、pnpm、Python、Docker 和 Docker Compose 精确版本的权威来源；`docker-compose.yml` 锁定 MySQL 镜像版本。版本变化必须同时更新锁定文件、本节和相关验收。

Windows 11 是当前主要开发与容器验收环境。仓库脚本优先提供 PowerShell 入口；跨平台脚本不得依赖 PowerShell 独有行为，若暂时只能在 Windows 运行必须在命令旁明确标注。

M1 只要求 MySQL 可运行。Redis 和 MinIO 仍是第一版技术基线，但应在短期状态、限流、录音或素材功能首次需要时接入；在此之前通过明确接口和测试替身避免业务代码绑定具体基础设施。

## 5. 计划命令契约

工程骨架完成后，应提供以下入口或等价脚本：

```powershell
# M1 基础设施
docker compose up -d mysql

# 进入语音和短期状态里程碑后
docker compose up -d redis minio

# 后端
cd backend
python -m venv .venv
python -m pip install -e ".[dev]"
python -m alembic upgrade head
python -m uvicorn app.main:app --reload

# 前端
cd frontend
pnpm install
pnpm dev

# 测试
cd backend
python -m pytest

cd ../frontend
pnpm test
pnpm exec playwright test
```

最终命令以实际 `pyproject.toml`、`package.json` 和脚本为准。任何变化都必须同步更新本文件。

## 6. 环境变量

T00-01 只定义当前本地应用和 MySQL 所需配置，仓库提交的 `.env.example` 内容如下：

```text
APP_ENV=development
APP_HOST=127.0.0.1
APP_PORT=8000
FRONTEND_ORIGIN=http://localhost:5173
LOG_LEVEL=INFO

MYSQL_DATABASE=anxin_training
MYSQL_USER=anxin_app
MYSQL_PASSWORD=local-only-change-me
MYSQL_ROOT_PASSWORD=local-root-only-change-me
MYSQL_PORT=3306
DATABASE_URL=mysql+asyncmy://anxin_app:local-only-change-me@localhost:3306/anxin_training
```

配置按以下四层管理：

1. `.env.example`：提交到仓库，只包含安全的本地默认值和明显占位值。
2. 本地 `.env`：开发者私有，不提交，用于覆盖端口和本地开发凭据。
3. 测试配置：由测试进程或 CI 注入，使用隔离数据库和独立凭据。
4. 部署密钥：由部署平台密钥存储注入，不进入仓库、镜像或前端构建产物。

Redis、MinIO、存储和 AI 供应商变量在相应 Task 首次需要时加入，不在 T00-01 提前建立契约。

真实密钥不得提交、打印或返回给前端。新增变量时必须更新 `.env.example` 和部署文档。

## 7. Python 开发约定

- API 输入、场景配置和 AI 结构化输出使用 Pydantic 校验。
- 数据访问使用 SQLAlchemy 2，数据库结构变化使用 Alembic。
- I/O 密集接口可使用 `async def`；同步阻塞调用不得直接运行在事件循环中。
- 不在 FastAPI Web 进程加载重型本地推理模型。
- 领域规则保持纯函数或小型服务，便于单元测试。
- 统一异常类型和 API 错误响应，不把供应商错误原样暴露给用户。
- 日志使用结构化字段，不记录完整对话和敏感凭证。

## 8. WebSocket 开发约定

- 只接受通过身份、Origin、资源所有权和会话状态校验的连接。
- 长期 JWT 不放在 URL。
- 每条客户端消息带会话 ID、轮次编号和消息类型。
- 对重复、迟到和乱序消息进行幂等或拒绝处理。
- 主动打断时取消未完成的生成和合成任务。
- 断线重连必须重新鉴权并从持久化状态恢复。
- 连接关闭码和错误事件应可测试、可理解。

## 9. AI 适配器约定

每个 ASR、LLM、TTS 适配器必须：

- 实现统一协议；
- 设置超时；
- 支持取消；
- 将供应商异常映射为统一错误；
- 提供不调用公网的测试替身；
- 记录耗时、降级原因和结果状态；
- 在传输前完成必要脱敏。

业务模块不得导入供应商 SDK。

## 10. 前端开发约定

- 老人端和管理端视觉组件分开，不直接复用复杂后台交互。
- 主要操作有文字、图标和语音状态反馈。
- 麦克风权限拒绝后提供明确恢复步骤和 L4 入口。
- 所有 WebSocket 状态转换集中管理，不散落在页面组件。
- 训练页避免刷新丢失；无法恢复时说明已保存和未保存内容。
- 使用手机尺寸和真实触控完成端到端测试。

## 11. 测试要求

### 后端单元测试

- 状态机转换和结束条件；
- 评分规则；
- 家庭授权；
- 脱敏和终止词；
- 场景配置校验；
- AI 输出安全检查。

### 集成测试

- HTTP 与 WebSocket 鉴权；
- MySQL 事务和 Alembic 迁移；
- Redis 状态恢复；
- 对象存储过期策略；
- AI 适配器超时、取消和降级。

### 端到端测试

- 客服退款完整闭环；
- 主动打断；
- 老人分享和家属行动卡；
- 未授权访问拒绝；
- L1 至 L4 降级；
- 保健品场景复用训练引擎。

## 12. Git 工作流

- `main`：稳定主分支。
- `codex/<topic>` 或 `feature/<topic>`：功能开发。
- `fix/<topic>`：缺陷修复。
- `docs/<topic>`：纯文档变更。

提交信息使用简洁前缀：

```text
feat: add controlled training state machine
fix: reject unauthorized training websocket
docs: align project documentation with FastAPI design
test: cover fallback transitions
security: redact sensitive speech events
```

Pull Request 必须说明范围、影响、验证结果、安全隐私影响和降级行为。

## 13. 质量门禁

合入前至少确认：

- 格式化和静态检查通过；
- 相关单元、集成或端到端测试通过；
- 数据库迁移可执行；
- 场景配置校验通过；
- 未引入真实密钥和敏感测试数据；
- 权限和降级路径有验证；
- 文档与行为同步。

## 14. 文档维护

以下变更必须同步更新文档：

- 技术栈、目录和命令；
- API、WebSocket 消息和鉴权；
- 场景模型和评分规则；
- 家庭授权范围；
- 录音保留和删除策略；
- AI 供应商和数据传输；
- 部署及降级方案。

## 15. Task 调整与版本控制

Task 范围、依赖、文件和验收以[完整 Task 目录](superpowers/plans/2026-07-23-complete-project-task-catalog.md)为准；当前执行位置以[当前开发状态](CURRENT_STATUS.md)为准。二者不能互相替代。

### 15.1 状态规则

| Task 状态 | 调整规则 |
| --- | --- |
| 未开始 | 可以拆分、合并、调整依赖和验收 |
| 进行中 | 只允许不改变主要目标的澄清 |
| 已完成 | 不改写历史范围，新建补充或修复 Task |
| 已替代 | 保留原记录并指向替代 Task |

Task 开始执行后 ID 不再改变。新增 Task 使用当前里程碑下一个未使用编号，实际执行顺序由显式依赖和 `CURRENT_STATUS.md` 决定；不得为了保持数字连续而重编号进行中或已完成 Task。

### 15.2 变更步骤

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

规划调整必须记录到[Task 变更日志](TASK_CHANGELOG.md)，并运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\validate_task_catalog.ps1
```

规划调整与功能实现不得放在同一个提交。调整未开始 Task 时需要复核其上游依赖、下游依赖、里程碑 Gate、需求追踪和验收是否仍然闭合。

## 16. Bug、回归和 Gate 重验

### 16.1 归属判断

| 情况 | 处理 |
| --- | --- |
| 当前 Task 引入回归 | 在当前 Task 内修复，当前 Task 不得完成 |
| 已完成 Task 的潜藏缺陷 | 创建独立 Bugfix Task |
| 新需求改变原行为 | 走 Task 调整流程，不标记为 Bug |
| 不阻塞的轻微问题 | 建立后续 Task，不降低当前 Gate |
| 权限、安全、隐私、评分或数据问题 | 立即阻塞后续开发并优先修复 |

### 16.2 修复步骤

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

发生回归时，`CURRENT_STATUS.md` 必须记录 `active_regression`、`suspended_task` 和是否需要 Gate 重验。修复证据和恢复决定写入[Task 变更日志](TASK_CHANGELOG.md)。

禁止：

- 改写已完成 Task 的历史范围；
- 删除失败测试或降低验收标准；
- 把无关 Bug 偷塞入当前 Task；
- 通过 `git reset --hard` 或重写共享历史掩盖回归；
- 只运行修复测试而不运行原 Task、当前 Task 和受影响 Gate。

### 16.3 Gate 失效与重验

已通过 Gate 后发现阻塞性回归时：

- 保留原完成历史；
- 把当前里程碑健康状态标记为 `regression_detected`；
- 设置 `gate_reverification_required: true`；
- 修复完成后重新运行原 Gate；
- 记录新的验证时间、命令和结果；
- 验证通过后恢复里程碑完成状态，再恢复被暂停 Task。
