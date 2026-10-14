import { Request } from "express";

export interface AuthPrincipal {
  userId: string;
  institutionId: string;
  sessionId: string;
}

export interface AuthenticatedRequest extends Request {
  auth: AuthPrincipal;
}

export interface PublicUser {
  id: string;
  institutionId: string;
  studentId: string;
  email: string;
  displayName: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  tokenType: "Bearer";
  expiresIn: number;
}

export interface AuthenticationResult extends TokenPair {
  user: PublicUser;
}
