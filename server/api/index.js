// 先单独处理 /health，不加载 Prisma，确保部署可测
function sendHealth(res) {
  const raw = process.env.GROQ_API_KEY || "";
  const key = raw.trim().replace(/^["']|["']$/g, "");
  const groqConfigured = key.length > 10;
  res.setHeader("Content-Type", "application/json");
  res.status(200).end(
    JSON.stringify({
      status: "ok",
      time: new Date().toISOString(),
      groq_configured: groqConfigured,
      ...(groqConfigured ? {} : { hint: "在 Vercel Settings → Environment Variables 添加 GROQ_API_KEY 并 Redeploy" })
    })
  );
}

export default async function handler(req, res) {
  const path = (req.url || req.path || "").split("?")[0] || "/";
  if (path === "/health" || path === "/api/health") {
    sendHealth(res);
    return;
  }

  try {
    const { app } = await import("../src/index.js");
    return new Promise((resolve, reject) => {
      const onFinish = () => {
        res.removeListener("finish", onFinish);
        res.removeListener("error", onError);
        resolve();
      };
      const onError = (err) => {
        res.removeListener("finish", onFinish);
        res.removeListener("error", onError);
        reject(err);
      };
      res.once("finish", onFinish);
      res.once("error", onError);
      try {
        app(req, res);
      } catch (err) {
        onError(err);
      }
    });
  } catch (err) {
    console.error("Server init error:", err);
    res.setHeader("Content-Type", "application/json");
    res.status(500).end(
      JSON.stringify({
        error: "FUNCTION_INVOCATION_FAILED",
        message: err?.message || String(err),
        hint: "Check Vercel env: DATABASE_URL, GROQ_API_KEY, JWT_SECRET. Run prisma generate in build."
      })
    );
  }
}
