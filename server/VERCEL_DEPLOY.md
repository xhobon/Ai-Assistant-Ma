# 部署到 Vercel

## 一、准备数据库

Vercel 上无法跑本地 PostgreSQL，需要先用云端数据库：

1. **Vercel Postgres**（推荐，同账号）：  
   - 在 [Vercel Dashboard](https://vercel.com) → 你的项目 → Storage → Create Database → Postgres  
   - 创建后会在项目里自动加上 `POSTGRES_URL`（或 `DATABASE_URL`）

2. **或使用 Neon / Supabase**：  
   - [Neon](https://neon.tech) 或 [Supabase](https://supabase.com) 创建免费 Postgres  
   - 复制连接串，格式：`postgresql://用户:密码@主机:5432/数据库名?sslmode=require`

## 二、在 Vercel 创建项目并部署

1. 打开 [vercel.com](https://vercel.com)，用 GitHub 登录。

2. **Import 项目**：  
   - 若代码在 GitHub：选 “Add New” → “Project”，选该仓库  
   - **Root Directory** 填：`server`（只部署 server 目录）  
   - 若无仓库：在本地 `server` 目录执行 `vercel`，按提示登录并关联项目

3. **环境变量**（Settings → Environment Variables）必填：

   | 变量名 | 说明 |
   |--------|------|
   | `DATABASE_URL` | PostgreSQL 连接串（Vercel Postgres 创建后会自动加） |
   | `JWT_SECRET` | 任意长随机字符串，用于登录 Token |
   | `GROQ_API_KEY` | 你的 Groq API Key（[console.groq.com](https://console.groq.com) 获取，如 `gsk_xxx`） |

4. **部署**：  
   - 保存环境变量后，在 Deployments 里 “Redeploy” 一次  
   - 部署完成后会得到域名，如：`https://xxx.vercel.app`

## 三、数据库表结构（首次必须执行）

Vercel 不会自动执行 `db push`，需要你在本地或脚本里跑一次：

- **方式 A（推荐）**：本地已装 Node 和 Prisma 时，在 **本机** 的 `server` 目录执行：
  - 把 `.env` 里的 `DATABASE_URL` 改成 Vercel 用的那个（同上）
  - 执行：`npx prisma db push`
  - 可选：`npm run db:seed`

- **方式 B**：用 Vercel 的 “Run Command” 或一次性脚本（需在项目里加可执行脚本），在部署环境里执行 `prisma db push`（不推荐新手，优先用方式 A）。

## 四、在 App 里填服务器地址

在 App 的 **设置 → 服务器与智能体** 中：

- **服务器地址** 填：`https://你的项目.vercel.app`  
  （不要加末尾斜杠，不要带 `/api`）

保存后，翻译、AI 对话、语音/视频通话会走 Vercel 上的后端。

## 五、注意事项

- **执行时间**：Vercel 免费版单次请求约 10 秒限制，Groq 回复一般够用。
- **冷启动**：一段时间没人访问再请求可能稍慢，属正常。
- **CORS**：当前后端已允许 `*`，若以后要限制域名，在环境变量里设 `CORS_ORIGIN` 即可。
