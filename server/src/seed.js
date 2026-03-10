import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const contentPath = path.join(__dirname, "learning_content.json");

async function main() {
  const raw = fs.readFileSync(contentPath, "utf-8");
  const { categories } = JSON.parse(raw);

  await prisma.favorite.deleteMany();
  await prisma.vocabularyItem.deleteMany();
  await prisma.vocabCategory.deleteMany();

  const sorted = [...categories].sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
  for (const c of sorted) {
    await prisma.vocabCategory.create({
      data: {
        id: c.id,
        nameZh: c.nameZh,
        nameId: c.nameId,
        sortOrder: c.sortOrder || 0,
        items: {
          create: c.items.map((item) => ({
            id: item.id,
            textZh: item.textZh,
            textId: item.textId,
            exampleZh: item.exampleZh,
            exampleId: item.exampleId
          }))
        }
      }
    });
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
