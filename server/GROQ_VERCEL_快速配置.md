# Groq 接入 + 部署到 Vercel 快速步骤

## 1. 在 Vercel 添加 Groq API Key

- 打开 [Vercel Dashboard](https://vercel.com/) → 进入项目 **nextjs-boilerplate-pi-one-a27xruobcp**
- **Settings** → **Environment Variables**
- 新增变量：
  - **Name**: `GROQ_API_KEY`
  - **Value**: 你的 Groq API Key（在 [Groq Console](https://console.groq.com/) 的 API Keys 中创建或复制）
- 勾选 **Production**、**Preview** → **Save**

## 2. 重新部署

- **Deployments** → 最新一次部署右侧 **⋯** → **Redeploy**（或推送代码触发自动部署）

## 3. 验证

- 访问：`https://nextjs-boilerplate-pi-one-a27xruobcp.vercel.app/health`
- 应返回：`{"status":"ok","time":"..."}`

Mac App 已配置默认请求该地址，部署成功且填好 `GROQ_API_KEY` 后，对话与翻译会走 Groq 智能体。

---

**安全提示**：API Key 仅保存在 Vercel 环境变量中，不要写入代码或提交到 Git。若 Key 曾在别处暴露，建议在 Groq Console 中撤销并重新创建。
