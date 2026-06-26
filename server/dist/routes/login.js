"use strict";
// ============================================================
// Route: Login — Phone lookup for user existence
// ============================================================
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const router = (0, express_1.Router)();
router.post('/', async (req, res) => {
    const { phone } = req.body;
    if (!phone || typeof phone !== 'string') {
        res.status(400).json({ error: 'Număr de telefon invalid' });
        return;
    }
    let clientDb;
    try {
        clientDb = await req.pool.connect();
        const result = await clientDb.query('SELECT id, contaprobat, termeniacceptati FROM utilizatori WHERE nrtelefon = $1 LIMIT 1', [phone]);
        if (result.rows.length === 0) {
            res.json({ exists: false });
            return;
        }
        const user = result.rows[0];
        res.json({
            exists: true,
            userId: user.id,
            approved: user.contaprobat,
            acceptedterms: user.termeniacceptati,
        });
    }
    catch (err) {
        console.error('Eroare la baza de date (login):', err);
        res.status(500).json({ error: 'Eroare la comunicarea cu serverul' });
    }
    finally {
        if (clientDb)
            clientDb.release();
    }
});
exports.default = router;
//# sourceMappingURL=login.js.map