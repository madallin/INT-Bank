'use strict';

const fetch = require('node-fetch');

async function getRates(baseCurrency) {
  try {
    const url = `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${baseCurrency.toLowerCase()}.json`;
    const fallback = `https://latest.currency-api.pages.dev/v1/currencies/${baseCurrency.toLowerCase()}.json`;

    let res = await fetch(url);
    if (!res.ok) res = await fetch(fallback);
    if (!res.ok) throw new Error('Nu s-a putut prelua curs valutar');

    const data = await res.json();
    return data[baseCurrency.toLowerCase()]; // obiect cu rate
  } catch (err) {
    console.error('Eroare la fetch curs valutar:', err);
    throw err;
  }
}

async function convertCurrency(amount, fromCurrency, toCurrency) {
  if (fromCurrency === toCurrency) return amount;
  const rates = await getRates(fromCurrency);
  const rate = rates[toCurrency.toLowerCase()];
  if (!rate) throw new Error(`Nu există curs pentru ${fromCurrency} → ${toCurrency}`);
  return parseFloat((amount * rate).toFixed(2));
}

module.exports = { getRates, convertCurrency };
