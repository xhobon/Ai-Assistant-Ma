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

function getGroqApiKey() {
  const raw = process.env.GROQ_API_KEY || "";
  const key = raw.trim().replace(/^["']|["']$/g, "");
  return key.length > 10 ? key : null;
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

/** 从最近一轮对话中提取可长期记忆的用户信息（偏好、习惯、重要事实），返回 { content, category }[] */
async function extractMemoriesFromConversation(userMessage, assistantReply) {
  const groqKey = getGroqApiKey();
  if (!groqKey || groqKey.length <= 10) return [];
  const prompt = `你是一个记忆提取助手。根据下面这一轮对话，提取值得长期记住的、关于用户的信息（例如：偏好、习惯、重要事实、称呼、工作/生活背景等）。每条用一行简短中文描述，格式为：类别|内容。类别只能是 preference、habit、fact 之一。
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
      .filter((s) => s && s !== "无" && /^(preference|habit|fact)\|/.test(s));
    return lines.map((line) => {
      const idx = line.indexOf("|");
      const category = idx > 0 ? line.slice(0, idx).toLowerCase() : "fact";
      const content = (idx > 0 ? line.slice(idx + 1) : line).trim().slice(0, 500);
      return { content, category: ["preference", "habit", "fact"].includes(category) ? category : "fact" };
    });
  } catch (e) {
    console.warn("extractMemoriesFromConversation error:", e?.message);
    return [];
  }
}

// 专用于翻译的模型调用：走千问（DashScope）免费/低价模型，避免和聊天共用 Groq
async function llmTranslate(messages) {
  const qwenKeyRaw = process.env.QWEN_API_KEY || process.env.DASHSCOPE_API_KEY || "";
  const qwenKey = qwenKeyRaw.trim().replace(/^["']|["']$/g, "");
  if (!qwenKey || qwenKey.length < 10) {
    throw new Error(
      "请配置 QWEN_API_KEY（千问 Model Studio 的 API Key）。在 .env/.env.local 与 Vercel 环境变量中设置 QWEN_API_KEY 后重新部署。"
    );
  }
  const baseURL = (process.env.QWEN_BASE_URL || "https://dashscope.aliyuncs.com/compatible-mode/v1").replace(/\/+$/, "");
  const model = process.env.QWEN_TRANSLATE_MODEL || "qwen-plus";

  const res = await fetch(`${baseURL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${qwenKey}`
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: 0 // 纯翻译，尽量减少生成花样
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
  return data?.choices?.[0]?.message?.content || "";
}

/// 支持图片的 AI 对话（使用 vision 模型）
async function llmChatWithImage(messages, imageBase64, userPrompt) {
  const groqKey = getGroqApiKey();
  if (!groqKey || groqKey.length <= 10) {
    throw new Error(
      "请配置 GROQ_API_KEY（免费）：访问 https://console.groq.com 注册，创建 API Key，在 Vercel 环境变量中添加 GROQ_API_KEY，并 Redeploy"
    );
  }
  
  // 构建包含图片的消息
  // Groq 目前可能不支持 vision 模型，先尝试使用支持 vision 的模型
  // 如果失败，回退到文本描述
  const imageUrl = `data:image/jpeg;base64,${imageBase64}`;
  
  // 修改最后一条用户消息，添加图片
  const lastMessage = messages[messages.length - 1];
  const messagesWithImage = [
    ...messages.slice(0, -1),
    {
      role: lastMessage.role,
      content: [
        { type: "text", text: userPrompt },
        { type: "image_url", image_url: { url: imageUrl } }
      ]
    }
  ];
  
  // 尝试使用 vision 模型（如果 Groq 支持）
  // 注意：Groq 可能还没有 vision 模型，这里先尝试
  const visionModels = [
    "llama-3.2-11b-vision-preview",
    "llama-3.1-8b-instant" // 回退模型
  ];
  
  for (const model of visionModels) {
    try {
      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqKey}`
        },
        body: JSON.stringify({
          model: model,
          messages: messagesWithImage,
          temperature: 0.4,
          max_tokens: 2048
        })
      });
      
      const raw = await res.text().catch(() => "");
      const data = (() => { try { return JSON.parse(raw); } catch { return {}; } })();
      
      if (res.ok) {
        const content = data?.choices?.[0]?.message?.content;
        if (content) return content.trim();
      }
      
      // 如果模型不支持，尝试下一个
      if (res.status === 400 && data?.error?.message?.includes("vision")) {
        continue;
      }
      
      const errMsg = data?.error?.message || data?.error || raw || `HTTP ${res.status}`;
      throw new Error(`Groq API 错误: ${res.status} ${String(errMsg).slice(0, 200)}`);
    } catch (err) {
      // 如果是最后一个模型，抛出错误
      if (model === visionModels[visionModels.length - 1]) {
        throw err;
      }
      // 否则继续尝试下一个模型
      continue;
    }
  }
  
  // 如果所有模型都失败，返回提示
  throw new Error("当前 Groq API 暂不支持图片识别，请稍后再试或联系管理员。");
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
  const groqKey = getGroqApiKey();
  res.json({
    status: "ok",
    time: new Date().toISOString(),
    groq_configured: !!groqKey,
    hint: !groqKey ? "在 Vercel 项目 Settings → Environment Variables 添加 GROQ_API_KEY 并 Redeploy" : undefined
  });
});

