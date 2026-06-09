// lib/data/models/location_data.dart
// Romanian county (județ) and locality data management

import 'dart:convert' show json;
import 'package:flutter/services.dart' show rootBundle;

List<Map<String, dynamic>> judete = [];
Map<String, List<String>> mapLocalitati = {};

/// Loads the judete.json asset and populates [judete] and [mapLocalitati].
Future<void> loadJudete() async {
  final jsonString = await rootBundle.loadString('assets/judete.json');
  final List<dynamic> data = json.decode(jsonString);

  judete = data.cast<Map<String, dynamic>>();

  mapLocalitati = {
    for (final item in judete)
      item['judet'] as String: (List<String>.from(item['localitati'])..sort()),
  };
}
