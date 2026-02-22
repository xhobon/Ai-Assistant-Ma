import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const categories = [
    { nameZh: "日常问候", nameId: "Sapaan", sortOrder: 1 },
    { nameZh: "旅行必备", nameId: "Perjalanan", sortOrder: 2 },
    { nameZh: "购物点餐", nameId: "Belanja & Pesan", sortOrder: 3 },
    { nameZh: "紧急沟通", nameId: "Darurat", sortOrder: 4 }
  ];

  for (const c of categories) {
    const existing = await prisma.vocabCategory.findFirst({ where: { nameZh: c.nameZh } });
    if (!existing) {
      await prisma.vocabCategory.create({ data: c });
    }
  }

  const greeting = await prisma.vocabCategory.findFirst({
    where: { nameZh: "日常问候" }
  });

  if (greeting) {
    const items = [
      { textZh: "你好", textId: "Halo" },
      { textZh: "早上好", textId: "Selamat pagi" },
      { textZh: "谢谢", textId: "Terima kasih" }
    ];
    for (const item of items) {
      const exists = await prisma.vocabularyItem.findFirst({
        where: { categoryId: greeting.id, textZh: item.textZh }
      });
      if (!exists) {
        await prisma.vocabularyItem.create({
          data: { ...item, categoryId: greeting.id }
        });
      }
    }
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
