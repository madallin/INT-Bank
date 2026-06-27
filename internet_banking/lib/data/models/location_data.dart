import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_data.freezed.dart';
part 'location_data.g.dart';

@freezed
class LocationData with _$LocationData
{
  const factory LocationData({
    required String city,
    required String county,
    required String country,
    String? street,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) = _LocationData;

  factory LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);
}

extension LocationDataGetters on LocationData
{
  String get displayAddress
  {
    final parts = <String>[];
    if(street != null && street!.isNotEmpty) parts.add(street!);
    parts.add(city);
    parts.add(county);
    if(postalCode != null && postalCode!.isNotEmpty)
    {
      parts.add(postalCode!);
    }
    parts.add(country);
    return parts.join(', ');
  }
}
