# DiscordTranslationBot（Reaction 翻译 Bot）：安装、接入本地 API、权限、迁移

项目路径：`/Users/davidli/.openclaw/workspace/scripts/DiscordTranslationBot-upstream`

这个项目的职责是：

- 监听 Discord 里的翻译相关交互（尤其是 reaction）
- 调用翻译 provider
- 把翻译结果返回到 Discord

当前本机方案不是 Azure，而是：

- **LibreTranslate provider**
- 指向本地 MLX Translate API：`http://127.0.0.1:5010`

---

## 一、当前架构

调用链如下：

`Discord reaction` → `DiscordTranslationBot-upstream` → `LibreTranslate provider` → `http://127.0.0.1:5010/translate`

因此它依赖本地翻译 API 先正常启动。

---

## 二、如何安装这个 Bot

### 1. 准备 .NET 环境

这个项目是 .NET 项目。

当前运行脚本里使用：

```bash
export PATH="$HOME/.dotnet:$PATH"
```

所以新机器上至少要先保证：

- `dotnet` 已安装
- `~/.dotnet` 在 PATH 中可用，或系统 PATH 已直接包含 dotnet

### 2. 拉依赖 / 编译

```bash
cd /Users/davidli/.openclaw/workspace/scripts/DiscordTranslationBot-upstream
export PATH="$HOME/.dotnet:$PATH"
dotnet restore
dotnet build -c Release
```

### 3. 运行

当前本地运行脚本：

```bash
cd /Users/davidli/.openclaw/workspace/scripts/DiscordTranslationBot-upstream
./run-bot-local.sh
```

脚本内部会进入：

- `src/DiscordTranslationBot`

然后执行：

```bash
dotnet run -c Release
```

---

## 三、如何配置本地翻译 API

### 方式 A：本地配置文件

可以使用示例：

- `appsettings.Local.example.json`

建议在本地复制成：

- `appsettings.Local.json`

配置思路：

```json
{
  "Discord": {
    "BotToken": "PUT_DISCORD_BOT_TOKEN_HERE"
  },
  "TranslationProviders": {
    "AzureTranslator": {
      "Enabled": false,
      "ApiUrl": "https://api.cognitive.microsofttranslator.com",
      "Region": "",
      "SecretKey": ""
    },
    "LibreTranslate": {
      "Enabled": true,
      "ApiUrl": "http://127.0.0.1:5010"
    }
  },
  "Telemetry": {
    "Enabled": false
  }
}
```

### 方式 B：环境变量

```bash
Discord__BotToken=YOUR_DISCORD_BOT_TOKEN
TranslationProviders__LibreTranslate__Enabled=true
TranslationProviders__LibreTranslate__ApiUrl=http://127.0.0.1:5010
TranslationProviders__AzureTranslator__Enabled=false
Telemetry__Enabled=false
```

### 方式 C：.NET user-secrets（推荐）

如果你不想把 token 明文落到仓库里，推荐 user-secrets。

优点：

- 不污染 git
- 不需要把敏感信息写到仓库文件

当前机器就是走这种思路配置过的。

---

## 四、如何链接 Discord Bot

### 1. 在 Discord Developer Portal 创建应用

创建 Bot 后，拿到：

- Bot Token

### 2. 把 bot 邀请进服务器

需要给它至少这些能力：

- View Channels
- Read Message History
- Send Messages
- Add Reactions（如果流程依赖 reaction 交互）

### 3. 打开 Intents

至少检查：

- **Message Content Intent**

之前这个项目就遇到过：

- `Disallowed intent(s)`

当时原因就是没开 Message Content Intent。

---

## 五、如何验证它是否工作

### 先看本地翻译 API

```bash
curl -sS http://127.0.0.1:5010/health
```

### 再启动 bot

```bash
./run-bot-local.sh
```

### 在 Discord 内验证

1. 找一条普通消息
2. 添加目标国旗 reaction（例如 🇨🇳）
3. 观察 bot 是否返回译文

---

## 六、当前已知问题 / 历史经验

这项目此前已经踩过一个关键坑：

- reaction 事件收到后，C# 端发给 `/translate` 的 body 曾经变成空 `{}`
- 结果本地 API 返回 `400 Bad Request`

因此以后若再出现“reaction 收到了但不出翻译”，优先检查：

1. Bot 是否成功收到 reaction 事件
2. `/translate` 请求 body 是否正确
3. `source / target / q` 是否传到了本地 API

---

## 七、迁移到别的设备

### 需要带走的内容

- 整个 `DiscordTranslationBot-upstream` 目录
- 本地配置模板
- user-secrets 的配置内容（需要人工重新注入，不能只靠 git）

### 新机器迁移步骤

1. 安装 .NET
2. 复制项目目录
3. `dotnet restore`
4. 准备本地配置（推荐 user-secrets）
5. 把 `LibreTranslate.ApiUrl` 指到新机器的翻译 API
6. 邀请 bot 到目标服务器
7. 打开 Developer Portal 里的 intents
8. 启动并做 reaction 测试

### 迁移时最容易漏掉的点

- token 没迁过去
- 新机器没开本地翻译 API
- API 地址还写着旧机器 `127.0.0.1:5010` / 或错误地址
- Message Content Intent 忘了开
- bot 没有频道可见权限

---

## 八、最小恢复手册

如果以后要快速恢复：

1. 先确认 `mlx-qwen35-translate` 正常
2. 再确认 bot token 配置已写入
3. 执行：

```bash
cd /Users/davidli/.openclaw/workspace/scripts/DiscordTranslationBot-upstream
./run-bot-local.sh
```

4. 去 Discord 里做一次 reaction 测试
