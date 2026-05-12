#!/usr/bin/env bash
# 用途：调试和兜底管理 openclaw-weixin 的微信用户授权。
# 主要用于把某个 xxx@im.wechat 写入 allowFrom、ownerAllowFrom 和 elevated 权限。
# 日常使用优先通过 OpenClaw Agent 对话管理；这个脚本用于排查 pairing/权限问题。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STATE_DIR="$PROJECT_DIR/runtime/volumes/openclaw"
CONFIG_PATH="$PROJECT_DIR/configs/openclaw/openclaw.json"

USER_ID="${1:-}"
ACCOUNT_ID="${2:-}"
LIST_ONLY=0

if [ -z "$ACCOUNT_ID" ]; then
  ACCOUNT_ID="$(node - "$STATE_DIR/openclaw-weixin/accounts.json" <<'NODE'
const fs = require("node:fs");
const file = process.argv[2];
try {
  const accounts = JSON.parse(fs.readFileSync(file, "utf8"));
  process.stdout.write(Array.isArray(accounts) && accounts[0] ? String(accounts[0]) : "");
} catch {
  process.stdout.write("");
}
NODE
)"
fi

if [ -z "$ACCOUNT_ID" ]; then
  echo "No OpenClaw Weixin account found. Login first: docker exec -it agent-openclaw sh -lc 'node /app/openclaw.mjs channels login --channel openclaw-weixin'" >&2
  exit 1
fi

if [ "$USER_ID" = "list" ] || [ "$USER_ID" = "candidates" ]; then
  LIST_ONLY=1
fi

if [ -z "$USER_ID" ] || [ "$USER_ID" = "latest" ] || [ "$LIST_ONLY" = "1" ]; then
  SELF_USER_ID="$(node - "$STATE_DIR/openclaw-weixin/accounts/$ACCOUNT_ID.json" <<'NODE'
const fs = require("node:fs");
try {
  const account = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  process.stdout.write(typeof account.userId === "string" ? account.userId : "");
} catch {
  process.stdout.write("");
}
NODE
)"
  CANDIDATE_INPUT="$(mktemp)"
  {
    docker exec agent-openclaw sh -lc 'node /app/openclaw.mjs sessions --json --limit 50' 2>/dev/null || true
    printf '\n---DOCKER-LOGS---\n'
    docker logs --tail 1000 agent-openclaw 2>/dev/null || true
    printf '\n---CONTEXT-TOKENS---\n'
    cat "$STATE_DIR/openclaw-weixin/accounts/$ACCOUNT_ID.context-tokens.json" 2>/dev/null || true
  } > "$CANDIDATE_INPUT"
  CANDIDATES="$(node - "$SELF_USER_ID" "$CANDIDATE_INPUT" <<'NODE'
const fs = require("node:fs");
const selfUserId = (process.argv[2] || "").trim();
const inputPath = process.argv[3];
const input = fs.readFileSync(inputPath, "utf8");
const selfLower = selfUserId.toLowerCase();
const seen = new Map();

function add(value, source) {
  if (typeof value !== "string") return;
  const match = value.match(/[A-Za-z0-9_-]+@im\.wechat\b/g);
  if (!match) return;
  for (const raw of match) {
    const id = raw.trim();
    if (!id) continue;
    const lower = id.toLowerCase();
    const current = seen.get(lower);
    if (!current) {
      seen.set(lower, { id, source, isSelf: selfLower && lower === selfLower });
    } else if (current.id === lower && id !== lower) {
      current.id = id;
      current.source = source;
    }
  }
}

const [sessionsPart = "", logsPart = "", tokenPart = ""] = input.split(/\n---DOCKER-LOGS---\n|\n---CONTEXT-TOKENS---\n/);
try {
  const parsed = JSON.parse(sessionsPart.trim());
  const rows = Array.isArray(parsed) ? parsed : parsed.sessions ?? parsed.items ?? [];
  for (const row of rows) {
    const candidates = [
      row.displayName,
      row.lastTo,
      row.lastFrom,
      row.deliveryContext?.from,
      row.deliveryContext?.to,
      row.origin?.from,
      row.origin?.to,
      row.origin?.peer,
      row.peer,
    ];
    for (const candidate of candidates) add(candidate, "sessions");
    if (typeof row.key === "string") {
      add(row.key, "session-key");
    }
  }
} catch {
  // fall through
}
for (const line of logsPart.split(/\r?\n/)) {
  if (/from=|inbound:|authorization:|processOneMessage/.test(line)) add(line, "logs");
}
try {
  const tokens = JSON.parse(tokenPart.trim());
  for (const key of Object.keys(tokens ?? {})) add(key, "context-token");
} catch {
  add(tokenPart, "context-token");
}