// 客户端登录配置（如 Google 客户端 ID，用于 OAuth）
app.get("/api/config", (_req, res) => {
  const googleClientId = (process.env.GOOGLE_CLIENT_ID || "").trim();
  res.json({ googleClientId: googleClientId || null });
});

// 仅支持 Google 登录/注册，走 /api/auth/social；此处统一提示
app.post("/api/auth/login", (_req, res) => {
  res.status(400).json({ error: "USE_GOOGLE", message: "请使用 Google 账号登录" });
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
              data: { userId: req.user.sub, title: `对话-${nanoid(6)}` }
            });
        if (conversation) {
          await prisma.message.create({
            data: { conversationId: conversation.id, role: "user", content: `[文件: ${fileName}] ${message || "请分析这个文件"}` }
          });
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
        const memories = await prisma.userMemory.findMany({
          where: { userId: req.user.sub },
          orderBy: { createdAt: "desc" },
          take: 50
        });
        if (memories.length > 0) {
          systemParts.push("已记住的关于该用户的信息：\n" + memories.map((m) => `- [${m.category}] ${m.content}`).join("\n"));
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
          data: { userId: req.user.sub, title: `对话-${nanoid(6)}` }
        });
    if (conversation) {
      await prisma.message.create({
        data: { conversationId: conversation.id, role: "user", content: userMessageContent }
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
    const memories = await prisma.userMemory.findMany({
      where: { userId: req.user.sub },
      orderBy: { createdAt: "desc" },
      take: 50
    });
    if (memories.length > 0) {
      const memoryText = memories.map((m) => `- [${m.category}] ${m.content}`).join("\n");
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
  }

  // 登录用户：从本轮对话中提取新记忆并写入
  if (req.user && reply) {
    try {
      const newMemories = await extractMemoriesFromConversation(userMessageContent, reply);
      for (const { content, category } of newMemories) {
        if (!content || content.length < 2) continue;
        const existing = await prisma.userMemory.findFirst({
          where: { userId: req.user.sub, content }
        });
        if (!existing) {
          await prisma.userMemory.create({
            data: { userId: req.user.sub, content: content.slice(0, 500), category }
          });
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

  return res.json({ translated });
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

// ---------- 助理长期记忆（自主学习与个性化） ----------
app.get("/api/user/memory", authMiddleware, async (req, res) => {
  const list = await prisma.userMemory.findMany({
    where: { userId: req.user.sub },
    orderBy: { createdAt: "desc" },
    take: 200
  });
  return res.json({
    memories: list.map((m) => ({
      id: m.id,
      content: m.content,
      category: m.category,
      createdAt: m.createdAt.toISOString()
    }))
  });
});

app.post("/api/user/memory", authMiddleware, async (req, res) => {
  const schema = z.object({
    memories: z.array(z.object({
      content: z.string().min(1).max(500),
      category: z.enum(["fact", "preference", "habit"]).optional()
    })).max(50)
  });
  const parseResult = schema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: parseResult.error.flatten() });
  }
  const { memories } = parseResult.data;
  for (const { content, category = "fact" } of memories) {
    const existing = await prisma.userMemory.findFirst({
      where: { userId: req.user.sub, content }
    });
    if (!existing) {
      await prisma.userMemory.create({
        data: { userId: req.user.sub, content: content.trim().slice(0, 500), category }
      });
    }
  }
  return res.json({ success: true });
});

app.delete("/api/user/memory/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  await prisma.userMemory.deleteMany({
    where: { id, userId: req.user.sub }
  });
  return res.json({ success: true });
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
