import
{
    Controller,
    Get,
    Query,
    Logger,
} from '@nestjs/common';
import axios from 'axios';

const GEOAPIFY_BASE = 'https://api.geoapify.com/v1/geocode';

@Controller('places')
export class PlacesController
{
    private readonly logger = new Logger(PlacesController.name);

    @Get('autocomplete')
    async autocomplete(@Query() query: { text?: string; locality?: string })
    {
        const { text, locality } = query;
        if(!text)
        {
            return { statusCode: 400, error: 'Missing text query' };
        }

        const apiKey = process.env.GEOAPIFY_KEY;
        if(!apiKey)
        {
            return { statusCode: 500, error: 'Geoapify API key not configured' };
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

            const geoapifyRes = await axios.get(
                `${GEOAPIFY_BASE}/autocomplete`,
                { params },
            );

            const results = geoapifyRes.data?.results || [];

            const predictions = results.map((r: any) =>
            {
                const streetPart = r.street
                    ? [r.street, r.housenumber].filter(Boolean).join(', ')
                    : (r.address_line1 || r.formatted || '').split(',')[0]?.trim() || '';
                const postcode = r.postcode ? ` (${r.postcode})` : '';
                return {
                    place_id: r.place_id,
                    description: r.place_id
                        ? (streetPart + postcode || r.formatted || '')
                        : '',
                    strada: r.street || (r.address_line1 || '').split(',')[0]?.trim() || '',
                    numar: r.housenumber || '',
                    localitate: r.city || r.county || '',
                    judet: r.state || '',
                    codPostal: r.postcode || '',
                    tara: r.country || '',
                };
            });

            return { predictions };
        }
        catch (err: any)
        {
            this.logger.error(err, 'Eroare la Geoapify autocomplete');
            return { statusCode: 500, error: 'Error fetching from Geoapify' };
        }
    }

    @Get('details')
    async details(@Query() query: { place_id?: string })
    {
        const { place_id } = query;
        if(!place_id)
        {
            return { statusCode: 400, error: 'Missing place_id query' };
        }

        const apiKey = process.env.GEOAPIFY_KEY;
        if(!apiKey)
        {
            return { statusCode: 500, error: 'Geoapify API key not configured' };
        }

        try
        {
            const geoapifyRes = await axios.get(`${GEOAPIFY_BASE}/search`, {
                params: { id: place_id, format: 'json', lang: 'ro', apiKey },
            });

            const results = geoapifyRes.data?.results || [];
            if(results.length === 0)
            {
                return { statusCode: 404, error: 'Place not found' };
            }

            const result = results[0];
            return {
                address: {
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
                },
            };
        }
        catch (err: any)
        {
            this.logger.error(err, 'Eroare la Geoapify details');
            return { statusCode: 500, error: 'Error fetching place details from Geoapify' };
        }
    }

    @Get('reverse')
    async reverse(@Query() query: { lat?: string; lon?: string })
    {
        const { lat, lon } = query;
        if(!lat || !lon)
        {
            return { statusCode: 400, error: 'Missing lat/lon query' };
        }

        const apiKey = process.env.GEOAPIFY_KEY;
        if(!apiKey)
        {
            return { statusCode: 500, error: 'Geoapify API key not configured' };
        }

        try
        {
            const geoapifyRes = await axios.get(`${GEOAPIFY_BASE}/reverse`, {
                params: { lat, lon, format: 'json', lang: 'ro', limit: 1, apiKey },
            });

            const results = geoapifyRes.data?.results || [];
            if(results.length === 0)
            {
                return { statusCode: 404, error: 'No address found for these coordinates' };
            }

            const result = results[0];
            return {
                address: {
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
                },
            };
        }
        catch (err: any)
        {
            this.logger.error(err, 'Eroare la Geoapify reverse');
            return { statusCode: 500, error: 'Error fetching reverse geocode from Geoapify' };
        }
    }
}
