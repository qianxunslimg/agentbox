#!/usr/bin/env sh
# 用途：OpenClaw 容器启动前的自举脚本。
# 负责确保微信、记忆、工作流、抖音、邮箱等插件已安装，并在插件安装后启动 Gateway。
# 这个脚本由 docker-compose 自动调用，通常不需要手动运行。
set -eu

CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-/home/node/.openclaw/openclaw.json}"
CONFIG_DIR="$(dirname "$CONFIG_PATH")"
STATE_DIR="${OPENCLAW_STATE_DIR:-$CONFIG_DIR}"
BOOTSTRAP_CONFIG_BACKUP=""

sync_configured_skills() {
  if [ -d "$CONFIG_DIR/skills" ]; then
    echo "[openclaw-bootstrap] syncing configured workspace skills"
    mkdir -p "$STATE_DIR/workspace/skills"
    cp -R "$CONFIG_DIR/skills/." "$STATE_DIR/workspace/skills/"
  fi
}

prepare_config_for_plugin_install() {
  BOOTSTRAP_CONFIG_BACKUP="$CONFIG_PATH.bootstrap-slots.bak"
  node - "$CONFIG_PATH" "$BOOTSTRAP_CONFIG_BACKUP" <<'NODE'
const fs = require("node:fs");
const configPath = process.argv[2];
const backupPath = process.argv[3];
try {
  const raw = fs.readFileSync(configPath, "utf8");
  const cfg = JSON.parse(raw);
  if (!cfg.plugins?.slots?.memory) {
    process.exit(0);
  }
  fs.writeFileSync(backupPath, raw);
  delete cfg.plugins.slots.memory;
  if (Object.keys(cfg.plugins.slots).length === 0) {
    delete cfg.plugins.slots;
  }
  fs.writeFileSync(configPath, `${JSON.stringify(cfg, null, 2)}\n`);
} catch {
  process.exit(0);
}
NODE
}

restore_config_after_plugin_install() {
  if [ -n "$BOOTSTRAP_CONFIG_BACKUP" ] && [ -f "$BOOTSTRAP_CONFIG_BACKUP" ]; then
    mv "$BOOTSTRAP_CONFIG_BACKUP" "$CONFIG_PATH"
  fi
}

trap restore_config_after_plugin_install EXIT

sync_configured_skills

package_version() {
  node - "$1" <<'NODE'
const fs = require("node:fs");
const pkgPath = process.argv[2];
try {
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  process.stdout.write(pkg.version || "");
} catch {
  process.stdout.write("");
}
NODE
}

record_install_path() {
  node - "$STATE_DIR/plugins/installs.json" "$1" <<'NODE'
const fs = require("node:fs");
const recordsPath = process.argv[2];
const pluginId = process.argv[3];
try {
  const records = JSON.parse(fs.readFileSync(recordsPath, "utf8"));
  process.stdout.write(records.installRecords?.[pluginId]?.installPath || "");
} catch {
  process.stdout.write("");
}
NODE
}

ensure_npm_plugin() {
  spec="$1"
  pkg_path="$2"
  expected_version="$3"
  plugin_id="$4"

  installed_version="$(package_version "$pkg_path")"
  recorded_path="$(record_install_path "$plugin_id")"
  expected_path="$(dirname "$pkg_path")"
  if [ "$installed_version" = "$expected_version" ] && [ "$recorded_path" = "$expected_path" ]; then
    echo "[openclaw-bootstrap] $spec already installed"
  else
    echo "[openclaw-bootstrap] installing $spec"
    node /app/openclaw.mjs plugins install "$spec" --force --pin
  fi
}

ensure_extension_plugin() {
  spec="$1"
  pkg_path="$2"
  expected_version="$3"
  plugin_id="$4"

  installed_version="$(package_version "$pkg_path")"
  recorded_path="$(record_install_path "$plugin_id")"
  expected_path="$(dirname "$pkg_path")"
  if [ "$installed_version" = "$expected_version" ] && [ "$recorded_path" = "$expected_path" ]; then
    echo "[openclaw-bootstrap] $spec already installed"
  else
    echo "[openclaw-bootstrap] installing $spec"
    node /app/openclaw.mjs plugins install "$spec" --force --pin
  fi
}

