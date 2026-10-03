import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../l10n/l10n.dart';

/// Field rules for the transfer form. Each method returns a Romanian message
/// for the field, or null when the value is valid.
abstract final class TransferFormValidator
{
  /// Bank code of INT Bank's own accounts (`RO..INTB....`).
  static const internalBankCode = 'INTB';

  /// SEPA limit for the beneficiary name.
  static const maxNameLength = 70;
  static const maxReasonLength = 140;

  static String normalizeIban(String raw) => raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// True for IBANs issued by INT Bank itself.
  ///
  /// The current backend issues these with a non-standard length and, for
  /// currency sub-accounts, a fixed `49` check value, so they cannot pass the
  /// ISO 13616 checks. The server resolves them by exact lookup instead.
  static bool isInternalIban(String iban)
  {
    final c = normalizeIban(iban);
    return c.length > 8 && c.startsWith('RO') && c.substring(4, 8) == internalBankCode;
  }

  /// ISO 13616 / ISO 7064 MOD 97-10 check, for an IBAN from any country.
  static bool hasValidChecksum(String iban)
  {
    final c = normalizeIban(iban);
    if(!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(c)) return false;
    final rearranged = c.substring(4) + c.substring(0, 4);
    var remainder = 0;
    for(final unit in rearranged.codeUnits)
    {
      final digits = unit <= 57 ? '${unit - 48}' : '${unit - 55}';
      for(final d in digits.codeUnits)
      {
        remainder = (remainder * 10 + (d - 48)) % 97;
      }
    }
    return remainder == 1;
  }

  static String? iban(String raw, {String? ownIban})
  {
    final c = normalizeIban(raw);
    if(c.isEmpty) return AppL10n.current.transferValidationIntroduIbanUlDestinatarului;
    if(!RegExp(r'^[A-Z]{2}\d{2}').hasMatch(c))
    {
      return AppL10n.current.transferValidationIbanUlIncepeCodul;
    }
    if(!RegExp(r'^[A-Z0-9]+$').hasMatch(c)) return AppL10n.current.transferValidationIbanUlPoateContine;
    if(c.length < 15 || c.length > 34) return AppL10n.current.transferValidationIbanUlAreLungime;
    if(ownIban != null && ownIban.isNotEmpty && c == normalizeIban(ownIban))
    {
      return AppL10n.current.transferValidationAcestaEsteContulCare;
    }
    if(isInternalIban(c)) return null;
    if(c.startsWith('RO'))
    {
      if(c.length != 24)
      {
        return AppL10n.current.transferValidationIbanRomanescAre24(c.length);
      }
      if(!Validators.isValidRomanianIban(c))
      {
        return AppL10n.current.transferValidationIbanUlEsteValid;
      }
      return null;
    }
    if(!hasValidChecksum(c))
    {
      return AppL10n.current.transferValidationIbanUlEsteValid;
    }
    return null;
  }

  static String? beneficiaryName(String raw)
  {
    final name = raw.trim();
    if(name.isEmpty) return AppL10n.current.transferValidationIntroduNumeleBeneficiarului;
    if(name.length < 2) return AppL10n.current.transferValidationNumeleEstePreaScurt;
    if(name.length > maxNameLength) return AppL10n.current.transferValidationNumelePoateAveaCel(maxNameLength);
    if(!RegExp(r'\p{L}', unicode: true).hasMatch(name)) return AppL10n.current.transferValidationNumeleTrebuieSaContina;
    return null;
  }

  static String? amount(double? value, {double? available, String currency = 'RON'})
  {
    if(value == null || value <= 0) return AppL10n.current.transferValidationIntroduSumaMaiMare;
    if(available != null && value > available)
    {
      return AppL10n.current.transferValidationSoldInsuficientDisponibil(formatMoney(available, currency));
    }
    return null;
  }

  static String? reason(String raw)
  {
    final reason = raw.trim();
    if(reason.isEmpty) return AppL10n.current.transferValidationDescrieScurtPlataEx;
    if(reason.length < 3) return AppL10n.current.transferValidationDetaliilePlatiiTrebuieSa;
    if(reason.length > maxReasonLength) return AppL10n.current.transferValidationDetaliilePotAveaCel(maxReasonLength);
    return null;
  }
}
