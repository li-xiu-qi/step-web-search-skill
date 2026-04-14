#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.json"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/step-web-search.sh "<query>" [--n <number>] [--category <value>] [--api-key <key>] [--base-url <url>] [--timeout-ms <ms>] [--dry-run] [--insecure] [--help]

Examples:
  ./scripts/step-web-search.sh "OpenAI o3 最新消息" --n 5 --category research
  ./scripts/step-web-search.sh "最新 AI 科研" --dry-run
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' is required but not found in PATH." >&2
    exit 127
  fi
}

json_get_string() {
  local key="$1"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return
  fi
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"[[:space:]]*,?[[:space:]]*$/\1/p" "$CONFIG_FILE" | head -n1
}

json_get_number() {
  local key="$1"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return
  fi
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*([0-9]+)[[:space:]]*,?[[:space:]]*$/\1/p" "$CONFIG_FILE" | head -n1
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

QUERY_PARTS=()
N_OVERRIDE=""
CATEGORY_OVERRIDE=""
API_KEY_OVERRIDE=""
BASE_URL_OVERRIDE=""
TIMEOUT_MS_OVERRIDE=""
DRY_RUN=0
INSECURE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --n)
      [[ $# -ge 2 ]] || { echo "Error: --n requires a value" >&2; exit 2; }
      N_OVERRIDE="$2"
      shift 2
      ;;
    --category)
      [[ $# -ge 2 ]] || { echo "Error: --category requires a value" >&2; exit 2; }
      CATEGORY_OVERRIDE="$2"
      shift 2
      ;;
    --api-key)
      [[ $# -ge 2 ]] || { echo "Error: --api-key requires a value" >&2; exit 2; }
      API_KEY_OVERRIDE="$2"
      shift 2
      ;;
    --base-url)
      [[ $# -ge 2 ]] || { echo "Error: --base-url requires a value" >&2; exit 2; }
      BASE_URL_OVERRIDE="$2"
      shift 2
      ;;
    --timeout-ms)
      [[ $# -ge 2 ]] || { echo "Error: --timeout-ms requires a value" >&2; exit 2; }
      TIMEOUT_MS_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --insecure)
      INSECURE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      QUERY_PARTS+=("$1")
      shift
      ;;
  esac
done

QUERY="${QUERY_PARTS[*]:-}"
if [[ -z "$QUERY" ]]; then
  usage
  exit 2
fi

require_cmd curl

CFG_API_KEY="$(json_get_string api_key)"
CFG_BASE_URL="$(json_get_string base_url)"
CFG_DEFAULT_N="$(json_get_number default_n)"
CFG_DEFAULT_CATEGORY="$(json_get_string default_category)"
CFG_TIMEOUT_MS="$(json_get_number timeout_ms)"

API_KEY="${API_KEY_OVERRIDE:-${STEPFUN_API_KEY:-$CFG_API_KEY}}"
BASE_URL="${BASE_URL_OVERRIDE:-${CFG_BASE_URL:-https://api.stepfun.com}}"
N="${N_OVERRIDE:-${CFG_DEFAULT_N:-10}}"
CATEGORY="${CATEGORY_OVERRIDE:-${CFG_DEFAULT_CATEGORY:-}}"
TIMEOUT_MS="${TIMEOUT_MS_OVERRIDE:-${CFG_TIMEOUT_MS:-30000}}"

if [[ "$DRY_RUN" -eq 0 && -z "$API_KEY" ]]; then
  echo "Error: API key is missing. Set config.json api_key or use --api-key/STEPFUN_API_KEY." >&2
  exit 2
fi

if ! [[ "$N" =~ ^[0-9]+$ ]]; then
  echo "Error: n must be a number, got '$N'" >&2
  exit 2
fi

if ! [[ "$TIMEOUT_MS" =~ ^[0-9]+$ ]]; then
  echo "Error: timeout-ms must be a number, got '$TIMEOUT_MS'" >&2
  exit 2
fi

if [[ -n "$CATEGORY" ]]; then
  case "$CATEGORY" in
    programming|research|gov|business)
      ;;
    *)
      echo "Error: category must be one of: programming, research, gov, business" >&2
      exit 2
      ;;
  esac
fi

ENDPOINT="${BASE_URL%/}/v1/search"
PAYLOAD="{\"query\":\"$(json_escape "$QUERY")\",\"n\":$N"
if [[ -n "$CATEGORY" ]]; then
  PAYLOAD+=",\"category\":\"$(json_escape "$CATEGORY")\""
fi
PAYLOAD+="}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] endpoint: $ENDPOINT"
  echo "[dry-run] payload: $PAYLOAD"
  exit 0
fi

TIMEOUT_SEC=$(( (TIMEOUT_MS + 999) / 1000 ))
TMP_BODY="$(mktemp)"
TMP_ERR="$(mktemp)"
trap 'rm -f "$TMP_BODY" "$TMP_ERR"' EXIT

CURL_TLS_FLAG=""
if [[ "$INSECURE" -eq 1 ]]; then
  CURL_TLS_FLAG="-k"
fi

set +e
HTTP_CODE="$(curl $CURL_TLS_FLAG -sS -m "$TIMEOUT_SEC" -o "$TMP_BODY" -w "%{http_code}" -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "$PAYLOAD" 2>"$TMP_ERR")"
CURL_EXIT=$?
set -e

if [[ "$CURL_EXIT" -ne 0 ]]; then
  cat "$TMP_ERR" >&2
  if grep -Eiq 'AcquireCredentialsHandle failed|SEC_E_NO_CREDENTIALS' "$TMP_ERR"; then
    echo "Hint: this Windows TLS environment cannot establish HTTPS for curl." >&2
    echo "Fallback: use Node.js runner directly:" >&2
    echo "  node \"$SCRIPT_DIR/step-web-search.mjs\" \"$QUERY\" --n $N" >&2
  fi
  exit 1
fi

if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
  echo "HTTP $HTTP_CODE" >&2
  cat "$TMP_BODY" >&2
  exit 1
fi

cat "$TMP_BODY"