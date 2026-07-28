# API 约定

## 1. 适用范围

本文定义安信伴老公开 HTTP API 的通用请求和响应契约。所有字段的数据表示遵循 [`DATA_CONVENTIONS.md`](./DATA_CONVENTIONS.md)。

本文不定义具体 HTTP 路由、数据库表或业务状态机。WebSocket 消息契约由后续任务单独定义。

## 2. 成功响应

单一资源直接返回资源对象，不增加通用 `data` 包装层：

```json
{
  "training_session_id": "550e8400-e29b-41d4-a716-446655440000",
  "scenario_version_id": "991f3f54-79d7-4b0e-b2b0-a8f22f3d327c",
  "created_at": "2026-07-24T08:30:15.123Z"
}
```

集合响应使用第 4 节定义的统一游标分页对象。

## 3. 幂等写请求

需要幂等保护的写请求使用 `Idempotency-Key` 请求头。键由客户端生成，格式为 UUID v4。

幂等作用域至少包含已认证主体和端点：

- 同一作用域、同一键和同一请求语义返回首次业务结果。
- 并发收到相同请求时只执行一次业务副作用。
- 同一作用域和同一键被不同请求体复用时返回 `IDEMPOTENCY_KEY_REUSED`。
- 服务端必须保存足以比较请求语义并重放业务结果的信息；具体保存介质和期限由实现任务定义。

## 4. 游标分页

分页请求参数固定为：

- `cursor`：可选的不透明字符串，由服务端生成；客户端不得解析或构造。
- `limit`：可选整数，默认值 20，允许范围 1 至 100。

非末页响应：

```json
{
  "items": [
    {
      "training_session_id": "550e8400-e29b-41d4-a716-446655440000"
    }
  ],
  "next_cursor": "eyJvZmZzZXQiOjIwfQ",
  "has_more": true
}
```

末页响应：

```json
{
  "items": [],
  "next_cursor": null,
  "has_more": false
}
```

`items` 始终为数组。`has_more` 为 `true` 时 `next_cursor` 必须是非空字符串；为 `false` 时 `next_cursor` 必须为 `null`。

## 5. 错误响应

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
  "request_id": "a9cb2a7c-4c09-4f7b-8414-4ad3d2aeb004"
}
```

- `code`：稳定的英文大写 `UPPER_SNAKE_CASE` 机器码，客户端只依据此字段分支。
- `message`：安全、可展示的简体中文说明，不作为程序分支依据。
- `details`：始终为 JSON 对象；无额外信息时返回空对象。
- `request_id`：UUID 字符串，用于日志关联。

错误响应不得包含内部堆栈、SQL、密钥、令牌、完整录音、完整转写或其他敏感数据。

首批通用错误码：

| `code` | 含义 |
| --- | --- |
| `VALIDATION_ERROR` | 请求格式或字段校验失败 |
| `AUTHENTICATION_REQUIRED` | 缺少或无法验证身份 |
| `PERMISSION_DENIED` | 已认证主体无权执行操作 |
| `RESOURCE_NOT_FOUND` | 资源不存在或不可向当前主体披露 |
| `CONFLICT` | 当前资源状态与操作冲突 |
| `IDEMPOTENCY_KEY_REUSED` | 幂等键被不同请求语义复用 |
| `RATE_LIMITED` | 请求频率超过限制 |
| `INTERNAL_ERROR` | 未公开内部细节的服务端错误 |

无字段级详情的错误示例：

```json
{
  "code": "RESOURCE_NOT_FOUND",
  "message": "未找到请求的资源",
  "details": {},
  "request_id": "59d84a2f-63de-40f4-bf25-04723c74fa78"
}
```

## 6. 请求关联与演进

服务端为每个请求生成或传播内部认可的请求标识，并在错误响应中返回 `request_id`。客户端不得用 `request_id` 推断用户、资源或时间信息。

后续 API Task 必须引用本文和 `DATA_CONVENTIONS.md`，不得重新定义分页、错误结构或训练领域字段名。
