# Local Agent Platform

自托管 AI Agent 平台，全部用 Docker Compose 一键启动，支持本地模型（Ollama）。

## 快速开始（3 步）

```bash
# 1. 安装 Ollama + 拉模型
curl -fsSL https://ollama.com/install.sh | sh
bash scripts/pull-models.sh

# 2. 启动服务
bash scripts/start.sh up

# 3. 打开浏览器
#   Chat UI:  http://localhost:3000    （聊天、RAG 文档问答）
#   Agent:    http://localhost:8080    （无代码创建自主 Agent）
#   Team OS:  http://localhost:4082    （多 Agent 协作）
```

## 项目结构

```
agent/
├── docker/
│   ├── docker-compose.yml   # 主服务编排
│   └── .env.example
├── frameworks/              # Git submodules（源码参考）
│   ├── openclaw/            # 通用 AI 助手（371k stars）
│   ├── openclaw-cn/         # 中文社区版
│   ├── dulus/               # Python CLI Agent（类 Claude Code）
│   ├── aider/               # 终端 AI 结对编程
│   ├── localagi/            # 无代码 Agent 平台
│   ├── openagentd/          # 多 Agent 协作 OS
│   └── open-webui/          # 自托管聊天前端
├── configs/                 # 配置文件示例
├── scripts/                 # 管理脚本
├── docs/                    # 使用文档
└── archive/                 # 历史代码
```

## 服务说明

| 服务 | 地址 | 功能 |
|------|------|------|
| **Open WebUI** | http://localhost:3000 | 聊天前端、RAG 文档问答、Web 搜索、多模型切换 |
| **LocalAGI** | http://localhost:8080 | 无代码 Agent 构建器，创建自主执行任务的 Agent |
| **OpenAgentd** | http://localhost:4082 | 多 Agent 协作、持久记忆、任务调度 |

## 常用操作

```bash
bash scripts/start.sh up          # 启动全部服务
bash scripts/start.sh webui       # 只启动 Open WebUI
bash scripts/start.sh agent       # 启动 LocalAGI + OpenAgentd
bash scripts/start.sh down        # 停止全部
bash scripts/start.sh logs webui  # 查看日志（也支持 localagi/openagentd）
bash scripts/start.sh restart     # 重启

# 拉取更多模型
bash scripts/pull-models.sh       # 默认（7B）
bash scripts/pull-models.sh full  # 全量（32B，需 24G 显存）

# 终端编程（直接运行，不需要 Docker）
bash scripts/start-aider.sh
bash scripts/start-dulus.sh
```

## 框架选型指南

| 需求 | 推荐 | 说明 |
|------|------|------|
| 聊天 / RAG 问答 | Open WebUI | 类 ChatGPT 界面，支持文档上传 |
| 无代码 Agent | LocalAGI | Web UI 拖拽创建 Agent |
| 终端编程助手 | Aider / Dulus | Git 感知，多文件编辑 |
| 多平台消息 | OpenClaw | Telegram/微信/Discord 全支持 |
| 多 Agent 协作 | OpenAgentd | 持久记忆，Agent 间通信 |

## 模型推荐

参见 [docs/models.md](docs/models.md)
