# OpenClaw 使用说明

OpenClaw 用来把 AI 助手接到聊天渠道里。本项目当前固定使用：

- OpenClaw: `ghcr.io/openclaw/openclaw:2026.5.7`
- 微信插件: `@tencent-weixin/openclaw-weixin@2.4.3`
- 默认模型: `proxy/gpt-5.4-mini`
- 本地搜索: SearXNG
- 长期记忆: `@openclaw/memory-lancedb@2026.5.7`
- 工作流: `@openclaw/lobster@2026.5.7`
- 抖音研究: `douyin-insights-openclaw-plugin@0.1.5`
- 邮箱: `email@0.1.0`

启动时会自动执行 `scripts/openclaw-bootstrap.sh`，如果插件不存在，会安装到 `runtime/volumes/openclaw/npm/` 或 `runtime/volumes/openclaw/extensions/`。这些目录是运行期缓存，已被 `.gitignore` 忽略；换机器后启动会自动重建。

项目级 skill 放在 `configs/openclaw/skills/`，启动时会同步到 `runtime/volumes/openclaw/workspace/skills/`。例如 `weixin` 负责微信收件人、角色权限、昵称识别和微信投递规则，这类规则属于可迁移配置，不应该只写在运行时记忆里。

## 1. 配置密钥

复制示例文件：

```bash
cp configs/openclaw/.env.example configs/openclaw/.env
cp configs/openclaw/openclaw.json.example configs/openclaw/openclaw.json
```

编辑 `configs/openclaw/.env`：

```env
OPENCLAW_GATEWAY_TOKEN=换成你自己的控制台令牌
OPENCLAW_CONFIG_PATH=/home/node/openclaw-config/openclaw.json
OPENCLAW_STATE_DIR=/home/node/.openclaw
DEEPSEEK_API_KEY=你的 DeepSeek API Key
OPENAI_API_KEY=你的 OpenAI 兼容中转站 Key
SOCIAL_MEDIA_MCP_API_KEY=可选，抖音研究插件需要
QQ_EMAIL_ADDRESS=你的QQ邮箱，例如 123456@qq.com
QQ_EMAIL_AUTH_CODE=QQ邮箱授权码，不是QQ密码
```

不要把真实 `.env` 提交到 Git。

## 2. 目录边界

本项目把 OpenClaw 相关文件分成两类：

- `configs/openclaw/`: 可迁移配置，包括 `.env`、`openclaw.json`、`searxng/settings.yml`
- `runtime/volumes/openclaw/`: 运行时状态，包括微信登录态、会话、记忆库、插件安装缓存、日志

换机器时优先迁移 `configs/openclaw/` 和必要的 `runtime/volumes/openclaw/` 状态目录；插件缓存可以不迁移，启动时会自动安装。

## 3. 启动

```bash
bash scripts/start-openclaw.sh
```

或直接：

```bash
docker compose --profile full up -d openclaw
```

如果要同时启动搜索和长期记忆依赖，建议使用脚本。脚本会确保 `ollama`、`searxng` 和 `openclaw` 都启动，并把现有 `agent-ollama` 接入 OpenClaw 的 Docker 网络：

```bash
bash scripts/start-openclaw.sh
```

检查状态：

```bash
docker ps --filter name=agent-openclaw
docker exec agent-openclaw node /app/openclaw.mjs --version
docker exec agent-openclaw node /app/openclaw.mjs channels status --deep
```

## 4. 打开控制台

浏览器打开：

```text
http://127.0.0.1:18789/
```

连接信息：

- WebSocket URL: `ws://127.0.0.1:18789`
- 网关令牌: `configs/openclaw/.env` 里的 `OPENCLAW_GATEWAY_TOKEN`
- 密码: 留空，除非你自己额外配置了密码认证

如果出现“协议不匹配”，通常是浏览器缓存了旧版 Control UI。用无痕窗口打开，或清理 `127.0.0.1:18789` 的站点数据后再进。

## 5. 登录个人微信

首次接微信需要扫码：

```bash
docker exec -it agent-openclaw sh -lc 'node /app/openclaw.mjs channels login --channel openclaw-weixin'
```

终端里会出现二维码，使用微信小号扫码。成功后会保存登录态到：

```text
runtime/volumes/openclaw/openclaw-weixin/accounts/
```

登录后重启 OpenClaw：

```bash
docker compose --profile full restart openclaw
```

然后从微信小号给机器人发消息测试。

本项目已设置：

```json
{
  "session": {
    "dmScope": "per-account-channel-peer"
  }
}
```

这个配置很重要：多个微信号同时登录时，OpenClaw 会按“账号 + 渠道 + 对端用户”隔离私聊会话，避免大号/小号共用 `agent:main:main` 导致身份判断串号。

### 给自己的微信大号放开权限

本项目默认把微信私聊走 pairing allowlist。注意：`openclaw-weixin` 连接的是微信 iLink bot 通道，不是普通个人微信号的聊天同步。也就是说，另一个微信号给你登录时使用的个人微信号发普通私聊，OpenClaw 不会收到。

你要用自己的大号测试时，有两种方式：

