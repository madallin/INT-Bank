package com.intbank.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class RetryService
{

    private static final Logger log = LoggerFactory.getLogger(RetryService.class);

    private static final RetryOptions DEFAULT_OPTIONS = new RetryOptions(3, 1000, 30000, BackoffStrategy.EXPONENTIAL, List.of());

    public <T> T execute(RetryableOperation<T> operation, RetryOptions options) throws Exception
    {
        RetryOptions opts = options != null ? options : DEFAULT_OPTIONS;
        Exception lastError = null;

        for (int attempt = 1; attempt <= opts.maxAttempts(); attempt++) {
            try {
                return operation.execute();
            } catch (Exception err) {
                lastError = err;
                if (!isRetryable(err, opts.retryableErrors())) {
                    throw err;
                }
                if (attempt >= opts.maxAttempts()) {
                    throw err;
                }
                long delay = calculateDelay(attempt, opts);
                log.warn("Attempt {}/{} failed: {}. Retrying in {}ms...", attempt, opts.maxAttempts(), err.getMessage(), delay);
                Thread.sleep(delay);
            }
        }
        throw lastError != null ? lastError : new RuntimeException("Retry exhausted with unknown error");
    }

    private boolean isRetryable(Exception error, List<String> retryableErrors)
    {
        if (retryableErrors == null || retryableErrors.isEmpty()) return true;
        String msg = error.getMessage() != null ? error.getMessage() : "";
        return retryableErrors.stream().anyMatch(msg::contains);
    }

    private long calculateDelay(int attempt, RetryOptions opts)
    {
        return switch (opts.strategy()) {
            case LINEAR -> Math.min(opts.baseDelayMs() * attempt, opts.maxDelayMs());
            case EXPONENTIAL -> Math.min(opts.baseDelayMs() * (long) Math.pow(2, attempt - 1), opts.maxDelayMs());
            case DECORRELATED_JITTER -> {
                long prevDelay = opts.baseDelayMs() * (long) Math.pow(2, attempt - 2);
                long range = Math.min(opts.maxDelayMs(), Math.max(opts.baseDelayMs(), prevDelay * 3));
                yield opts.baseDelayMs() + (long) (Math.random() * (range - opts.baseDelayMs()));
            }
            default -> opts.baseDelayMs();
        };
    }

    public interface RetryableOperation<T> {
        T execute() throws Exception;
    }

    public record RetryOptions(int maxAttempts, long baseDelayMs, long maxDelayMs, BackoffStrategy strategy, List<String> retryableErrors) {}

    public enum BackoffStrategy { LINEAR, EXPONENTIAL, DECORRELATED_JITTER }
}