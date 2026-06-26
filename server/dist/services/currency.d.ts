declare function getRates(baseCurrency: string): Promise<Record<string, number>>;
declare function convertCurrency(amount: number, fromCurrency: string, toCurrency: string): Promise<number>;
export { getRates, convertCurrency };
//# sourceMappingURL=currency.d.ts.map