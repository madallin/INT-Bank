declare function decryptAESGCM(any: string): string;
declare function panHash(pan: string): string;
export interface AccountAndCardResult {
    account: {
        id: number;
        IBAN: string;
        moneda: string;
        sold: number;
    };
    card: {
        id: number;
        token: string;
        last4: string;
        expiryMMYY: string;
        accountId: number;
    };
}
declare function createAccountAndCard(userId: number, currency?: string, countryCode?: string): Promise<AccountAndCardResult>;
export { createAccountAndCard, decryptAESGCM, panHash };
//# sourceMappingURL=banking.d.ts.map