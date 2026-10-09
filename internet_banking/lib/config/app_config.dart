import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig
{
  /// Shown on the Profile tab; kept equal to `version` in pubspec.yaml (checked by a test).
  static const appVersion = '1.0.0';

  static String get serverUrl {
    try {
      return dotenv.isInitialized ? (dotenv.env['SERVER_URL'] ?? 'localhost') : 'localhost';
    } catch (_) {
      return 'localhost';
    }
  }

  static int get serverPort {
    try {
      return dotenv.isInitialized ? (int.tryParse(dotenv.env['SERVER_PORT'] ?? '') ?? 8443) : 8443;
    } catch (_) {
      return 8443;
    }
  }

  static String get baseUrl => serverPort == 443
      ? 'https://$serverUrl'
      : 'https://$serverUrl:$serverPort';

  /// Approval notifications socket (same host and port as the API).
  static String get wsUrl => serverPort == 443
      ? 'wss://$serverUrl/ws/approval'
      : 'wss://$serverUrl:$serverPort/ws/approval';

  /// SHA-256 pins of the server's TLS certificate (comma separated hex, colons allowed),
  /// from CERT_SHA256_PINS. Empty: normal certificate validation, no pinning.
  /// Include the next certificate's pin before rotating the server certificate.
  static List<String> get certificatePins {
    try {
      final raw = dotenv.isInitialized ? (dotenv.env['CERT_SHA256_PINS'] ?? '') : '';
      return raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }
}

const int lightForestGreenColor = 0xFF00695C;
const int darkForestGreenColor = 0xFF1B5E20;
const int darkGreyColor = 0xFF1F2937;
