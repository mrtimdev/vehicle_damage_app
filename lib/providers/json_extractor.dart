import 'dart:convert';

/// Models sometimes wrap JSON in ```json fences or add stray text despite
/// instructions. This strips fences and grabs the first {...} block so
/// parsing doesn't explode.
Map<String, dynamic> extractJsonObject(String raw) {
  String text = raw.trim();

  // Strip markdown code fences if present.
  text = text.replaceAll(RegExp(r'^```(json)?', multiLine: true), '');
  text = text.replaceAll(RegExp(r'```$', multiLine: true), '');
  text = text.trim();

  // If there's leading/trailing prose, isolate the first balanced { ... }.
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    text = text.substring(start, end + 1);
  }

  try {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // fall through to error below
  }
  throw FormatException('Could not parse model response as JSON:\n$raw');
}
