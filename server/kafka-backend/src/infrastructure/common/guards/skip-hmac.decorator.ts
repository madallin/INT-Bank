import { SetMetadata } from '@nestjs/common';

export const SKIP_HMAC_KEY = 'skipHmac';
export const SkipHmac = () => SetMetadata(SKIP_HMAC_KEY, true);
