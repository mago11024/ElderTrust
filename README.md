# 安信伴老

面向家庭协同与社区共育的老年人反诈情景训练系统。

本项目旨在通过情景化训练、家庭协同提醒、社区共育活动与风险识别反馈，帮助老年人提升对常见诈骗场景的识别、判断和求助能力。当前仓库处于项目基线设计阶段，已确定第一版推荐技术栈和核心功能范围，后续源码应按本文档约定落地。

## 项目目标

- 提供贴近真实生活的反诈情景训练，例如冒充客服、投资理财、保健品推销、冒充亲友、中奖返利等场景。
- 支持老年用户以低门槛方式完成学习、练习、测评和复盘。
- 支持家庭成员了解训练进展，协助进行提醒、陪伴和干预。
- 支持社区工作者组织课程、查看群体学习情况、沉淀线下宣教材料。
- 保护老年用户及家庭成员的个人信息，避免在训练过程中引入新的隐私和安全风险。

## 适用角色

- 老年用户：进行反诈情景学习、互动训练、风险判断和结果复盘。
- 家庭成员：查看授权范围内的训练进度，协助提醒和陪伴学习。
- 社区工作者：组织活动、管理课程、查看统计数据、跟进重点人群。
- 系统管理员：维护用户、内容、权限、配置、审计和运行状态。
- 开发人员：实现、测试、部署和维护系统能力。

## 文档导航

- [项目概览](docs/PROJECT_OVERVIEW.md)：项目背景、范围、角色、核心能力与边界。
- [技术栈与核心功能](docs/TECH_STACK_AND_CORE_FEATURES.md)：第一版技术选型、功能模块、版本边界与交付路线。
- [需求说明](docs/REQUIREMENTS.md)：业务目标、功能需求、非功能需求与验收标准。
- [架构设计](docs/ARCHITECTURE.md)：建议系统架构、模块边界、数据流与技术决策原则。
- [开发指南](docs/DEVELOPMENT.md)：本地开发、分支、代码规范、测试与交付流程。
- [安全与隐私](docs/SECURITY_PRIVACY.md)：数据分级、权限、日志、合规和风险控制要求。
- [贡献指南](CONTRIBUTING.md)：协作方式、提交规范、评审要求和文档维护规则。
- [Pull Request 模板](.github/PULL_REQUEST_TEMPLATE.md)：提交变更时的检查清单。

## 技术栈基线

第一版采用稳妥、易维护、适合课程管理和后台业务的 Web 技术栈：

- 前端：Vue 3、TypeScript、Vite、Pinia、Vue Router、Element Plus。
- 后端：Java 17、Spring Boot 3、Spring Security、JWT、MyBatis-Plus。
- 数据库：MySQL 8。
- 缓存与会话辅助：Redis。
- 文件与素材存储：MinIO 或兼容 S3 的对象存储。
- 接口文档：OpenAPI 3 / Swagger UI。
- 测试：JUnit 5、Spring Boot Test、Vitest、Playwright。
- 部署：Docker Compose、Nginx、独立 MySQL 与 Redis 服务。

语音识别、智能对话、大模型辅助生成训练内容等能力暂不作为第一版必需功能，应以后续可插拔服务方式接入。

## 推荐目录结构

```text
.
├── README.md
├── CONTRIBUTING.md
├── docs/
│   ├── PROJECT_OVERVIEW.md
│   ├── REQUIREMENTS.md
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT.md
│   └── SECURITY_PRIVACY.md
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md
├── frontend/
├── backend/
├── docs/api/
├── scripts/
└── tests/
```

源码接入时应优先按此结构创建工程；如确需调整，应同步更新本 README、`docs/ARCHITECTURE.md` 和 `docs/DEVELOPMENT.md`。

## 开发协作原则

- 需求先行：涉及用户流程、权限、数据结构或外部接口的变更，应先更新需求或设计说明。
- 小步提交：每次提交聚焦一个明确目的，避免混合重构、功能和格式化。
- 安全默认开启：涉及个人信息、训练记录、家庭关系和社区管理数据时，应默认最小权限、最少采集、可审计。
- 可验证交付：功能完成前应提供测试、截图、接口示例或人工验收记录。
- 文档同步：代码行为、配置方式、部署流程发生变化时，同步更新相关文档。

## 许可证

许可证尚未确定。正式开源或对外发布前，应补充 `LICENSE` 文件并在本节说明授权范围。
