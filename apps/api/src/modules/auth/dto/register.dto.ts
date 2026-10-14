import { ApiProperty } from "@nestjs/swagger";
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  Length,
  MaxLength,
  MinLength,
} from "class-validator";

export class RegisterDto {
  @ApiProperty({ example: "CAMPUS" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  institutionCode!: string;

  @ApiProperty({ example: "SV20260001" })
  @IsString()
  @Length(4, 50)
  studentId!: string;

  @ApiProperty({ example: "Nguyễn Minh Anh" })
  @IsString()
  @Length(2, 200)
  displayName!: string;

  @ApiProperty({ example: "minhanh@example.edu.vn" })
  @IsEmail()
  @MaxLength(320)
  email!: string;

  @ApiProperty({ minLength: 8, maxLength: 72, writeOnly: true })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;
}
