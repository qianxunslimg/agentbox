#!/usr/bin/env bash
# 用途：兜底管理 OpenClaw 的微信收件人别名配置。
# 配置文件是 configs/openclaw/weixin-recipients.json；日常可以让 Agent 通过对话读取/修改。
# 这个脚本用于命令行查看、新增、删除、设置默认微信收件人。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="$PROJECT_DIR/configs/openclaw/weixin-recipients.json"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/openclaw-weixin-recipient.sh list
  bash scripts/openclaw-weixin-recipient.sh get [alias]
  bash scripts/openclaw-weixin-recipient.sh add <alias> <to@im.wechat> [accountId] [label] [role]
  bash scripts/openclaw-weixin-recipient.sh default <alias>
  bash scripts/openclaw-weixin-recipient.sh remove <alias>

Examples:
  bash scripts/openclaw-weixin-recipient.sh list
  bash scripts/openclaw-weixin-recipient.sh get owner
  bash scripts/openclaw-weixin-recipient.sh add main 'xxx@im.wechat' 'replace-with-account-id' '我的大号' admin
  bash scripts/openclaw-weixin-recipient.sh default main
USAGE
}

ensure_config() {
  if [ -f "$CONFIG_PATH" ]; then
    return
  fi
  cp "$PROJECT_DIR/configs/openclaw/weixin-recipients.json.example" "$CONFIG_PATH"
  echo "Created $CONFIG_PATH. Edit it before use." >&2
}

cmd="${1:-list}"
shift || true
ensure_config

case "$cmd" in
  list)
    node - "$CONFIG_PATH" <<'NODE'
const fs = require("node:fs");
const cfg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
function recipientsArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") {
    return Object.entries(value).map(([alias, item]) => ({ alias, ...(item ?? {}) }));
  }
  return [];
}
const recipients = recipientsArray(cfg.recipients);
for (const item of recipients) {
  const alias = item.alias;
  const mark = alias === cfg.default ? "*" : " ";
  const enabled = item.enabled === false ? "disabled" : "enabled";
  const aliases = Array.isArray(item.aliases) ? item.aliases.join(",") : "";
  console.log(`${mark} ${alias}\t${enabled}\trole=${item.role ?? "user"}\t${item.label ?? ""}\taliases=${aliases}\t${item.to ?? ""}\taccount=${item.accountId ?? ""}`);
}
NODE
    ;;
  get)
    alias_name="${1:-}"
    node - "$CONFIG_PATH" "$alias_name" <<'NODE'
const fs = require("node:fs");
const cfg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const aliasName = process.argv[3] || cfg.default;
function recipientsArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") {
    return Object.entries(value).map(([alias, item]) => ({ alias, ...(item ?? {}) }));
  }
  return [];
}
function normalize(value) {
  return String(value || "").trim().toLowerCase();
}
function candidates(recipient) {
  return [
    recipient.alias,
    recipient.label,
    ...(Array.isArray(recipient.aliases) ? recipient.aliases : []),
  ].filter(Boolean);
}
function score(recipient, query) {
  const q = normalize(query);
  if (!q) return recipient.alias === cfg.default ? 1 : 0;
  let best = 0;
  for (const candidate of candidates(recipient)) {
    const c = normalize(candidate);
    if (!c) continue;
    if (c === q) best = Math.max(best, 1000 + c.length);
    else if (q.includes(c) || c.includes(q)) best = Math.max(best, 100 + Math.min(c.length, q.length));
  }
  return best;
}
const matches = recipientsArray(cfg.recipients)
  .filter((recipient) => recipient.enabled !== false)
  .map((recipient) => ({ recipient, score: score(recipient, aliasName) }))
  .filter((entry) => entry.score > 0)
  .sort((a, b) => b.score - a.score);
