// db/seed_localitati.js
// Rulează o singură dată: node db/seed_localitati.js
// Populează tabela `localitati_referinta` cu județele și localitățile din judete.json

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { Pool } = require('pg');
const fs = require('fs');

const pool = new Pool({
  host: process.env.PGHOST,
  port: process.env.PGPORT ? Number(process.env.PGPORT) : 5432,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  database: process.env.PGDATABASE,
});

async function seed() {
  const client = await pool.connect();
  try {
    // Citește judete.json
    const jsonPath = path.join(__dirname, '..', '..', 'internet_banking', 'assets', 'judete.json');
    const raw = fs.readFileSync(jsonPath, 'utf-8');
    const data = JSON.parse(raw);

    console.log(`Se procesează ${data.length} județe...`);

    let totalInserted = 0;

    for (const item of data) {
      const judet = item.judet;
      const localitati = item.localitati || [];

      for (const localitate of localitati) {
        try {
          await client.query(
            `INSERT INTO localitati_referinta (judet, localitate)
             VALUES ($1, $2)
             ON CONFLICT (judet, localitate) DO NOTHING`,
            [judet, localitate]
          );
          totalInserted++;
        } catch (err) {
          console.error(`Eroare la inserarea ${localitate}, ${judet}:`, err.message);
        }
      }
    }

    console.log(`✅ S-au inserat ${totalInserted} localități în localitati_referinta.`);
  } catch (err) {
    console.error('Eroare la seed:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
