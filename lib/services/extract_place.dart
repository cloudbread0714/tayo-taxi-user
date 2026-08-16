import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Picks a Korean place name from speech text using Places Autocomplete.
/// Uses GOOGLE_API_KEY from local .env. No billed LLM key.
Future<String?> extractPlaceName(String inputText) async {
  final apiKey = dotenv.env['GOOGLE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) return null;

  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/autocomplete/json',
    {
      'input': inputText,
      'key': apiKey,
      'language': 'ko',
      'components': 'country:kr',
    },
  );

  try {
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data is! Map) return null;

    final predictions = data['predictions'];
    if (predictions is! List || predictions.isEmpty) return null;

    final first = predictions.first;
    if (first is! Map) return null;

    final structured = first['structured_formatting'];
    if (structured is Map && structured['main_text'] is String) {
      final name = (structured['main_text'] as String).trim();
      if (name.isNotEmpty) return name;
    }

    final description = first['description'];
    if (description is String && description.trim().isNotEmpty) {
      return description.trim();
    }
    return null;
  } catch (_) {
    return null;
  }
}
