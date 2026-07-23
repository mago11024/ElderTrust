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

## 4. 计划开发环境

| 工具 | 版本基线 |
| --- | --- |
| Node.js | 20 LTS 或项目锁定版本 |
| pnpm | 9.x 或项目锁定版本 |
| Python | 3.12 |
| MySQL | 8.0+ |
| Redis | 7.x |
| MinIO | 与 S3 API 兼容的稳定版本 |
| Docker | 24+ |
| Docker Compose | v2 |

实际工程创建后必须通过锁文件和工具配置固定版本。

## 5. 计划命令契约

工程骨架完成后，应提供以下入口或等价脚本：

```powershell
# 基础设施
docker compose up -d mysql redis minio

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

第一版至少需要以下配置，仓库只提交 `.env.example`：

```text
APP_ENV=
APP_HOST=
APP_PORT=
FRONTEND_ORIGIN=

DATABASE_URL=
REDIS_URL=

JWT_SECRET=
JWT_EXPIRE_MINUTES=

STORAGE_ENDPOINT=
STORAGE_BUCKET=
STORAGE_ACCESS_KEY=
STORAGE_SECRET_KEY=
RECORDING_RETENTION_POLICY=

ASR_PROVIDER=
ASR_API_KEY=
LLM_PROVIDER=
LLM_API_KEY=
TTS_PROVIDER=
TTS_API_KEY=

AI_REQUEST_TIMEOUT_SECONDS=
TRAINING_MAX_DURATION_SECONDS=
TRAINING_MAX_TURNS=
LOG_LEVEL=
```

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