const rows = [...seen.values()].sort((a, b) => Number(a.isSelf) - Number(b.isSelf));
for (const row of rows) {
  process.stdout.write(`${row.isSelf ? "self" : "candidate"}\t${row.id}\t${row.source}\n`);
}
NODE
  )"
  rm -f "$CANDIDATE_INPUT"

  if [ "$LIST_ONLY" = "1" ]; then
    if [ -n "$SELF_USER_ID" ]; then
      echo "Logged-in/scanner Weixin user: $SELF_USER_ID"
    fi
    echo "$CANDIDATES"
    exit 0
  fi

  USER_ID="$(printf '%s\n' "$CANDIDATES" | awk -F '\t' '$1 == "candidate" { print $2; exit }')"

  if [ -z "$USER_ID" ]; then
    if [ -n "$SELF_USER_ID" ]; then
      echo "Only found the logged-in/scanner Weixin user, not another Weixin sender: $SELF_USER_ID" >&2
    else
      echo "No external Weixin sender found." >&2
    fi
    echo "Send one fresh message from the Weixin account you want to approve, then run:" >&2
    echo "  bash scripts/openclaw-approve-weixin-user.sh latest" >&2
    echo "To inspect what OpenClaw can currently see, run:" >&2
    echo "  bash scripts/openclaw-approve-weixin-user.sh list" >&2
    exit 1
  fi
fi

if [ -z "$USER_ID" ]; then
  echo "No Weixin user id found. Pass it explicitly, for example:" >&2
  echo "  bash scripts/openclaw-approve-weixin-user.sh 'xxx@im.wechat'" >&2
  exit 1
fi

node - "$STATE_DIR" "$CONFIG_PATH" "$ACCOUNT_ID" "$USER_ID" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const stateDir = process.argv[2];
const configPath = process.argv[3];
const accountId = process.argv[4];
const userId = process.argv[5];

function safeKey(raw) {
  const trimmed = String(raw).trim().toLowerCase();
  if (!trimmed) throw new Error("invalid key");
  const safe = trimmed.replace(/[\\/:*?"<>|]/g, "_").replace(/\.\./g, "_");
  if (!safe || safe === "_") throw new Error("invalid key");
  return safe;
}

function addUnique(list, value) {
  if (!Array.isArray(list)) return [value];
  return list.includes(value) ? list : [...list, value];
}

const credentialsDir = path.join(stateDir, "credentials");
fs.mkdirSync(credentialsDir, { recursive: true });

const allowFromPath = path.join(
  credentialsDir,
  `${safeKey("openclaw-weixin")}-${safeKey(accountId)}-allowFrom.json`,
);

let allowFrom = { version: 1, allowFrom: [] };
try {
  allowFrom = JSON.parse(fs.readFileSync(allowFromPath, "utf8"));
} catch {
  // create below
}
allowFrom.version = 1;
allowFrom.allowFrom = addUnique(allowFrom.allowFrom, userId);
fs.writeFileSync(allowFromPath, `${JSON.stringify(allowFrom, null, 2)}\n`);

const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
cfg.commands = {
  ...(cfg.commands ?? {}),
  native: true,
  nativeSkills: true,
  restart: true,
  ownerDisplay: cfg.commands?.ownerDisplay ?? "raw",
  ownerAllowFrom: addUnique(cfg.commands?.ownerAllowFrom, userId),
};
cfg.tools = cfg.tools ?? {};
cfg.tools.elevated = {
  ...(cfg.tools.elevated ?? {}),
  enabled: true,
  allowFrom: {
    ...(cfg.tools.elevated?.allowFrom ?? {}),
    "openclaw-weixin": addUnique(cfg.tools.elevated?.allowFrom?.["openclaw-weixin"], userId),
  },
};
cfg.meta = {
  ...(cfg.meta ?? {}),
  lastTouchedVersion: cfg.meta?.lastTouchedVersion ?? "2026.5.7",
  lastTouchedAt: new Date().toISOString(),
};
fs.writeFileSync(configPath, `${JSON.stringify(cfg, null, 2)}\n`);

console.log(`Approved Weixin user: ${userId}`);
console.log(`Account: ${accountId}`);
console.log(`AllowFrom: ${allowFromPath}`);
console.log("Updated commands.ownerAllowFrom and tools.elevated.allowFrom.openclaw-weixin.");
NODE

docker compose -f "$PROJECT_DIR/docker-compose.yml" --profile full up -d --force-recreate openclaw
