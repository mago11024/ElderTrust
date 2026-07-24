# T00-01 工具链与本地环境设计

## 目标

为后续工程初始化建立可复现、安全且可验证的本地开发基线。当前 Task 只锁定工具版本、定义配置分层、提供 MySQL 容器，并同步开发文档与正式开发前检查清单。

## 范围

本 Task 创建：

- `.tool-versions`
- `.env.example`
- `docker-compose.yml`

本 Task 修改：

- `docs/DEVELOPMENT.md`
- `docs/PRE_DEVELOPMENT_CHECKLIST.md`

本 Task 不创建前后端工程，不引入 Redis、MinIO、AI 供应商配置或部署编排。

## 版本基线

采用截至 2026-07-24 仍受支持的稳定版本线，并在锁定文件中记录精确版本：

| 工具 | 锁定版本 | 选择理由 |
| --- | --- | --- |
| Node.js | 24.18.0 | 当前 LTS，替代已经 EOL 的 Node.js 20 和 25 |
| pnpm | 11.4.0 | 与 Node.js 24 配套的当前稳定版本 |
| Python | 3.12.10 | 保持项目 Python 3.12 硬边界，并使用最后一个提供 Windows 安装器的 3.12 维护版本 |
| Docker Engine/CLI | 29.6.2 | 当前 29 系列安全修复版本 |
| Docker Compose | 5.1.4 | 当前 Compose v2 后续兼容版本，使用 `docker compose` 子命令 |
| MySQL | 8.4.10 | MySQL 8.4 LTS 当前已发布修复版本 |

`.tool-versions` 是开发工具精确版本的权威来源；`docker-compose.yml` 通过不可变的 MySQL 补丁版本标签锁定数据库镜像；文档必须与两者一致。

## 配置分层

配置分为四层：

1. `.env.example`：提交到仓库，只包含变量名、安全的本地默认值和明显的占位值。
2. 本地 `.env`：开发者私有，不提交，用于覆盖本机端口和本地开发凭据。
3. 测试配置：由测试进程或 CI 注入，使用隔离数据库和独立凭据，不复用开发数据。
4. 部署密钥：由部署平台的密钥存储注入，不写入仓库、镜像或前端构建产物。

T00-01 只定义 M1 当前需要的应用和 MySQL 配置。AI、Redis、MinIO 等后续变量在相应 Task 首次需要时加入，避免提前建立无效契约。

## MySQL Compose 服务

`docker-compose.yml` 只定义 `mysql` 服务：

- 显式使用稳定项目名 `anxin-training`，避免中文工作区名称无法归一化时解析失败；
- 使用 `mysql:8.4.10`；
- 从环境变量读取数据库名、普通用户和密码；
- 提供适合本地开发的非敏感默认占位值；
- 映射本地端口但允许通过环境变量覆盖；
- 使用命名卷保存本地数据；
- 使用 `mysqladmin ping` 健康检查；
- 设置明确的重启策略；
- 不定义 Redis、MinIO、应用容器或外部网络。

Compose 文件不使用已经废弃的顶层 `version` 字段。

## 验证策略

先运行一组聚焦 T00-01 的内联 PowerShell 断言，并在目标文件尚未创建时确认它按预期失败。为遵守 Task 文件清单，本 Task 不新增持久化验证脚本。断言检查：

- 要求的三个新文件存在；
- 五项开发工具均有精确版本；
- MySQL 镜像为锁定版本；
- Compose 中只有 `mysql` 服务并包含健康检查；
- `.env.example` 不包含真实密钥或后续范围变量；
- 两份文档中的版本和配置分层与锁定文件一致。

最小实现完成后依次运行：

1. T00-01 内联 PowerShell 断言；
2. `docker compose config`；
3. `docker compose up -d mysql`；
4. 等待 MySQL 健康状态并执行 `mysqladmin ping`；
5. `docker compose down`，保留命名卷以避免破坏本地数据；
6. `scripts/validate_task_catalog.ps1` 作为治理回归。

若 Windows 主机缺少 Compose 插件或工具版本不匹配，配置文件仍可完成，但 T00-01 不标记完成，直到主机环境升级并取得新鲜的容器验证证据。

## 错误与安全处理

- 所有示例密码必须明确标注为仅限本地、需要覆盖的占位值。
- 文档明确禁止把本地 `.env`、测试凭据或部署密钥提交到仓库。
- 验证断言只解析固定文件，不执行文件中的命令或插值内容。
- 容器启动失败时保留诊断输出，不降低健康检查或验收标准。
- 停止验证容器时不删除命名卷，除非用户明确要求清理数据。

## 完成标准

- T00-01 内联 PowerShell 断言通过；
- `docker compose config` 返回成功；
- Windows 开发设备上的 MySQL 容器达到健康状态且可响应 ping；
- 文档版本与锁定文件一致；
- 没有引入本 Task “不包含”的服务或工程骨架。
