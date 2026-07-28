# T01-03 统一开发脚本与 CI 设计

## 1. 目标

为现有 FastAPI 后端、Vue 老人端和 MySQL 开发容器建立统一、可重复的本地开发与质量检查入口，并让 GitHub Actions 复用同一套检查命令。

本设计只覆盖 T01-03。Redis、MinIO、应用容器化、生产部署、训练页面和真实端到端用例均不在范围内。

## 2. 已确认前提

- T01-01、T01-02 和上一 Gate T00-04 已完成并通过验收。
- Windows 11 是当前主要开发环境，仓库统一入口使用 PowerShell。
- MySQL 继续由 `docker-compose.yml` 管理；后端和前端直接在宿主机运行。
- `.gitignore` 已由提交 `099e64f` 创建，T01-03 对它执行扩充而不是重复创建。
- 开发入口采用同终端统一编排。

## 3. 开发入口

`scripts/dev.ps1` 负责以下流程：

1. 从脚本位置解析仓库根目录，不依赖调用者当前目录。
2. 检查 `docker`、`python` 和 `pnpm` 命令是否可用。
3. 执行 `docker compose up -d --wait mysql`，以 Compose 健康状态作为 MySQL 就绪条件。
4. 在同一终端启动后端：

   ```powershell
   python -m uvicorn app.main:app --reload
   ```

   后端工作目录为 `backend`。

5. 在同一终端启动前端：

   ```powershell
   pnpm dev
   ```

   前端工作目录为 `frontend`。

6. 持续跟踪两个应用子进程并转发其输出。

任一应用进程意外退出时，脚本停止另一个由本次调用创建的应用进程，并返回非零退出码。用户按 Ctrl+C 时，同样清理本次调用创建的前后端进程，但不停止 MySQL。需要停止数据库时，开发者显式执行：

```powershell
docker compose stop mysql
```

脚本不得清理调用前已经存在的容器或无关进程。

## 4. 统一质量入口

`scripts/test.ps1` 从仓库根目录稳定执行检查，按以下顺序失败即停：

### 4.1 后端

```powershell
python -m ruff format --check .
python -m ruff check .
python -m mypy
python -m pytest
```

工作目录为 `backend`。

### 4.2 前端

```powershell
pnpm test --run
pnpm typecheck
```

工作目录为 `frontend`。

### 4.3 端到端预留入口

脚本读取 `frontend/package.json`：

- 存在 `scripts.test:e2e` 时执行 `pnpm test:e2e`；
- 尚不存在时输出明确的 `SKIP`，说明端到端入口将在 T01-13 接入；
- 跳过尚未实现的端到端检查不视为失败。

这样可以在 T01-13 只增加前端脚本和测试配置，无需复制或改写 CI 的检查流程。

每个检查阶段输出清晰的阶段名称。实际命令返回非零退出码时，统一入口必须返回非零退出码，且不继续运行后续阶段。

## 5. CI

`.github/workflows/ci.yml` 在所有 pull request 和 `main` 分支 push 时运行，采用 Windows runner，以匹配当前主要开发与脚本环境。

CI 执行以下步骤：

1. 检出代码。
2. 安装仓库锁定范围内的 Python 3.12、Node.js 24 和 pnpm 11.4.0。
3. 使用 `python -m pip install -e ".[dev]"` 安装后端。
4. 使用 `pnpm install --frozen-lockfile` 安装前端。
5. 从仓库根目录调用：

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/test.ps1
   ```

CI 不重新声明 Ruff、mypy、pytest、Vitest 或类型检查命令。质量检查的顺序和行为只由 `scripts/test.ps1` 定义。

工作流只需要读取仓库内容，并使用并发取消避免同一分支的过期运行继续占用资源。

## 6. 工程配置

### 6.1 `.editorconfig`

根级规则统一：

- UTF-8；
- LF；
- 文件末尾换行；
- 删除行尾空白；
- Python 使用 4 空格；
- Vue、TypeScript、JavaScript、JSON、YAML、Markdown 和 PowerShell 使用 2 空格；
- Markdown 保留有意义的行尾空格。

### 6.2 `.gitignore`

保留现有 `.worktrees/`，并忽略：

- `.env` 及本地覆盖文件，但保留 `.env.example`；
- Python 虚拟环境、缓存、类型检查、测试和覆盖率产物；
- Node 依赖、构建、测试和覆盖率产物；
- IDE、编辑器和操作系统临时文件。

不得忽略 `pnpm-lock.yaml`、源码、测试、文档和示例配置。

### 6.3 Docker Compose

`docker-compose.yml` 继续只声明 MySQL 和其数据卷。现有健康检查是 `dev.ps1 --wait` 的就绪契约；增加 `start_interval: 2s`，让 MySQL 在启动宽限期内更快接受健康探测，不增加 Redis、MinIO 或应用服务。

## 7. 错误处理

- 缺少必需命令时，在启动任何子进程前失败，并给出缺失命令名称。
- MySQL 启动或健康检查失败时，不启动前后端。
- 后端或前端启动失败时，清理另一个由本次调用启动的应用进程。
- 质量检查缺少依赖时保留原命令错误并返回非零状态，不静默安装或修改开发者环境。
- 所有脚本使用 `try/finally` 恢复工作目录并执行必要清理。
- 日志不得输出真实密钥、本地 `.env` 内容或数据库密码。

## 8. 测试策略

实现遵循测试驱动顺序：

1. 先增加 PowerShell 工作流契约测试，验证脚本和 CI 尚不存在时按预期失败。
2. 使用临时目录和 PATH 命令替身验证：
   - 从任意工作目录调用仍能解析仓库路径；
   - 后端、前端和端到端检查的顺序；
   - 缺少 `test:e2e` 时明确跳过；
   - 实际检查失败会传播非零退出码并停止后续检查；
   - 开发入口先等待 MySQL，再启动两个应用；
   - 应用失败或中断时只清理本次创建的应用进程。
3. 验证 CI 结构、锁定工具版本、冻结安装和对 `scripts/test.ps1` 的复用。
4. 解析 CI YAML 和 Compose 配置。
5. 运行真实 T01-01、T01-02 和 T01-03 回归检查。

测试替身不得要求真实启动长期运行的 Vite 或 Uvicorn 服务，也不得操作开发者已有的 MySQL 容器。最终人工冒烟验证可单独启动开发入口，并在确认两个服务可访问后中断。

## 9. 文档

`docs/DEVELOPMENT.md` 更新为实际命令契约，至少说明：

- 统一开发启动命令；
- 前置依赖安装命令；
- 同终端日志与 Ctrl+C 行为；
- MySQL 的保留和手动停止方式；
- 统一本地质量检查命令；
- 端到端检查在 T01-13 前的 `SKIP` 行为；
- CI 与本地复用同一入口。

## 10. 验收

完成前必须取得以下新鲜证据：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test.ps1
docker compose config
python scripts/check_traceability.py
powershell -ExecutionPolicy Bypass -File scripts/validate_task_catalog.ps1
```

此外，CI YAML 必须通过解析检查，工作流契约测试必须通过，且工作区中的无关修改不得进入提交。
