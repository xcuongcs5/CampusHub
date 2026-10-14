# Campus Hub API

Project NestJS độc lập cung cấp backend cho Campus Hub.

## Ranh giới

- Chỉ chứa TypeScript/NestJS source, Prisma, migration và backend tests.
- Không chứa hoặc build source Flutter.
- REST/OpenAPI là contract công khai với mobile.
- Không dựa vào filesystem hoặc release version của mobile.
- Có container image, environment, migration và CI/CD riêng.

## Phát triển

```powershell
npm install
Copy-Item .env.example .env
npm run prisma:validate
npm run prisma:generate
npm run prisma:deploy
npm run prisma:seed
npm run start:dev
```

File `.env` local không được commit. `DATABASE_URL` là biến bắt buộc; cấu hình Docker mặc định
dùng database `campus_hub` tại `localhost:5432` với tài khoản local `campus/campus`.

## Database

```powershell
npm run prisma:deploy
```

Không dùng `prisma db push` cho môi trường dùng chung. Mọi thay đổi schema phải đi qua
migration đã review, bao gồm custom PostgreSQL constraint và trigger.

