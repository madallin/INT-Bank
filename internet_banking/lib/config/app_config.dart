class AppConfig
{
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'localhost',
  );

  static const int serverPort = int.fromEnvironment(
    'SERVER_PORT',
    defaultValue: 8443,
  );
}

const int lightForestGreenColor = 0xFF00695C;
const int darkForestGreenColor = 0xFF1B5E20;
const int darkGreyColor = 0xFF1F2937;
