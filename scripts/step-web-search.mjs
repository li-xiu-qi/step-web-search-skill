#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const configPath = path.join(rootDir, "config.json");

function usage() {
  console.log(
`Usage:
  node scripts/step-web-search.mjs "<query>" [--n <number>] [--category <value>]
    [--api-key <key>] [--base-url <url>] [--timeout-ms <ms>] [--format json|markdown|table] [--dry-run] [--help]

Examples:
  node scripts/step-web-search.mjs "OpenAI o3 最新消息" --n 5 --category research
  node scripts/step-web-search.mjs "Claude Mythos" --format markdown --n 3`
  );
}

function readConfig() {
  if (!fs.existsSync(configPath)) {
    return {};
  }
  return JSON.parse(fs.readFileSync(configPath, "utf8"));
}

function formatAsMarkdown(results) {
  if (!Array.isArray(results) || results.length === 0) {
    return "无结果。";
  }
  const lines = [];
  for (const r of results) {
    const title = r.title || "无标题";
    const url = r.url || "";
    const snippet = (r.snippet || r.content || "").trim();
    const time = r.time || "";
    lines.push(`### ${title}`);
    if (time) lines.push(`- 时间: ${time}`);
    lines.push(`- 链接: ${url}`);
    if (snippet) {
      lines.push("");
      lines.push(snippet);
    }
    lines.push("");
  }
  return lines.join("\n");
}

function formatAsTable(results) {
  if (!Array.isArray(results) || results.length === 0) {
    return "无结果。";
  }
  const header = "| 序号 | 标题 | 时间 | 链接 |\n|------|------|------|------|";
  const rows = results.map((r, i) => {
    const title = (r.title || "无标题").replace(/\|/g, "\\|");
    const time = (r.time || "").replace(/\|/g, "\\|");
    const url = (r.url || "").replace(/\|/g, "\\|");
    return `| ${i + 1} | ${title} | ${time} | ${url} |`;
  });
  return [header, ...rows].join("\n");
}

const args = process.argv.slice(2);
let queryParts = [];
let nOverride = "";
let categoryOverride = "";
let apiKeyOverride = "";
let baseUrlOverride = "";
let timeoutMsOverride = "";
let formatOverride = "";
let dryRun = false;

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--n") {
    nOverride = args[++i] ?? "";
    continue;
  }
  if (arg === "--category") {
    categoryOverride = args[++i] ?? "";
    continue;
  }
  if (arg === "--api-key") {
    apiKeyOverride = args[++i] ?? "";
    continue;
  }
  if (arg === "--base-url") {
    baseUrlOverride = args[++i] ?? "";
    continue;
  }
  if (arg === "--timeout-ms") {
    timeoutMsOverride = args[++i] ?? "";
    continue;
  }
  if (arg === "--format") {
    formatOverride = args[++i] ?? "";
    continue;
  }
  if (arg === "--dry-run") {
    dryRun = true;
    continue;
  }
  if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  }
  queryParts.push(arg);
}

const query = queryParts.join(" ").trim();
if (!query) {
  usage();
  process.exit(2);
}

const config = readConfig();
const apiKey = apiKeyOverride || process.env.STEPFUN_API_KEY || config.api_key || "";
const baseUrl = (baseUrlOverride || config.base_url || "https://api.stepfun.com").replace(/\/+$/, "");
const n = Number(nOverride || config.default_n || 10);
const category = categoryOverride || config.default_category || "";
const timeoutMs = Number(timeoutMsOverride || config.timeout_ms || 30000);
const format = formatOverride || "json";

if (!apiKey && !dryRun) {
  console.error("Error: API key is missing. Set config.json api_key or use --api-key/STEPFUN_API_KEY.");
  process.exit(2);
}

if (!["json", "markdown", "table"].includes(format)) {
  console.error("Error: format must be one of: json, markdown, table");
  process.exit(2);
}

if (category && !["programming", "research", "gov", "business"].includes(category)) {
  console.error("Error: category must be one of: programming, research, gov, business");
  process.exit(2);
}

if (!Number.isFinite(n) || n < 1 || !Number.isInteger(n)) {
  console.error("Error: n must be a positive integer.");
  process.exit(2);
}

if (!Number.isFinite(timeoutMs) || timeoutMs < 1) {
  console.error("Error: timeout-ms must be a positive number.");
  process.exit(2);
}

const body = { query, n };
if (category) {
  body.category = category;
}

if (dryRun) {
  console.log(`[dry-run] endpoint: ${baseUrl}/v1/search`);
  console.log(`[dry-run] payload:  ${JSON.stringify(body)}`);
  console.log(`[dry-run] format:   ${format}`);
  process.exit(0);
}

const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

try {
  const res = await fetch(`${baseUrl}/v1/search`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
    signal: controller.signal,
  });

  clearTimeout(timeoutId);
  const text = await res.text();

  if (!res.ok) {
    console.error(`HTTP ${res.status}`);
    console.error(text);
    process.exit(1);
  }

  if (format === "json") {
    console.log(text);
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    console.error("Error: failed to parse response JSON.");
    console.error(text);
    process.exit(1);
  }

  const results = data.results || [];
  if (format === "markdown") {
    console.log(formatAsMarkdown(results));
  } else if (format === "table") {
    console.log(formatAsTable(results));
  }
  process.exit(0);
} catch (err) {
  clearTimeout(timeoutId);
  if (err.name === "AbortError") {
    console.error(`Error: request timed out after ${timeoutMs}ms`);
  } else {
    console.error(`Error: ${err.message}`);
  }
  process.exit(1);
}
