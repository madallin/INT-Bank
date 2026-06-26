import { Request, Response, NextFunction } from 'express';
export interface UserPayload {
    userId: number;
    role?: string;
    iat?: number;
    exp?: number;
}
export interface UserTokenRequest extends Request {
    userId?: number;
    userRole?: string;
}
declare function verifyUserToken(req: UserTokenRequest, res: Response, next: NextFunction): void;
export default verifyUserToken;
//# sourceMappingURL=verifyUserToken.d.ts.map