// 已废弃：后端仅使用 Groq（GROQ_API_KEY 环境变量），不再支持将 API Key 写入数据库。
// 若需配置 Groq，请在 Vercel / 部署环境变量中设置 GROQ_API_KEY。
console.warn("set-api-key.js 已废弃，请使用环境变量 GROQ_API_KEY 配置 Groq。");
process.exit(0);
