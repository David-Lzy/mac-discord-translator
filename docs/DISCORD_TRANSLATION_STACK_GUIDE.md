# Discord 翻译项目总览

这套项目目前由 3 个组件组成：

1. **本地 LLM 翻译 API**
   - 路径：`scripts/mlx-qwen35-translate`
   - 作用：在本机启动一个 LibreTranslate-compatible HTTP API
   - 当前默认地址：`http://127.0.0.1:5010`

2. **Reaction 翻译 Bot（上游 .NET 项目）**
   - 路径：`scripts/DiscordTranslationBot-upstream`
   - 作用：监听 Discord reaction（例如 🇨🇳），调用本地翻译 API 返回结果

3. **频道镜像翻译 Bot（Node.js）**
   - 路径：`scripts/discord-mirror-bot`
   - 作用：把 EN / ZH 两个频道配成一对，一边发言，另一边自动出翻译

---

## 零点五、一键部署入口

当前仓库已经补上了 macOS 本地部署脚手架：

- `bin/install.sh`
- `bin/setup-wizard.sh`
- `bin/deploy.sh`
- `bin/status.sh`
- `docs/ONE_CLICK_DEPLOYMENT.md`

如果你不是要逐个组件手动搭，建议优先阅读 `docs/ONE_CLICK_DEPLOYMENT.md`。

---

## 一、推荐部署顺序

### 方案 A：只做 reaction 翻译

按下面顺序：

1. 先搭建 `mlx-qwen35-translate`
2. 确认 `http://127.0.0.1:5010/health` 正常
3. 再配置并启动 `DiscordTranslationBot-upstream`
4. 在 Discord 里给消息加国旗 reaction 验证结果

### 方案 B：做频道镜像翻译（双语或多语组）

按下面顺序：

1. 准备一个 OpenAI-compatible / vLLM-compatible 翻译接口
2. 配置 `discord-mirror-bot/.env`
3. 配置频道对，或配置多语频道组
4. 启动 Node bot
5. 用真人账号在任意一边发消息测试

### 方案 C：两套一起上

- `mlx-qwen35-translate` + `DiscordTranslationBot-upstream` 负责 **reaction 翻译**
- `discord-mirror-bot` 负责 **频道镜像翻译**

两者可以同时存在，互不冲突。

---

## 二、三者之间的关系

### 1) 本地 MLX API

提供这几个接口：

- `GET /health`
- `GET /languages`
- `POST /translate`

其中 `POST /translate` 的请求/响应形状故意做成 **LibreTranslate 兼容**，这样 .NET bot 可以直接接。

### 2) DiscordTranslationBot-upstream

它本来支持 Azure / LibreTranslate。
现在本机走的是：

- **LibreTranslate provider**
- 指向：`http://127.0.0.1:5010`

也就是说：

`Discord 消息 reaction` → `.NET bot` → `本地 MLX Translate API` → `翻译结果`

### 3) discord-mirror-bot

这个 bot 不走 LibreTranslate 兼容层。
它直接请求一个 **OpenAI-compatible chat completions endpoint**：

- `VLLM_BASE_URL`
- `VLLM_MODEL`

当前实现是：

`配对频道消息 / 多语组频道消息` → `mirror bot` → `chat completions 翻译接口` → `目标频道（1 对 1 或 1 对多）`

---

## 三、权限与账号建议

### Discord 应用 / Bot 建议

建议至少准备 **1 个独立 bot**。
更稳妥的做法是：

- reaction 翻译 bot 用 1 个 token
- mirror bot 用另 1 个 token

如果只是本机测试，也可以先复用同一个 bot，但长期不建议这样做。

### 需要开的常见权限

至少：

- View Channels
- Send Messages
- Read Message History
- Add Reactions（reaction bot 常用）
- Manage Webhooks（mirror bot 推荐）

### 需要在 Discord Developer Portal 打开的 Intents

至少：

- **Message Content Intent**
- （如果 bot 逻辑需要）Guild Messages / Guild Message Reactions 对应权限

---


## 三点五、当前已验证的进阶形态

除了普通 EN↔ZH 配对外，当前 `discord-mirror-bot` 已支持：

- **图片/附件同步转发**
- **纯附件消息同步**
- **多语分组翻译**（一个频道组内多个语言子频道互相翻译）

当前已经在 Foundation Discord 中落地过一个 `off-topic` 多语组，语言包括：

- `zh`
- `en`
- `ja`
- `fr`
- `de`
- `es`
- `ru`

也就是说，mirror bot 已经不再只是“成对频道”方案，而是可以做“一个主题，多语言子频道互相翻译”的方案。

## 四、迁移到别的设备时的最小清单

### 必带项目目录

- `scripts/mlx-qwen35-translate`
- `scripts/DiscordTranslationBot-upstream`
- `scripts/discord-mirror-bot`

### 不能直接靠 git 带走的配置

1. `discord-mirror-bot/.env`
2. `DiscordTranslationBot-upstream` 的本地配置（如 user-secrets / 本地 appsettings）
3. 新机器上的 LaunchAgent / system service
4. Discord bot token / 应用权限 / 服务器邀请

### 迁移后必须重新检查

- 模型是否已下载成功
- 本地端口是否被占用
- bot token 是否有效
- bot 是否已加入目标服务器
- channel id 是否还是新服务器里的正确 id
- Webhook 权限是否可用

---

## 五、建议的长期整理方式

建议以后就按下面目录认知：

- `scripts/mlx-qwen35-translate/SETUP_AND_MIGRATION.md`
  - 负责“本地 LLM + API 层”
- `scripts/DiscordTranslationBot-upstream/SETUP_AND_MIGRATION.md`
  - 负责“reaction bot 安装、权限、接入本地 API”
- `scripts/discord-mirror-bot/SETUP_AND_MIGRATION.md`
  - 负责“频道镜像 bot 安装、频道配对、迁移”

这样后续无论你自己回看，还是交给别人接手，都比较清晰。

---

## 六、当前本地文档索引

- 总览：`/Users/davidli/.openclaw/workspace/scripts/DISCORD_TRANSLATION_STACK_GUIDE.md`
- 本地 MLX API：`/Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate/SETUP_AND_MIGRATION.md`
- Reaction bot：`/Users/davidli/.openclaw/workspace/scripts/DiscordTranslationBot-upstream/SETUP_AND_MIGRATION.md`
- Mirror bot：`/Users/davidli/.openclaw/workspace/scripts/discord-mirror-bot/SETUP_AND_MIGRATION.md`

- Discord 权限检查：`docs/DISCORD_PERMISSIONS_CHECKLIST.md`

- 预检查：`bin/preflight.sh`
- Discord 访问校验：`bin/check-discord-config.py`
- smoke-test 配置生成：`bin/generate-smoke-test-config.sh`