1. 最简单：直接用大号重新扫码登录 `openclaw-weixin`，让大号成为当前 bot 的授权用户。
2. 如果你有一个可被大号打开的 bot 会话入口，则用大号给这个 bot 发一条消息，不是给普通微信小号发消息。
3. 然后在项目根目录运行：

```bash
bash scripts/openclaw-approve-weixin-user.sh latest
```

脚本会从 OpenClaw 最近收到的微信消息里找外部 sender id，并过滤掉当前登录/扫码账号自己。你也可以先查看它当前能看到哪些 ID：

```bash
bash scripts/openclaw-approve-weixin-user.sh list
```

如果 `latest` 提示只看到 logged-in/scanner user，说明大号那条消息还没有进入 OpenClaw；重新用大号发一条新消息后再跑一次。

成功后脚本会把最近的外部 `xxx@im.wechat` 写进：

```text
runtime/volumes/openclaw/credentials/openclaw-weixin-<account>-allowFrom.json
```

同时同步到 `commands.ownerAllowFrom` 和 `tools.elevated.allowFrom.openclaw-weixin`，让这个微信号拥有 owner 级命令和 elevated 工具权限。

如果你已经知道微信 sender id，也可以显式传入：

```bash
bash scripts/openclaw-approve-weixin-user.sh 'xxx@im.wechat'
```

### 微信收件人配置

为了避免每次都手写 `xxx@im.wechat`，项目提供了一个本地收件人配置：

```text
configs/openclaw/weixin-recipients.json
```

真实文件已被 `.gitignore` 忽略；可提交的是示例文件：

```text
configs/openclaw/weixin-recipients.json.example
```

当前结构类似：

```json
{
  "default": "owner",
  "recipients": [
    {
      "alias": "owner",
      "label": "当前扫码微信",
      "channel": "openclaw-weixin",
      "accountId": "replace-with-openclaw-weixin-account-id",
      "to": "replace-with-user-id@im.wechat",
      "role": "admin",
      "aliases": ["我", "主号"],
      "enabled": true
    }
  ]
}
```

查看收件人：

```bash
bash scripts/openclaw-weixin-recipient.sh list
bash scripts/openclaw-weixin-recipient.sh get owner
```

新增一个别名：

```bash
bash scripts/openclaw-weixin-recipient.sh add main 'xxx@im.wechat' 'replace-with-account-id' '我的大号' admin
```

`alias` 是程序用的稳定短名，`label` 是人看的名字，`aliases` 是可选昵称列表。Agent 匹配收件人时会按当前微信会话、`alias`、`label`、`aliases[]` 以及中文包含关系来识别，例如配置 `label: "张三"` 或 `aliases: ["小张"]` 后，说“发给小张”也应该能匹配到张三。

设置默认收件人或删除别名：

```bash
bash scripts/openclaw-weixin-recipient.sh default main
bash scripts/openclaw-weixin-recipient.sh remove main
```

注意：这里的 `to` 必须是已经和 `openclaw-weixin` iLink bot 建立过上下文的微信用户。普通个人微信号之间发私聊不会自动出现在这里。

### 通过 Agent 管理微信推送

日常不需要手敲脚本。管理员可以直接在 OpenClaw 对话里说：

```text
列出当前微信收件人。
```

```text
把 main 设置为默认微信收件人。
```

```text
每天早上 9 点给 main 发一条今日提醒。
```

```text
一分钟后给 owner 发一条测试提醒，内容是“微信定时推送测试成功”。
```

Agent 执行这类任务时应读取：

```text
configs/openclaw/weixin-recipients.json
```

然后把别名解析为：

```text
channel=openclaw-weixin
accountId=<收件人的 accountId>
to=<收件人的 to>
role=<收件人的 role>
```

关键点：微信定时推送必须显式带 `--announce --channel --account --to`。如果只创建 `--system-event` 或只投递到 `agent:main:main`，任务历史里可能显示“成功”，但投递状态会是“未请求”，微信不会收到消息。

定时任务原则：明确时间点、倒计时、周期性任务一律走 OpenClaw `cron`。不要用子 agent 挂着轮询/睡眠等时间，除非用户明确要求持续观察上下文，或者这个任务没法表达成 cron。

时间原则：用户用中文说的时间默认是北京时间，也就是 `Asia/Shanghai` / UTC+8。OpenClaw 日志常用 UTC，排查时要先换算。创建明确日期时间的 cron 时加 `--tz Asia/Shanghai`，或者使用带 `+08:00` 的 ISO 时间。

底层命令参考：

```bash
docker exec agent-openclaw node /app/openclaw.mjs cron add \
  --announce \
  --channel openclaw-weixin \
  --account '<recipient.accountId>' \
  --to '<recipient.to>' \
  --name wx-test \
  --at 1m \
  --tz Asia/Shanghai \
  --message "一分钟测试提醒：如果你收到这条，说明微信定时推送通了。" \
  --delete-after-run \
  --expect-final
```

`scripts/openclaw-weixin-recipient.sh` 只作为兜底管理工具，正常使用入口是 Agent 对话。

