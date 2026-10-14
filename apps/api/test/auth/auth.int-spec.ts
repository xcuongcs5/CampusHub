import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import { PrismaClient } from "@prisma/client";
import request from "supertest";

import { AppModule } from "../../src/app.module";

jest.setTimeout(30_000);

const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ??
  "postgresql://campus:campus@localhost:5432/campus_hub_test?schema=public";
const databaseName = new URL(TEST_DATABASE_URL).pathname.slice(1);
if (databaseName !== "campus_hub_test") {
  throw new Error(
    `Authentication tests refuse to truncate non-test database: ${databaseName}`,
  );
}

describe("Authentication API", () => {
  const prisma = new PrismaClient({
    datasources: { db: { url: TEST_DATABASE_URL } },
  });
  let app: INestApplication;

  beforeAll(async () => {
    process.env.DATABASE_URL = TEST_DATABASE_URL;
    process.env.NODE_ENV = "test";
    process.env.JWT_ACCESS_SECRET =
      "authentication-integration-test-secret-at-least-32-characters";
    process.env.JWT_ISSUER = "campus-hub-test";
    process.env.JWT_AUDIENCE = "campus-hub-test-client";

    await prisma.$connect();
    await prisma.$executeRawUnsafe('TRUNCATE TABLE "institutions" CASCADE');
    await prisma.institution.create({
      data: {
        code: "CAMPUS",
        name: "Campus Test University",
        timezone: "Asia/Ho_Chi_Minh",
      },
    });

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api/v1");
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    await prisma.$disconnect();
  });

  it("registers, protects profile, rotates refresh token and revokes session", async () => {
    const registration = await request(app.getHttpServer())
      .post("/api/v1/auth/register")
      .send({
        institutionCode: "campus",
        studentId: "sv20260001",
        displayName: "Nguyễn Minh Anh",
        email: "MinhAnh@Example.edu.vn",
        password: "secret123",
      })
      .expect(201);

    expect(registration.body.user).toMatchObject({
      studentId: "SV20260001",
      email: "minhanh@example.edu.vn",
      displayName: "Nguyễn Minh Anh",
    });
    expect(registration.body.accessToken).toEqual(expect.any(String));
    expect(registration.body.refreshToken).toEqual(expect.any(String));

    await request(app.getHttpServer()).get("/api/v1/auth/me").expect(401);

    await request(app.getHttpServer())
      .get("/api/v1/auth/me")
      .set("Authorization", `Bearer ${registration.body.accessToken}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body.email).toBe("minhanh@example.edu.vn");
      });

    const refreshed = await request(app.getHttpServer())
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: registration.body.refreshToken })
      .expect(200);
    expect(refreshed.body.refreshToken).not.toBe(
      registration.body.refreshToken,
    );

    await request(app.getHttpServer())
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: registration.body.refreshToken })
      .expect(401);

    await request(app.getHttpServer())
      .post("/api/v1/auth/logout")
      .set("Authorization", `Bearer ${refreshed.body.accessToken}`)
      .expect(204);

    await request(app.getHttpServer())
      .get("/api/v1/auth/me")
      .set("Authorization", `Bearer ${refreshed.body.accessToken}`)
      .expect(401);

    await request(app.getHttpServer())
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: refreshed.body.refreshToken })
      .expect(401);
  });

  it("logs in and rejects duplicate registration", async () => {
    const login = await request(app.getHttpServer())
      .post("/api/v1/auth/login")
      .send({
        institutionCode: "CAMPUS",
        email: "minhanh@example.edu.vn",
        password: "secret123",
      })
      .expect(200);
    expect(login.body.tokenType).toBe("Bearer");
    expect(login.body.expiresIn).toBe(900);

    await request(app.getHttpServer())
      .post("/api/v1/auth/login")
      .send({
        institutionCode: "CAMPUS",
        email: "minhanh@example.edu.vn",
        password: "wrong-password",
      })
      .expect(401);

    await request(app.getHttpServer())
      .post("/api/v1/auth/register")
      .send({
        institutionCode: "CAMPUS",
        studentId: "SV20260002",
        displayName: "Duplicate Email",
        email: "minhanh@example.edu.vn",
        password: "secret123",
      })
      .expect(409);
  });
});
