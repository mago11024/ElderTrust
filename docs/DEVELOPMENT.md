# 开发指南

## 目的

本文档为开发人员提供项目协作、代码组织、环境配置、测试和交付的基础规则。当前仓库处于项目基线设计阶段，后续源码应按本文档确定的 Vue 3 + Spring Boot 3 技术栈落地。

## 开发前准备

建议新成员先阅读：

1. `README.md`
2. `docs/PROJECT_OVERVIEW.md`
3. `docs/TECH_STACK_AND_CORE_FEATURES.md`
4. `docs/REQUIREMENTS.md`
5. `docs/ARCHITECTURE.md`
6. `docs/SECURITY_PRIVACY.md`
7. `CONTRIBUTING.md`

在开始开发前，应明确本次任务对应的需求、影响范围、验收方式和安全隐私影响。

## 开发环境

第一版推荐版本如下：

```text
Node.js: 20 LTS
pnpm: 9.x
Java: 17
Maven: 3.9.x
MySQL: 8.0+
Redis: 7.x
MinIO: RELEASE.2024 或兼容版本
Docker: 24+
Docker Compose: v2
前端测试: Vitest、Vue Test Utils、Playwright
后端测试: JUnit 5、Spring Boot Test、Testcontainers
```

原则：

- 版本必须固定或给出明确范围。
- 本地、测试、生产环境应尽量保持一致。
- 密钥、密码和令牌不得提交到仓库。

## 目录约定

```text
frontend/        前端应用
backend/         后端服务
docs/            项目文档
docs/api/        API 文档
scripts/         开发、构建、部署辅助脚本
tests/           跨模块或端到端测试
.github/         GitHub 工作流、模板和协作配置
```

源码接入时应按此结构创建工程。如果实际代码采用不同结构，应更新本节。

## 本地启动

源码接入后建议使用以下命令约定：

```bash
# 安装依赖
cd frontend
pnpm install

# 启动前端
pnpm dev

# 启动后端
cd ../backend
mvn spring-boot:run

# 启动本地基础设施
cd ..
docker compose up -d mysql redis minio

# 运行前端测试
cd frontend
pnpm test

# 运行后端测试
cd ../backend
mvn test
```

工程创建后，应补充：

- 运行目录。
- 必要环境变量。
- 默认端口。
- 常见失败原因和解决方式。

## 环境变量

不得提交真实密钥。建议后续提供 `.env.example`，只包含示例值。

建议变量：

```text
APP_ENV=
APP_PORT=
FRONTEND_BASE_URL=
DATABASE_URL=
JWT_SECRET=
LOG_LEVEL=
REDIS_HOST=
REDIS_PORT=
STORAGE_ENDPOINT=
STORAGE_ACCESS_KEY=
STORAGE_SECRET_KEY=
THIRD_PARTY_API_KEY=
```

要求：

- 生产密钥必须由部署环境或密钥管理系统提供。
- 日志中不得打印密钥。
- 环境变量新增、删除或改名时，应更新本文档和 `.env.example`。

## 分支策略

建议使用轻量分支流程：

- `main`：稳定主分支。
- `feature/<topic>`：功能开发。
- `fix/<topic>`：缺陷修复。
- `docs/<topic>`：文档更新。
- `chore/<topic>`：构建、配置或维护变更。

变更合入 `main` 前应经过自测和代码评审。

## 提交信息

建议使用清晰的提交前缀：

```text
feat: 新功能
fix: 修复缺陷
docs: 文档变更
test: 测试变更
refactor: 重构
chore: 工程维护
security: 安全相关变更
```

示例：

```text
docs: add initial project documentation
feat: add scenario training result model
fix: prevent unauthorized family progress access
```

## 代码规范

通用要求：

- 命名清晰，避免含义模糊的缩写。
- 业务逻辑不要散落在界面层或路由层。
- 权限判断集中实现，避免每个页面自行拼装规则。
- 外部输入必须校验。
- 错误处理应给用户可理解反馈，同时保留便于排查的日志。
- 不提交无关格式化和大规模重排。

涉及老年用户体验时：

- 文案简洁直接。
- 操作路径尽量短。
- 关键按钮明确区分。
- 失败后提供下一步建议。

## 测试要求

后续接入源码后，建议至少覆盖：

- 单元测试：核心业务规则、权限判断、结果计算。
- 接口测试：鉴权、参数校验、错误响应。
- 集成测试：训练流程、家庭授权、社区活动。
- 端到端测试：关键用户路径。
- 安全测试：越权访问、敏感信息泄露、导出权限。

优先测试高风险逻辑：

- 家庭成员是否只能看授权数据。
- 社区工作者是否只能访问所属范围。
- 训练结果是否正确计算。
- 内容发布是否经过审核状态。
- 敏感信息是否不会出现在日志和响应中。

## Pull Request 要求

提交 PR 前应确认：

- 需求或问题背景清楚。
- 影响范围说明完整。
- 自测结果可复现。
- 涉及隐私、安全或权限的变更已经重点说明。
- 文档已同步更新。

可使用 `.github/PULL_REQUEST_TEMPLATE.md` 作为检查清单。

## 发布前检查

正式发布前建议检查：

- 所有必要测试通过。
- 数据库迁移可回滚或有备份方案。
- 生产环境配置完整。
- 日志和监控可用。
- 管理员账号和权限经过确认。
- 隐私政策、用户协议或告知说明已准备。
- 关键功能有人工验收记录。

## 文档维护

以下情况必须更新文档：

- 新增或修改核心功能。
- 修改启动、部署、测试命令。
- 修改环境变量。
- 修改权限、角色、数据范围。
- 修改 API 契约。
- 修改数据保存、导出、删除、匿名化规则。

文档过期会直接影响开发效率和系统安全，应与代码变更一起提交。
