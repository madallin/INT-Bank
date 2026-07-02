import { Injectable, Logger } from '@nestjs/common';

export enum BackoffStrategy
{
  LINEAR = 'linear',
  EXPONENTIAL = 'exponential',
  DECORRELATED_JITTER = 'decorrelated_jitter',
}

export interface RetryOptions
{
  maxAttempts: number;
  baseDelayMs: number;
  maxDelayMs: number;
  strategy: BackoffStrategy;
  retryableErrors?: Array<string | RegExp>;
}

const DEFAULT_OPTIONS: RetryOptions = {
  maxAttempts: 3,
  baseDelayMs: 1000,
  maxDelayMs: 30000,
  strategy: BackoffStrategy.EXPONENTIAL,
};

@Injectable()
export class RetryService
{
  private readonly logger = new Logger(RetryService.name);

  async execute<T>(
    operation: () => Promise<T>,
    options?: Partial<RetryOptions>,
  ): Promise<T>
  {
    const opts = { ...DEFAULT_OPTIONS, ...options };
    let lastError: Error | undefined;

    for(let attempt = 1; attempt <= opts.maxAttempts; attempt++)
    {
      try
      {
        return await operation();
      }
      catch(err)
      {
        lastError = err instanceof Error ? err : new Error(String(err));

        // Propagate immediately for non-retryable failures instead of wasting attempts
        if(!this.isRetryable(lastError, opts.retryableErrors))
        {
          throw lastError;
        }

        if(attempt >= opts.maxAttempts)
        {
          throw lastError;
        }

        const delay = this.calculateDelay(attempt, opts);

        this.logger.warn(
          `Attempt ${attempt}/${opts.maxAttempts} failed: ${lastError.message}. ` +
          `Retrying in ${delay}ms...`,
        );

        await this.sleep(delay);
      }
    }

    throw lastError ?? new Error('Retry exhausted with unknown error');
  }

  async executeSafe<T>(
    operation: () => Promise<T>,
    options?: Partial<RetryOptions>,
  ): Promise<{ success: true; value: T } | { success: false; error: Error }>
  {
    try
    {
      const value = await this.execute(operation, options);
      return { success: true, value };
    }
    catch(err)
    {
      return {
        success: false,
        error: err instanceof Error ? err : new Error(String(err)),
      };
    }
  }

  private calculateDelay(attempt: number, options: RetryOptions): number
  {
    switch(options.strategy)
    {
      case BackoffStrategy.LINEAR:
        return Math.min(options.baseDelayMs * attempt, options.maxDelayMs);

      case BackoffStrategy.EXPONENTIAL:
        return Math.min(
          options.baseDelayMs * Math.pow(2, attempt - 1),
          options.maxDelayMs,
        );

      case BackoffStrategy.DECORRELATED_JITTER:
      {
        // Prevents thundering herd when multiple consumers retry simultaneously
        // sleep = min(cap, random_between(base, sleep * 3))
        const cap = options.maxDelayMs;
        const base = options.baseDelayMs;
        const prevDelay = options.baseDelayMs * Math.pow(2, attempt - 2);
        const range = Math.min(cap, Math.max(base, prevDelay * 3));
        return base + Math.random() * (range - base);
      }

      default:
        return options.baseDelayMs;
    }
  }

  // Defaults to retryable for all errors unless explicit filter provided
  private isRetryable(
    error: Error,
    retryableErrors?: Array<string | RegExp>,
  ): boolean
  {
    if(!retryableErrors || retryableErrors.length === 0)
    {
      return true;
    }

    const message = error.message;
    return retryableErrors.some((pattern) =>
      typeof pattern === 'string'
        ? message.includes(pattern)
        : pattern.test(message),
    );
  }

  private sleep(ms: number): Promise<void>
  {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}