import "express-async-errors";
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import morgan from "morgan";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { nanoid } from "nanoid";
import { z } from "zod";
import { PrismaClient } from "@prisma/client";
import { MsEdgeTTS, OUTPUT_FORMAT } from "edge-tts-node";

dotenv.config();

const TTS_MAX_LENGTH = 2000;
const TTS_VOICES = {
  "zh-CN": "zh-CN-XiaoxiaoNeural",
  "id-ID": "id-ID-GadisNeural",
  "en-US": "en-US-JennyNeural"
};
function getTTSVoice(lang) {
  const prefix = (lang || "").slice(0, 2);
  if (lang && TTS_VOICES[lang]) return TTS_VOICES[lang];
  if (prefix === "zh") return TTS_VOICES["zh-CN"];
  if (prefix === "id") return TTS_VOICES["id-ID"];
  return TTS_VOICES["zh-CN"];
}
function escapeTTS(s) {
  if (typeof s !== "string") return "";
  return s
    .slice(0, TTS_MAX_LENGTH)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const app = express();
const globalForPrisma = globalThis;
const prisma = globalForPrisma.prisma ?? new PrismaClient();
globalForPrisma.prisma = prisma;

const PORT = Number(process.env.PORT || 8080);
const JWT_SECRET = process.env.JWT_SECRET || "dev_secret";

function getGroqApiKey() {
  return process.env.GROQ_API_KEY || null;
}

async function llmChat(messages) {
  const groqKey = getGroqApiKey();
  if (!groqKey || groqKey.length <= 10) {
    throw new Error(
      "请配置 GROQ_API_KEY（免费）：访问 https://console.groq.com 注册，创建 API Key，在 Vercel 环境变量中添加 GROQ_API_KEY，并 Redeploy"
    );
  }
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${groqKey}`
    },
    body: JSON.stringify({
      model: "llama-3.1-8b-instant",
      messages,
      temperature: 0.4
    })
  });
  const raw = await res.text().catch(() => "");
  const data = (() => { try { return JSON.parse(raw); } catch { return {}; } })();
  if (res.ok) {
    const content = data?.choices?.[0]?.message?.content;
    if (content) return content.trim();
  }
  const errMsg = data?.error?.message || data?.error || raw || `HTTP ${res.status}`;
  throw new Error(`Groq API 错误: ${res.status} ${String(errMsg).slice(0, 200)}`);
}

app.use(cors({ origin: process.env.CORS_ORIGIN || "*" }));
app.use(express.json({ limit: "2mb" }));
app.use(morgan("dev"));

function signToken(user) {
  return jwt.sign({ sub: user.id, email: user.email, phone: user.phone }, JWT_SECRET, {
    expiresIn: "7d"
  });
}

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    return res.status(401).json({ error: "UNAUTHORIZED" });
  }
  const token = authHeader.replace("Bearer ", "");
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    return next();
  } catch (error) {
    return res.status(401).json({ error: "INVALID_TOKEN" });
  }
}

function optionalAuthMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  req.user = null;
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.replace("Bearer ", "");
    try {
      req.user = jwt.verify(token, JWT_SECRET);
    } catch {}
  }
  next();
}

app.get("/health", async (req, res) => {
  res.json({ status: "ok", time: new Date().toISOString() });
});

const registerSchema = z.object({
  email: z.string().email().optional(),
  phone: z.string().min(6).optional(),
  password: z.string().min(6),
  displayName: z.string().min(1)
});

app.post("/api/auth/register", async (req, res) => {
  const parseResult = registerSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { email, phone, password, displayName } = parseResult.data;
  if (!email && !phone) {
    return res.status(400).json({ error: "EMAIL_OR_PHONE_REQUIRED" });
  }

  const existingUser = await prisma.user.findFirst({
    where: {
      OR: [{ email: email || undefined }, { phone: phone || undefined }]
    }
  });
  if (existingUser) {
    return res.status(409).json({ error: "USER_EXISTS" });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: {
      email: email || null,
      phone: phone || null,
      passwordHash,
      displayName
    }
  });

  return res.json({ token: signToken(user), user });
});

const loginSchema = z.object({
  account: z.string().min(3),
  password: z.string().min(6)
});

app.post("/api/auth/login", async (req, res) => {
  const parseResult = loginSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { account, password } = parseResult.data;
  const user = await prisma.user.findFirst({
    where: {
      OR: [{ email: account }, { phone: account }]
    }
  });

  if (!user || !user.passwordHash) {
    return res.status(401).json({ error: "INVALID_CREDENTIALS" });
  }

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    return res.status(401).json({ error: "INVALID_CREDENTIALS" });
  }

  const updated = await prisma.user.update({
    where: { id: user.id },
    data: { lastLoginAt: new Date() }
  });

  return res.json({ token: signToken(updated), user: updated });
});

const socialSchema = z.object({
  provider: z.enum(["APPLE", "GOOGLE"]),
  providerUserId: z.string().min(2),
  email: z.string().email().optional(),
  displayName: z.string().min(1)
});

app.post("/api/auth/social", async (req, res) => {
  const parseResult = socialSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { provider, providerUserId, email, displayName } = parseResult.data;

  let providerRecord = await prisma.authProvider.findUnique({
    where: { provider_providerUserId: { provider, providerUserId } },
    include: { user: true }
  });

  if (!providerRecord) {
    const user = await prisma.user.create({
      data: {
        email: email || null,
        displayName
      }
    });

    providerRecord = await prisma.authProvider.create({
      data: {
        provider,
        providerUserId,
        email: email || null,
        userId: user.id
      },
      include: { user: true }
    });
  }

  return res.json({ token: signToken(providerRecord.user), user: providerRecord.user });
});

app.get("/api/profile", authMiddleware, async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.user.sub },
    include: {
      favorites: true,
      learningLogs: true
    }
  });

  return res.json({ user });
});

app.post("/api/assistant/chat", optionalAuthMiddleware, async (req, res) => {
  const schema = z.object({
    conversationId: z.string().optional(),
    message: z.string().min(1)
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { conversationId, message } = parseResult.data;
  let conversation = null;
  if (req.user) {
    conversation = conversationId
      ? await prisma.conversation.findUnique({ where: { id: conversationId } })
      : await prisma.conversation.create({
          data: { userId: req.user.sub, title: `对话-${nanoid(6)}` }
        });
    if (conversation) {
      await prisma.message.create({
        data: { conversationId: conversation.id, role: "user", content: message }
      });
    }
  }

  let history = [];
  if (conversation) {
    const rows = await prisma.message.findMany({
      where: { conversationId: conversation.id },
      orderBy: { createdAt: "asc" }
    });
    history = rows.map((m) => ({ role: m.role, content: m.content }));
  } else {
    history = [{ role: "user", content: message }];
  }
  if (!history.some((m) => m.role === "system")) {
    history.unshift({ role: "system", content: "你是专业、可靠的AI助理，请用中文简洁回答。" });
  }

  let reply;
  try {
    reply = await llmChat(history);
  } catch (err) {
    reply = `抱歉，AI 服务暂时不可用：${err.message}`;
  }

  if (conversation) {
    await prisma.message.create({
      data: { conversationId: conversation.id, role: "assistant", content: reply }
    });
  }

  return res.json({
    conversationId: conversation?.id ?? null,
    reply
  });
});

app.post("/api/translate", optionalAuthMiddleware, async (req, res) => {
  const schema = z.object({
    text: z.string().min(1),
    sourceLang: z.string().min(2),
    targetLang: z.string().min(2)
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { text, sourceLang, targetLang } = parseResult.data;

  let translated;
  try {
    const langNames = { "zh-CN": "中文", "id-ID": "印尼语", "en-US": "英语" };
    const s = langNames[sourceLang] || sourceLang;
    const t = langNames[targetLang] || targetLang;
    translated = await llmChat([
      { role: "system", content: `你只输出翻译结果，不要解释。将文本从${s}翻译为${t}。` },
      { role: "user", content: text }
    ]);
  } catch (err) {
    translated = `翻译失败: ${err.message}`;
  }

  if (req.user) {
    await prisma.translationHistory.create({
      data: {
        userId: req.user.sub,
        sourceLang,
        targetLang,
        sourceText: text,
        targetText: translated
      }
    });
  }

  return res.json({ translated });
});

app.post("/api/tts", async (req, res) => {
  const schema = z.object({
    text: z.string().min(1).max(TTS_MAX_LENGTH),
    lang: z.string().min(2).max(10).optional()
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }
  const { text, lang } = parseResult.data;
  const voice = getTTSVoice(lang || "zh-CN");
  const safeText = escapeTTS(text);
  if (!safeText) return res.status(400).json({ error: "text required" });
  try {
    const tts = new MsEdgeTTS({});
    await tts.setMetadata(voice, OUTPUT_FORMAT.WEBM_24KHZ_16BIT_MONO_OPUS);
    const readable = tts.toStream(safeText);
    res.setHeader("Content-Type", "audio/webm");
    res.setHeader("Cache-Control", "no-store");
    readable.pipe(res);
    readable.on("error", (err) => {
      if (!res.headersSent) res.status(500).json({ error: err.message });
      else res.end();
    });
  } catch (err) {
    console.error("TTS error:", err.message);
    return res.status(500).json({ error: err?.message || "TTS failed" });
  }
});

app.get("/api/translate/history", authMiddleware, async (req, res) => {
  const history = await prisma.translationHistory.findMany({
    where: { userId: req.user.sub },
    orderBy: { createdAt: "desc" },
    take: 20
  });

  return res.json({ history });
});

app.get("/api/learning/categories", async (req, res) => {
  const categories = await prisma.vocabCategory.findMany({
    orderBy: { sortOrder: "asc" },
    include: { items: true }
  });

  return res.json({ categories });
});

app.post("/api/learning/favorites", authMiddleware, async (req, res) => {
  const schema = z.object({ vocabId: z.string().min(1), isFavorite: z.boolean() });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { vocabId, isFavorite } = parseResult.data;
  if (isFavorite) {
    await prisma.favorite.upsert({
      where: { userId_vocabId: { userId: req.user.sub, vocabId } },
      update: {},
      create: { userId: req.user.sub, vocabId }
    });
  } else {
    await prisma.favorite.deleteMany({
      where: { userId: req.user.sub, vocabId }
    });
  }

  return res.json({ ok: true });
});

app.post("/api/learning/session", authMiddleware, async (req, res) => {
  const schema = z.object({ minutes: z.number().int().min(1), masteredCount: z.number().int().min(0) });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { minutes, masteredCount } = parseResult.data;
  const log = await prisma.learningSession.create({
    data: {
      userId: req.user.sub,
      minutes,
      masteredCount
    }
  });

  return res.json({ log });
});

app.use((err, req, res, next) => {
  console.error("Express error:", err?.message || err);
  res.status(500).json({
    error: "INTERNAL_ERROR",
    message: err?.message || String(err)
  });
});

if (process.env.VERCEL !== "1") {
  app.listen(PORT, () => {
    console.log(`API server running on port ${PORT}`);
  });
}

export { app };
