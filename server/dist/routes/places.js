"use strict";
// ============================================================
// Route: Places — Geoapify Address Autocomplete/Reverse
// ============================================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const axios_1 = __importDefault(require("axios"));
const router = (0, express_1.Router)();
const GEOAPIFY_BASE = 'https://api.geoapify.com/v1/geocode';
/**
 * GET /places/autocomplete?text=...&locality=...
 */
router.get('/autocomplete', async (req, res) => {
    const { text, locality } = req.query;
    if (!text) {
        res.status(400).json({ error: 'Missing text query' });
        return;
    }
    const apiKey = process.env.GEOAPIFY_KEY;
    if (!apiKey) {
        res.status(500).json({ error: 'Geoapify API key not configured' });
        return;
    }
    try {
        const params = {
            text,
            type: 'street',
            format: 'json',
            lang: 'ro',
            apiKey,
            filter: 'countrycode:ro',
        };
        if (locality) {
            params.text = `${text}, ${locality}`;
        }
        const geoapifyRes = await axios_1.default.get(`${GEOAPIFY_BASE}/autocomplete`, { params });
        const results = geoapifyRes.data?.results || [];
        const predictions = results.map((r) => ({
            place_id: r.place_id,
            description: r.place_id
                ? (() => {
                    const streetPart = r.street
                        ? [r.street, r.housenumber].filter(Boolean).join(', ')
                        : (r.address_line1 || r.formatted || '').split(',')[0]?.trim() || '';
                    const postcode = r.postcode ? ` (${r.postcode})` : '';
                    return streetPart + postcode || r.formatted || '';
                })()
                : '',
            strada: r.street || (r.address_line1 || '').split(',')[0]?.trim() || '',
            numar: r.housenumber || '',
            localitate: r.city || r.county || '',
            judet: r.state || '',
            codPostal: r.postcode || '',
            tara: r.country || '',
        }));
        res.json({ predictions });
    }
    catch (err) {
        console.error('Eroare la Geoapify autocomplete:', err.response?.data || err.message);
        res.status(500).json({ error: 'Error fetching from Geoapify' });
    }
});
/**
 * GET /places/details?place_id=...
 */
router.get('/details', async (req, res) => {
    const { place_id } = req.query;
    if (!place_id) {
        res.status(400).json({ error: 'Missing place_id query' });
        return;
    }
    const apiKey = process.env.GEOAPIFY_KEY;
    if (!apiKey) {
        res.status(500).json({ error: 'Geoapify API key not configured' });
        return;
    }
    try {
        const geoapifyRes = await axios_1.default.get(`${GEOAPIFY_BASE}/search`, {
            params: {
                id: place_id,
                format: 'json',
                lang: 'ro',
                apiKey,
            },
        });
        const results = geoapifyRes.data?.results || [];
        if (results.length === 0) {
            res.status(404).json({ error: 'Place not found' });
            return;
        }
        const result = results[0];
        const address = {
            place_id,
            formatted_address: result.formatted || '',
            strada: result.street || result.address_line1?.split(',')[0]?.trim() || '',
            numar: result.housenumber || '',
            localitate: result.city || result.county || '',
            judet: result.state || '',
            codPostal: result.postcode || '',
            tara: result.country || '',
            lat: result.lat || null,
            lng: result.lon || null,
        };
        res.json({ address });
    }
    catch (err) {
        console.error('Eroare la Geoapify details:', err.response?.data || err.message);
        res.status(500).json({ error: 'Error fetching place details from Geoapify' });
    }
});
/**
 * GET /places/reverse?lat=...&lon=...
 */
router.get('/reverse', async (req, res) => {
    const { lat, lon } = req.query;
    if (!lat || !lon) {
        res.status(400).json({ error: 'Missing lat/lon query' });
        return;
    }
    const apiKey = process.env.GEOAPIFY_KEY;
    if (!apiKey) {
        res.status(500).json({ error: 'Geoapify API key not configured' });
        return;
    }
    try {
        const geoapifyRes = await axios_1.default.get(`${GEOAPIFY_BASE}/reverse`, {
            params: {
                lat,
                lon,
                format: 'json',
                lang: 'ro',
                limit: 1,
                apiKey,
            },
        });
        const results = geoapifyRes.data?.results || [];
        if (results.length === 0) {
            res.status(404).json({ error: 'No address found for these coordinates' });
            return;
        }
        const result = results[0];
        const address = {
            place_id: result.place_id || '',
            formatted_address: result.formatted || '',
            strada: result.street || result.address_line1?.split(',')[0]?.trim() || '',
            numar: result.housenumber || '',
            localitate: result.city || result.county || '',
            judet: result.state || '',
            codPostal: result.postcode || '',
            tara: result.country || '',
            lat: result.lat || null,
            lng: result.lon || null,
        };
        res.json({ address });
    }
    catch (err) {
        console.error('Eroare la Geoapify reverse:', err.response?.data || err.message);
        res.status(500).json({ error: 'Error fetching reverse geocode from Geoapify' });
    }
});
exports.default = router;
//# sourceMappingURL=places.js.map