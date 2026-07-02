import { Injectable, Logger } from '@nestjs/common';
import { redis } from '../../config/redis';

const BLACKLIST_PREFIX = 'token_blacklist:';
const REFRESH_TOKEN_PREFIX = 'refresh_token:';
const USER_REVOCATION_TTL_SECONDS = 3600 * 24 * 7; // 7 days

@Injectable()
export class TokenBlacklistService
{
    private readonly logger = new Logger(TokenBlacklistService.name);

    async revokeAccessToken(jti: string, expiresInSeconds: number): Promise<void>
    {
        const key = `${BLACKLIST_PREFIX}${jti}`;
        await redis.setex(key, expiresInSeconds, 'revoked');
    }

    async isRevoked(jti: string): Promise<boolean>
    {
        const key = `${BLACKLIST_PREFIX}${jti}`;
        const result = await redis.get(key);
        return result !== null;
    }

    async storeRefreshToken(
        tokenId: string,
        userId: number,
        expiresInSeconds: number,
        metadata?: Record<string, string>,
    ): Promise<void>
    {
        const key = `${REFRESH_TOKEN_PREFIX}${tokenId}`;
        const data = {
            userId,
            createdAt: new Date().toISOString(),
            ...metadata,
        };
        await redis.setex(key, expiresInSeconds, JSON.stringify(data));
    }

    async validateRefreshToken(tokenId: string): Promise<{ userId: number } | null>
    {
        const key = `${REFRESH_TOKEN_PREFIX}${tokenId}`;
        const raw = await redis.get(key);

        if(!raw)
        {
            return null;
        }

        try
        {
            const data = JSON.parse(raw);
            return { userId: data.userId };
        }
        catch
        {
            return null;
        }
    }

    async revokeRefreshToken(tokenId: string): Promise<void>
    {
        const key = `${REFRESH_TOKEN_PREFIX}${tokenId}`;
        await redis.del(key);
    }

    // SCAN-based bulk revocation; safe for production since it doesn't block the server
    async revokeAllUserRefreshTokens(userId: number): Promise<number>
    {
        let revokedCount = 0;
        let cursor = '0';

        do
        {
            const [newCursor, keys] = await redis.scan(
                cursor,
                'MATCH',
                `${REFRESH_TOKEN_PREFIX}*`,
                'COUNT',
                100,
            );
            cursor = newCursor;

            for(const key of keys)
            {
                const raw = await redis.get(key);
                if(!raw) continue;

                try
                {
                    const data = JSON.parse(raw);
                    if(data.userId === userId)
                    {
                        await redis.del(key);
                        revokedCount++;
                    }
                }
                catch
                {
                    // Skip malformed entries
                }
            }
        }
        while(cursor !== '0');

        this.logger.log(`Revoked ${revokedCount} refresh tokens for user ${userId}`);
        return revokedCount;
    }

    // Blanket revocation: all access tokens issued before this timestamp are invalid.
    // Used during password changes or security incidents.
    async revokeAllUserAccessTokensBefore(userId: number, timestamp: number): Promise<void>
    {
        const key = `user_revocation:${userId}`;
        await redis.set(key, timestamp.toString());
        await redis.expire(key, USER_REVOCATION_TTL_SECONDS);
    }

    async getUserRevocationTimestamp(userId: number): Promise<number | null>
    {
        const key = `user_revocation:${userId}`;
        const raw = await redis.get(key);
        return raw ? parseInt(raw, 10) : null;
    }
}