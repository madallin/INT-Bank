class LocationData
{
  final String city;
  final String county;
  final String country;
  final String? street;
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  LocationData({
    required this.city,
    required this.county,
    required this.country,
    this.street,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  factory LocationData.fromJson(Map<String, dynamic> json)
  {
    return LocationData(
      city: json['city'] ?? '',
      county: json['county'] ?? '',
      country: json['country'] ?? '',
      street: json['street'],
      postalCode: json['postalCode'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

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
