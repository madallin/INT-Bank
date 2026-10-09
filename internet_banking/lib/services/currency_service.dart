import '../core/network/dio_client.dart';

class CurrencyService
{
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  final DioClient _client = DioClient();

  bool _hasRates = false;
  Map<String, Map<String, double>> _rates = {};
  double _commissionPercent = 0.0;

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
        _rates = parseRates(data);

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

  /// The server sends units of each currency for one unit of `base`:
  /// `{"base": "RON", "rates": {"RON": 1.0, "EUR": 0.201}}`. Every pair is derived
  /// from that (EUR -> USD = rates[USD] / rates[EUR]). A nested
  /// `{"RON": {"EUR": 0.201}}` map is accepted too.
  static Map<String, Map<String, double>> parseRates(Map<String, dynamic> data)
  {
    final raw = data['rates'];
    final result = <String, Map<String, double>>{};
    if(raw is! Map) return result;
    if(raw.values.every((v) => v is num))
    {
      final base = data['base']?.toString() ?? 'RON';
      final perBase = <String, double>{base: 1.0};
      raw.forEach((k, v) => perBase[k.toString()] = (v as num).toDouble());
      for(final from in perBase.keys)
      {
        result[from] = {
          for(final to in perBase.keys)
            if(perBase[from]! > 0) to: perBase[to]! / perBase[from]!,
        };
      }
      return result;
    }
    raw.forEach((from, targets)
    {
      if(targets is Map)
      {
        result[from.toString()] = {
          for(final t in targets.entries)
            if(t.value is num) t.key.toString(): (t.value as num).toDouble(),
        };
      }
    });
    return result;
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
