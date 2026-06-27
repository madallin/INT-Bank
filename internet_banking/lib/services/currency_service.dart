import '../core/network/dio_client.dart';

class CurrencyService
{
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  final DioClient _client = DioClient();

  bool _hasRates = false;
  Map<String, Map<String, double>> _rates = {};
  double _commissionPercent = 1.0;

  bool get hasRates => _hasRates;
  Map<String, Map<String, double>>? get rates => _hasRates ? _rates : null;
  double get commissionPercent => _commissionPercent;

  Future<void> fetchRates() async
  {
    try
    {
      final response = await _client.get('/currency/api/v1/exchange-rates');

      if(response.statusCode == 200)
{
        final data = response.data as Map<String, dynamic>;
        final rawRates = data['rates'] as Map<String, dynamic>;
        _rates = {};

        for(final entry in rawRates.entries)
{
          final fromCurrency = entry.key;
          final toRates = entry.value as Map<String, dynamic>;
          _rates[fromCurrency] = {};

          for(final toEntry in toRates.entries)
{
            final toCurrency = toEntry.key;
            _rates[fromCurrency]![toCurrency] = (toEntry.value as num).toDouble();
          }
        }

        if(data['commission_percent'] != null)
{
          _commissionPercent = (data['commission_percent'] as num).toDouble();
        }

        _hasRates = true;
      }
    }
    catch(e)
{
      _hasRates = false;
    }
  }

  double? getRate(String from, String to)
  {
    if(!_hasRates) return null;
    if(from == to) return 1.0;

    if(_rates.containsKey(from) && _rates[from]!.containsKey(to))
{
      return _rates[from]![to];
    }

    if(_rates.containsKey(to) && _rates[to]!.containsKey(from))
{
      final inverseRate = _rates[to]![from];
      return inverseRate != 0 ? 1.0 / inverseRate! : null;
    }

    return null;
  }

  double? convert(double amount, String from, String to)
  {
    final rate = getRate(from, to);
    if(rate == null) return null;

    final effectiveRate = rate * (1 - _commissionPercent / 100);
    return amount * effectiveRate;
  }
}
