# step-web-search-skill

一个轻量级跨平台 StepFun 搜索封装，调用官方 `POST /v1/search` 接口。

## 特性

- 提供三套入口：`.sh`（macOS / Linux）、`.cmd`（Windows cmd/PowerShell）、`.mjs`（跨平台 Node.js）
- `.sh` 与 `.cmd` 主要执行链路不依赖 Python/Node 运行时
- `.mjs` 作为 Windows curl TLS 故障时的 fallback，同时支持 `json/markdown/table` 格式化输出
- 从本地 `config.json` 读取 `api_key`
- 支持 `query`、`n`、`category`、超时、`dry-run`、`--insecure`
- 已验证的 `category`：`programming`、`research`、`gov`、`business`

## 快速开始

1. 复制配置模板：

```bash
cp config.example.json config.json
```

2. 在 `config.json` 中填写真实 `api_key`。

3. 执行搜索：

Windows（cmd / PowerShell）：

```powershell
.\scripts\step-web-search.cmd "OpenAI o3 最新消息" --n 5 --category research
```

```powershell
node .\scripts\step-web-search.mjs "OpenAI o3 最新消息" --n 5 --category research --format markdown
```

macOS / Linux：

```bash
chmod +x ./scripts/step-web-search.sh
./scripts/step-web-search.sh "OpenAI o3 最新消息" --n 5 --category research
```

**注意**：在 PowerShell 中连续执行多条命令时，请用分号 `;` 代替 `&&`。

## CLI 参数

```text
step-web-search [query] [--n <number>] [--category <value>] [--api-key <key>]
  [--base-url <url>] [--timeout-ms <ms>] [--format json|markdown|table]
  [--dry-run] [--insecure] [--help]
```

说明：

- `--n`：返回结果数量，默认值来自 `config.json` 的 `default_n`，未配置时为 `10`
- `--category`：分类筛选；仅支持 `programming`、`research`、`gov`、`business`
- `--api-key`：临时覆盖配置文件里的 key
- `--base-url`：临时覆盖接口域名，默认 `https://api.stepfun.com`
- `--timeout-ms`：请求超时，单位毫秒
- `--format`：输出格式，仅 Node.js 脚本 `.mjs` 支持。可选 `json`（默认）、`markdown`、`table`
- `--dry-run`：仅打印请求参数，不发送网络请求
- `--insecure`：将 `-k` 透传给 curl（仅 `.sh` / `.cmd` 有效，用于排查 TLS）

`category` 可省略，接口会返回通用结果。

## 说明与安全

- `config.json` 已被 `.gitignore` 忽略，不会提交仓库
- 真实密钥请只保留在你本机
- 协作者共享 `config.example.json`

## 排障

- Windows 下如果报 `SEC_E_NO_CREDENTIALS` 或 `AcquireCredentialsHandle failed`，
  通常是本机 TLS/凭证环境问题，不是参数问题。此时建议直接使用 Node.js 备用入口：
  ```powershell
  node .\scripts\step-web-search.mjs "你的查询" --n 5
  ```

## 参考文档

- [StepFun Search API 官方文档](https://platform.stepfun.com/docs/zh/api-reference/search/search)
- [StepFun Search API 摘要](./references/stepfun-search-api.md)

## 许可证

MIT
