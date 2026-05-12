# Ollama 使用说明

Ollama 已容器化，通过 Docker Compose 管理。

## 启动

```bash
docker compose -f docker/docker-compose.yml up -d ollama
```

已集成在 `bash scripts/start.sh up` 中，无需单独启动。

## 模型管理

```bash
# 查看已安装模型
docker exec agent-ollama ollama list

# 拉取新模型
docker exec agent-ollama ollama pull <模型名>

# 删除模型
docker exec agent-ollama ollama rm <模型名>

# 一键拉取推荐模型
bash scripts/pull-models.sh          # 默认（7B）
bash scripts/pull-models.sh full     # 全量（32B，需 24G 显存）
```

## 命令行对话

### 交互式对话

```bash
docker exec -it agent-ollama ollama run qwen2.5-coder:7b
```

进入对话后直接输入，`/bye` 退出，`/help` 查看帮助。

### 单次问答

```bash
docker exec agent-ollama ollama run qwen2.5-coder:7b "用Python写一个快速排序"
```

## API 调用

Ollama 容器端口映射到宿主机 `127.0.0.1:11434`，可直接调用。

### generate（补全）

```bash
curl -s http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:7b",
  "prompt": "解释一下什么是递归",
  "stream": false
}' | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

### chat（对话）

```bash
curl -s http://localhost:11434/api/chat -d '{
  "model": "qwen2.5-coder:7b",
  "messages": [
    {"role": "user", "content": "你好，你是谁？"}
  ],
  "stream": false
}' | python3 -c "import sys,json; print(json.load(sys.stdin)['message']['content'])"
```

### OpenAI 兼容接口

```bash
curl -s http://localhost:11434/v1/chat/completions -d '{
  "model": "qwen2.5-coder:7b",
  "messages": [
    {"role": "user", "content": "你好"}
  ]
}' | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])"
```

## 通过各服务使用

| 服务 | 用法 |
|------|------|
| Open WebUI | 浏览器打开 http://localhost:3000，选择模型即可对话 |
| Aider（结对编程） | `bash scripts/start-aider.sh /your/project` |
| Dulus（CLI Agent） | `bash scripts/start-dulus.sh /your/project` |
| OpenAgentd（多Agent） | 浏览器打开 http://localhost:4082 |

所有服务都在同一个 Docker 网络内，通过 `http://ollama:11434` 访问模型，无需额外配置。

## 模型推荐

| 显存 | 推荐模型 |
|------|---------|
| 24 GB（4090） | `qwen2.5-coder:32b` |
| 12-16 GB | `qwen2.5-coder:14b` |
| 8 GB | `qwen2.5-coder:7b` |
| 4 GB / CPU | `qwen2.5-coder:3b` |

详见 [docs/models.md](models.md)
