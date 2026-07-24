# T00-02 API 与数据约定设计

## 目标

在任何 HTTP 路由、数据库表或前后端工程出现前，固定后续任务共同使用的 JSON、标识符、时间、枚举、幂等、分页、错误响应以及训练领域公开命名，避免各模块形成不兼容契约。

## 范围

本设计产出两份权威文档：

- `docs/API_CONVENTIONS.md`：API 请求与响应、幂等、分页和错误格式。
- `docs/DATA_CONVENTIONS.md`：通用 JSON 数据类型、标识符、时间、枚举和训练领域命名。

本任务不定义具体 HTTP 路由、数据库表、ORM 模型、WebSocket 消息或业务状态机。

## 基础数据约定

- JSON 字段名统一使用英文 `snake_case`。
- 公开资源标识符统一使用 UUID v4，以小写、带连字符的 JSON 字符串表示。
- 时间戳统一使用 UTC RFC 3339，固定以 `Z` 结尾并保留三位毫秒；字段名使用 `*_at`。
- 不含时间的日期使用 `YYYY-MM-DD`。
- 枚举使用稳定的英文小写 `snake_case` 字符串。既有值不得改名或改变含义，只能兼容地追加新值。
- 布尔值只使用 JSON `true` 和 `false`。
- 数量、序号使用 JSON 整数。未来若出现货币，使用最小货币单位整数，不使用浮点数。
- 字段缺失与显式 `null` 含义不同；允许为空的字段必须在契约中明确声明。
- 服务端拒绝请求中的未知字段；响应消费者应容忍新增字段。

## API 约定

### 成功响应

单一资源直接返回资源对象，集合直接返回统一分页对象，不增加通用 `data` 包装层。

### 幂等

- 需要幂等保护的写请求使用 `Idempotency-Key` 请求头。
- 键由客户端生成，格式为 UUID v4。
- 幂等作用域至少包含已认证主体和端点。
- 同一作用域、同一键和同一请求语义返回首次业务结果。
- 同一作用域和同一键被不同请求体复用时，返回 `IDEMPOTENCY_KEY_REUSED` 冲突错误。

### 游标分页

- 请求参数固定为 `cursor` 和 `limit`。
- `cursor` 是服务端生成的不透明字符串，客户端不得解析或构造。
- `limit` 默认值为 20，允许范围为 1 至 100。
- 响应字段固定为 `items`、`next_cursor` 和 `has_more`。
- 最后一页返回 `next_cursor: null` 和 `has_more: false`。

### 错误响应

所有错误使用同一顶层结构：

```json
{
  "code": "VALIDATION_ERROR",
  "message": "请求参数不符合要求",
  "details": {
    "fields": [
      {
        "field": "limit",
        "reason": "must_be_between_1_and_100"
      }
    ]
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

- `code` 是稳定的英文大写 `UPPER_SNAKE_CASE` 机器码。
- `message` 是安全、可展示的简体中文说明，不作为程序分支依据。
- `details` 始终是 JSON 对象；无额外信息时返回空对象。
- `request_id` 使用 UUID，供日志关联，不暴露内部堆栈、凭据或敏感数据。
- 首批通用错误码为 `VALIDATION_ERROR`、`AUTHENTICATION_REQUIRED`、`PERMISSION_DENIED`、`RESOURCE_NOT_FOUND`、`CONFLICT`、`IDEMPOTENCY_KEY_REUSED`、`RATE_LIMITED` 和 `INTERNAL_ERROR`。

## 训练领域公开命名

- `training_session_id`：一次训练会话的公开标识符。
- `turn_id`：一次会话内单个轮次的公开标识符。
- `turn_index`：轮次在会话内从 1 开始的稳定整数序号。
- `scenario_id`：跨版本保持稳定的场景标识符。
- `scenario_version_id`：不可变场景版本的公开标识符。

训练会话开始时必须记录并锁定 `scenario_version_id`。后续轮次、降级和评分均引用该版本，不使用含糊的 `session_id`、`round_id`、`scene_id` 或 `version` 作为公开字段名。

## 文档与验证

两份正式文档中的每个 JSON 示例必须可由标准 JSON 解析器解析。验收脚本应提取 Markdown 中标记为 `json` 的代码块并逐个执行 `ConvertFrom-Json`，同时检查：

- 必需章节和规范字段存在；
- 训练领域名称只使用本设计固定的字段；
- 文档没有定义具体路由或数据库表；
- 任务目录校验继续通过。

后续 API Task 应引用 `docs/API_CONVENTIONS.md` 和 `docs/DATA_CONVENTIONS.md`，不再自行定义同义字段。
