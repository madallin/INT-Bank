"use strict";
// ============================================================
// Constants — Banking, Crypto, Rate Limit configuration
// ============================================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.GLOBAL_MAX_REQUESTS = exports.GLOBAL_WINDOW_MS = exports.USERS_MAX_REQUESTS = exports.USERS_WINDOW_MS = exports.TWOFA_VERIFY_WINDOW_MS = exports.TWOFA_VERIFY_MAX = exports.TWOFA_REQUEST_MAX = exports.LOGIN_MAX_ATTEMPTS = exports.LOGIN_WINDOW_MS = exports.AES_GCM_TAG_BYTES = exports.AES_GCM_IV_BYTES = exports.MAX_RETRIES = exports.DEFAULT_CARD_LIFETIME_YEARS = exports.CARD_LENGTH = exports.CARD_BIN = exports.IBAN_ACCOUNT_LENGTH = exports.BANK_CODE = void 0;
exports.BANK_CODE = 'INTB';
exports.IBAN_ACCOUNT_LENGTH = 16;
exports.CARD_BIN = '499999';
exports.CARD_LENGTH = 16;
exports.DEFAULT_CARD_LIFETIME_YEARS = 3;
exports.MAX_RETRIES = 7;
// Crypto constants
exports.AES_GCM_IV_BYTES = 12;
exports.AES_GCM_TAG_BYTES = 16;
// Rate limit constants
exports.LOGIN_WINDOW_MS = 60 * 60 * 1000; // 1 hour
exports.LOGIN_MAX_ATTEMPTS = 10;
exports.TWOFA_REQUEST_MAX = 3;
exports.TWOFA_VERIFY_MAX = 6;
exports.TWOFA_VERIFY_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
exports.USERS_WINDOW_MS = 10 * 60 * 1000; // 10 minutes
exports.USERS_MAX_REQUESTS = 200;
exports.GLOBAL_WINDOW_MS = 60 * 1000; // 1 minute
exports.GLOBAL_MAX_REQUESTS = 150;
//# sourceMappingURL=constants.js.map