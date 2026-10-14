import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";

import { AuthenticatedRequest } from "./auth.types";
import { AuthService } from "./auth.service";

@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.headers.authorization;
    const [scheme, token] = authorization?.split(" ") ?? [];
    if (scheme !== "Bearer" || !token) {
      throw new UnauthorizedException("Bearer access token is required.");
    }
    request.auth = await this.authService.verifyAccessToken(token);
    return true;
  }
}
