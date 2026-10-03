import 'package:dio/dio.dart';
import '../../l10n/l10n.dart';

/// Maps an exception to a message that is safe to show to the customer.
///
/// Raw exception text (URLs, hosts, stack details) must never reach the UI.
/// A server-provided `error` string is used when present, since the backend
/// already returns customer-facing Romanian messages there.
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

String? _messageForResponse(Response<dynamic>? response)
{
  final data = response?.data;
  if(data is Map && data['error'] is String && (data['error'] as String).trim().isNotEmpty)
  {
    return data['error'] as String;
  }

  final status = response?.statusCode ?? 0;
  if(status == 401) return AppL10n.current.errorsSesiuneaExpiratAutentificaNou;
  if(status == 403) return AppL10n.current.errorsPermisiuneaAceastaOperatiune;
  if(status == 404) return AppL10n.current.errorsResursaSolicitataFostGasita;
  if(status == 429) return AppL10n.current.errorsPreaMulteIncercariAsteapta;
  if(status >= 500) return AppL10n.current.errorsServiciulEsteTemporarIndisponibil;
  return null;
}
