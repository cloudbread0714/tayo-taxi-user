import 'package:cloud_functions/cloud_functions.dart';

const _functionsRegion = 'asia-northeast3';

/// Extracts a Korean place name from speech text via Cloud Functions.
/// The Gemini key stays on the server.
Future<String?> extractPlaceName(String inputText) async {
  final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
      .httpsCallable('extractPlaceName');

  try {
    final result = await callable.call(<String, dynamic>{
      'inputText': inputText,
    });
    final data = result.data;
    if (data is! Map) return null;
    final place = data['place'];
    if (place is! String) return null;

    final cleaned = place.replaceAll('\n', '').trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == 'none') {
      return null;
    }
    return cleaned;
  } on FirebaseFunctionsException {
    return null;
  }
}
