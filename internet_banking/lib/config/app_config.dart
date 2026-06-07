// lib/config/app_config.dart
// Application configuration — colors, server URLs, constants

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ---- Colors ----
const int lightForestGreenColor = 0xFF0D9488;
const int darkForestGreenColor = 0xFF00695C;
const int lightGreyColor = 0xFF6B7280;
const int darkGreyColor = 0xFF333333;

// ---- Server Configuration ----
/// Loaded from internet_banking/.env at runtime via flutter_dotenv.
/// Falls back to 'localhost:8443' if .env is missing or SERVER_URL is not set.
String get serverUrl => dotenv.get('SERVER_URL', fallback: 'localhost:8443');

// ---- App Constants ----
const int pinLength = 6;
const int cardFlipDurationSeconds = 60;
const int splashDelaySeconds = 4;
