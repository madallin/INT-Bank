import { Request, Response, NextFunction } from 'express';
export interface ClientPayload {
    deviceId: string;
    iat?: number;
    exp?: number;
}
export interface ClientTokenRequest extends Request {
    client?: ClientPayload;
}
declare function verifyClientToken(req: ClientTokenRequest, res: Response, next: NextFunction): void;
export default verifyClientToken;
//# sourceMappingURL=verifyClientToken.d.ts.map