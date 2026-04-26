# MLX 本地翻译 API：搭建、封装、运维、迁移

项目路径：`/Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate`

这个项目的职责是：

- 在 Apple Silicon 本机加载 MLX 模型
- 启动一个本地 HTTP 服务
- 对外暴露 LibreTranslate-compatible API
- 让其他 bot 可以把它当作翻译后端直接调用

---

## 一、当前实现

### 入口文件

- `server.py`

### 当前默认环境变量

- `MLX_TRANSLATE_HOST=127.0.0.1`
- `MLX_TRANSLATE_PORT=5010`
- `MLX_TRANSLATE_MODEL=mlx-community/Qwen3.5-0.8B-4bit`
- `MLX_TRANSLATE_MAX_TOKENS=512`

### 当前接口

- `GET /health`
- `GET /languages`
- `POST /translate`

### 当前请求格式

```json
{
  "q": "Hello, how are you today?",
  "source": "en",
  "target": "zh"
}
```

### 当前响应格式

```json
{
  "translatedText": "你好，今天过得怎么样？",
  "detectedLanguage": {
    "language": "en"
  }
}
```

这就是为什么它可以直接伪装成 LibreTranslate 给上游 bot 使用。

---

## 二、如何搭建本地 LLM

### 1. 环境要求

建议：

- macOS
- Apple Silicon
- Python 3
- 可用的虚拟环境（venv）

### 2. 创建虚拟环境

```bash
cd /Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate
python3 -m venv .venv
source .venv/bin/activate
```

### 3. 安装依赖

本机当前可见依赖核心是：

- `mlx`
- `mlx-lm`
- `mlx-metal`
- `transformers`
- `sentencepiece`
- `huggingface_hub`

如果在新机器重装，建议至少执行：

```bash
pip install mlx mlx-lm mlx-metal transformers sentencepiece huggingface_hub
```

如果需要完全复刻，建议在旧机器先导出：

```bash
pip freeze > requirements.lock.txt
```

然后在新机器：

```bash
pip install -r requirements.lock.txt
```

### 4. 首次拉模型

当前默认模型：

- `mlx-community/Qwen3.5-0.8B-4bit`

首次启动时，MLX / HuggingFace 会自动下载模型。

---

## 三、如何包裹 API

当前 `server.py` 直接用 Python 标准库 `ThreadingHTTPServer` 提供 HTTP 服务。

它做的封装层有三件事：

1. 接收 HTTP 请求
2. 把翻译需求转成 Qwen 的 prompt
3. 把模型输出重新包装成 LibreTranslate-compatible JSON

也就是说，这里真正的“API 包裹层”就在 `server.py`。

### 当前翻译调用逻辑

- 收到 `q/source/target`
- 用 `TOKENIZER.apply_chat_template(...)` 构造 prompt
- 调 `generate(...)`
- 返回 `translatedText`

### 为什么这样设计

因为这样下游 bot 无需知道你底层模型是什么：

- 今天可以是 `mlx-community/Qwen3.5-0.8B-4bit`
- 明天可以换别的 MLX 模型
- 只要 `/translate` 接口不变，上层 bot 无需改代码

---

## 四、如何启动 / 停止

### 直接前台运行

```bash
cd /Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate
./run-server.sh
```

### 当前 run-server.sh 做的事

- 激活 `.venv`
- 设置 host / port / model
- `python server.py`

### 作为 macOS LaunchAgent 管理

当前机器已经按 LaunchAgent 方式安装：

- `~/Library/LaunchAgents/ai.openclaw.mlx-translate-api.plist`

### 重启服务

```bash
cd /Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate
./restart-service.sh
```

### 停止服务

```bash
cd /Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate
./stop-service.sh
```

---

## 五、如何验证是否正常

### 健康检查

```bash
curl -sS http://127.0.0.1:5010/health
```

预期类似：

```json
{"ok": true, "model": "mlx-community/Qwen3.5-0.8B-4bit"}
```

### 语言列表

```bash
curl -sS http://127.0.0.1:5010/languages
```

### 翻译测试

```bash
curl -sS -X POST http://127.0.0.1:5010/translate \
  -H 'Content-Type: application/json' \
  -d '{"q":"Hello, how are you today?","source":"en","target":"zh"}'
```

---

## 六、日志位置

- `server.stdout.log`
- `server.stderr.log`

完整路径：

- `/Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate/server.stdout.log`
- `/Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate/server.stderr.log`

---

## 七、迁移到别的设备

### 需要带走的内容

- 整个项目目录 `scripts/mlx-qwen35-translate`
- 如果想完全复刻环境，带走依赖锁文件（建议自己补一份 `requirements.lock.txt`）
- LaunchAgent plist（或者在新机器重新生成）

### 在新机器的推荐步骤

1. 拷贝项目目录
2. 创建 `.venv`
3. 安装依赖
4. 启动一次 `./run-server.sh`
5. 验证 `/health`
6. 再决定是否注册为 LaunchAgent

### 迁移时最常见问题

- 新机器没装 Python / venv
- 没有 Apple Silicon，MLX 不适配
- 模型首次下载失败
- 5010 端口被占用
- LaunchAgent 路径写死了旧用户目录

---

## 八、如果要换模型

只要保持 `/translate` 接口兼容，下游无需改。

通常只需要改：

- `MLX_TRANSLATE_MODEL`

例如放到 `run-server.sh` 或 LaunchAgent 环境里。

然后重启服务即可。

---

## 九、最小恢复手册

如果哪天服务坏了，最快恢复顺序：

1. `source .venv/bin/activate`
2. `python server.py`
3. `curl http://127.0.0.1:5010/health`
4. `curl /translate` 做一次手测
5. 正常后再重挂 LaunchAgent
