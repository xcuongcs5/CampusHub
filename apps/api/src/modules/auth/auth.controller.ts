import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";

import { AccessTokenGuard } from "./access-token.guard";
import { AuthService } from "./auth.service";
import { AuthenticatedRequest } from "./auth.types";
import { LoginDto } from "./dto/login.dto";
import { RefreshTokenDto } from "./dto/refresh-token.dto";
import { RegisterDto } from "./dto/register.dto";

@ApiTags("Authentication")
@Controller("auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post("register")
  register(@Body() input: RegisterDto) {
    return this.authService.register(input);
  }

  @Post("login")
  @HttpCode(HttpStatus.OK)
  login(@Body() input: LoginDto) {
    return this.authService.login(input);
  }

  @Post("refresh")
  @HttpCode(HttpStatus.OK)
  refresh(@Body() input: RefreshTokenDto) {
    return this.authService.refresh(input.refreshToken);
  }

  @Post("logout")
  @UseGuards(AccessTokenGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Req() request: AuthenticatedRequest): Promise<void> {
    await this.authService.logout(request.auth);
  }

  @Get("me")
  @UseGuards(AccessTokenGuard)
  @ApiBearerAuth()
  me(@Req() request: AuthenticatedRequest) {
    return this.authService.getCurrentUser(request.auth);
  }
}
