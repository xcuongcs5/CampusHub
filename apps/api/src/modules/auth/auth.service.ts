import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { AppUser, Prisma } from "@prisma/client";
import { compare, hash } from "bcryptjs";
import {
  createHash,
  randomBytes,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";

import { PrismaService } from "../../core/database/prisma.service";
import { LoginDto } from "./dto/login.dto";
import { RegisterDto } from "./dto/register.dto";
import {
  AuthenticationResult,
  AuthPrincipal,
  PublicUser,
  TokenPair,
} from "./auth.types";

interface AccessTokenPayload {
  sub: string;
  institutionId: string;
  sessionId: string;
  type: "access";
}

@Injectable()
export class AuthService {
  private readonly accessSecret: string;
  private readonly issuer: string;
  private readonly audience: string;
  private readonly accessTokenTtlSeconds = 15 * 60;
  private readonly refreshTokenTtlMs = 30 * 24 * 60 * 60 * 1_000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    config: ConfigService,
  ) {
    const configuredSecret = config.get<string>("JWT_ACCESS_SECRET");
    if (!configuredSecret && config.get("NODE_ENV") === "production") {
      throw new Error("JWT_ACCESS_SECRET is required in production.");
    }
    this.accessSecret =
      configuredSecret ??
      "campus-hub-local-access-secret-change-before-production";
    this.issuer = config.get<string>("JWT_ISSUER") ?? "campus-hub-local";
    this.audience = config.get<string>("JWT_AUDIENCE") ?? "campus-hub-mobile";
  }

  async register(input: RegisterDto): Promise<AuthenticationResult> {
    const institution = await this.prisma.institution.findUnique({
      where: { code: input.institutionCode.trim().toUpperCase() },
    });
    if (!institution) {
      throw new NotFoundException("Institution was not found.");
    }

    const email = input.email.trim().toLowerCase();
    const studentId = input.studentId.trim().toUpperCase();
    const passwordHash = await hash(input.password, 12);
    let user: AppUser;
    try {
      user = await this.prisma.appUser.create({
        data: {
          institutionId: institution.id,
          externalRef: studentId,
          email,
          displayName: input.displayName.trim(),
          passwordHash,
        },
      });
    } catch (error: unknown) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw new ConflictException(
          "Email or student ID is already registered.",
        );
      }
      throw error;
    }
    return this.createAuthenticationResult(user);
  }

  async login(input: LoginDto): Promise<AuthenticationResult> {
    const institution = await this.prisma.institution.findUnique({
      where: { code: input.institutionCode.trim().toUpperCase() },
    });
    if (!institution) {
      throw this.invalidCredentials();
    }
    const user = await this.prisma.appUser.findUnique({
      where: {
        institutionId_email: {
          institutionId: institution.id,
          email: input.email.trim().toLowerCase(),
        },
      },
    });
    if (
      !user ||
      !user.active ||
      !user.passwordHash ||
      !(await compare(input.password, user.passwordHash))
    ) {
      throw this.invalidCredentials();
    }
    return this.createAuthenticationResult(user);
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const [sessionId, secret, ...extra] = refreshToken.split(".");
    if (!sessionId || !secret || extra.length > 0) {
      throw this.invalidRefreshToken();
    }
    const session = await this.prisma.authSession.findUnique({
      where: { id: sessionId },
      include: { user: true },
    });
    const incomingHash = this.hashRefreshToken(secret);
    if (
      !session ||
      session.revokedAt ||
      session.expiresAt <= new Date() ||
      !session.user.active ||
      !this.hashesMatch(incomingHash, session.refreshTokenHash.trim())
    ) {
      throw this.invalidRefreshToken();
    }

    const nextSecret = randomBytes(32).toString("base64url");
    const nextHash = this.hashRefreshToken(nextSecret);
    const rotated = await this.prisma.authSession.updateMany({
      where: {
        id: session.id,
        refreshTokenHash: session.refreshTokenHash,
        revokedAt: null,
      },
      data: { refreshTokenHash: nextHash, lastUsedAt: new Date() },
    });
    if (rotated.count !== 1) {
      throw this.invalidRefreshToken();
    }
    return this.issueTokens(
      session.user,
      session.id,
      `${session.id}.${nextSecret}`,
    );
  }

  async logout(principal: AuthPrincipal): Promise<void> {
    await this.prisma.authSession.updateMany({
      where: {
        id: principal.sessionId,
        userId: principal.userId,
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
  }

  async getCurrentUser(principal: AuthPrincipal): Promise<PublicUser> {
    const user = await this.prisma.appUser.findFirst({
      where: {
        id: principal.userId,
        institutionId: principal.institutionId,
        active: true,
      },
    });
    if (!user) throw new UnauthorizedException();
    return this.toPublicUser(user);
  }

  async verifyAccessToken(token: string): Promise<AuthPrincipal> {
    try {
      const payload = await this.jwt.verifyAsync<AccessTokenPayload>(token, {
        secret: this.accessSecret,
        issuer: this.issuer,
        audience: this.audience,
      });
      if (
        payload.type !== "access" ||
        !payload.sub ||
        !payload.institutionId ||
        !payload.sessionId
      ) {
        throw new UnauthorizedException();
      }
      const activeSession = await this.prisma.authSession.count({
        where: {
          id: payload.sessionId,
          userId: payload.sub,
          revokedAt: null,
          expiresAt: { gt: new Date() },
          user: {
            is: {
              active: true,
              institutionId: payload.institutionId,
            },
          },
        },
      });
      if (activeSession !== 1) {
        throw new UnauthorizedException();
      }
      return {
        userId: payload.sub,
        institutionId: payload.institutionId,
        sessionId: payload.sessionId,
      };
    } catch {
      throw new UnauthorizedException("Access token is invalid or expired.");
    }
  }

  private async createAuthenticationResult(
    user: AppUser,
  ): Promise<AuthenticationResult> {
    const sessionId = randomUUID();
    const refreshSecret = randomBytes(32).toString("base64url");
    await this.prisma.authSession.create({
      data: {
        id: sessionId,
        userId: user.id,
        refreshTokenHash: this.hashRefreshToken(refreshSecret),
        expiresAt: new Date(Date.now() + this.refreshTokenTtlMs),
      },
    });
    return {
      user: this.toPublicUser(user),
      ...(await this.issueTokens(
        user,
        sessionId,
        `${sessionId}.${refreshSecret}`,
      )),
    };
  }

  private async issueTokens(
    user: AppUser,
    sessionId: string,
    refreshToken: string,
  ): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync(
      {
        sub: user.id,
        institutionId: user.institutionId,
        sessionId,
        type: "access",
      } satisfies AccessTokenPayload,
      {
        secret: this.accessSecret,
        issuer: this.issuer,
        audience: this.audience,
        expiresIn: this.accessTokenTtlSeconds,
      },
    );
    return {
      accessToken,
      refreshToken,
      tokenType: "Bearer",
      expiresIn: this.accessTokenTtlSeconds,
    };
  }

  private toPublicUser(user: AppUser): PublicUser {
    return {
      id: user.id,
      institutionId: user.institutionId,
      studentId: user.externalRef,
      email: user.email,
      displayName: user.displayName,
    };
  }

  private hashRefreshToken(secret: string): string {
    return createHash("sha256").update(secret).digest("hex");
  }

  private hashesMatch(left: string, right: string): boolean {
    const leftBytes = Buffer.from(left, "hex");
    const rightBytes = Buffer.from(right, "hex");
    return (
      leftBytes.length === rightBytes.length &&
      timingSafeEqual(leftBytes, rightBytes)
    );
  }

  private invalidCredentials(): UnauthorizedException {
    return new UnauthorizedException("Email or password is incorrect.");
  }

  private invalidRefreshToken(): UnauthorizedException {
    return new UnauthorizedException("Refresh token is invalid or expired.");
  }
}