const item = matches[0]?.recipient;
if (!item) {
  console.error(`Unknown Weixin recipient alias: ${aliasName}`);
  process.exit(1);
}
if (item.enabled === false) {
  console.error(`Weixin recipient alias is disabled: ${aliasName}`);
  process.exit(1);
}
console.log(JSON.stringify({
  alias: aliasName,
  channel: item.channel || "openclaw-weixin",
  accountId: item.accountId,
  to: item.to,
  role: item.role || "user",
  label: item.label || aliasName,
  aliases: Array.isArray(item.aliases) ? item.aliases : [],
}, null, 2));
NODE
    ;;
  add)
    alias_name="${1:-}"
    to="${2:-}"
    account_id="${3:-}"
    label="${4:-$alias_name}"
    role="${5:-user}"
    if [ -z "$alias_name" ] || [ -z "$to" ]; then
      usage >&2
      exit 1
    fi
    if [ "$role" != "admin" ] && [ "$role" != "user" ]; then
      echo "Invalid role: $role. Use admin or user." >&2
      exit 1
    fi
    if [ -z "$account_id" ]; then
      account_id="$(node - "$PROJECT_DIR/runtime/volumes/openclaw/openclaw-weixin/accounts.json" <<'NODE'
const fs = require("node:fs");
try {
  const accounts = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  process.stdout.write(Array.isArray(accounts) && accounts[0] ? String(accounts[0]) : "");
} catch {
  process.stdout.write("");
}
NODE
)"
    fi
    if [ -z "$account_id" ]; then
      echo "No accountId provided and no OpenClaw Weixin account found." >&2
      exit 1
    fi
    node - "$CONFIG_PATH" "$alias_name" "$to" "$account_id" "$label" "$role" <<'NODE'
const fs = require("node:fs");
const [file, aliasName, to, accountId, label, role] = process.argv.slice(2);
const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
function recipientsArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") {
    return Object.entries(value).map(([alias, item]) => ({ alias, ...(item ?? {}) }));
  }
  return [];
}
const recipients = recipientsArray(cfg.recipients);
cfg.default ??= aliasName;
const next = {
  alias: aliasName,
  label,
  channel: "openclaw-weixin",
  accountId,
  to,
  role,
  enabled: true,
  notes: "Added by scripts/openclaw-weixin-recipient.sh",
};
const index = recipients.findIndex((item) => item.alias === aliasName);
if (index >= 0) {
  recipients[index] = next;
} else {
  recipients.push(next);
}
cfg.recipients = recipients;
fs.writeFileSync(file, `${JSON.stringify(cfg, null, 2)}\n`);
console.log(`Saved Weixin recipient alias: ${aliasName}`);
console.log(`to=${to}`);
    console.log(`accountId=${accountId}`);
console.log(`role=${role}`);
NODE
    ;;
  default)
    alias_name="${1:-}"
    if [ -z "$alias_name" ]; then
      usage >&2
      exit 1
    fi
    node - "$CONFIG_PATH" "$alias_name" <<'NODE'
const fs = require("node:fs");
const [file, aliasName] = process.argv.slice(2);
const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
function recipientsArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") {
    return Object.entries(value).map(([alias, item]) => ({ alias, ...(item ?? {}) }));
  }
  return [];
}
const recipients = recipientsArray(cfg.recipients);
const item = recipients.find((recipient) => recipient.alias === aliasName);
if (!item) {
  console.error(`Unknown Weixin recipient alias: ${aliasName}`);
  process.exit(1);
}
cfg.recipients = recipients;
cfg.default = aliasName;
fs.writeFileSync(file, `${JSON.stringify(cfg, null, 2)}\n`);
console.log(`Default Weixin recipient: ${aliasName}`);
NODE
    ;;
  remove|rm|delete)
    alias_name="${1:-}"
    if [ -z "$alias_name" ]; then
      usage >&2
      exit 1
    fi
    node - "$CONFIG_PATH" "$alias_name" <<'NODE'
const fs = require("node:fs");
const [file, aliasName] = process.argv.slice(2);
const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
function recipientsArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") {
    return Object.entries(value).map(([alias, item]) => ({ alias, ...(item ?? {}) }));
  }
  return [];
}
const recipients = recipientsArray(cfg.recipients);
const next = recipients.filter((recipient) => recipient.alias !== aliasName);
if (next.length === recipients.length) {
  console.error(`Unknown Weixin recipient alias: ${aliasName}`);
  process.exit(1);
}
cfg.recipients = next;
if (cfg.default === aliasName) {
  cfg.default = next[0]?.alias ?? "";
}
fs.writeFileSync(file, `${JSON.stringify(cfg, null, 2)}\n`);
console.log(`Removed Weixin recipient alias: ${aliasName}`);
if (cfg.default) console.log(`Default Weixin recipient: ${cfg.default}`);
NODE
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
