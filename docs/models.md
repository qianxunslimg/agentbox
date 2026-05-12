# 模型选择指南

根据硬件选择合适的模型。

## 按显存选择

### 24 GB 显存（RTX 3090 / 4090）

```bash
ollama pull qwen2.5-coder:32b     # 代码能力最强，~18 tok/s
ollama pull deepseek-r1:32b       # 推理能力强
ollama pull qwen3.5:35b           # 最新 MoE，实际激活 ~3B
```

推荐主力：`qwen2.5-coder:32b`（Q4_K_M 量化）

### 12-16 GB 显存（RTX 4070 / 4080）

```bash
ollama pull qwen2.5-coder:14b     # 代码首选
ollama pull deepseek-r1:14b       # 推理 + 工具调用
ollama pull phi-4:14b             # 微软出品
```

推荐主力：`qwen2.5-coder:14b`

### 8 GB 显存（RTX 3060 / 4060）

```bash
ollama pull qwen2.5-coder:7b      # 轻量代码
ollama pull deepseek-r1:8b        # 轻量推理
ollama pull llama3.2:3b           # 轻快通用
```

推荐主力：`qwen2.5-coder:7b`

### 无独显 / CPU 运行

```bash
ollama pull qwen2.5:1.5b          # 综合最好
ollama pull deepseek-r1:1.5b      # 推理能力
ollama pull gemma3:1b             # Google 高效小模型
```

推荐主力：`qwen2.5:1.5b`

## 按用途选择

| 用途 | 推荐模型 | 说明 |
|------|---------|------|
| 写代码 | qwen2.5-coder | 代码理解和生成能力最好 |
| 聊天 / 通用 | qwen3.5 或 llama3.3 | 综合能力强 |
| 复杂推理 | deepseek-r1 | 推理链，适合数学/逻辑 |
| Agent 工具调用 | deepseek-r1-tool-calling | 专门训练了 function calling |
| 嵌入 / RAG | nomic-embed-text | 文本向量化 |
| 轻量 / 边缘设备 | qwen2.5:1.5b | 资源极低 |

## 量化格式说明

| 格式 | 质量 | 大小 |
|------|------|------|
| Q8_0 | 几乎无损 | 最大 |
| Q6_K | 极佳 | 较大 |
| Q5_K_M | 很好 | 中等 |
| Q4_K_M | 良好（推荐） | 较小 |
| Q3_K_M | 可接受 | 最小可用 |

Ollama 默认拉取 Q4_K_M，在质量和速度间取得平衡。