patch_weixin_context_token_restore() {
  # 用途：修补 openclaw-weixin 2.4.3 的 CLI 主动发信链路。
  # 现象：embedded Agent 只能通过 `openclaw message send` 发微信，但 CLI 临时进程不会恢复磁盘里的 context token，
  #      会出现 `contextToken missing`，导致主动推送不稳定。
  # 处理：让插件的 getContextToken 在内存未命中时，从 accounts/*.context-tokens.json 懒加载一次。
  node - "$STATE_DIR/npm/node_modules/@tencent-weixin/openclaw-weixin" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const root = process.argv[2];
const marker = "agent-patch: lazy-load persisted context token for CLI sends";

function patchFile(relPath, oldText, newText) {
  const filePath = path.join(root, relPath);
  if (!fs.existsSync(filePath)) return;
  const raw = fs.readFileSync(filePath, "utf8");
  if (raw.includes(marker)) {
    console.log(`[openclaw-bootstrap] ${relPath} already patched`);
    return;
  }
  if (!raw.includes(oldText)) {
    console.warn(`[openclaw-bootstrap] ${relPath} patch skipped: expected context not found`);
    return;
  }
  fs.writeFileSync(filePath, raw.replace(oldText, newText));
  console.log(`[openclaw-bootstrap] patched ${relPath}`);
}

patchFile(
  "dist/src/messaging/inbound.js",
`/** Retrieve the cached context token for a given account+user pair. */
export function getContextToken(accountId, userId) {
    const k = contextTokenKey(accountId, userId);
    const val = contextTokenStore.get(k);
    logger.debug(\`getContextToken: key=\${k} found=\${val !== undefined} storeSize=\${contextTokenStore.size}\`);
    return val;
}`,
`/** Retrieve the cached context token for a given account+user pair. */
export function getContextToken(accountId, userId) {
    const k = contextTokenKey(accountId, userId);
    let val = contextTokenStore.get(k);
    if (val === undefined) {
        // ${marker}.
        try {
            const filePath = resolveContextTokenFilePath(accountId);
            if (fs.existsSync(filePath)) {
                const tokens = JSON.parse(fs.readFileSync(filePath, "utf-8"));
                const token = tokens?.[userId];
                if (typeof token === "string" && token) {
                    contextTokenStore.set(k, token);
                    val = token;
                }
            }
        }
        catch (err) {
            logger.warn(\`getContextToken: failed to lazy-load persisted token for account=\${accountId}: \${String(err)}\`);
        }
    }
    logger.debug(\`getContextToken: key=\${k} found=\${val !== undefined} storeSize=\${contextTokenStore.size}\`);
    return val;
}`
);

patchFile(
  "src/messaging/inbound.ts",
`/** Retrieve the cached context token for a given account+user pair. */
export function getContextToken(accountId: string, userId: string): string | undefined {
  const k = contextTokenKey(accountId, userId);
  const val = contextTokenStore.get(k);
  logger.debug(
    \`getContextToken: key=\${k} found=\${val !== undefined} storeSize=\${contextTokenStore.size}\`,
  );
  return val;
}`,
`/** Retrieve the cached context token for a given account+user pair. */
export function getContextToken(accountId: string, userId: string): string | undefined {
  const k = contextTokenKey(accountId, userId);
  let val = contextTokenStore.get(k);
  if (val === undefined) {
    // ${marker}.
    try {
      const filePath = resolveContextTokenFilePath(accountId);
      if (fs.existsSync(filePath)) {
        const tokens = JSON.parse(fs.readFileSync(filePath, "utf-8")) as Record<string, string>;
        const token = tokens?.[userId];
        if (typeof token === "string" && token) {
          contextTokenStore.set(k, token);
          val = token;
        }
      }
    } catch (err) {
      logger.warn(\`getContextToken: failed to lazy-load persisted token for account=\${accountId}: \${String(err)}\`);
    }
  }
  logger.debug(
    \`getContextToken: key=\${k} found=\${val !== undefined} storeSize=\${contextTokenStore.size}\`,
  );
  return val;
}`
);
NODE
}

prepare_config_for_plugin_install

ensure_npm_plugin \
  "${OPENCLAW_WEIXIN_PLUGIN_SPEC:-@tencent-weixin/openclaw-weixin@2.4.3}" \
  "$STATE_DIR/npm/node_modules/@tencent-weixin/openclaw-weixin/package.json" \
  "${OPENCLAW_WEIXIN_PLUGIN_VERSION:-2.4.3}" \
  "openclaw-weixin"

patch_weixin_context_token_restore

ensure_npm_plugin \
  "${OPENCLAW_MEMORY_LANCEDB_PLUGIN_SPEC:-@openclaw/memory-lancedb@2026.5.7}" \
  "$STATE_DIR/npm/node_modules/@openclaw/memory-lancedb/package.json" \
  "${OPENCLAW_MEMORY_LANCEDB_PLUGIN_VERSION:-2026.5.7}" \
  "memory-lancedb"

ensure_npm_plugin \
  "${OPENCLAW_LOBSTER_PLUGIN_SPEC:-@openclaw/lobster@2026.5.7}" \
  "$STATE_DIR/npm/node_modules/@openclaw/lobster/package.json" \
  "${OPENCLAW_LOBSTER_PLUGIN_VERSION:-2026.5.7}" \
  "lobster"

ensure_extension_plugin \
  "${OPENCLAW_DOUYIN_INSIGHTS_PLUGIN_SPEC:-clawhub:douyin-insights-openclaw-plugin}" \
  "$STATE_DIR/extensions/douyin-insights-openclaw-plugin/package.json" \
  "${OPENCLAW_DOUYIN_INSIGHTS_PLUGIN_VERSION:-0.1.5}" \
  "douyin-insights-openclaw-plugin"

ensure_extension_plugin \
  "${OPENCLAW_EMAIL_PLUGIN_SPEC:-clawhub:email}" \
  "$STATE_DIR/extensions/email/package.json" \
  "${OPENCLAW_EMAIL_PLUGIN_VERSION:-0.1.0}" \
  "email"

restore_config_after_plugin_install
trap - EXIT
