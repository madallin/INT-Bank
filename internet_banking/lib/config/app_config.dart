class AppConfig
{
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'api-internet-banking.onrender.com',
  );

  static const int serverPort = int.fromEnvironment(
    'SERVER_PORT',
    defaultValue: 3000,
  );
}

const int lightForestGreenColor = 0xFF2E7D32;
const int darkForestGreenColor = 0xFF1B5E20;
const int darkGreyColor = 0xFF1F2937;
