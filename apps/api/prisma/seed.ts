import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function seed(): Promise<void> {
  const institution = await prisma.institution.upsert({
    where: { code: "CAMPUS" },
    update: {
      name: "Campus University",
      timezone: "Asia/Ho_Chi_Minh",
    },
    create: {
      code: "CAMPUS",
      name: "Campus University",
      timezone: "Asia/Ho_Chi_Minh",
    },
  });

  await prisma.campus.upsert({
    where: {
      institutionId_code: {
        institutionId: institution.id,
        code: "MAIN",
      },
    },
    update: { name: "Cơ sở chính", active: true },
    create: {
      institutionId: institution.id,
      code: "MAIN",
      name: "Cơ sở chính",
    },
  });
}

seed()
  .then(() => prisma.$disconnect())
  .catch(async (error: unknown) => {
    console.error(error);
    await prisma.$disconnect();
    process.exitCode = 1;
  });
