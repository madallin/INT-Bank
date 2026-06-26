import { Router, Request, Response } from 'express';
import axios from 'axios';

const router = Router();
const GEOAPIFY_BASE = 'https://api.geoapify.com/v1/geocode';

router.get('/autocomplete', async (req: Request, res: Response) =>
{
  const { text, locality } = req.query;
  if(!text)
  {
    res.status(400).json({ error: 'Missing text query' });
    return;
  }

  const apiKey = process.env.GEOAPIFY_KEY;
  if(!apiKey)
  {
    res.status(500).json({ error: 'Geoapify API key not configured' });
    return;
  }

  try
  {
    const params: Record<string, any> = {
      text,
      type: 'street',
      format: 'json',
      lang: 'ro',
      apiKey,
      filter: 'countrycode:ro',
    };

    if(locality)
    {
      params.text = `${text}, ${locality}`;
    }

    const geoapifyRes = await axios.get(`${GEOAPIFY_BASE}/autocomplete`, { params });

    const results = geoapifyRes.data?.results || [];

    const predictions = results.map((r: any) => ({
      place_id: r.place_id,
      description: r.place_id
        ? (() =>
        {
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
  catch (err: any)
  {
    console.error('Eroare la Geoapify autocomplete:', err.response?.data || err.message);
    res.status(500).json({ error: 'Error fetching from Geoapify' });
  }
});

router.get('/details', async (req: Request, res: Response) =>
{
  const { place_id } = req.query;
  if(!place_id)
  {
    res.status(400).json({ error: 'Missing place_id query' });
    return;
  }

  const apiKey = process.env.GEOAPIFY_KEY;
  if(!apiKey)
  {
    res.status(500).json({ error: 'Geoapify API key not configured' });
    return;
  }

  try
  {
    const geoapifyRes = await axios.get(`${GEOAPIFY_BASE}/search`, {
      params: {
        id: place_id,
        format: 'json',
        lang: 'ro',
        apiKey,
      },
    });

    const results = geoapifyRes.data?.results || [];
    if(results.length === 0)
    {
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
  catch (err: any)
  {
    console.error('Eroare la Geoapify details:', err.response?.data || err.message);
    res.status(500).json({ error: 'Error fetching place details from Geoapify' });
  }
});

router.get('/reverse', async (req: Request, res: Response) =>
{
  const { lat, lon } = req.query;
  if(!lat || !lon)
  {
    res.status(400).json({ error: 'Missing lat/lon query' });
    return;
  }

  const apiKey = process.env.GEOAPIFY_KEY;
  if(!apiKey)
  {
    res.status(500).json({ error: 'Geoapify API key not configured' });
    return;
  }

  try
  {
    const geoapifyRes = await axios.get(`${GEOAPIFY_BASE}/reverse`, {
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
    if(results.length === 0)
    {
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
  catch (err: any)
  {
    console.error('Eroare la Geoapify reverse:', err.response?.data || err.message);
    res.status(500).json({ error: 'Error fetching reverse geocode from Geoapify' });
  }
});

export default router;
