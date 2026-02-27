# 通过 GitHub 把后端部署到 Vercel

## 一、确保「包含 server 的仓库」已在 GitHub 上

当前后端代码在目录：`Ai助理Mac/Ai助理Mac/server/`。

- **若整个项目（含 server）已在 GitHub**：跳过本节，直接做「二」。
- **若还没推过，或 server 从未提交过**：在终端执行（在**仓库根目录**，即 `Ai助理Mac` 或 `Ai助理Mac/Ai助理Mac` 上一级）：

```bash
cd /Users/akun/Desktop/Ai助理Mac/Ai助理Mac
git status
git add server
git commit -m "Add server backend for Vercel"
git push origin main
```

（如主分支叫 `master` 就改成 `git push origin master`。）

这样 GitHub 上会有一个**包含 `server` 文件夹**的仓库。

---

## 二、在 Vercel 用 GitHub 仓库新建项目

1. 打开 [vercel.com](https://vercel.com) → 左上角 **Add New** → **Project**。
2. 在 **Import Git Repository** 里选 **包含 `server` 目录的那个仓库**（不要选 `nextjs-boilerplate`）。
   - 若列表里没有，点 **Import Third-Party Git Repository**，填你的 GitHub 仓库地址。
3. 进入配置页后：
   - **Project Name**：可改，例如 `ai-assistant-api`。
   - **Root Directory**：点 **Edit** → 填 **`server`** → 确认。  
     （这样 Vercel 只会用仓库里的 `server/` 目录部署，不会当 Next.js 项目。）
   - **Framework Preset**：选 **Other**（后端由 `server/vercel.json` 决定，不是 Next.js）。
4. 先不要改别的，直接点 **Deploy**。
5. 等部署完成，记下给的域名，例如 `https://ai-assistant-api-xxx.vercel.app`。

---

## 三、配置环境变量并重新部署

1. 在新项目里点 **Settings** → **Environment Variables**。
2. 添加：
   - **Name**: `GROQ_API_KEY`  
     **Value**: 你的 Groq API Key（[console.groq.com](https://console.groq.com/)）
   - **Name**: `JWT_SECRET`  
     **Value**: 任意一长串随机字符（如 `my-secret-key-2026-xxx`）
3. 每个变量勾选 **Production**（和 **Preview** 如需），保存。
4. 打开 **Deployments** → 最新一次部署右侧 **⋯** → **Redeploy**，等完成。

---

## 四、验证

浏览器访问：

**`https://你的项目域名/health`**

应返回：`{"status":"ok","time":"..."}`。

---

## 五、在 Mac App 里用新地址

把 App 请求的 API 基础地址改成上一步的域名（不要加 `/api` 或末尾斜杠）。

若 App 里没有设置项，需要改代码：在 `AppServices.swift` 里把 `builtInProductionURL` 改成你的新后端地址，例如：

`https://ai-assistant-api-xxx.vercel.app`

之后对话、翻译会走这个 GitHub + Vercel 部署的后端。
