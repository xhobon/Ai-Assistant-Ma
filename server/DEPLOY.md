# AI 助理后端部署说明

## 一、环境要求

- Node.js 18+
- PostgreSQL 14+（或使用 Docker Compose）
- Groq API Key（[获取地址](https://console.groq.com)）

## 二、本地开发

```bash
cd server
cp .env.example .env
# 编辑 .env：填写 DATABASE_URL、JWT_SECRET、GROQ_API_KEY

npm install
npx prisma db push
npm run db:seed   # 可选，初始化学习分类数据
npm run dev
```

## 三、Docker 部署

```bash
cd server
export GROQ_API_KEY="gsk_xxx"
export JWT_SECRET="随机生成的长字符串"

docker compose up -d
# 首次启动后执行数据库迁移
docker compose exec api npx prisma db push
docker compose exec api node src/seed.js   # 可选
```

## 四、云服务器部署（以 Ubuntu 为例）

### 1. 安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### 2. 克隆代码并配置

```bash
git clone <your-repo> ai-assistant
cd ai-assistant/server
cp .env.example .env
nano .env   # 填写 GROQ_API_KEY、JWT_SECRET，修改 DATABASE_URL 若用外部数据库
```

### 3. 启动服务

```bash
docker compose up -d
docker compose exec api npx prisma db push
```

### 4. Nginx 反向代理（可选，需 HTTPS）

```nginx
server {
    listen 80;
    server_name your-domain.com;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 5. 配置 App 服务器地址

在 App 中进入 **我的 → 设置**，填写 **服务器地址** 为 `https://your-domain.com`，保存后即可通过服务器进行登录、AI 对话、翻译等。

## 五、环境变量说明

| 变量 | 必填 | 说明 |
|------|------|------|
| DATABASE_URL | 是 | PostgreSQL 连接串 |
| JWT_SECRET | 是 | 登录 Token 签名密钥，建议随机 32 位 |
| GROQ_API_KEY | 是 | Groq API Key（[console.groq.com](https://console.groq.com) 免费获取） |
| PORT | 否 | 端口，默认 8080 |
| CORS_ORIGIN | 否 | 允许的来源，默认 * |
