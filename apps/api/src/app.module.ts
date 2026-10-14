import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";

import { PrismaModule } from "./core/database/prisma.module";
import { AuthModule } from "./modules/auth/auth.module";
import { HealthModule } from "./modules/health/health.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    HealthModule,
  ],
})
export class AppModule {}
