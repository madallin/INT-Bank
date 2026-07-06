import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig
{
  static String get serverUrl => dotenv.env['SERVER_URL'] ?? 'localhost';

  static int get serverPort => int.tryParse(dotenv.env['SERVER_PORT'] ?? '') ?? 8443;

  static String get baseUrl => serverPort == 443
      ? 'https://$serverUrl'
      : 'https://$serverUrl:$serverPort';

  static String get wsUrl => 'wss://$serverUrl';
}

const int lightForestGreenColor = 0xFF00695C;
const int darkForestGreenColor = 0xFF1B5E20;
const int darkGreyColor = 0xFF1F2937;
