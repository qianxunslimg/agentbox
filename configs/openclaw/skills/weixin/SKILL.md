---
name: weixin
description: 管理微信收件人、角色权限、昵称识别和微信消息投递。
---

当用户要求处理微信相关能力时使用这个 skill，包括：识别微信用户、管理收件人、判断 admin/user 权限、给微信发消息、创建微信定时推送、查看或取消微信相关定时任务。

## 收件人配置

- 读取 `/home/node/openclaw-config/weixin-recipients.json`。
- 只使用配置文件里的 `recipients[]`，不要在 skill、文档或提示词里硬编码真实微信账号、`accountId` 或 `@im.wechat`。
- 每个收件人应包含：`alias`、`role`、`channel`、`accountId`、`to`、`enabled`；可以包含 `label` 和 `aliases[]`。
- 如果请求来自 `openclaw-weixin`，优先使用和当前会话 `accountId + to` 匹配且 `enabled=true` 的收件人。
- 如果用户说“我/自己/当前微信”，使用当前会话匹配到的收件人；如果匹配不到，再使用配置里的 `default`。

## 收件人匹配

- 用户提到收件人时，不要只做 `alias` 精确匹配。
- 匹配顺序：
  1. 当前微信会话的 `accountId + to`
  2. `alias` 精确匹配
  3. `label` 精确或包含匹配
  4. `aliases[]` 精确或包含匹配
  5. 中文昵称的包含匹配，例如用户说“小张”，配置的 `label` 是“张三”且 `aliases[]` 里有“小张”时应视为匹配。
- 如果多个收件人都匹配，优先选择匹配文本更长、更具体的项；仍不确定时再询问用户。
- 找不到匹配时，先列出可用收件人的 `alias`、`label`、`aliases[]`，不要直接说无法识别。

## 角色规则

- `admin`：管理员。可以查看、创建、修改、取消所有定时任务；可以给任意已配置收件人推送；可以管理收件人配置；可以使用 elevated 工具。
- `user`：普通用户。只能管理和自己相关的提醒；默认只能发给自己；不能修改 admin 配置，不能获得 elevated 权限。
- 判断权限时看配置里的 `role`，不要根据别名名称猜测权限。

## 微信消息投递

- 普通私信内容只要不是违法、威胁、骚扰或明显高风险，不要说教、不要反复确认、不要把“催一下睡觉/问候/测试消息”当成需要拒绝的内容。
- admin 已经有权限给任意已配置收件人发消息。目标可以从上下文或收件人配置明确推断时，直接执行；只有目标真的不明确时才问一句。
- 给微信发消息时，必须显式指定目标：
  - `channel: "openclaw-weixin"`
  - `accountId: <recipient.accountId>`
  - `target: <recipient.to>`
  - `message: <message text>`
- `openclaw-weixin` 依赖目标用户在对应 `accountId` 下的 context token。不要用“发起人的 accountId”给另一个收件人发；应使用收件人配置里的 `accountId`。
- 发送前尽量检查 `/home/node/.openclaw/openclaw-weixin/accounts/<recipient.accountId>.context-tokens.json` 是否包含 `<recipient.to>`。
- 如果缺少 context token，不能承诺“已发送成功”。应告诉用户：目标微信号需要先给这个 bot 发一条消息，建立上下文后才能稳定主动推送。
- 判断是否真正发到微信，不要只看 cron run 里的 `deliveryStatus: delivered`。还要检查日志是否有 `outbound: text sent OK to=<recipient.to>`，并且没有 `contextToken missing for to=<recipient.to>`。
- 不要把微信消息投递到 `agent:main:main`。这可能只在本地会话成功，不会发到微信。
- 不要用 `nodes.invoke` 调 `openclaw-weixin send`；这个命令不存在，而且常见报错是 `unknown node`。
- 不要用 `sessions_send` 给另一个会话发“请你发送给某某”。`sessions_send` 是会话协作工具，不是微信投递工具；报错 `Session send visibility is restricted to the current session tree` 就说明工具用错了。
- 当前部署使用 embedded runner，`message` 工具在这个 runner 下不可用；立即发送微信消息时必须用 `exec` 执行 OpenClaw CLI，并明确传 `--account`：

```bash
openclaw message send --channel openclaw-weixin --account '<recipient.accountId>' --target '<recipient.to>' --message '<message text>' --json
```

- 如果 `exec` 工具有 `security` 参数，发送微信消息这种 admin 操作使用 `security: "full"`；不要用会被 allowlist 拦截的 `security: "allowlist"`。
- 发送成功必须看到 CLI 返回 JSON 里有 `payload.result.messageId` 或 `messageId`，否则不能说“已发送”。

## 微信定时任务

- 用户使用中文自然语言说的时间，默认都是北京时间，也就是 `Asia/Shanghai` / UTC+8。
- 创建 cron 时，偏移时间用 `1m`、`20m`、`2h`；明确日期时间必须带 `--tz Asia/Shanghai`，或者转换成带时区的 ISO 时间。不要把北京时间误当成 UTC。
- 所有明确时间点、倒计时、周期性的定时任务都必须使用 OpenClaw `cron` 创建。
- 不要用子 agent 挂起、睡眠、循环检查、轮询当前时间的方式等待触发；这种方式浪费 token，默认禁止。
- 只有当用户明确要求“持续观察上下文并随时判断”、或者任务无法表达为 cron 时间/周期时，才可以考虑子 agent 或 heartbeat，并且要先说明原因。
- 只要用户期望微信收到定时消息，就必须显式带投递参数：
  - `--announce`
  - `--channel openclaw-weixin`
  - `--account <recipient.accountId>`
  - `--to <recipient.to>`
- 不要用本地-only 的 `--system-event` 来创建用户期望收到的微信提醒。
- 当前 OpenClaw 版本里，相对时间写 `1m`、`20m`、`2h`；不要写 `+1m`。

## 定时推送命令模板

```bash
openclaw cron add \
  --announce \
  --channel openclaw-weixin \
  --account '<recipient.accountId>' \
  --to '<recipient.to>' \
  --name '<stable-job-name>' \
  --at '<ISO time or duration like 20m>' \
  --tz Asia/Shanghai \
  --message '<instruction that produces the exact reminder text>' \
  --delete-after-run \
  --expect-final
```

## 排查微信投递失败

- 如果 UI 里运行结果是“成功”，但显示“未请求”或 `deliveryStatus: not-requested`，意思是这个任务没有请求任何渠道投递，所以微信不会收到。
- 如果 UI/cron run 显示 `deliveryStatus: delivered`，但微信没收到，继续查日志：
  - 有 `contextToken missing for to=...`：说明使用了错误 accountId，或目标用户还没和对应 bot 建立上下文。
  - 没有 `outbound: text sent OK to=...`：说明并没有真正走到微信发送成功路径。
  - 有 `outbound: text sent OK to=...` 但仍没收到：让目标微信号主动发一条消息刷新上下文，再重试。
- 检查 `/home/node/.openclaw/cron/runs/*.jsonl` 和 `/home/node/.openclaw/cron/jobs.json.bak`。
- 正确的微信定时推送任务必须包含明确的 channel delivery 信息，或者用上面的 `--announce --channel --account --to` 创建。
