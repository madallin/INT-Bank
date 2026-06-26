import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { IsNotEmpty, IsNumber, IsString, MinLength, Min } from 'class-validator';

import { TransferUseCase } from '../../../../core/ports/in/transfer.use-case';

export class InitiateTransferBodyDto
{
  @IsString()
  @IsNotEmpty()
  fromIban!: string;

  @IsString()
  @IsNotEmpty()
  toIban!: string;

  @IsNumber()
  @Min(1)
  amount!: number;

  @IsString()
  @IsNotEmpty()
  currency!: string;

  @IsString()
  @MinLength(3)
  reason!: string;

  @IsString()
  @IsNotEmpty()
  beneficiaryName!: string;

  @IsString()
  @IsNotEmpty()
  senderName!: string;
}

@Controller('transfers')
export class TransferController
{
  private readonly logger = new Logger(TransferController.name);

  constructor(private readonly transferUseCase: TransferUseCase) {}

  @Post()
  @HttpCode(HttpStatus.ACCEPTED)
  async initiate(@Body() body: InitiateTransferBodyDto)
  {
    this.logger.log(
      `POST /transfers - ${body.fromIban} -> ${body.toIban} | ${body.amount} ${body.currency}`,
    );

    const result = await this.transferUseCase.initiate({
      fromIban: body.fromIban,
      toIban: body.toIban,
      amount: body.amount,
      currency: body.currency,
      reason: body.reason,
      beneficiaryName: body.beneficiaryName,
      senderName: body.senderName,
    });

    return {
      status: HttpStatus.ACCEPTED,
      trackingId: result.trackingId,
      message: result.message,
      transferStatus: result.status,
    };
  }
}
