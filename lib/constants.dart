import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// iHRIS API Configuration loaded strictly from .env
String get ihrisApiBaseUrl {
  final url = dotenv.env['IHRIS_API_BASE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '';
  if (url.isEmpty) {
    debugPrint("WARNING: IHRIS_API_BASE_URL is not configured in .env!");
  }
  return url;
}

String get ihrisLoginEndpoint {
  final endpoint = dotenv.env['IHRIS_LOGIN_ENDPOINT'] ?? dotenv.env['LOGIN_ENDPOINT'] ?? '/login';
  return endpoint.startsWith('/') ? endpoint : '/$endpoint';
}

String get ihrisLoginUrl {
  final base = ihrisApiBaseUrl.endsWith('/')
      ? ihrisApiBaseUrl.substring(0, ihrisApiBaseUrl.length - 1)
      : ihrisApiBaseUrl;
  return '$base$ihrisLoginEndpoint';
}

// Global Aliases mapped to iHRIS API .env getters
String get baseUrl => ihrisApiBaseUrl;
String get loginEndpoint => ihrisLoginEndpoint;
String get loginUrl => ihrisLoginUrl;

String get appName => dotenv.env['APP_NAME'] ?? 'Document Management System';

// Legacy IP helper
String get ipAddress {
  final uri = Uri.tryParse(ihrisApiBaseUrl);
  if (uri != null && uri.host.isNotEmpty) {
    return uri.port != 0 && uri.port != 80 && uri.port != 443
        ? '${uri.host}:${uri.port}'
        : uri.host;
  }
  return '';
}

// Modern Enterprise Color Palette (Unbranded, Sleek & Professional)
const Color primaryDark = Color(0xFF0F172A); // Slate 900
const Color surfaceDark = Color(0xFF1E293B); // Slate 800
const Color primaryIndigo = Color(0xFF6366F1); // Indigo 500
const Color primaryIndigoDark = Color(0xFF4F46E5); // Indigo 600
const Color accentSky = Color(0xFF38BDF8); // Sky 400

// Compatibility aliases
const Color primaryRed = Color(0xFF4F46E5);
const Color primaryYellow = Color(0xFF38BDF8);
const Color textYellow = Color(0xFF818CF8);
const Color errorColor = Color(0xFFEF4444);
