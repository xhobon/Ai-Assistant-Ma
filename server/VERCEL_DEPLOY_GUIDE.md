# Vercel 部署指南（智能体 Groq + 部署）

部署域名示例：**https://nextjs-boilerplate-pi-one-a27xruobcp.vercel.app**

## 一、接入 Groq 智能体（必选，免费）

1. 打开 [Groq Cloud Console](https://console.groq.com/) 登录/注册。
2. 在 **API Keys** 中创建或复制你的 API Key（形如 `gsk_...`）。
3. 在 Vercel 中配置该 Key（见下一节环境变量）。

后端仅使用 Groq：通过 `GROQ_API_KEY` 调用 `llama-3.1-8b-instant`。

## 二、环境变量（在 Vercel 项目设置里填写）

进入 Vercel 项目 → **Settings** → **Environment Variables**，添加：

| 变量名 | 说明 |
|--------|------|
| `GROQ_API_KEY` | 必填，[Groq Console](https://console.groq.com/) 获取，用于 AI 对话与翻译 |
| `DATABASE_URL` | 数据库连接串（如 Neon PostgreSQL） |
| `JWT_SECRET` | 登录 Token 签名，建议随机长字符串 |

添加后勾选 **Production**、**Preview**，保存后需 **Redeploy** 一次才能生效。

## 三、根目录设置

若仓库根目录不是 `server`，请在 Vercel **Settings** → **General** 中：

- **Root Directory**：`server`
- **Build Command**：留空或 `prisma generate`（vercel.json 已配置）
- **Install Command**：`npm install`

## 四、部署方式

### 方式 A：Git 推送自动部署

1. 将包含 `server/` 的代码推送到已连接的 Git 仓库。
2. Vercel 会自动构建并部署；若未连接，在 Vercel 导入该仓库并设置 Root Directory 为 `server`。

### 方式 B：CLI 手动部署

```bash
cd server
npx vercel login
npx vercel env add GROQ_API_KEY production   # 按提示粘贴 Groq API Key（可选，也可在网页填）
npx vercel --prod
```

部署完成后访问你的项目域名（如 `https://nextjs-boilerplate-pi-one-a27xruobcp.vercel.app`）。

## 五、部署后验证

1. 在 Vercel **Deployments** 中确认部署成功。
2. 访问 `https://你的域名/health`，应返回 `{"status":"ok",...}`。
3. 在 Mac App 中把 API 基础地址设为 `https://你的域名`（不要带末尾 `/api`），即可使用 Groq 智能体对话与翻译。
