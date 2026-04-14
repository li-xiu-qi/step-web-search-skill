# StepFun Search API 摘要

官方文档：

- https://platform.stepfun.com/docs/zh/api-reference/search/search
- https://platform.stepfun.com/interface-key

## Endpoint

- Method: `POST`
- URL: `https://api.stepfun.com/v1/search`

## Headers

- `Content-Type: application/json`
- `Authorization: Bearer <STEP_API_KEY>`

## Body

```json
{
  "query": "OpenAI o3 最新消息",
  "n": 10,
  "category": "research"
}
```

## Live Verification

2026-04-14 本地实跑结果：

- `POST https://api.stepfun.com/v1/search` 返回 `200`
- 不传 `category` 也可正常返回
- 传错 `category` 时，接口返回 `400`，错误信息明确要求：
  `programming` `research` `gov` `business`

## Response Shape

```json
{
  "query": "OpenAI o3 最新消息",
  "category": "research",
  "results": [
    {
      "url": "https://example.com",
      "position": 1,
      "title": "示例标题",
      "time": "2024-12-26T09:19:36",
      "snippet": "摘要",
      "content": "正文提取内容"
    }
  ]
}
```