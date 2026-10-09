import 'package:dio/dio.dart';
import '../../l10n/l10n.dart';

/// Maps an exception to a message that is safe to show to the customer.
///
/// Raw exception text (URLs, hosts, stack details) must never reach the UI.
/// A known server `code` is translated first; otherwise the server-provided
/// `error` string is used in Romanian (the backend writes Romanian prose), and an
/// app message in the user's language otherwise.
String friendlyErrorMessage(
  Object error, {
  String? fallback,
})
{
  fallback ??= AppL10n.current.errorsAparutEroareNeasteptataIncearca;
  if(error is! DioException) return fallback;

  switch(error.type)
  {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return AppL10n.current.errorsServerulRaspundeIncearcaNou;
    case DioExceptionType.connectionError:
      return AppL10n.current.errorsPotiConectaServerVerifica;
    case DioExceptionType.badCertificate:
      return AppL10n.current.errorsConexiuneaEsteSiguraOperatiunea;
    case DioExceptionType.cancel:
      return AppL10n.current.errorsOperatiuneaFostAnulata;
    case DioExceptionType.badResponse:
      return _messageForResponse(error.response) ?? fallback;
    case DioExceptionType.unknown:
      return fallback;
  }
}

/// Stable machine codes the backend attaches to business-rule rejections.
String? _messageForCode(Object? code, Map<dynamic, dynamic> data)
{
  final l10n = AppL10n.current;
  switch(code)
  {
    case 'SCA_PIN_INVALID':
      final remaining = data['remainingAttempts'];
      return remaining is int ? l10n.errorsCodeScaPinInvalid(remaining) : null;
    case 'QUOTE_EXPIRED':
      return l10n.errorsCodeQuoteExpired;
    case 'VAULT_LOCKED':
      return l10n.errorsCodeVaultLocked;
    case 'VAULT_NOT_FOUND':
      return l10n.errorsCodeVaultNotFound;
    case 'VAULT_INVALID':
      return l10n.errorsCodeVaultInvalid;
    case 'DESTINATION_NOT_FOUND':
      return l10n.errorsCodeDestinationNotFound;
    case 'SCA_LOCKED':
      return l10n.errorsCodeScaLocked;
    case 'SCA_CHALLENGE_INVALID':
      return l10n.errorsCodeScaChallengeInvalid;
    case 'CURRENCY_MISMATCH':
      return l10n.errorsCodeCurrencyMismatch;
    case 'INSUFFICIENT_FUNDS':
      return l10n.errorsCodeInsufficientFunds;
    case 'ACCOUNT_NOT_OWNED':
      return l10n.errorsCodeAccountNotOwned;
    case 'SAME_ACCOUNT':
      return l10n.errorsCodeSameAccount;
    case 'UNSUPPORTED_CURRENCY_PAIR':
      return l10n.errorsCodeUnsupportedPair;
    case 'INVALID_AMOUNT':
      return l10n.errorsCodeInvalidAmount;
  }
  return null;
}

/// The message to show for a server reply body: a translated message for a known
/// `code`; otherwise the server's own `error` text, but only in Romanian (the
/// language the server writes in); otherwise [fallback].
String serverMessage(Object? data, String fallback) => _serverText(data) ?? fallback;

String? _serverText(Object? data)
{
  if(data is! Map) return null;
  final coded = _messageForCode(data['code'], data);
  if(coded != null) return coded;
  final error = data['error'];
  final speaksRomanian = AppL10n.current.localeName.startsWith('ro');
  if(speaksRomanian && error is String && error.trim().isNotEmpty) return error;
  return null;
}

String? _messageForResponse(Response<dynamic>? response)
{
  final data = response?.data;
  final text = _serverText(data);
  if(text != null) return text;

  final status = response?.statusCode ?? 0;
  if(status == 401) return AppL10n.current.errorsSesiuneaExpiratAutentificaNou;
  if(status == 403) return AppL10n.current.errorsPermisiuneaAceastaOperatiune;
  if(status == 404) return AppL10n.current.errorsResursaSolicitataFostGasita;
  if(status == 429) return AppL10n.current.errorsPreaMulteIncercariAsteapta;
  if(status >= 500) return AppL10n.current.errorsServiciulEsteTemporarIndisponibil;
  return null;
}
