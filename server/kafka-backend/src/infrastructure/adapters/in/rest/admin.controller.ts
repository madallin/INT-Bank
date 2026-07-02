import {
  Controller,
  Get,
  Post,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { OutboxProcessorService } from '../../../services/outbox-processor.service';

@Controller('admin')
export class AdminController
{
  constructor(
    private readonly outboxProcessor: OutboxProcessorService,
  ) {}

  @Get('outbox/stats')
  async getOutboxStats()
  {
    const stats = await this.outboxProcessor.getStats();
    return { data: stats };
  }

  @Post('outbox/reprocess-dead')
  @HttpCode(HttpStatus.ACCEPTED)
  async reprocessDeadOutbox()
  {
    const count = await this.outboxProcessor.reprocessDead();
    return {
      message: `${count} dead messages queued for reprocessing`,
      count,
    };
  }

  @Post('outbox/process-now')
  async processOutboxNow()
  {
    const result = await this.outboxProcessor.processNow();
    return {
      message: `Processed ${result.processed}, failed ${result.failed}`,
      data: result,
    };
  }

  @Get('dlq/stats')
  async getDlqStats()
  {
    const stats = await this.outboxProcessor.getStats();
    return {
      data: {
        deadMessages: stats.dead,
        pendingRetries: stats.pending,
        permanentlyFailed: stats.dead,
        totalMessages: stats.total,
      },
    };
  }

  @Get('balances')
  async getBalanceCacheStats()
  {
    return { message: 'Read model projector is operational' };
  }
}