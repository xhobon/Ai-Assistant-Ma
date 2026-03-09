# 从零开始：把后端部署到 GitHub + Vercel

按顺序做下面每一步即可。

---

## 第一步：在 GitHub 上新建仓库

1. 打开浏览器，访问：**https://github.com/new**
2. 登录你的 GitHub 账号（用户名例如：kun577522）。
3. 填写：
   - **Repository name**：填 `Ai-Assistant-Mac`（必须和这里一致，后面命令会用到）。
   - **Description**：可选，例如「AI 助理 Mac 端与后端」。
   - **Public** 或 **Private**：任选一个。
   - ⚠️ **不要**勾选「Add a README file」。
   - ⚠️ **不要**勾选「Add .gitignore」。
   - ⚠️ **不要**选择 License。
4. 点击绿色的 **Create repository**。
5. 创建完成后，页面上会显示仓库地址，例如：  
   `https://github.com/kun577522/Ai-Assistant-Mac`  
   先不用管页面上的「push an existing repository」命令，按下面第二步在终端做。

---

## 第二步：确认本地已有 server 的提交

1. 打开 **终端**（Terminal）。
2. 进入项目目录（复制整行执行）：
   ```bash
   cd /Users/akun/Desktop/Ai助理Mac/Ai助理Mac
   ```
3. 查看状态：
   ```bash
   git status
   ```
4. 若 `server` 还没被提交过，执行：
   ```bash
   git add server
   git commit -m "Add server backend for Vercel"
   ```
5. 若已经提交过（或上面执行后显示 "nothing to commit"），直接进行第三步。

---

## 第三步：把 GitHub 仓库加为远程并推送

在**同一终端**、**同一目录**下依次执行（一行一行执行）：

**3.1 添加远程（只做一次）**
```bash
git remote add origin https://github.com/kun577522/Ai-Assistant-Mac.git
```
- 若提示 `remote origin already exists`，先执行：  
  `git remote remove origin`  
  再重新执行上面这行。

**3.2 确保当前分支叫 main**
```bash
git branch -M main
```

**3.3 推送到 GitHub**
```bash
git push -u origin main
```

此时会要求你**登录 / 认证**：

- **Username for 'https://github.com':** 填你的 GitHub 用户名，例如 `kun577522`，回车。
- **Password for 'https://kun577522@github.com':**  
  ⚠️ **这里不能填登录密码**，要填 **Personal Access Token**。

---

## 第四步：获取 GitHub Personal Access Token（若从未用过）

1. 浏览器打开：**https://github.com/settings/tokens**
2. 点击 **Generate new token** → 选 **Generate new token (classic)**。
3. **Note** 随便填，例如：`Ai-Assistant-Mac-push`。
4. **Expiration** 选 90 days 或 No expiration（按你习惯）。
5. 在 **Select scopes** 里勾选 **repo**（会顺带勾选下面子项）。
6. 拉到最下面点 **Generate token**。
7. 生成后页面上会显示一串以 `ghp_` 开头的 token，**立刻复制保存**（离开页面后就再也看不到）。
8. 回到终端，在提示 **Password** 的地方**粘贴这串 token**（不会显示字符），回车。

若成功，会看到类似：`branch 'main' set up to track 'origin/main'.` 和推送进度。

---

## 第五步：在 Vercel 用 GitHub 仓库部署后端

1. 打开 **https://vercel.com**，登录（建议用 GitHub 登录，方便看到仓库）。
2. 点击右上角 **Add New...** → **Project**。
3. 在 **Import Git Repository** 里找到 **kun577522/Ai-Assistant-Mac**，点击 **Import**。
4. 进入配置页后：
   - **Project Name**：可保持默认或改成 `ai-assistant-api`。
   - 找到 **Root Directory**，点击 **Edit**，在输入框里填：**`server`**，确认。
   - **Framework Preset**：选择 **Other**（不要选 Next.js）。
5. 先不要改别的，直接点击 **Deploy**。
6. 等一两分钟，部署完成后会显示一个地址，例如：  
   `https://ai-assistant-api-xxx.vercel.app`  
   复制保存这个地址。

---

## 第六步：在 Vercel 里配置环境变量

1. 在刚部署的项目里，点上方 **Settings**。
2. 左侧点 **Environment Variables**。
3. 添加两个变量（每填完一行点 Add）：
   - **Key**：`GROQ_API_KEY`  
     **Value**：你的 Groq API Key（在 https://console.groq.com 的 API Keys 里创建或复制）。  
     环境勾选 **Production**（和 **Preview** 如需要）。
   - **Key**：`JWT_SECRET`  
     **Value**：任意一长串随机字符，例如 `MySecretKey2026AbcXyZ123`。  
     环境勾选 **Production**（和 **Preview** 如需要）。
4. 保存后，点 **Deployments**，在最新一次部署右侧 **⋯** 菜单里选 **Redeploy**，再点 **Redeploy** 确认。等部署完成。

---

## 第七步：验证后端是否正常

在浏览器地址栏输入（把域名换成你在第五步得到的）：

**https://你的项目域名/health**

例如：`https://ai-assistant-api-xxx.vercel.app/health`

应看到类似：`{"status":"ok","time":"2026-02-22T..."}`

说明后端已成功部署。

---

## 第八步：在 Mac App 里使用该地址

把 App 请求的 **API 基础地址** 改成第七步里用的那个域名（不要加 `/api` 或末尾斜杠）。

若 App 里没有可填的地方，需要改代码：在 Xcode 里打开项目，找到 **AppServices.swift**，把里面的 `builtInProductionURL` 改成你的 Vercel 地址，例如：

```swift
private static let builtInProductionURL = "https://ai-assistant-api-xxx.vercel.app"
```

保存后重新运行 Mac App，对话和翻译就会走你刚部署的后端。

---

## 常见问题

**Q: 终端里 `git push` 一直提示 Authentication failed**  
A: Password 处必须填 **Personal Access Token**，不能填 GitHub 登录密码。按第四步重新生成 token 再试。

**Q: 提示 remote origin already exists**  
A: 执行 `git remote remove origin`，再执行 `git remote add origin https://github.com/kun577522/Ai-Assistant-Mac.git`，然后 `git push -u origin main`。

**Q: Vercel 部署后访问域名显示 404**  
A: 检查是否把 **Root Directory** 设成了 **server**，且 **Framework Preset** 是 **Other**。若选的是 Next.js 或根目录没选 server，会 404。

**Q: /health 返回 500 或报错**  
A: 到 Vercel 项目 **Settings → Environment Variables** 确认已添加 `GROQ_API_KEY` 和 `JWT_SECRET`，并 **Redeploy** 一次。
