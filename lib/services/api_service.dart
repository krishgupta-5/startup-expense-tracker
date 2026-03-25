import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Secure API service for handling external API calls
///
/// This service centralizes API key management and provides a secure
/// way to make external API calls without exposing keys in the client code.
class ApiService {
  ApiService._();

  /// Get Gemini API key securely from environment variables
  static String get _geminiApiKey {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      throw Exception(
        'Gemini API key not configured. Please set GEMINI_API_KEY in your environment variables.',
      );
    }
    return apiKey;
  }

  /// Get API key for vision calls (exposed securely for vision API usage)
  static String get geminiApiKey => _geminiApiKey;

  /// Make a secure API call to Gemini
  ///
  /// [prompt] - The prompt to send to Gemini
  /// [model] - The Gemini model to use (defaults to gemini-3-flash-preview)
  /// Returns the response text from Gemini
  static Future<String> callGeminiAPI(
    String prompt, {
    String model = 'gemini-3-flash-preview',
  }) async {
    try {
      final apiKey = _geminiApiKey;
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ??
            'No response received.';
      } else {
        throw Exception(
          'Gemini API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to call Gemini API: $e');
    }
  }

  /// Validate if API key is properly configured
  ///
  /// Returns true if API key is configured, false otherwise
  static bool isApiKeyConfigured() {
    try {
      _geminiApiKey;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get configuration status for debugging
  ///
  /// Returns a map with configuration status
  static Map<String, dynamic> getConfigurationStatus() {
    return {
      'geminiConfigured': isApiKeyConfigured(),
      'hasEnvFile': dotenv.env.isNotEmpty,
      'envVars': dotenv.env.keys.toList(),
    };
  }
}
