# 快速上手

所有服务都在 Docker 里跑，不需要在宿主机装任何东西（除了 Docker）。

## 1. 启动全部服务

```bash
bash scripts/start.sh up
```

首次启动会自动 pull 镜像、build Aider/Dulus/OpenAgentd。

## 2. 拉取模型

```bash
bash scripts/pull-models.sh
```

模型数据存在项目内的 `runtime/volumes/ollama/`，不依赖宿主机路径。

## 3. 浏览器打开

| 地址 | 功能 |
|------|------|
| http://localhost:3000 | Open WebUI — 聊天、RAG 文档问答 |
| http://localhost:8080 | LocalAGI — 无代码 Agent 构建器 |
| http://localhost:4082 | OpenAgentd — 多 Agent 协作 OS |
| http://localhost:18789 | OpenClaw — 聊天渠道网关、微信接入 |

## 命令行对话

```bash
# 交互式对话
docker exec -it agent-ollama ollama run qwen2.5-coder:7b

# 单次问答
docker exec agent-ollama ollama run qwen2.5-coder:7b "用Python写快速排序"
```

详见 [docs/ollama-usage.md](ollama-usage.md)

## Agent / 编程助手

```bash
# Aider — AI 结对编程（Docker 内运行）
bash scripts/start-aider.sh /path/to/your/project

# Dulus — CLI Agent，类 Claude Code
bash scripts/start-dulus.sh /path/to/your/project
```

两个都是 `docker compose run` 启动，挂载工作目录，`Ctrl+C` 退出不留容器。

## OpenClaw / 微信

```bash
# 只启动 OpenClaw
bash scripts/start-openclaw.sh

# 微信扫码登录
docker exec -it agent-openclaw sh -lc 'node /app/openclaw.mjs channels login --channel openclaw-weixin'
```

详见 [docs/openclaw.md](openclaw.md)。

## 服务管理

```bash
bash scripts/start.sh up          # 启动全部（ollama + webui + agent）
bash scripts/start.sh webui       # 只启动 Open WebUI
bash scripts/start.sh agent       # 启动 LocalAGI + OpenAgentd
bash scripts/start.sh down        # 停止全部
bash scripts/start.sh logs webui  # 查看日志（也支持 localagi/openagentd）
bash scripts/start.sh restart     # 重启
```

## 添加新模型

```bash
docker exec agent-ollama ollama pull deepseek-r1:14b
docker exec agent-ollama ollama pull qwen2.5:7b

# 或一键拉取
bash scripts/pull-models.sh full
```

Open WebUI 刷新页面即可看到新模型。

## 更新框架

```bash
bash scripts/update-submodules.sh
```
