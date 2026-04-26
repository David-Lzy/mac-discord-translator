# Discord Mirror Bot：安装、频道配对、权限、迁移

项目路径：`/Users/davidli/.openclaw/workspace/scripts/discord-mirror-bot`

这个项目的职责是：

- 监听 EN / ZH 成对频道，或一个主题下的多语言频道组
- 一边有真人发言时，翻译到另一边，或同组其它语言频道
- 支持图片 / 附件同步转发
- 可选使用 webhook 伪装成原发言者的名字 / 头像

---

## 一、当前架构

当前 mirror bot 不是走 LibreTranslate 接口。
它要求一个 **OpenAI-compatible chat completions API**：

- `VLLM_BASE_URL`
- `VLLM_MODEL`

当前代码里请求的是：

- `POST {VLLM_BASE_URL}/chat/completions`

因此，它适合接：

- vLLM
- OpenAI-compatible local server
- 其它兼容 `chat/completions` 的模型网关

---

## 二、如何安装 Bot

### 1. 环境要求

- Node.js
- npm

### 2. 安装依赖

```bash
cd /Users/davidli/.openclaw/workspace/scripts/discord-mirror-bot
npm install
```

### 3. 配置环境变量

复制：

```bash
cp .env.example .env
```

然后填写：

- `DISCORD_BOT_TOKEN`
- `DISCORD_GUILD_ID`
- `VLLM_BASE_URL`
- `VLLM_MODEL`

以及频道配对：

### 单对模式

```env
MIRROR_EN_CHANNEL_ID=123
MIRROR_ZH_CHANNEL_ID=456
```

### 多对模式（推荐）

```env
MIRROR_CHANNEL_PAIRS=EN_ID:ZH_ID;EN_ID:ZH_ID;EN_ID:ZH_ID
```

### 多语分组模式

```env
MIRROR_CHANNEL_GROUPS=offtopic>CHANNEL_ID|zh,CHANNEL_ID|en,CHANNEL_ID|ja,CHANNEL_ID|fr,CHANNEL_ID|de,CHANNEL_ID|es,CHANNEL_ID|ru
```

当前代码已支持：

- 单对模式
- 多对模式
- 多语分组模式

优先级：

- `MIRROR_CHANNEL_GROUPS` + `MIRROR_CHANNEL_PAIRS` 可以同时存在
- group 会按组内广播
- pair 会继续按一对一工作
- 单对 env 只作为兜底

---

## 三、如何链接到 Discord

### 1. 创建 Bot

去 Discord Developer Portal 创建应用 / bot。

### 2. 邀请到服务器

至少需要：

- View Channels
- Send Messages
- Read Message History
- Manage Webhooks（推荐）

### 3. 必开 Intents

至少：

- **Message Content Intent**

因为它需要直接读取消息内容做翻译。

---

## 四、如何配置频道配对

### 配对原则

建议始终写成：

- `英文频道ID:中文频道ID`

因为 pair 模式下内部逻辑是：

- EN channel → 翻到 ZH
- ZH channel → 翻到 EN

### 分组原则

如果你要一个主题下多语互翻，建议写成：

- `GROUP_NAME>频道ID|语言码,频道ID|语言码,...`

例如：

```env
offtopic>123|zh,456|en,789|ja
```

表示：

- `123` 是中文频道
- `456` 是英文频道
- `789` 是日文频道
- 任意一个频道收到真人消息后，会翻译到其它所有语言频道

### 当前项目已经支持多组配对 + 多语组并存

这意味着一个 bot 进程可以同时接管：

- 普通 EN/ZH 成对频道
- 某个主题下的多语言频道组

---

## 五、如何运行

### 前台运行

```bash
cd /Users/davidli/.openclaw/workspace/scripts/discord-mirror-bot
node index.js
```

### 常见后台运行方式

当前机器使用的是类似：

```bash
nohup env $(grep -v '^#' .env | xargs) node index.js >> mirror-bot.log 2>&1 &
```

### 查看进程

```bash
pgrep -af "scripts/discord-mirror-bot/index.js"
```

### 查看日志

```bash
tail -n 50 /Users/davidli/.openclaw/workspace/scripts/discord-mirror-bot/mirror-bot.log
```

---

## 六、如何验证

### 启动后日志应看到

- `Mirror bot logged in as ...`
- `Guild: ...`
- `Group ...: ZH ... | EN ... | JA ...`（如果用了多语组）
- `Group pair...: EN ... | ZH ...`（如果还保留普通 pair）

### 实际验证方法

必须使用**真人账号**在一侧频道发消息。

原因：

- 当前代码会忽略 bot authored messages
- 也会避免 relay marker 形成回环

所以不要用 bot 自己发消息做端到端测试。

---

## 七、权限细节

### 为什么推荐开 Manage Webhooks

如果：

- `WEBHOOK_MODE=true`

bot 会尝试在目标频道创建 / 复用 webhook，然后把译文以更接近原作者昵称、头像的形式发出去。

如果不开这个权限：

- 把 `WEBHOOK_MODE=off`
- 它会退化成普通 bot 发消息

### 什么时候要关掉 webhook 模式

如果目标服务器对 webhook 很严格，或者不希望 bot 自动创建 webhook，可以关掉。

---

## 八、迁移到别的设备

### 需要带走的内容

- 整个 `discord-mirror-bot` 项目目录
- `.env`（注意这里面有 token，别直接公开）

### 新机器迁移步骤

1. 安装 Node.js
2. 拷贝项目目录
3. `npm install`
4. 复制并修改 `.env`
5. 检查目标翻译 API 地址是否正确
6. 启动 bot
7. 查看日志确认 pair 已加载
8. 用真人账号做双向测试

### 迁移时最容易出错的地方

- 新服务器的频道 ID 跟旧服务器不同
- bot 没被邀请进新服务器
- Message Content Intent 没开
- webhook 权限缺失
- `.env` 仍然指向旧的 `VLLM_BASE_URL`

---

## 九、当前建议的生产化思路

如果要长期稳定运行，建议：

1. 使用独立 bot token
2. 把 `.env` 独立保管
3. 给 bot 做成 LaunchAgent / systemd / pm2 之类的常驻服务
4. 把频道配对当作配置项管理
5. 保留日志文件，方便排错

---

## 十、最小恢复手册

如果以后临时坏了，最快恢复顺序：

1. 检查 `.env` 还在不在
2. 检查 `VLLM_BASE_URL` 是否可访问
3. 检查 `MIRROR_CHANNEL_GROUPS` / `MIRROR_CHANNEL_PAIRS` 是否还正确
4. 执行：

```bash
cd /Users/davidli/.openclaw/workspace/scripts/discord-mirror-bot
node index.js
```

4. 查看是否出现：
   - `Mirror bot logged in as ...`
   - `Pair: EN ... <-> ZH ...`
5. 用真人账号在任一配对频道发一条消息做实测
