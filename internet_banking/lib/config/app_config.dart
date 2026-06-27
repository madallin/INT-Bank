import 'package:flutter_dotenv/flutter_dotenv.dart';

String get serverUrl => dotenv.get('SERVER_URL', fallback: '192.168.1.103:3000');
int get serverPort => int.tryParse(dotenv.get('SERVER_PORT', fallback: '3000')) ?? 3000;

const int lightForestGreenColor = 0xFF2E7D32;
const int darkForestGreenColor = 0xFF1B5E20;
const int darkGreyColor = 0xFF1F2937;
