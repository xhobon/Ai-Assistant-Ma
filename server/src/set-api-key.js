import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const key = process.argv[2] || process.env.DEEPSEEK_API_KEY;
if (!key || key.length < 10) {
  console.error("用法: node src/set-api-key.js <API_KEY>");
  console.error("或设置环境变量 DEEPSEEK_API_KEY 后执行");
  process.exit(1);
}

async function main() {
  await prisma.systemConfig.upsert({
    where: { configKey: "DEEPSEEK_API_KEY" },
    update: { configVal: key },
    create: { configKey: "DEEPSEEK_API_KEY", configVal: key }
  });
  console.log("DEEPSEEK_API_KEY 已写入数据库");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
