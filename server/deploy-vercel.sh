#!/bin/bash
# 一键部署到 Vercel（免费），部署后 App 无需再填服务器地址
set -e
cd "$(dirname "$0")"

# 若未在环境里设置，则从 .env 读取
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi
: "${DATABASE_URL:=}"
: "${GROQ_API_KEY:=}"
: "${JWT_SECRET:=}"

echo "检查环境变量..."
[ -n "$DATABASE_URL" ] || { echo "错误: 请设置 DATABASE_URL"; exit 1; }
[ -n "$GROQ_API_KEY" ] || { echo "错误: 请设置 GROQ_API_KEY"; exit 1; }
[ -n "$JWT_SECRET" ] || { echo "错误: 请设置 JWT_SECRET"; exit 1; }

echo "安装依赖..."
npm install

echo "生成 Prisma Client..."
npx prisma generate

echo "推送数据库表结构..."
npx prisma db push

# 写入 Vercel 环境变量（需先有 vercel 登录）
echo "正在把环境变量写入 Vercel..."
printf '%s' "$DATABASE_URL" | npx vercel env add DATABASE_URL production 2>/dev/null || true
printf '%s' "$JWT_SECRET" | npx vercel env add JWT_SECRET production 2>/dev/null || true
printf '%s' "$GROQ_API_KEY" | npx vercel env add GROQ_API_KEY production 2>/dev/null || true

echo "部署到 Vercel（首次会要求浏览器登录，项目名请填: ai-assistant-backend）..."
npx vercel --prod --yes 2>/dev/null || npx vercel --prod

echo "完成。App 已内置默认地址 https://ai-assistant-backend.vercel.app，无需在设置里填写。"
