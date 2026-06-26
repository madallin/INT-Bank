import { Request, Response, NextFunction } from 'express';
import { Pool } from 'pg';
/**
 * Validated address object attached to the request.
 */
export interface ValidatedAddress {
    placeId: string;
    strada: string;
    numar: string;
    bloc: string;
    scara: string;
    apartament: string;
    localitate: string;
    judet: string;
    codPostal: string;
    formattedAddress: string;
    lat: null;
    lng: null;
}
/** Extends Express Request to include the validated address. */
export interface AddressValidationRequest extends Request {
    addressValidated?: ValidatedAddress;
    pool?: Pool;
}
/**
 * Middleware de validare a adresei.
 * Așteaptă în req.body: { placeId, strada, numar, bloc, scara, apartament, localitate, judet, codPostal }
 * La succes, adaugă req.addressValidated la obiectul standardizat.
 * La eșec, returnează 400 cu eroarea.
 */
export declare function validateAddress(req: AddressValidationRequest, res: Response, next: NextFunction): Promise<void>;
//# sourceMappingURL=addressValidation.d.ts.map