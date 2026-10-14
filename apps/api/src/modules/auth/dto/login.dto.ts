import { ApiProperty } from "@nestjs/swagger";
import { IsEmail, IsNotEmpty, IsString, MaxLength } from "class-validator";

export class LoginDto {
  @ApiProperty({ example: "CAMPUS" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  institutionCode!: string;

  @ApiProperty({ example: "minhanh@example.edu.vn" })
  @IsEmail()
  @MaxLength(320)
  email!: string;

  @ApiProperty({ writeOnly: true })
  @IsString()
  @IsNotEmpty()
  password!: string;
}