## 6. 换机器迁移

必须迁移：

- `configs/openclaw/.env`
- `configs/openclaw/openclaw.json`
- `configs/openclaw/weixin-recipients.json`
- `runtime/volumes/openclaw/openclaw-weixin/accounts/`

可不迁移：

- `runtime/volumes/openclaw/npm/`
- `runtime/volumes/openclaw/extensions/`

这些是自动安装的插件缓存，换机器启动时会自动重建。

## 7. 插件与工具

### 搜索

本项目使用本地 SearXNG，配置位于：

```text
configs/openclaw/searxng/settings.yml
configs/openclaw/openclaw.json
```

验证：

```bash
curl 'http://127.0.0.1:8888/search?q=OpenClaw&format=json'
```

### 长期记忆

`memory-lancedb` 使用 Ollama 的 `nomic-embed-text` embedding 模型：

```bash
docker exec agent-openclaw node /app/openclaw.mjs ltm stats
docker exec agent-openclaw node /app/openclaw.mjs ltm search "你的关键词"
```

当前配置默认 `autoRecall: true`、`autoCapture: false`。也就是说它会主动召回记忆，但不会自动把每次回答都写入记忆库，避免乱记。

### Lobster 工作流

`@openclaw/lobster` 已启用，用于更结构化的多步骤任务。可在 Control UI 里让 Claw 执行“收集资料 -> 写文档 -> 发送微信”这类流水线。

### 抖音研究

`douyin-insights-openclaw-plugin` 已安装并启用，但它需要外部 hosted MCP 服务的 API key：

```env
SOCIAL_MEDIA_MCP_API_KEY=...
```

没填 key 时插件会加载，但调用抖音工具会鉴权失败。插件是社区插件，不是 OpenClaw 官方插件；只做公开视频/评论/创作者资料读取，不提供登录、发帖、点赞、评论。

### 邮箱

`email` 社区插件已启用，当前按 QQ 邮箱配置：

```text
IMAP: imap.qq.com:993 TLS
SMTP: smtp.qq.com:465 TLS
```

先在 QQ 邮箱网页版开启 `IMAP/SMTP`，生成授权码，然后填到：

```env
QQ_EMAIL_ADDRESS=123456@qq.com
QQ_EMAIL_AUTH_CODE=你的QQ邮箱授权码
```

可用工具包括：

```text
email_mailboxes_list
email_messages_search
email_message_get
email_send
email_reply
```

发送邮件默认需要 `confirm=true`，避免 Agent 未经确认乱发真实邮件。

### 定时邮件测试

先把 `configs/openclaw/.env` 里的 QQ 邮箱信息填好并重启：

```bash
docker compose --profile full up -d --force-recreate openclaw
```

然后可以创建一个一分钟后的测试任务：

```bash
docker exec agent-openclaw node /app/openclaw.mjs cron add \
  --name "email-self-test" \
  --at "1m" \
  --tz Asia/Shanghai \
  --delete-after-run \
  --timeout-seconds 120 \
  --message "用 email_send 给你的 QQ 邮箱发一封测试邮件，收件人就是发件邮箱自己，主题是 OpenClaw 定时邮件测试，正文写当前时间和一句测试成功。调用 email_send 时设置 confirm=true。" \
  --expect-final
```

也可以直接在微信里说：

```text
一分钟后给我的 QQ 邮箱发一封测试邮件，主题 OpenClaw 定时邮件测试，正文写当前时间，发送时 confirm=true。
```

查看和删除定时任务：

```bash
docker exec agent-openclaw node /app/openclaw.mjs cron list
docker exec agent-openclaw node /app/openclaw.mjs cron rm email-self-test
```

## 8. 常见问题

### 控制台协议不匹配

现象：页面提示“协议不匹配”。

原因：浏览器缓存的 Control UI 版本和正在运行的 Gateway 版本不同。

处理：

```text
Chrome 设置 -> 隐私和安全 -> 第三方 Cookie -> 查看所有网站数据和权限
搜索 127.0.0.1，删除 127.0.0.1:18789 相关数据
```

或者直接用无痕窗口打开。

### 微信能收到但不回复

先看状态：

```bash
docker exec agent-openclaw node /app/openclaw.mjs channels status --deep
docker logs --tail 200 agent-openclaw
```

重点看：

- `openclaw-weixin` 是否 `running`
- 是否有 `fetch failed`
- DeepSeek 是否报鉴权错误

### 重新扫码

如果微信登录态失效：

```bash
docker exec -it agent-openclaw sh -lc 'node /app/openclaw.mjs channels login --channel openclaw-weixin'
docker compose --profile full restart openclaw
```

### 查看插件版本

```bash
docker exec agent-openclaw sh -lc 'node -e "console.log(JSON.parse(require(\"fs\").readFileSync(\"/home/node/openclaw-config/npm/node_modules/@tencent-weixin/openclaw-weixin/package.json\", \"utf8\")).version)"'
```

正常应为：

```text
2.4.3
```

## 9. 重要说明

个人微信接入有平台风控风险，建议只使用小号。不要把主力微信号接到自动化机器人上。
