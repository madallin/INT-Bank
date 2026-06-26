"use strict";
// ============================================================
// Middleware: Address Validation
// Validates the address received from the frontend.
//   a) Checks required fields
//   b) Compares locality + county against the SQL reference table
//   c) Returns the standardized address object
// ============================================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateAddress = validateAddress;
/**
 * Middleware de validare a adresei.
 * Așteaptă în req.body: { placeId, strada, numar, bloc, scara, apartament, localitate, judet, codPostal }
 * La succes, adaugă req.addressValidated la obiectul standardizat.
 * La eșec, returnează 400 cu eroarea.
 */
async function validateAddress(req, res, next) {
    const { placeId, strada, numar, bloc, scara, apartament, localitate, judet, codPostal, } = req.body;
    // --- Validare câmpuri obligatorii ---
    if (!placeId) {
        res.status(400).json({ error: 'placeId lipsește. Adresa trebuie selectată din sugestii.' });
        return;
    }
    if (!strada || !localitate || !judet) {
        res.status(400).json({ error: 'Strada, localitatea și județul sunt obligatorii.' });
        return;
    }
    // --- (a) Verifică localitatea + județul în tabelul SQL de referință ---
    try {
        const client = await req.pool.connect();
        try {
            const refResult = await client.query(`SELECT 1 FROM localitati_referinta
         WHERE LOWER(judet) = LOWER($1)
           AND LOWER(localitate) = LOWER($2)
         LIMIT 1`, [judet, localitate]);
            if (refResult.rows.length === 0) {
                res.status(400).json({
                    error: `Adresa „${localitate}, ${judet}” nu există în baza noastră de referință. Verifică județul și localitatea.`,
                });
                return;
            }
        }
        finally {
            client.release();
        }
    }
    catch (dbErr) {
        console.error('Eroare la interogarea localitati_referinta:', dbErr.message);
        // Dacă tabelul nu există, nu blocăm — e configurabil
        if (dbErr.code !== '42P01') {
            // 42P01 = undefined_table
            res.status(500).json({ error: 'Eroare internă la validarea adresei' });
            return;
        }
        console.warn('Tabelul localitati_referinta nu există — se omite verificarea în SQL.');
    }
    // --- (b) Totul e valid → obiect standardizat ---
    const addressParts = [
        strada.trim(),
        numar ? `Nr. ${numar}` : '',
        bloc ? `Bl. ${bloc}` : '',
        scara ? `Sc. ${scara}` : '',
        apartament ? `Ap. ${apartament}` : '',
    ].filter(Boolean);
    req.addressValidated = {
        placeId: placeId,
        strada: strada.trim(),
        numar: (numar || '').trim(),
        bloc: (bloc || '').trim(),
        scara: (scara || '').trim(),
        apartament: (apartament || '').trim(),
        localitate: localitate.trim(),
        judet: judet.trim(),
        codPostal: (codPostal || '').trim(),
        formattedAddress: addressParts.join(', '),
        lat: null,
        lng: null,
    };
    next();
}
//# sourceMappingURL=addressValidation.js.map