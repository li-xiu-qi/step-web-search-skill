---
name: step-web-search-skill
description: |
  当 agent 需要通过 StepFun 官方 /v1/search 接口执行联网检索时使用。
  触发于用户提到 StepFun 搜索、step-1-search、联网搜索、网页检索，
  或要求把 StepFun Search 封装成可复用脚本、CLI、Skill 的场景。
  适用于需要本地脚本直接调用 StepFun Search API，而不是通用浏览器搜索的情况。
---

# step-web-search-skill

## 定位

本 Skill 规范了通过 StepFun `POST /v1/search` 接口执行本地联网搜索的完整执行流程。

## 触发条件

当用户有以下意图时，必须调用本 Skill：

- 要求使用 StepFun 进行网页搜索
- 提到 "step-1-search"、"StepFun 搜索"、"stepfun 联网"
- 需要将搜索能力脚本化、CLI 化
- 要求验证 StepFun Search API 的连通性

## 执行流程

### 步骤 1：选择调用入口

根据当前环境选择唯一入口：

1. **macOS / Linux**：优先使用 `scripts/step-web-search.sh`
2. **Windows 且 curl 可用**：优先使用 `scripts/step-web-search.cmd`
3. **Windows 且 curl 报 TLS 错误**：降级到 `node scripts/step-web-search.mjs`
4. **需要格式化输出（markdown/table）**：强制使用 `scripts/step-web-search.mjs`

### 步骤 2：确认配置文件

检查 skill 根目录下是否存在 `config.json`：
- 若存在：从中读取 `api_key`
- 若不存在：要求用户先复制 `config.example.json` 为 `config.json` 并填入真实 key
- 临时覆盖：可通过 `--api-key` 参数或 `STEPFUN_API_KEY` 环境变量传入

### 步骤 3：构造命令

标准命令格式：

```bash
# Unix
./scripts/step-web-search.sh "<query>" --n <number> --category <value>

# Windows
cd step-web-search-skill
.\scripts\step-web-search.cmd "<query>" --n <number> --category <value>

# Node.js 跨平台
node scripts/step-web-search.mjs "<query>" --n <number> --category <value> --format json
```

**PowerShell 特别注意**：命令分隔符用分号 `;` 代替 `&&`。

### 步骤 4：执行并捕获输出

- `.sh` / `.cmd` 默认输出原始 JSON
- `.mjs` 可通过 `--format markdown` 或 `--format table` 输出可读格式
- 所有脚本在参数错误、网络失败、鉴权失败时返回非 0 退出码

### 步骤 5：异常处理

| 异常现象 | 判断 | 处理动作 |
|----------|------|----------|
| `SEC_E_NO_CREDENTIALS` 或 `AcquireCredentialsHandle failed` | Windows curl TLS 握手失败 | 立即换用 `node scripts/step-web-search.mjs` |
| `HTTP 401` | API key 无效或缺失 | 检查 `config.json` 中的 `api_key` 是否正确 |
| `HTTP 400` | 参数错误 | 检查 `category` 是否使用了未支持的值 |
| 超时无响应 | 网络或服务端问题 | 增加 `--timeout-ms` 重试，或检查 base_url |

## 参数规范

| 参数 | 用途 | 默认值 |
|------|------|--------|
| `--n` | 返回结果数量 | 10（或 `config.json` 中的 `default_n`） |
| `--category` | 搜索分类过滤 | 空字符串（通用搜索） |
| `--api-key` | 临时覆盖 API key | 读取环境变量或 `config.json` |
| `--base-url` | 临时覆盖接口域名 | `https://api.stepfun.com` |
| `--timeout-ms` | 请求超时（毫秒） | 30000 |
| `--format` | 输出格式（仅 `.mjs` 支持） | `json`，可选 `markdown` / `table` |
| `--dry-run` | 仅打印请求参数，不发送 | 关闭 |
| `--insecure` | 透传 `-k` 给 curl（仅排查证书用） | 关闭 |

`category` 的可用取值（已实跑验证）：`programming`、`research`、`gov`、`business`。

## 输出处理约定

- 若用户要求"整理成 Markdown"、"输出表格"、"方便阅读"，必须使用 `.mjs` 入口并指定 `--format markdown` 或 `--format table`
- 若用户要求"返回原始结果"、"JSON"、"二次解析"，优先使用 `.sh` / `.cmd` 的默认 JSON 输出
- 网络错误必须在返回给用户之前显式说明失败原因

## 安全约束

- `config.json` 已加入 `.gitignore`，禁止将其提交到版本控制
- 真实 API key 只保留在本地
- 对外共享时仅提供 `config.example.json`

## 关联文档

- [README](./README.md) —— 面向人类用户的安装与使用说明
- [StepFun Search API 摘要](./references/stepfun-search-api.md) —— 接口细节参考
