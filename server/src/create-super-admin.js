import "express-async-errors";
import dotenv from "dotenv";
import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

dotenv.config();

const prisma = new PrismaClient();

async function createSuperAdmin() {
  const email = process.env.SUPER_ADMIN_EMAIL || "admin@ai-assistant.com";
  const password = process.env.SUPER_ADMIN_PASSWORD || "SuperAdmin2026!";
  const displayName = process.env.SUPER_ADMIN_NAME || "超级管理员";

  try {
    // 检查是否已存在
    const existing = await prisma.user.findFirst({
      where: {
        OR: [
          { email },
          { role: "super_admin" }
        ]
      }
    });

    if (existing) {
      if (existing.role === "super_admin") {
        console.log("✅ 超级管理员已存在:");
        console.log(`   邮箱: ${existing.email || "未设置"}`);
        console.log(`   名称: ${existing.displayName}`);
        console.log(`   ID: ${existing.id}`);
        return;
      } else {
        // 升级为超级管理员
        await prisma.user.update({
          where: { id: existing.id },
          data: { role: "super_admin" }
        });
        console.log("✅ 已将用户升级为超级管理员:");
        console.log(`   邮箱: ${existing.email || "未设置"}`);
        console.log(`   名称: ${existing.displayName}`);
        return;
      }
    }

    // 创建新的超级管理员
    const passwordHash = await bcrypt.hash(password, 10);
    const admin = await prisma.user.create({
      data: {
        email,
        displayName,
        passwordHash,
        role: "super_admin"
      }
    });

    console.log("✅ 超级管理员创建成功!");
    console.log(`   邮箱: ${admin.email}`);
    console.log(`   密码: ${password}`);
    console.log(`   名称: ${admin.displayName}`);
    console.log(`   ID: ${admin.id}`);
    console.log("\n⚠️  请妥善保管密码，建议首次登录后修改密码！");
  } catch (error) {
    console.error("❌ 创建超级管理员失败:", error.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

createSuperAdmin();
