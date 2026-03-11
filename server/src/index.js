import "express-async-errors";
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import morgan from "morgan";
import crypto from "crypto";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { nanoid } from "nanoid";
import { z } from "zod";
import { PrismaClient } from "@prisma/client";
import { MsEdgeTTS, OUTPUT_FORMAT } from "edge-tts-node";

dotenv.config();

const TTS_MAX_LENGTH = 2000;
const TTS_VOICES = {
  // 更自然的中文神经网络音色（可按需替换：zh-CN-YunxiNeural / zh-CN-XiaoyiNeural 等）
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

function normalizeLang(lang) {
  if (!lang || typeof lang !== "string") return "zh-CN";
  const s = lang.trim();
  if (!s) return "zh-CN";
  // 常见兼容：zh / zh-cn / zh_CN
  if (s.toLowerCase() === "zh" || s.toLowerCase() === "zh-cn" || s.toLowerCase() === "zh_cn") return "zh-CN";
  if (s.toLowerCase() === "id" || s.toLowerCase() === "id-id" || s.toLowerCase() === "id_id") return "id-ID";
  return s;
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

function addNaturalPausesForZh(escapedText) {
  // 在不改变语义的情况下增加轻微停顿，降低“播报感”
  if (!escapedText) return "";
  return escapedText
    .replace(/([，,])/g, "$1<break time=\"140ms\"/>")
    .replace(/([。！？!?\n])/g, "$1<break time=\"220ms\"/>");
}

function stripConversationTitleNoise(text) {
  if (!text || typeof text !== "string") return "";
  let s = text
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/\[图片\]/g, " ")
    .replace(/\[文件:[^\]]+\]/g, " ")
    .replace(/\[用户附了一张图\]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  s = s.replace(/^(请|帮我|帮忙|麻烦|能否|能不能|可以|想要|请帮我|帮我一下|帮忙一下)\s*/g, "");
  return s.trim();
}

function clampTitleLength(title, min = 6, max = 20) {
  const chars = Array.from(title || "");
  if (chars.length >= min && chars.length <= max) return title;
  if (chars.length > max) return chars.slice(0, max).join("");
  return chars.join("");
}

function generateConversationTitle(rawMessage, fallback = "对话摘要") {
  const cleaned = stripConversationTitleNoise(rawMessage);
  if (!cleaned) {
    return clampTitleLength("图片识别任务", 6, 20);
  }
  const noPunc = cleaned.replace(/[^\p{L}\p{N}\s]/gu, " ").replace(/\s+/g, " ").trim();
  const base = noPunc || cleaned;
  const chars = Array.from(base);
  if (chars.length >= 6) {
    return clampTitleLength(chars.slice(0, 20).join(""), 6, 20);
  }
  const padded = `关于${base}咨询`;
  return clampTitleLength(padded, 6, 20);
}

function clampNumber(n, min, max) {
  const x = Number(n);
  if (!Number.isFinite(x)) return null;
  return Math.min(max, Math.max(min, x));
}

function buildSSML({ textEscaped, lang, voice, style, ratePct, pitchPct }) {
  const xmlLang = normalizeLang(lang);
  const safeVoice = (voice || "").trim();
  const safeStyle = (style || "").trim();
  const rate = typeof ratePct === "number" ? `${ratePct >= 0 ? "+" : ""}${ratePct}%` : null;
  const pitch = typeof pitchPct === "number" ? `${pitchPct >= 0 ? "+" : ""}${pitchPct}%` : null;

  const core = (() => {
    const base = xmlLang.startsWith("zh") ? addNaturalPausesForZh(textEscaped) : textEscaped;
    const prosodyAttrs = [
      rate ? ` rate="${rate}"` : "",
      pitch ? ` pitch="${pitch}"` : ""
    ].join("");
    const withProsody = prosodyAttrs.trim()
      ? `<prosody${prosodyAttrs}>${base}</prosody>`
      : base;
    if (safeStyle) {
      return `<mstts:express-as style="${safeStyle}">${withProsody}</mstts:express-as>`;
    }
    return withProsody;
  })();

  return `<speak xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" version="1.0" xml:lang="${xmlLang}"><voice name="${safeVoice}">${core}</voice></speak>`;
}

const app = express();
const globalForPrisma = globalThis;
const prisma = globalForPrisma.prisma ?? new PrismaClient();
globalForPrisma.prisma = prisma;

const PORT = Number(process.env.PORT || 8080);
const JWT_SECRET = process.env.JWT_SECRET || "dev_secret";
const RESEND_API_KEY = (process.env.RESEND_API_KEY || "").trim();
const RESEND_FROM_EMAIL = (process.env.RESEND_FROM_EMAIL || "").trim();
const AUTH_DEBUG_RETURN_CODE = process.env.AUTH_DEBUG_RETURN_CODE === "1";
const GOOGLE_CLIENT_ID = (process.env.GOOGLE_CLIENT_ID || "").trim();
const GOOGLE_CLIENT_SECRET = (process.env.GOOGLE_CLIENT_SECRET || "").trim();
const DEFAULT_GOOGLE_APP_REDIRECT = "aiassistant://oauth/google";
const googleOAuthStates = new Map();
const googleOAuthTickets = new Map();

function getOllamaBaseUrl() {
  const raw = process.env.OLLAMA_API || "";
  return raw.trim().replace(/^["']|["']$/g, "").replace(/\/+$/, "");
}

function getOllamaChatModel() {
  const raw = process.env.OLLAMA_CHAT_MODEL || "qwen2.5:7b-instruct";
  return raw.trim().replace(/^["']|["']$/g, "") || "qwen2.5:7b-instruct";
}

function getOllamaTranslateModel() {
  const raw = process.env.OLLAMA_TRANSLATE_MODEL || "qwen2.5:3b";
  return raw.trim().replace(/^["']|["']$/g, "") || "qwen2.5:3b";
}

function getOllamaNoteModel() {
  const raw = process.env.OLLAMA_NOTE_MODEL || "";
  return raw.trim().replace(/^["']|["']$/g, "") || getOllamaChatModel();
}

function getOllamaSummaryModel() {
  const raw = process.env.OLLAMA_SUMMARY_MODEL || "";
  return raw.trim().replace(/^["']|["']$/g, "") || getOllamaChatModel();
}

const MEMORY_CATEGORY_SET = new Set(["preference", "habit", "goal"]);

function normalizeMemoryCategory(category) {
  const raw = String(category || "").trim().toLowerCase();
  if (raw === "fact") return "preference";
  if (MEMORY_CATEGORY_SET.has(raw)) return raw;
  return "preference";
}

function clampConfidence(value, fallback = 0.65) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(1, Math.max(0.2, n));
}

function defaultTTLByCategory(category) {
  switch (normalizeMemoryCategory(category)) {
    case "habit":
      return 180;
    case "goal":
      return 0; // 长期目标默认不过期
    case "preference":
    default:
      return 365;
  }
}

function computeExpiresAt(category, ttlDays) {
  const n = Number(ttlDays);
  const days = Number.isFinite(n) ? Math.max(0, Math.min(3650, Math.round(n))) : defaultTTLByCategory(category);
  if (days <= 0) return null;
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
}

async function llmChatWithModel(model, messages) {
  const ollamaBase = getOllamaBaseUrl();
  if (!ollamaBase) {
    throw new Error("请配置 OLLAMA_API（例如：https://xxxxx.ngrok-free.dev）");
  }
  const res = await fetch(`${ollamaBase}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages,
      stream: false
    })
  });
  const raw = await res.text().catch(() => "");
  const data = (() => {
    try {
      return JSON.parse(raw);
    } catch {
      return {};
    }
  })();
  if (res.ok) {
    const content = data?.message?.content;
    if (content) return content.trim();
  }
  const errMsg = data?.error || data?.message || raw || `HTTP ${res.status}`;
  throw new Error(`Ollama API 错误: ${res.status} ${String(errMsg).slice(0, 200)}`);
}

async function llmChat(messages) {
  return llmChatWithModel(getOllamaChatModel(), messages);
}

/** 从最近一轮对话中提取可长期记忆的用户信息，返回 { content, category, confidence, ttlDays, source }[] */
async function extractMemoriesFromConversation(userMessage, assistantReply) {
  const ollamaBase = getOllamaBaseUrl();
  if (!ollamaBase) return [];
  const prompt = `你是一个记忆提取助手。根据下面这一轮对话，只提取值得长期记住的用户信息。每条用一行中文，格式必须为：
类别|置信度|有效期天数|内容
其中：
- 类别只能是 preference、habit、goal
- 置信度为 0~1 小数（例如 0.82）
- 有效期天数：0 表示长期不过期；否则 1~3650
- 内容要短、可复用，不要完整复述对话
若没有任何值得长期记忆的信息，只输出：无

用户：${(userMessage || "").slice(0, 800)}
助理：${(assistantReply || "").slice(0, 800)}`;
  try {
    const out = await llmChat([
      { role: "system", content: "只输出上述格式的条目或「无」，不要其他解释。" },
      { role: "user", content: prompt }
    ]);
    const lines = (out || "")
      .split(/\n/)
      .map((s) => s.trim())
      .filter((s) => s && s !== "无" && /^(preference|habit|goal)\|/i.test(s));
    return lines
      .map((line) => {
        const parts = line.split("|").map((s) => s.trim());
        const category = normalizeMemoryCategory(parts[0]);
        const confidence = clampConfidence(parts[1], category === "goal" ? 0.78 : 0.7);
        const ttlDays = Number(parts[2]);
        const content = String(parts.slice(3).join("|") || "").trim().slice(0, 500);
        if (!content) return null;
        return {
          content,
          category,
          confidence,
          ttlDays: Number.isFinite(ttlDays) ? Math.max(0, Math.min(3650, Math.round(ttlDays))) : defaultTTLByCategory(category),
          source: "auto_extract"
        };
      })
      .filter(Boolean);
  } catch (e) {
    console.warn("extractMemoriesFromConversation error:", e?.message);
    return [];
  }
}

/** 基于最近多轮对话自动总结长期记忆，减少噪音 */
async function summarizeConversationMemories(windowMessages) {
  if (!Array.isArray(windowMessages) || windowMessages.length < 4) return [];
  const compact = windowMessages
    .slice(-12)
    .map((m) => `${m.role === "user" ? "用户" : "助理"}：${String(m.content || "").slice(0, 300)}`)
    .join("\n");
  const prompt = `你是一个长期记忆总结助手。根据最近多轮对话，提取“稳定且长期有价值”的用户信息。
每行格式必须为：类别|置信度|有效期天数|内容
要求：
- 类别仅可为 preference、habit、goal
- 只输出 0~3 条，宁缺毋滥
- 置信度建议 >= 0.72
- 有效期：habit 推荐 120~365，preference 推荐 180~730，goal 推荐 0
- 若没有可写入长期记忆的内容，只输出：无

对话窗口：
${compact}`;
  try {
    const out = await llmChat([
      { role: "system", content: "你只输出指定格式，不要解释。" },
      { role: "user", content: prompt }
    ]);
    const lines = (out || "")
      .split(/\n/)
      .map((s) => s.trim())
      .filter((s) => s && s !== "无" && /^(preference|habit|goal)\|/i.test(s))
      .slice(0, 3);
    return lines
      .map((line) => {
        const parts = line.split("|").map((s) => s.trim());
        const category = normalizeMemoryCategory(parts[0]);
        const confidence = clampConfidence(parts[1], 0.78);
        const ttlDays = Number(parts[2]);
        const content = String(parts.slice(3).join("|") || "").trim().slice(0, 500);
        if (!content || confidence < 0.72) return null;
        return {
          content,
          category,
          confidence,
          ttlDays: Number.isFinite(ttlDays) ? Math.max(0, Math.min(3650, Math.round(ttlDays))) : defaultTTLByCategory(category),
          source: "auto_summary"
        };
      })
      .filter(Boolean);
  } catch (e) {
    console.warn("summarizeConversationMemories error:", e?.message);
    return [];
  }
}

async function cleanupExpiredMemories(userId) {
  if (!userId) return;
  await prisma.userMemory.deleteMany({
    where: {
      userId,
      expiresAt: { lt: new Date() }
    }
  });
}

async function upsertUserMemories(userId, items = []) {
  if (!userId || !Array.isArray(items) || items.length === 0) return;
  for (const item of items) {
    const content = String(item?.content || "").trim().slice(0, 500);
    if (!content || content.length < 2) continue;
    const category = normalizeMemoryCategory(item?.category);
    const confidence = clampConfidence(item?.confidence, category === "goal" ? 0.78 : 0.65);
    const expiresAt = computeExpiresAt(category, item?.ttlDays);
    const source = String(item?.source || "manual").trim().toLowerCase();
    const existing = await prisma.userMemory.findFirst({
      where: { userId, content }
    });
    if (!existing) {
      await prisma.userMemory.create({
        data: { userId, content, category, confidence, expiresAt, source }
      });
    } else {
      await prisma.userMemory.update({
        where: { id: existing.id },
        data: {
          category,
          confidence: Math.max(existing.confidence || 0, confidence),
          expiresAt: expiresAt || existing.expiresAt,
          source
        }
      });
    }
  }
}

// 专用于翻译的模型调用：走本地/自建 Ollama，避免和聊天共用模型
async function llmTranslate(messages) {
  const ollamaBase = getOllamaBaseUrl();
  if (!ollamaBase) {
    throw new Error("请配置 OLLAMA_API（例如：https://xxxxx.ngrok-free.dev）");
  }
  const res = await fetch(`${ollamaBase}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: getOllamaTranslateModel(),
      messages,
      stream: false
    })
  });
  const raw = await res.text().catch(() => "");
  const data = (() => {
    try {
      return JSON.parse(raw);
    } catch {
      return {};
    }
  })();
  if (!res.ok) {
    const msg = data?.error?.message || data?.message || raw || `HTTP ${res.status}`;
    throw new Error(msg);
  }

  const translated = data?.message?.content || "";
  if (!translated || typeof translated !== "string") {
    throw new Error("本地模型返回为空");
  }
  return translated;
}

/// 支持图片的 AI 对话（使用 vision 模型）
async function llmChatWithImage(messages, imageBase64, userPrompt) {
  const textOnlyFallback = [
    ...messages,
    {
      role: "system",
      content:
        "用户上传了图片（base64 已接收），但当前模型为文本模型。请基于用户文字需求提供可执行建议，并明确说明无法直接读取图片内容。"
    },
    { role: "user", content: userPrompt || "请帮我分析这张图" }
  ];
  return llmChat(textOnlyFallback);
}

app.use(cors({ origin: process.env.CORS_ORIGIN || "*" }));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));
app.use(morgan("dev"));

function signToken(user) {
  return jwt.sign({ sub: user.id, email: user.email, phone: user.phone }, JWT_SECRET, {
    expiresIn: "7d"
  });
}

function cleanupOAuthStore() {
  const now = Date.now();
  for (const [k, v] of googleOAuthStates.entries()) {
    if (v.expiresAt <= now) googleOAuthStates.delete(k);
  }
  for (const [k, v] of googleOAuthTickets.entries()) {
    if (v.expiresAt <= now) googleOAuthTickets.delete(k);
  }
}

function getRequestOrigin(req) {
  const proto = (req.headers["x-forwarded-proto"] || req.protocol || "https").toString().split(",")[0].trim();
  const host = (req.headers["x-forwarded-host"] || req.headers.host || "").toString().split(",")[0].trim();
  if (!host) return "";
  return `${proto}://${host}`;
}

function appendQuery(urlText, key, value) {
  const url = new URL(urlText);
  url.searchParams.set(key, value);
  return url.toString();
}

function resolvePostAuthRedirect(raw, req) {
  const fallback = DEFAULT_GOOGLE_APP_REDIRECT;
  if (!raw || typeof raw !== "string") return fallback;
  try {
    const candidate = new URL(raw);
    if (candidate.protocol === "aiassistant:") return candidate.toString();
    const origin = getRequestOrigin(req);
    if (origin && `${candidate.protocol}//${candidate.host}` === origin) return candidate.toString();
    return fallback;
  } catch {
    return fallback;
  }
}

async function sendVerificationEmail(email, code, purpose) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    throw new Error("EMAIL_SERVICE_NOT_CONFIGURED");
  }
  const subject = purpose === "register" ? "注册验证码" : "登录验证码";
  const html = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #1f2937;">
      <h2 style="margin: 0 0 12px;">AI 全能助理 验证码</h2>
      <p style="margin: 0 0 8px;">您本次${purpose === "register" ? "注册" : "登录"}的验证码是：</p>
      <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px; margin: 8px 0 14px;">${code}</p>
      <p style="margin: 0; color: #6b7280;">验证码 10 分钟内有效，请勿泄露给他人。</p>
    </div>
  `;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to: [email],
      subject,
      html
    })
  });
  if (!res.ok) {
    const raw = await res.text().catch(() => "");
    throw new Error(`EMAIL_SEND_FAILED:${res.status}:${raw.slice(0, 200)}`);
  }
}

async function upsertSocialUser({ provider, providerUserId, email, displayName }) {
  let providerRecord = await prisma.authProvider.findUnique({
    where: { provider_providerUserId: { provider, providerUserId } },
    include: { user: true }
  });
  if (providerRecord) {
    const updated = await prisma.user.update({
      where: { id: providerRecord.user.id },
      data: { lastLoginAt: new Date() }
    });
    return updated;
  }

  const normalizedEmail = email ? email.toLowerCase() : null;
  let user = null;
  if (normalizedEmail) {
    user = await prisma.user.findUnique({ where: { email: normalizedEmail } });
  }
  if (!user) {
    user = await prisma.user.create({
      data: {
        email: normalizedEmail,
        displayName
      }
    });
  }
  await prisma.authProvider.create({
    data: {
      provider,
      providerUserId,
      email: normalizedEmail,
      userId: user.id
    }
  });
  const updated = await prisma.user.update({
    where: { id: user.id },
    data: { lastLoginAt: new Date() }
  });
  return updated;
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

// 管理员权限检查中间件
async function adminMiddleware(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: "UNAUTHORIZED" });
  }
  const user = await prisma.user.findUnique({
    where: { id: req.user.sub }
  });
  if (!user || (user.role !== "admin" && user.role !== "super_admin")) {
    return res.status(403).json({ error: "FORBIDDEN" });
  }
  req.userRole = user.role;
  return next();
}

// 超级管理员权限检查中间件
async function superAdminMiddleware(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: "UNAUTHORIZED" });
  }
  const user = await prisma.user.findUnique({
    where: { id: req.user.sub }
  });
  if (!user || user.role !== "super_admin") {
    return res.status(403).json({ error: "FORBIDDEN" });
  }
  return next();
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
  const ollamaBase = getOllamaBaseUrl();
  res.json({
    status: "ok",
    time: new Date().toISOString(),
    ollama_configured: !!ollamaBase,
    chat_model: getOllamaChatModel(),
    translate_model: getOllamaTranslateModel(),
    hint: !ollamaBase ? "在 Vercel 项目 Settings → Environment Variables 添加 OLLAMA_API 并 Redeploy" : undefined
  });
});

const registerSchema = z.object({
  email: z.string().email(),
  code: z.string().min(4).max(10),
  // 密码改为可选：主要使用邮箱验证码登录，后续如需密码可扩展
  password: z.string().min(6).optional(),
  displayName: z.string().min(1)
});

const emailCodeSchema = z.object({
  email: z.string().email(),
  purpose: z.enum(["login", "register"])
});

async function verifyEmailCode(email, code, purpose) {
  const now = new Date();
  const record = await prisma.emailVerificationCode.findFirst({
    where: {
      email: email.toLowerCase(),
      purpose,
      expiresAt: { gt: now },
      usedAt: null
    },
    orderBy: { createdAt: "desc" }
  });
  if (!record) return false;
  if (record.code !== code) return false;
  await prisma.emailVerificationCode.update({
    where: { id: record.id },
    data: { usedAt: now }
  });
  return true;
}

app.post("/api/auth/send-code", async (req, res) => {
  const parseResult = emailCodeSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }
  const { email, purpose } = parseResult.data;
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 分钟有效

  await prisma.emailVerificationCode.create({
    data: {
      email: email.toLowerCase(),
      code,
      purpose,
      expiresAt
    }
  });

  try {
    await sendVerificationEmail(email, code, purpose);
    return res.json({ ok: true });
  } catch (err) {
    console.error("[auth] send-code email error:", err?.message || err);
    if (AUTH_DEBUG_RETURN_CODE) {
      console.log(`[auth] send-code ${purpose} to ${email}: ${code}`);
      return res.json({ ok: true, code });
    }
    return res.status(503).json({
      error: "EMAIL_SERVICE_UNAVAILABLE",
      message: "邮件服务不可用，请稍后重试"
    });
  }
});

app.post("/api/auth/register", async (req, res) => {
  const parseResult = registerSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { email, password, displayName, code } = parseResult.data;

  const ok = await verifyEmailCode(email, code, "register");
  if (!ok) {
    return res.status(400).json({ error: "INVALID_OR_EXPIRED_CODE" });
  }

  const existingUser = await prisma.user.findFirst({
    where: {
      email
    }
  });
  if (existingUser) {
    return res.status(409).json({ error: "USER_EXISTS" });
  }

  const passwordHash = password ? await bcrypt.hash(password, 10) : null;
  const user = await prisma.user.create({
    data: {
      email,
      phone: null,
      passwordHash,
      displayName
    }
  });

  return res.json({ token: signToken(user), user });
});

const loginSchema = z.object({
  account: z.string().min(3).optional(),
  password: z.string().min(6).optional(),
  email: z.string().email().optional(),
  code: z.string().min(4).max(10).optional()
});

app.post("/api/auth/login", async (req, res) => {
  const parseResult = loginSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { account, password, email, code } = parseResult.data;

  // 优先邮箱 + 验证码登录
  if (email && code) {
    const okCode = await verifyEmailCode(email, code, "login");
    if (!okCode) {
      return res.status(400).json({ error: "INVALID_OR_EXPIRED_CODE" });
    }
    let user = await prisma.user.findFirst({
      where: { email }
    });
    if (!user) {
      // 首次登录，自动创建账号
      const nameFromEmail = email.split("@")[0] || "新用户";
      user = await prisma.user.create({
        data: {
          email,
          displayName: nameFromEmail.slice(0, 20)
        }
      });
    }
    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() }
    });
    return res.json({ token: signToken(updated), user: updated });
  }

  // 兼容旧版：账号 + 密码登录（邮箱或手机号）
  if (!account || !password) {
    return res.status(400).json({ error: "ACCOUNT_OR_CODE_REQUIRED" });
  }

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
  const user = await upsertSocialUser({
    provider,
    providerUserId,
    email,
    displayName
  });
  return res.json({ token: signToken(user), user });
});

app.get("/api/auth/google/start", async (req, res) => {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    return res.status(503).json({ error: "GOOGLE_OAUTH_NOT_CONFIGURED" });
  }
  cleanupOAuthStore();
  const state = nanoid(36);
  const postAuthRedirect = resolvePostAuthRedirect(req.query.redirect_uri, req);
  const serverOrigin = getRequestOrigin(req);
  if (!serverOrigin) {
    return res.status(400).json({ error: "INVALID_SERVER_ORIGIN" });
  }
  const callbackURL = `${serverOrigin}/api/auth/google/callback`;
  googleOAuthStates.set(state, {
    postAuthRedirect,
    callbackURL,
    expiresAt: Date.now() + 10 * 60 * 1000
  });

  const authURL = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  authURL.searchParams.set("client_id", GOOGLE_CLIENT_ID);
  authURL.searchParams.set("redirect_uri", callbackURL);
  authURL.searchParams.set("response_type", "code");
  authURL.searchParams.set("scope", "openid email profile");
  authURL.searchParams.set("state", state);
  authURL.searchParams.set("prompt", "select_account");
  authURL.searchParams.set("access_type", "offline");
  return res.redirect(authURL.toString());
});

app.get("/api/auth/google/callback", async (req, res) => {
  cleanupOAuthStore();
  const state = String(req.query.state || "");
  const code = String(req.query.code || "");
  const oauthError = String(req.query.error || "");
  const stateEntry = googleOAuthStates.get(state);
  googleOAuthStates.delete(state);
  const fallbackRedirect = DEFAULT_GOOGLE_APP_REDIRECT;
  if (!stateEntry) {
    return res.redirect(appendQuery(fallbackRedirect, "error", "invalid_state"));
  }
  const postAuthRedirect = stateEntry.postAuthRedirect || fallbackRedirect;
  if (oauthError) {
    return res.redirect(appendQuery(postAuthRedirect, "error", oauthError));
  }
  if (!code) {
    return res.redirect(appendQuery(postAuthRedirect, "error", "missing_code"));
  }

  try {
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: GOOGLE_CLIENT_ID,
        client_secret: GOOGLE_CLIENT_SECRET,
        redirect_uri: stateEntry.callbackURL,
        grant_type: "authorization_code"
      })
    });
    if (!tokenRes.ok) {
      const raw = await tokenRes.text().catch(() => "");
      throw new Error(`GOOGLE_TOKEN_EXCHANGE_FAILED:${tokenRes.status}:${raw.slice(0, 160)}`);
    }
    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token;
    if (!accessToken) throw new Error("GOOGLE_ACCESS_TOKEN_MISSING");

    const userRes = await fetch("https://openidconnect.googleapis.com/v1/userinfo", {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    if (!userRes.ok) {
      const raw = await userRes.text().catch(() => "");
      throw new Error(`GOOGLE_USERINFO_FAILED:${userRes.status}:${raw.slice(0, 160)}`);
    }
    const profile = await userRes.json();
    const providerUserId = String(profile.sub || "").trim();
    if (!providerUserId) throw new Error("GOOGLE_SUB_MISSING");
    const email = typeof profile.email === "string" ? profile.email.toLowerCase() : null;
    const displayName = String(profile.name || profile.given_name || "Google用户").trim().slice(0, 40) || "Google用户";
    const user = await upsertSocialUser({
      provider: "GOOGLE",
      providerUserId,
      email,
      displayName
    });
    const ticket = crypto.randomUUID();
    googleOAuthTickets.set(ticket, {
      auth: { token: signToken(user), user },
      expiresAt: Date.now() + 2 * 60 * 1000
    });
    return res.redirect(appendQuery(postAuthRedirect, "ticket", ticket));
  } catch (err) {
    console.error("[auth] google callback error:", err?.message || err);
    return res.redirect(appendQuery(postAuthRedirect, "error", "oauth_failed"));
  }
});

app.get("/api/auth/google/result", async (req, res) => {
  cleanupOAuthStore();
  const ticket = String(req.query.ticket || "");
  if (!ticket) return res.status(400).json({ error: "MISSING_TICKET" });
  const payload = googleOAuthTickets.get(ticket);
  if (!payload) return res.status(400).json({ error: "INVALID_OR_EXPIRED_TICKET" });
  googleOAuthTickets.delete(ticket);
  return res.json(payload.auth);
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

// ---------- 会话同步（跨设备） ----------
app.get("/api/conversations", authMiddleware, async (req, res) => {
  const takeRaw = Number(req.query.take || 20);
  const take = Number.isFinite(takeRaw) ? Math.min(Math.max(takeRaw, 1), 100) : 20;
  const list = await prisma.conversation.findMany({
    where: { userId: req.user.sub },
    orderBy: { lastMessageAt: "desc" },
    take,
    include: {
      messages: {
        orderBy: { createdAt: "desc" },
        take: 1
      }
    }
  });

  return res.json({
    conversations: list.map((c) => ({
      id: c.id,
      title: c.title,
      createdAt: c.createdAt.toISOString(),
      updatedAt: c.lastMessageAt?.toISOString?.() || c.messages[0]?.createdAt?.toISOString?.() || c.createdAt.toISOString(),
      lastMessage: c.messages[0]?.content || ""
    }))
  });
});

app.get("/api/conversations/:id/messages", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const conversation = await prisma.conversation.findFirst({
    where: { id, userId: req.user.sub },
    select: { id: true }
  });
  if (!conversation) {
    return res.status(404).json({ error: "会话不存在" });
  }

  const messages = await prisma.message.findMany({
    where: { conversationId: id },
    orderBy: { createdAt: "asc" }
  });

  return res.json({
    messages: messages.map((m) => ({
      id: m.id,
      role: m.role,
      content: m.content,
      time: m.createdAt.toISOString()
    }))
  });
});

app.patch("/api/conversations/:id/title", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const schema = z.object({
    title: z.string().min(6).max(20)
  });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const cleanTitle = String(parsed.data.title).trim();
  if (!cleanTitle) {
    return res.status(400).json({ error: "标题不能为空" });
  }
  const conversation = await prisma.conversation.findFirst({
    where: { id, userId: req.user.sub },
    select: { id: true }
  });
  if (!conversation) {
    return res.status(404).json({ error: "会话不存在" });
  }
  const updated = await prisma.conversation.update({
    where: { id },
    data: { title: cleanTitle }
  });
  return res.json({ ok: true, title: updated.title });
});

app.delete("/api/conversations/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const conversation = await prisma.conversation.findFirst({
    where: { id, userId: req.user.sub },
    select: { id: true }
  });
  if (!conversation) {
    return res.status(404).json({ error: "会话不存在" });
  }
  await prisma.message.deleteMany({ where: { conversationId: id } });
  await prisma.conversation.delete({ where: { id } });
  return res.json({ ok: true });
});

// 文件上传处理中间件（解析multipart/form-data）

function parseMultipartFormData(req) {
  return new Promise((resolve, reject) => {
    const formData = {};
    const chunks = [];
    
    const contentType = req.headers["content-type"] || "";
    if (!contentType.includes("multipart/form-data")) {
      return reject(new Error("Content-Type must be multipart/form-data"));
    }
    
    const boundary = contentType.split("boundary=")[1];
    if (!boundary) {
      return reject(new Error("Missing boundary in Content-Type"));
    }
    
    let buffer = Buffer.alloc(0);
    
    req.on("data", (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
    });
    
    req.on("end", () => {
      const parts = buffer.toString("binary").split(`--${boundary}`);
      
      for (const part of parts) {
        if (!part.trim() || part.includes("--")) continue;
        
        const [headers, ...bodyParts] = part.split("\r\n\r\n");
        const body = bodyParts.join("\r\n\r\n").replace(/\r\n$/, "");
        
        const nameMatch = headers.match(/name="([^"]+)"/);
        const filenameMatch = headers.match(/filename="([^"]+)"/);
        
        if (nameMatch) {
          const name = nameMatch[1];
          if (filenameMatch) {
            // 文件字段
            const filename = filenameMatch[1];
            const fileData = Buffer.from(body, "binary");
            formData[name] = { filename, data: fileData };
          } else {
            // 普通字段
            formData[name] = body.trim();
          }
        }
      }
      
      resolve(formData);
    });
    
    req.on("error", reject);
  });
}

app.post("/api/assistant/chat", optionalAuthMiddleware, async (req, res) => {
  const contentType = req.headers["content-type"] || "";
  
  // 处理文件上传（multipart/form-data）
  if (contentType.includes("multipart/form-data")) {
    try {
      const formData = await parseMultipartFormData(req);
      const message = formData.message || "";
      const file = formData.file;
      const fileName = formData.fileName || "unknown";
      const fileType = formData.fileType || "text";
      const conversationId = formData.conversationId;
      const userContext = formData.userContext ? String(formData.userContext).trim() : "";
      
      if (!file || !file.data) {
        return res.status(400).json({ error: "未提供文件" });
      }
      
      const fileData = file.data;
      let fileContent = "";
      let processedMessage = message || `请分析这个${fileType === "pdf" ? "PDF" : "文本"}文件：${fileName}`;
      
      // 根据文件类型处理
      if (fileType === "pdf") {
        // PDF文件，转换为base64发送给AI（如果支持vision）
        const base64Data = fileData.toString("base64");
        // 对于PDF，我们可以尝试提取文本或直接发送base64
        // 这里简化处理，提示用户PDF需要特殊处理
        processedMessage += `\n\n[这是一个PDF文件，文件名：${fileName}，大小：${fileData.length}字节]`;
      } else if (fileType === "text") {
        // 文本文件，直接读取内容
        try {
          fileContent = fileData.toString("utf-8");
          // 限制文本长度，避免超过token限制
          if (fileContent.length > 50000) {
            fileContent = fileContent.substring(0, 50000) + "\n\n[文件内容过长，已截断]";
          }
          processedMessage += `\n\n文件内容：\n${fileContent}`;
        } catch (err) {
          processedMessage += `\n\n[无法读取文件内容：${err.message}]`;
        }
      } else {
        // 其他类型，尝试作为文本读取
        try {
          fileContent = fileData.toString("utf-8");
          if (fileContent.length > 50000) {
            fileContent = fileContent.substring(0, 50000) + "\n\n[文件内容过长，已截断]";
          }
          processedMessage += `\n\n文件内容：\n${fileContent}`;
        } catch (err) {
          processedMessage += `\n\n[无法读取文件内容]`;
        }
      }
      
      // 创建或获取对话
      let conversation = null;
      if (req.user) {
        conversation = conversationId
          ? await prisma.conversation.findUnique({ where: { id: conversationId } })
          : await prisma.conversation.create({
              data: { userId: req.user.sub, title: generateConversationTitle(message || fileName || "文件分析") }
            });
        if (conversation) {
          await prisma.message.create({
            data: { conversationId: conversation.id, role: "user", content: `[文件: ${fileName}] ${message || "请分析这个文件"}` }
          });
          const shouldRename = !conversation.title || conversation.title.startsWith("对话-");
          if (shouldRename) {
            const title = generateConversationTitle(message || fileName || "文件分析");
            await prisma.conversation.update({
              where: { id: conversation.id },
              data: { title, lastMessageAt: new Date() }
            });
          } else {
            await prisma.conversation.update({
              where: { id: conversation.id },
              data: { lastMessageAt: new Date() }
            });
          }
        }
      }
      
      // 构建历史记录
      let history = [];
      if (conversation) {
        const rows = await prisma.message.findMany({
          where: { conversationId: conversation.id },
          orderBy: { createdAt: "asc" }
        });
        history = rows.map((m) => ({ role: m.role, content: m.content }));
      } else {
        history = [{ role: "user", content: processedMessage }];
      }
      let systemParts = ["你是专业、可靠的AI助理，请用中文简洁回答。当用户上传文件时，请仔细分析文件内容并给出有用的建议。"];
      if (userContext) {
        systemParts.push("关于当前用户（请据此个性化回答）：\n" + userContext.slice(0, 2000));
      }
      if (req.user) {
        await cleanupExpiredMemories(req.user.sub);
        const memories = await prisma.userMemory.findMany({
          where: {
            userId: req.user.sub,
            OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }]
          },
          orderBy: [{ confidence: "desc" }, { updatedAt: "desc" }],
          take: 80
        });
        if (memories.length > 0) {
          systemParts.push("已记住的关于该用户的信息（按重要度排序）：\n" + memories.map((m) => `- [${m.category}|${(m.confidence || 0.65).toFixed(2)}] ${m.content}`).join("\n"));
        }
      }
      const systemContent = systemParts.join("\n\n");
      if (!history.some((m) => m.role === "system")) {
        history.unshift({ role: "system", content: systemContent });
      } else {
        history[0] = { role: "system", content: systemContent };
      }
      // 更新最后一条消息为包含文件内容的消息
      if (history.length > 0 && history[history.length - 1].role === "user") {
        history[history.length - 1].content = processedMessage;
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
        await prisma.conversation.update({
          where: { id: conversation.id },
          data: { lastMessageAt: new Date() }
        });
      }

      if (req.user && reply) {
        try {
          const newMemories = await extractMemoriesFromConversation(processedMessage, reply);
          await upsertUserMemories(req.user.sub, newMemories);
        } catch (extractErr) {
          console.warn("File chat memory extract/save error:", extractErr?.message);
        }
      }
      
      return res.json({
        conversationId: conversation?.id ?? null,
        reply
      });
    } catch (err) {
      return res.status(400).json({ error: `文件处理失败: ${err.message}` });
    }
  }
  
  // 处理JSON请求（文本消息和图片base64）
  const schema = z.object({
    conversationId: z.string().optional(),
    message: z.string().optional(),
    image: z.string().optional(), // base64 图片
    userContext: z.string().optional(), // 未登录时客户端传来的「关于用户」的上下文（本地记忆）
    localExecution: z.boolean().optional() // 本机执行模式：助理可输出 [CMD]命令[/CMD]，由客户端执行后回传结果
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { conversationId, message, image, userContext, localExecution } = parseResult.data;
  // 至少需要 message 或 image 之一
  if ((!message || message.trim().length === 0) && !image) {
    return res.status(400).json({ error: "需要提供消息或图片" });
  }
  let conversation = null;
  const userMessageContent = message || (image ? "[图片]" : "");
  if (req.user) {
    conversation = conversationId
      ? await prisma.conversation.findUnique({ where: { id: conversationId } })
      : await prisma.conversation.create({
          data: { userId: req.user.sub, title: generateConversationTitle(userMessageContent) }
        });
    if (conversation) {
      await prisma.message.create({
        data: { conversationId: conversation.id, role: "user", content: userMessageContent }
      });
      const shouldRename = !conversation.title || conversation.title.startsWith("对话-");
      if (shouldRename) {
        const title = generateConversationTitle(userMessageContent);
        await prisma.conversation.update({
          where: { id: conversation.id },
          data: { title, lastMessageAt: new Date() }
        });
      } else {
        await prisma.conversation.update({
          where: { id: conversation.id },
          data: { lastMessageAt: new Date() }
        });
      }
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
    history = [{ role: "user", content: userMessageContent }];
  }

  // 构建系统提示：基础 + 用户上下文（未登录时的 userContext + 登录用户的云端记忆）+ 本机执行约定
  let systemParts = ["你是专业、可靠的AI助理，请用中文简洁回答。"];
  if (localExecution) {
    systemParts.push(
      "【本机执行】当前对话已开启本机执行，你要像一位真人助手一样，主动帮用户操作电脑、完成任务。请用以下能力（每次只输出一条 [CMD]...[/CMD]，执行结果会发回给你，你可继续发下一条）：\n" +
      "1) 打开应用：用户说「打开 XXX」时回复 [CMD]OPEN_APP:XXX[/CMD]（如 打开 wps → OPEN_APP:wps，打开 QQ音乐 → OPEN_APP:QQ音乐）。\n" +
      "2) 打开文件夹/文件：打开桌面/下载/文档等用 [CMD]OPEN_FOLDER:~/Desktop[/CMD]、[CMD]OPEN_FOLDER:~/Downloads[/CMD]、[CMD]OPEN_FOLDER:~/Documents[/CMD]；打开某文件用 [CMD]OPEN_FILE:路径[/CMD]（路径仅限用户目录或 /Applications 下）。\n" +
      "3) 查看本机信息：用 [CMD]命令[/CMD] 输出一条安全命令（如 ls、ls ~/Downloads、pwd、date、whoami、df -h、cat 用户目录下的某文件），根据结果再决定下一步或直接回答。\n" +
      "4) 多步任务：用户说「帮我整理下载」「看看桌面有什么」等，你先用 ls 查看，再根据结果用 OPEN_FOLDER/OPEN_FILE 打开或建议下一步，像真人助手一样一步步完成。\n" +
      "禁止：给出手动操作步骤代替 [CMD]；使用 rm、mv、sudo、格式化等危险命令。"
    );
  }
  if (userContext && String(userContext).trim()) {
    systemParts.push("关于当前用户（请据此个性化回答）：\n" + String(userContext).trim().slice(0, 2000));
  }
  if (req.user) {
    await cleanupExpiredMemories(req.user.sub);
    const memories = await prisma.userMemory.findMany({
      where: {
        userId: req.user.sub,
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }]
      },
      orderBy: [{ confidence: "desc" }, { updatedAt: "desc" }],
      take: 80
    });
    if (memories.length > 0) {
      const memoryText = memories.map((m) => `- [${m.category}|${(m.confidence || 0.65).toFixed(2)}] ${m.content}`).join("\n");
      systemParts.push("已记住的关于该用户的信息：\n" + memoryText);
    }
  }
  const systemContent = systemParts.join("\n\n");
  if (!history.some((m) => m.role === "system")) {
    history.unshift({ role: "system", content: systemContent });
  } else {
    history[0] = { role: "system", content: systemContent };
  }

  let reply;
  try {
    if (image) {
      reply = await llmChatWithImage(history, image, message || "请识别这张图片");
    } else {
      reply = await llmChat(history);
    }
  } catch (err) {
    reply = `抱歉，AI 服务暂时不可用：${err.message}`;
  }

  // 兜底：用户说「打开 XXX」且开启了本机执行时，按类型返回 OPEN_APP / OPEN_FOLDER
  if (localExecution && message && !/\[CMD\]/.test(reply)) {
    const openMatch = message.match(/(?:帮我)?打开\s+([^\s，。！？]+)/i);
    if (openMatch) {
      const raw = openMatch[1].trim().toLowerCase();
      const folderMap = { 桌面: "~/Desktop", 下载: "~/Downloads", 文档: "~/Documents", 音乐: "~/Music", 图片: "~/Pictures", 视频: "~/Movies" };
      const path = folderMap[raw] || folderMap[raw.replace(/\s/g, "")];
      if (path) {
        reply = `[CMD]OPEN_FOLDER:${path}[/CMD]`;
      } else {
        const keyword = openMatch[1].trim().replace(/\s+/g, " ").slice(0, 50);
        reply = `[CMD]OPEN_APP:${keyword}[/CMD]`;
      }
    }
  }

  if (conversation) {
    await prisma.message.create({
      data: { conversationId: conversation.id, role: "assistant", content: reply }
    });
    await prisma.conversation.update({
      where: { id: conversation.id },
      data: { lastMessageAt: new Date() }
    });
  }

  // 登录用户：从本轮对话中提取新记忆并写入
  if (req.user && reply) {
    try {
      const newMemories = await extractMemoriesFromConversation(userMessageContent, reply);
      await upsertUserMemories(req.user.sub, newMemories);

      // 每 6 条消息做一次会话窗口总结，减少噪音并沉淀长期目标
      if (conversation) {
        const messageCount = await prisma.message.count({ where: { conversationId: conversation.id } });
        if (messageCount > 0 && messageCount % 6 === 0) {
          const rows = await prisma.message.findMany({
            where: { conversationId: conversation.id },
            orderBy: { createdAt: "asc" },
            take: 12
          });
          const summaryMemories = await summarizeConversationMemories(rows.map((m) => ({ role: m.role, content: m.content })));
          await upsertUserMemories(req.user.sub, summaryMemories);
        }
      }
    } catch (extractErr) {
      console.warn("Memory extract/save error:", extractErr?.message);
    }
  }

  return res.json({
    conversationId: conversation?.id ?? null,
    reply
  });
});

app.post("/api/notes/ai", optionalAuthMiddleware, async (req, res) => {
  try {
    const prompt = String(req.body?.prompt || "").trim();
    if (!prompt) return res.status(400).json({ error: "缺少 prompt" });
    const reply = await llmChatWithModel(getOllamaNoteModel(), [
      { role: "system", content: "你是笔记整理助手，只输出用户要求的 JSON 结果。" },
      { role: "user", content: prompt }
    ]);
    return res.json({ reply });
  } catch (err) {
    return res.status(500).json({ error: err.message || "AI 处理失败" });
  }
});

app.post("/api/summaries/ai", optionalAuthMiddleware, async (req, res) => {
  try {
    const prompt = String(req.body?.prompt || "").trim();
    if (!prompt) return res.status(400).json({ error: "缺少 prompt" });
    const reply = await llmChatWithModel(getOllamaSummaryModel(), [
      { role: "system", content: "你是内容总结助手，只输出用户要求的 JSON 结果。" },
      { role: "user", content: prompt }
    ]);
    return res.json({ reply });
  } catch (err) {
    return res.status(500).json({ error: err.message || "AI 处理失败" });
  }
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

    // 本接口仅做中文与印尼文互译，禁止任何问答，仅输出与原文对应的翻译
    const systemPrompt =
      `你是一个纯翻译引擎，仅做中文与印尼文互译。禁止任何问答、解释、自我介绍或额外句子，仅输出与用户输入对应的翻译。\n` +
      `规则（必须遵守）：\n` +
      `1）只把用户给的整段从${s}译成${t}，输出仅该句/段的翻译，无任何其他内容。\n` +
      `2）疑问句只译成疑问句，绝不回答。例：输入「你是谁？」只输出「Siapa kamu?」或「Siapa Anda?」；输入「你是什么模型？」只输出「Kamu model apa?」或「Model apa kamu?」。禁止输出「Saya adalah...」「我是...」「dikembangkan oleh」等任何回答。\n` +
      `3）请求/祈使句只译成请求/祈使句，绝不回答。例：输入「帮我看看合同有没有问题」只输出「Bantu saya periksa apakah kontrak ini ada masalah」。禁止输出「我需要看到…」「Saya perlu melihat...」「请提供」等。\n` +
      `4）输出长度与原文相当，禁止成段解释或补充。`;
    translated = await llmTranslate([
      { role: "system", content: systemPrompt },
      { role: "user", content: text }
    ]);

    const out = (translated || "").trim();
    // 禁止出现的回答式句式：一旦出现即视为违规，重试为纯翻译
    const answerPhrases =
      /saya adalah|i am|我是|i'm|dikembangkan oleh|developed by|perusahaan teknologi|technology company|meta|openai|我需要|请提供|我没看到|i need to see|please provide|silakan berikan|saya perlu melihat/i;
    const looksLikeAnswer = answerPhrases.test(out);
    if (looksLikeAnswer) {
      const strictUser =
        targetLang === "id-ID"
          ? `Translate the following to Indonesian only. Output ONLY the translation, one short sentence. Do not answer the question, do not introduce yourself, do not explain.\n\n${text}`
          : `Translate the following to Chinese only. Output ONLY the translation, one short sentence. Do not answer the question, do not introduce yourself, do not explain.\n\n${text}`;
      translated = await llmTranslate([
        { role: "system", content: "You are a translator. Output ONLY the translation of the user's text. No answer, no self-introduction, no explanation. One short sentence only." },
        { role: "user", content: strictUser }
      ]);
    }
    const out2 = (translated || "").trim();
    const hasChinese = /[\u4e00-\u9fff]/.test(out2);
    const hasLatin = /[A-Za-z]/.test(out2);
    if (targetLang === "id-ID" && hasChinese) {
      translated = await llmTranslate([
        { role: "system", content: "Output ONLY the Indonesian translation. No Chinese characters, no explanation." },
        { role: "user", content: text }
      ]);
    } else if (targetLang === "zh-CN" && !hasChinese && hasLatin) {
      translated = await llmTranslate([
        { role: "system", content: "Output ONLY the Chinese translation. No English/Indonesian, no explanation." },
        { role: "user", content: text }
      ]);
    }
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

  return res.json({ translated, translation: translated });
});

// 保存翻译历史
app.post("/api/translations", authMiddleware, async (req, res) => {
  const schema = z.object({
    sourceLang: z.string().min(2),
    targetLang: z.string().min(2),
    sourceText: z.string().min(1),
    targetText: z.string().min(1)
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }

  const { sourceLang, targetLang, sourceText, targetText } = parseResult.data;

  await prisma.translationHistory.create({
    data: {
      userId: req.user.sub,
      sourceLang,
      targetLang,
      sourceText,
      targetText
    }
  });

  return res.json({ success: true });
});

// 获取翻译历史
app.get("/api/translations", authMiddleware, async (req, res) => {
  const translations = await prisma.translationHistory.findMany({
    where: { userId: req.user.sub },
    orderBy: { createdAt: "desc" },
    take: 100 // 限制返回100条
  });

  return res.json({
    translations: translations.map((t) => ({
      id: t.id,
      sourceLang: t.sourceLang,
      targetLang: t.targetLang,
      sourceText: t.sourceText,
      targetText: t.targetText,
      createdAt: t.createdAt.toISOString()
    }))
  });
});

// 保存笔记
app.post("/api/notes", authMiddleware, async (req, res) => {
  const schema = z.object({
    title: z.string().min(1),
    summary: z.string().min(1),
    category: z.string().min(1),
    tags: z.array(z.string()).optional().default([]),
    content: z.string().min(1),
    rawText: z.string().min(1),
    reminderAt: z.string().optional().nullable(),
    reminderText: z.string().optional().nullable(),
    reminderSnoozeHours: z.number().int().optional().nullable()
  });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const data = parsed.data;
  const reminderAt = data.reminderAt ? new Date(data.reminderAt) : null;

  const note = await prisma.note.create({
    data: {
      userId: req.user.sub,
      title: data.title,
      summary: data.summary,
      category: data.category,
      tags: data.tags,
      content: data.content,
      rawText: data.rawText,
      reminderAt,
      reminderText: data.reminderText || null,
      reminderSnoozeHours: data.reminderSnoozeHours ?? null
    }
  });

  return res.json({ id: note.id });
});

// 保存总结
app.post("/api/summaries", authMiddleware, async (req, res) => {
  const schema = z.object({
    title: z.string().min(1),
    summary: z.string().min(1),
    category: z.string().min(1),
    tags: z.array(z.string()).optional().default([]),
    content: z.string().min(1),
    rawText: z.string().min(1)
  });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const data = parsed.data;

  const summary = await prisma.summary.create({
    data: {
      userId: req.user.sub,
      title: data.title,
      summary: data.summary,
      category: data.category,
      tags: data.tags,
      content: data.content,
      rawText: data.rawText
    }
  });

  return res.json({ id: summary.id });
});

app.post("/api/tts", async (req, res) => {
  const schema = z.object({
    text: z.string().min(1).max(TTS_MAX_LENGTH),
    lang: z.string().min(2).max(10).optional(),
    // 可选：自定义音色/情感与韵律（都免费，走 Edge 神经网络语音）
    voice: z.string().min(3).max(80).optional(),
    style: z.string().regex(/^[A-Za-z0-9_-]{1,32}$/).optional(),
    // -30 ~ +30（百分比），越大越快/越高
    rate: z.number().min(-30).max(30).optional(),
    pitch: z.number().min(-30).max(30).optional()
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }
  const { text, lang, voice: voiceOverride, style, rate, pitch } = parseResult.data;
  const langNorm = normalizeLang(lang || "zh-CN");
  const voice = (voiceOverride && String(voiceOverride).trim()) ? String(voiceOverride).trim() : getTTSVoice(langNorm);
  const safeText = escapeTTS(text);
  if (!safeText) return res.status(400).json({ error: "text required" });

  // 默认策略：中文使用更“聊天感”的风格（若不支持会自动回退）
  const defaultStyle = (() => {
    if (style) return style;
    if (langNorm.startsWith("zh") && voice === "zh-CN-XiaoxiaoNeural") return "chat";
    return "";
  })();

  const ratePct = clampNumber(rate, -30, 30);
  const pitchPct = clampNumber(pitch, -30, 30);
  const ssml = buildSSML({
    textEscaped: safeText,
    lang: langNorm,
    voice,
    style: defaultStyle,
    ratePct: ratePct ?? undefined,
    pitchPct: pitchPct ?? undefined
  });
  try {
    const tts = new MsEdgeTTS({});
    await tts.setMetadata(voice, OUTPUT_FORMAT.WEBM_24KHZ_16BIT_MONO_OPUS);
    let readable;
    try {
      // 优先走 SSML（更自然：停顿/语气/韵律）
      readable = tts.toStream(ssml);
    } catch (e) {
      // 若风格/SSML 不被该音色支持，则回退为纯文本
      readable = tts.toStream(safeText);
    }
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
    include: { items: { orderBy: { id: "asc" } } }
  });

  return res.json({ categories });
});

app.get("/api/learning/favorites", authMiddleware, async (req, res) => {
  const list = await prisma.favorite.findMany({
    where: { userId: req.user.sub },
    select: { vocabId: true },
    orderBy: { createdAt: "desc" }
  });

  return res.json({ favorites: list.map((f) => f.vocabId) });
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

// ---------- 助理长期记忆（自主学习与个性化） ----------
app.get("/api/user/memory", authMiddleware, async (req, res) => {
  await cleanupExpiredMemories(req.user.sub);
  const list = await prisma.userMemory.findMany({
    where: {
      userId: req.user.sub,
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }]
    },
    orderBy: [{ confidence: "desc" }, { updatedAt: "desc" }],
    take: 200
  });
  return res.json({
    memories: list.map((m) => ({
      id: m.id,
      content: m.content,
      category: m.category,
      confidence: m.confidence,
      expiresAt: m.expiresAt ? m.expiresAt.toISOString() : null,
      source: m.source,
      updatedAt: m.updatedAt.toISOString(),
      createdAt: m.createdAt.toISOString()
    }))
  });
});

app.post("/api/user/memory", authMiddleware, async (req, res) => {
  const schema = z.object({
    memories: z.array(z.object({
      content: z.string().min(1).max(500),
      category: z.enum(["preference", "habit", "goal", "fact"]).optional(),
      confidence: z.number().min(0).max(1).optional(),
      ttlDays: z.number().int().min(0).max(3650).optional(),
      source: z.enum(["manual", "auto_extract", "auto_summary"]).optional()
    })).max(50)
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }
  const { memories } = parseResult.data;
  await upsertUserMemories(req.user.sub, memories);
  return res.json({ success: true });
});

app.delete("/api/user/memory/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  await prisma.userMemory.deleteMany({
    where: { id, userId: req.user.sub }
  });
  return res.json({ success: true });
});

// ---------- 用户整体使用统计（对话 / 翻译 / 学习） ----------
app.get("/api/user/stats", authMiddleware, async (req, res) => {
  const userId = req.user.sub;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [totalConversations, totalTranslations, totalLearningAgg, learningSessions] = await Promise.all([
    prisma.conversation.count({ where: { userId } }),
    prisma.translationHistory.count({ where: { userId } }),
    prisma.learningSession.aggregate({
      _sum: { minutes: true },
      where: { userId }
    }),
    prisma.learningSession.count({ where: { userId } })
  ]);

  const [todayConversations, todayTranslations, todayLearningAgg] = await Promise.all([
    prisma.conversation.count({
      where: { userId, createdAt: { gte: today } }
    }),
    prisma.translationHistory.count({
      where: { userId, createdAt: { gte: today } }
    }),
    prisma.learningSession.aggregate({
      _sum: { minutes: true },
      where: { userId, sessionDate: { gte: today } }
    })
  ]);

  const totalLearningMinutes = totalLearningAgg?._sum?.minutes || 0;
  const todayLearningMinutes = todayLearningAgg?._sum?.minutes || 0;

  return res.json({
    todayConversations,
    todayTranslations,
    todayLearningMinutes,
    totalConversations,
    totalTranslations,
    totalLearningMinutes,
    learningSessions
  });
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
